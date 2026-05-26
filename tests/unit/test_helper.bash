#!/usr/bin/env bash
# Common Bats helper: locate repo root + load bats-support / bats-assert.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# shellcheck source=/dev/null
load "${REPO_ROOT}/node_modules/bats-support/load.bash"
# shellcheck source=/dev/null
load "${REPO_ROOT}/node_modules/bats-assert/load.bash"
