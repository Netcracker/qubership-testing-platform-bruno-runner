#!/usr/bin/env bats

load test_helper

# ---------------------------------------------------------------------------
# Setup: source the lib under test and prepare a temp sandbox
# ---------------------------------------------------------------------------

setup() {
  # Temp dir for each test — cleaned up in teardown
  TEST_TMP="$(mktemp -d)"

  # Minimal exports that the helpers depend on at source time
  export TMP_DIR="$TEST_TMP"
  export PATH_TO_ALLURE_RESULTS="$TEST_TMP/allure-results"
  export PATH_TO_ATTACHMENTS_DIR="$TEST_TMP/attachments"
  export BRU_BIN="$TEST_TMP/bin"
  export BRUNO_ENV_STR="environments/test"
  export BRUNO_FLAGS_CLI=""
  export COLLECTION_TIMEOUT="3600"

  mkdir -p "$PATH_TO_ALLURE_RESULTS" "$PATH_TO_ATTACHMENTS_DIR" "$BRU_BIN"

  # shellcheck source=/dev/null
  source "${REPO_ROOT}/scripts/lib/collection-runner.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# write_allure_placeholder
# ---------------------------------------------------------------------------

@test "write_allure_placeholder: status=skipped writes valid JSON with uuid" {
  write_allure_placeholder "skipped" "My Collection" "No folders matched" "trace info"

  local files=("$PATH_TO_ALLURE_RESULTS"/*-result.json)
  [ "${#files[@]}" -eq 1 ]

  local status
  status=$(jq -r '.status' "${files[0]}")
  [ "$status" = "skipped" ]

  local name
  name=$(jq -r '.name' "${files[0]}")
  [ "$name" = "My Collection" ]

  local uuid
  uuid=$(jq -r '.uuid' "${files[0]}")
  [ -n "$uuid" ]
}

@test "write_allure_placeholder: status=broken includes labels array" {
  write_allure_placeholder "broken" "Some Suite" "Report not generated" "raw.log"

  local files=("$PATH_TO_ALLURE_RESULTS"/*-result.json)
  [ "${#files[@]}" -eq 1 ]

  local status
  status=$(jq -r '.status' "${files[0]}")
  [ "$status" = "broken" ]

  local label_count
  label_count=$(jq '.labels | length' "${files[0]}")
  [ "$label_count" -ge 1 ]
}

@test "write_allure_placeholder: message and trace are embedded in statusDetails" {
  write_allure_placeholder "skipped" "Col" "the message" "the trace"

  local files=("$PATH_TO_ALLURE_RESULTS"/*-result.json)
  local msg trace
  msg=$(jq -r '.statusDetails.message' "${files[0]}")
  trace=$(jq -r '.statusDetails.trace' "${files[0]}")

  [ "$msg" = "the message" ]
  [ "$trace" = "the trace" ]
}

# ---------------------------------------------------------------------------
# resolve_folders
# ---------------------------------------------------------------------------

@test "resolve_folders: returns matching dirs from a collection tree" {
  # Build a fake collection directory with a sub-folder named "smoke"
  local col_dir="$TEST_TMP/fake-collection"
  mkdir -p "$col_dir/smoke" "$col_dir/regression"

  # cd into the collection dir as run_collection_body would
  pushd "$col_dir" > /dev/null

  local -a input_folders=("smoke")
  resolve_folders input_folders

  popd > /dev/null

  [ "${#RESOLVED_FOLDERS[@]}" -eq 1 ]
  [[ "${RESOLVED_FOLDERS[0]}" == *smoke* ]]
}

@test "resolve_folders: warns when folder not found" {
  local col_dir="$TEST_TMP/fake-collection2"
  mkdir -p "$col_dir"
  pushd "$col_dir" > /dev/null

  local -a input_folders=("nonexistent")
  run resolve_folders input_folders

  popd > /dev/null

  assert_output --partial "not found"
}

@test "resolve_folders: empty input leaves RESOLVED_FOLDERS empty" {
  local col_dir="$TEST_TMP/fake-collection3"
  mkdir -p "$col_dir/smoke"
  pushd "$col_dir" > /dev/null

  local -a input_folders=()
  resolve_folders input_folders

  popd > /dev/null

  [ "${#RESOLVED_FOLDERS[@]}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# wait_for_collection_slot
# ---------------------------------------------------------------------------

@test "wait_for_collection_slot: returns once a tracked pid finishes" {
  # Start a short background job
  sleep 0.2 &
  local pid=$!
  active_collection_pids=("$pid")

  # Should not hang — the sleep will finish in 0.2s
  run bash -c "
    source '${REPO_ROOT}/scripts/lib/collection-runner.sh'
    active_collection_pids=($pid)
    wait_for_collection_slot
    echo done
  "
  assert_success
  assert_output --partial "done"
}

# ---------------------------------------------------------------------------
# run_bru
# ---------------------------------------------------------------------------

setup_bru_stub() {
  # Create a stub bru.js that records its arguments
  mkdir -p "$BRU_BIN"
  cat > "$BRU_BIN/bru.js" <<'STUB'
#!/usr/bin/env bash
echo "BRU_CALLED: $*" >&2
# write an empty reporter file so caller doesn't fail on missing report
for i in "$@"; do
  if [[ "$prev" == "--reporter-json" ]]; then
    echo "[]" > "$i"
  fi
  prev="$i"
done
exit 0
STUB
  chmod +x "$BRU_BIN/bru.js"
}

@test "run_bru: invokes bru.js run with env and reporter args (no folders)" {
  setup_bru_stub
  local report="$PATH_TO_ATTACHMENTS_DIR/col-result.json"
  local log="$PATH_TO_ATTACHMENTS_DIR/col.raw.log"

  run run_bru "$report" "$log"

  assert_success
  # stderr captured via 2>&1 in run_bru's tee; check log
  assert [ -f "$log" ]
}

@test "run_bru: appends folder args when provided" {
  setup_bru_stub
  local report="$PATH_TO_ATTACHMENTS_DIR/col2-result.json"
  local log="$PATH_TO_ATTACHMENTS_DIR/col2.raw.log"

  run run_bru "$report" "$log" "smoke" "regression"

  assert_success
  # The stub echoes its args to stderr which is teed to log
  run cat "$log"
  assert_output --partial "smoke"
  assert_output --partial "regression"
}
