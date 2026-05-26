#!/usr/bin/env bats

load test_helper

setup() {
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/local_start.sh"
  TMP_TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_TEST_DIR"
}

@test "load_json_file: valid JSON returns compact string on stdout" {
  local f="${TMP_TEST_DIR}/ok.json"
  printf '{\n  "a": 1,\n  "b": "two"\n}\n' > "$f"

  run load_json_file "$f"

  assert_success
  assert_output --partial '{ "a": 1, "b": "two"}'
}

@test "load_json_file: missing file returns 1 and stderr message" {
  run load_json_file "${TMP_TEST_DIR}/does-not-exist.json"

  assert_failure 1
  assert_output --partial "not found"
}

@test "load_json_file: non-object JSON returns 1" {
  local f="${TMP_TEST_DIR}/bad.json"
  printf '"hello"\n' > "$f"

  run load_json_file "$f"

  assert_failure 1
  assert_output --partial "Invalid JSON format"
}

@test "load_json_file: empty file returns 1" {
  local f="${TMP_TEST_DIR}/empty.json"
  : > "$f"

  run load_json_file "$f"

  assert_failure 1
  assert_output --partial "Invalid JSON format"
}
