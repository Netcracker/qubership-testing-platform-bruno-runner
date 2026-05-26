#!/usr/bin/env bash
# Layer 3: build the image once, then run all docker-based bats tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "e2e: docker is required" >&2
  exit 2
fi

BATS="${ROOT}/node_modules/.bin/bats"
if [[ ! -x "$BATS" ]]; then
  echo "e2e: bats not found — run 'npm install' first" >&2
  exit 1
fi

export BRUNO_RUNNER_IMAGE="${BRUNO_RUNNER_IMAGE:-bruno-runner:test}"

echo "e2e: building ${BRUNO_RUNNER_IMAGE}..."
DOCKER_BUILDKIT=1 docker build -t "${BRUNO_RUNNER_IMAGE}" .

echo "e2e: running bats tests/e2e ..."
"$BATS" --verbose-run "${ROOT}/tests/e2e"
