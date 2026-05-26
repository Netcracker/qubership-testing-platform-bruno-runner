#!/usr/bin/env bats
# E2E tests for discover_bruno_collections in scripts/tools/bru_tools.sh.
# Each test mounts a fixture script into the container and inspects stdout.

load ../unit/test_helper

IMAGE="${BRUNO_RUNNER_IMAGE:-bruno-runner:test}"

# Runs a one-shot container that sources bru_tools.sh, calls
# discover_bruno_collections, and prints every discovered path on its own line.
_run_discover() {
  # $@ — extra docker -v flags for staging the collections tree
  docker run --rm \
    "$@" \
    --entrypoint bash \
    "$IMAGE" -c '
      source /scripts/tools/bru_tools.sh
      discover_bruno_collections RESULT
      for p in "${RESULT[@]}"; do echo "$p"; done
    ' 2>&1 || true
}

# ── helpers ──────────────────────────────────────────────────────────────────

# Create a temp dir inside the container (owned by root is fine for read tests).
_mkwork() {
  docker run --rm --entrypoint sh "$IMAGE" -c 'mktemp -d'
}

# Populate $WORK with an arbitrary collections layout via a shell snippet.
_stage() {
  local snippet="$1"
  docker run --rm -u 0 \
    -v "${WORK}:/work" \
    --entrypoint sh "$IMAGE" -c "$snippet"
}

# ── setup / teardown ─────────────────────────────────────────────────────────

setup() {
  WORK="$(_mkwork)"
  export WORK
}

teardown() {
  docker run --rm -u 0 -v "${WORK}:/work" \
    --entrypoint sh "$IMAGE" -c "rm -rf /work" 2>/dev/null || true
}

# ── tests ─────────────────────────────────────────────────────────────────────

@test "discover_bruno_collections: finds single collection" {
  _stage "mkdir -p /work/collections/my-suite && touch /work/collections/my-suite/collection.bru"

  run _run_discover -v "${WORK}:/work" -w /work
  [[ "$output" == *"collections/my-suite"* ]]
}

@test "discover_bruno_collections: finds multiple collections sorted" {
  _stage "
    mkdir -p /work/collections/zebra /work/collections/apple
    touch /work/collections/zebra/collection.bru
    touch /work/collections/apple/collection.bru
  "

  run _run_discover -v "${WORK}:/work" -w /work

  # Extract only the discovered-path lines (suppress the emoji log line)
  mapfile -t lines < <(echo "$output" | grep '^collections/')
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "collections/apple" ]
  [ "${lines[1]}" = "collections/zebra" ]
}

@test "discover_bruno_collections: returns empty when no collection.bru present" {
  _stage "mkdir -p /work/collections/empty-suite"

  run _run_discover -v "${WORK}:/work" -w /work

  mapfile -t lines < <(echo "$output" | grep '^collections/')
  [ "${#lines[@]}" -eq 0 ]
}

@test "discover_bruno_collections: ignores collection.bru inside .git directories" {
  _stage "
    mkdir -p /work/collections/real-suite
    touch /work/collections/real-suite/collection.bru
    mkdir -p /work/collections/real-suite/.git/nested
    touch /work/collections/real-suite/.git/nested/collection.bru
  "

  run _run_discover -v "${WORK}:/work" -w /work

  mapfile -t lines < <(echo "$output" | grep '^collections/')
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "collections/real-suite" ]
}

@test "discover_bruno_collections: ignores collection.bru inside node_modules" {
  _stage "
    mkdir -p /work/collections/real-suite
    touch /work/collections/real-suite/collection.bru
    mkdir -p /work/collections/real-suite/node_modules/pkg
    touch /work/collections/real-suite/node_modules/pkg/collection.bru
  "

  run _run_discover -v "${WORK}:/work" -w /work

  mapfile -t lines < <(echo "$output" | grep '^collections/')
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "collections/real-suite" ]
}

@test "discover_bruno_collections: does not discover collection.bru at depth 1 (directly under collections/)" {
  _stage "
    mkdir -p /work/collections
    touch /work/collections/collection.bru
  "

  run _run_discover -v "${WORK}:/work" -w /work

  mapfile -t lines < <(echo "$output" | grep '^collections/')
  [ "${#lines[@]}" -eq 0 ]
}

@test "discover_bruno_collections: does not discover collection.bru at depth 3 (too deep)" {
  _stage "
    mkdir -p /work/collections/suite/nested
    touch /work/collections/suite/nested/collection.bru
  "

  run _run_discover -v "${WORK}:/work" -w /work

  mapfile -t lines < <(echo "$output" | grep '^collections/')
  [ "${#lines[@]}" -eq 0 ]
}
