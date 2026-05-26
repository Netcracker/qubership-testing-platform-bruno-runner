#!/usr/bin/env bats

load test_helper

setup() {
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/scripts/tools/bru_tools.sh"
  source "${REPO_ROOT}/scripts/parse-extra-vars.sh"
}


# ---------------- extract_bruno_collections ----------------

@test "extract_bruno_collections: parses array into bash array" {
  local arr=()
  extract_bruno_collections '{"execution_list":[{"type": "collection","name": "collections/bruno_base_test, collections/bruno_smoke_test"}]}' arr

  [ "${#arr[@]}" -eq 2 ]
  [ "${arr[0]}" = "collections/bruno_base_test" ]
  [ "${arr[1]}" = "collections/bruno_smoke_test" ]
}

@test "extract_bruno_collections: parses single name into bash array" {
  extract_bruno_collections '{"execution_list":[{"type": "collection","name": "collections/bruno_base_test"}]}' "arr"

  [ "${#arr[@]}" -eq 1 ]
  [ "${arr[0]}" = "collections/bruno_base_test" ]
}

@test "extract_bruno_collections: empty collections produces empty array" {
  local arr=()
  extract_bruno_collections '{"collections":[]}' arr
  [ "${#arr[@]}" -eq 0 ]
}

# ---------------- discover_bruno_collections ----------------

@test "discover_bruno_collections: finds dirs containing collection.bru" {
  # Layout must match discover_bruno_collections find(1): file at collections/<dir>/collection.bru (depth 2 under collections).
  local tmp="$BATS_TEST_TMPDIR/discover_fixture"
  mkdir -p "$tmp/collections/zebra" "$tmp/collections/apple"
  touch "$tmp/collections/zebra/collection.bru"
  touch "$tmp/collections/apple/collection.bru"
  (
    cd "$tmp" || exit 1
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/tools/bru_tools.sh"
    local arr=()
    discover_bruno_collections arr
    [ "${#arr[@]}" -eq 2 ]
    [ "${arr[0]}" = "collections/apple" ]
    [ "${arr[1]}" = "collections/zebra" ]
  )
}

@test "discover_bruno_collections: empty when no collection.bru" {
  local tmp="$BATS_TEST_TMPDIR/discover_empty"
  mkdir -p "$tmp/collections/empty/nested"
  (
    cd "$tmp" || exit 1
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/scripts/tools/bru_tools.sh"
    local arr=()
    discover_bruno_collections arr
    [ "${#arr[@]}" -eq 0 ]
  )
}

# ---------------- extract_test_type ----------------

@test "extract_test_type: parses type from execution_list" {
  extract_test_type '{"execution_list":[{"type": "collection","name": "collections/bruno_base_test"}]}' "TEST_TYPE"

  [ "$TEST_TYPE" = "collection" ]
}

@test "extract_test_type: returns empty for missing type" {
  local result=""
  extract_test_type '{"execution_list":[{"name": "collections/bruno_base_test"}]}' result 
  [ "$result" = "" ]
}

@test "extract_test_type: returns empty for completely empty input" {
  local result=""
  extract_test_type '{}' result
  [ "$result" = "" ]
}


# ---------------- extract_bruno_folders ----------------

@test "extract_bruno_folders: parses array into bash array" {
  extract_bruno_folders 'folder1|folder2|collection/folder3' "arr"

  [ "${#arr[@]}" -eq 3 ]
  [ "${arr[0]}" = "folder1" ]
  [ "${arr[1]}" = "folder2" ]
  [ "${arr[2]}" = "collection/folder3" ]
}

@test "extract_bruno_folders: parses string into bash array" {
  extract_bruno_folders 'collection/smoke/phase2/login/keyclock' "arr"

  [ "${#arr[@]}" -eq 1 ]
  [ "${arr[0]}" = "collection/smoke/phase2/login/keyclock" ]
}

@test "extract_bruno_folders: empty collections produces empty array" {
  extract_bruno_folders '' "arr"
  [ "${#arr[@]}" -eq 0 ]
}
