#!/bin/bash

# ============================================
# Function to load a JSON file
# Returns: file content as a compact JSON string
# Exits with code 1 if file is not found or JSON is invalid
# ============================================
load_json_file() {
  local file_path="$1"

  if [ ! -f "$file_path" ]; then
    echo "Error: File $file_path not found" >&2
    return 1
  fi

  echo "File content:" >&2
  cat -A "$file_path" >&2
  echo "" >&2

  json_content=$(tr -d '\n\r' < "$file_path" | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//')

  if [[ ! "$json_content" =~ ^\{.*\}$ ]]; then
    echo "Error: Invalid JSON format" >&2
    return 1
  fi

  echo "$json_content"
}

main() {
  set -euo pipefail
  export TMP_DIR="/tmp/clone"
  export WORK_DIR
  WORK_DIR=$(pwd)
  export BRU_BIN="$WORK_DIR/node_modules/@usebruno/cli/bin"
  export PATH="$WORK_DIR/node_modules/.bin:$PATH"
  export LOCAL_RUN=true
  rm -rf "${TMP_DIR:?}/"*
  cp -r "$WORK_DIR/local-collection" "$TMP_DIR"

  # ============================================
  # Set environment variables for local run and debugging
  # ============================================
  export ENVIRONMENT_NAME=""
  export ATP_TESTS_GIT_REPO_URL=""
  export ATP_TESTS_GIT_REPO_BRANCH=""
  export ATP_TESTS_GIT_TOKEN=""
  export TEST_PARAMS="{}"

  # ============================================
  # S3 path settings
  # ============================================
  export ATP_STORAGE_SERVER_URL=
  export ATP_STORAGE_USERNAME=
  export ATP_STORAGE_PASSWORD=
  export ATP_STORAGE_BUCKET=
  export ATP_STORAGE_PROVIDER=
  export ATP_STORAGE_SERVER_UI_URL=
  export ATP_REPORT_VIEW_UI_URL=""

  # ============================================
  # Bruno settings
  # ============================================
  if ! TEST_PARAMS=$(load_json_file "$(pwd)/tools/local_test_params.json"); then
    echo "Failed to load parameters from TEST_PARAMS" >&2
    exit 1
  fi
  export TEST_PARAMS

  if [[ ! -f "entrypoint.sh" ]]; then
    echo "Error: entrypoint.sh not found in the current directory!" >&2
    exit 1
  fi

  ./entrypoint.sh
}

# Source-safe guard: only run main when executed directly, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
