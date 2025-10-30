#!/bin/bash

# ============================================
# Initialization
# ============================================
set -euo pipefail  # Strict mode: exit on errors, check for unset variables
export TMP_DIR="/tmp/clone"
export WORK_DIR=$(pwd)
# Needed for pushd operation
export BRU_BIN="$WORK_DIR/node_modules/@usebruno/cli/bin"
export PATH="$WORK_DIR/node_modules/.bin:$PATH"
# Turn on local run mode
export LOCAL_RUN=true
# Remove previous contents if any
rm -rf "${TMP_DIR:?}/"*
# Copy collections into temp directory
cp -r $WORK_DIR/local-collection $TMP_DIR

# ============================================
# Function to load a JSON file
# Returns: file content as a compact JSON string
# Exits with code 1 if file is not found or JSON is invalid
# ============================================
load_json_file() {
  local file_path="$1"
  
  # Check existing file
  if [ ! -f "$file_path" ]; then
    echo "Error: File $file_path not found" >&2
    return 1
  fi

  # Output file contents for debug
  echo "File content:" >&2
  cat -A "$file_path" >&2
  echo "" >&2

  # Reading a JSON file and removing spaces/line breaks
  json_content=$(tr -d '\n\r' < "$file_path" | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//')
  
  # Basic JSON validation (check for curly brackets)
  if [[ ! "$json_content" =~ ^\{.*\}$ ]]; then
    echo "Error: Invalid JSON format" >&2
    return 1
  fi

  echo "$json_content"
}

# ============================================
# Set environment variables for local run and debugging
# ============================================
## Git settings. Input parameters from project
export ENVIRONMENT_NAME=""
export ATP_TESTS_GIT_REPO_URL=""
export ATP_TESTS_GIT_REPO_BRANCH=""
export ATP_TESTS_GIT_TOKEN=""
# The value of this environment variable must remain unchanged
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

# Check that entrypoint.sh exists in the current directory (project root)
if [[ ! -f "entrypoint.sh" ]]; then
    echo "Error: entrypoint.sh not found in the current directory!" >&2
    exit 1
fi

# Check that start_runs.sh exists in the current directory (project root)
if [[ ! -f "start_runs.sh" ]]; then
    echo "Error: start_runs.sh not found in the current directory!" >&2
    exit 1
fi

# ============================================
# Run local collections
# If you need to run collections without downloading from Git and uploading to S3 storage when running locally, 
# use start_tests.sh; otherwise, use entrypoint.sh
# ============================================
./entrypoint.sh
