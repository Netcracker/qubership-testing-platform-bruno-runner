#!/usr/bin/env bats

load ../unit/test_helper

IMAGE="${BRUNO_RUNNER_IMAGE:-bruno-runner:test}"

setup() {
  # Use a Linux-native tmpfs path so Docker volume mounts are writable by uid 1007.
  WORK="$(docker run --rm --entrypoint sh "$IMAGE" -c 'mktemp -d')"
  # Stage a project root that local_start.sh expects: entrypoint.sh,
  # local-collection/, and tools/local_test_params.json.
  docker run --rm -u 0 \
    -v "${REPO_ROOT}:/src:ro" \
    -v "${WORK}:/work" \
    --entrypoint sh "$IMAGE" -c "
      cp /src/local_start.sh  /work/local_start.sh  && chmod 755 /work/local_start.sh
      cp /src/entrypoint.sh   /work/entrypoint.sh   && chmod 755 /work/entrypoint.sh
      cp -r /src/tests/fixtures/local-collection /work/local-collection
      mkdir -p /work/tools
      cp /src/tests/fixtures/local_test_params.json /work/tools/local_test_params.json
      mkdir -p /work/tmp_clone
      chown -R 1007:1007 /work
    "
  export WORK
}

teardown() {
  docker run --rm -u 0 -v "${WORK}:/work" --entrypoint sh "$IMAGE" -c "rm -rf /work" 2>/dev/null || true
}

@test "local_start: container-mode local_start.sh reaches local_run branch" {
  run docker run --rm \
    -u 1007 \
    -v "${WORK}:/app" \
    -v "${WORK}/tmp_clone:/tmp/clone" \
    -w /app \
    -e ATP_STORAGE_USERNAME=dummy \
    -e ATP_STORAGE_PASSWORD=dummy \
    --entrypoint bash \
    "$IMAGE" /app/local_start.sh 2>&1 || true

  # local_start.sh exports LOCAL_RUN=true, so entrypoint.sh should hit local_run_tests
  # which prints one of these markers (see tools/bru_tools.sh::local_run_tests).
  [[ "$output" == *"Starting test execution"* ]] || \
  [[ "$output" == *"Running test suite"* ]] || \
  [[ "$output" == *"Launching Bruno collections"* ]]
}
