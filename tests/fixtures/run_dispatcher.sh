#!/bin/bash
# Shared entrypoint for dispatcher e2e tests.
# Volume-mounted read-only into each test container.
# All variation is provided via -e flags on the docker run command.
set -e

source /scripts/tools/bru_tools.sh
source /scripts/lib/collection-runner.sh
source /scripts/test-runner-bruno.sh

export TMP_DIR=/tmp/work
export BRUNO_ENV="${BRUNO_ENV:-local}"
export BRUNO_FLAGS="${BRUNO_FLAGS:---insecure}"
export BRUNO_FLAGS_CLI="${BRUNO_FLAGS_CLI:---insecure}"
export BRUNO_FOLDERS="${BRUNO_FOLDERS:-}"
export PARALLELISM=1

cd "$TMP_DIR"
run_bruno_from_test_params
