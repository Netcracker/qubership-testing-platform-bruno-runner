#!/usr/bin/env bats
# E2E tests for run_bruno_from_test_params + run_collection_body dispatcher logic.
# Each test mounts tests/fixtures/run_dispatcher.sh as the container entrypoint
# and varies only the -e flags passed to docker run.

load ../unit/test_helper

IMAGE="${BRUNO_RUNNER_IMAGE:-bruno-runner:test}"
DISPATCHER_SCRIPT="${REPO_ROOT}/tests/fixtures/run_dispatcher.sh"

_docker_run() {
  # Usage: _docker_run [extra docker -e flags...] -- extra_env_pairs
  # All positional args are passed verbatim before the image name.
  docker run --rm -u 1007 \
    -v "${WORK}:/tmp/work" \
    -v "${DISPATCHER_SCRIPT}:/run_dispatcher.sh:ro" \
    "$@" \
    --entrypoint bash \
    "$IMAGE" /run_dispatcher.sh 2>&1 || true
}

setup() {
  WORK="$(docker run --rm --entrypoint sh "$IMAGE" -c 'mktemp -d')"

  # Stage fixture as collections/local-collection/ (the path dispatcher expects)
  docker run --rm -u 0 \
    -v "${REPO_ROOT}/tests/fixtures:/src:ro" \
    -v "${WORK}:/work" \
    --entrypoint sh "$IMAGE" -c "
      mkdir -p /work/collections
      cp -r /src/local-collection /work/collections
      chown -R 1007:1007 /work
    "

  TEST_PARAMS='{"execution_list":[{"type":"collection","name":"collections/local-collection"}]}'
  MISSING_TEST_PARAMS='{"execution_list":[{"type":"collection","name":"collections/nonexistent"}]}'
  export WORK TEST_PARAMS MISSING_TEST_PARAMS
}

teardown() {
  docker run --rm -u 0 -v "${WORK}:/work" \
    --entrypoint sh "$IMAGE" -c "rm -rf /work" 2>/dev/null || true
}

@test "dispatcher: full-collection run produces result.json and allure results" {
  run _docker_run \
    -e TEST_PARAMS="$TEST_PARAMS" \
    -e BRUNO_ENV=local \
    -e BRUNO_FOLDERS="" \

  # result.json written under attachments/
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'test -f /work/attachments/local-collection-result.json && echo found || echo missing'
  [[ "$output" == "found" ]]

  # at least one allure result JSON
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'ls /work/allure-results/*-result.json 2>/dev/null | head -1'
  [[ -n "$output" ]]

  # environment.properties written
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'grep -c "BRUNO_ENV=" /work/allure-results/environment.properties'
  [[ "$output" -ge 1 ]]

  # tests_count.csv references the collection
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'grep -c "local-collection" /work/tests_count.csv'
  [[ "$output" -ge 1 ]]
}

@test "dispatcher: missing collection dir writes skipped allure placeholder" {
  run _docker_run \
    -e TEST_PARAMS="$MISSING_TEST_PARAMS" \
    -e BRUNO_ENV=local \
    -e BRUNO_FOLDERS="" \

  # no raw report produced
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'ls /work/attachments/nonexistent-result.json 2>/dev/null && echo found || echo missing'
  [[ "$output" == "missing" ]]

  # a skipped placeholder exists in allure-results
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'grep -rl "\"status\": \"skipped\"" /work/allure-results/*-result.json 2>/dev/null | head -1'
  [[ -n "$output" ]]
}

@test "dispatcher: folder-filter mode runs only matched folder" {
  run _docker_run \
    -e TEST_PARAMS="$TEST_PARAMS" \
    -e BRUNO_ENV=local \
    -e BRUNO_FOLDERS="smoke" \

  # bru was invoked against the smoke folder and produced a report
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'test -f /work/attachments/local-collection-result.json && echo found || echo missing'
  [[ "$output" == "found" ]]
}

@test "dispatcher: no-match folder filter writes skipped placeholder" {
  run _docker_run \
    -e TEST_PARAMS="$TEST_PARAMS" \
    -e BRUNO_ENV=local \
    -e BRUNO_FOLDERS="nonexistent-folder" \

  # no raw report
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'ls /work/attachments/local-collection-result.json 2>/dev/null && echo found || echo missing'
  [[ "$output" == "missing" ]]

  # placeholder with skipped status and "No matching folders found" message
  run docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" \
    -c 'grep -rl "\"status\": \"skipped\"" /work/allure-results/ 2>/dev/null | head -1'
  [[ -n "$output" ]]
}
