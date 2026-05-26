# TODO update docs to NPM
#!/bin/bash
# Layer 1: static checks - bash -n on every *.sh, shellcheck if available.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Discover all *.sh files outside tests/, node_modules/, and .git/.
mapfile -t FILES < <(
  find . \
    -type d \( -name node_modules -o -name .git -o -path ./tests \) -prune -o \
    -type f -name '*.sh' -print \
    | sort
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "static: no shell scripts found"
  exit 0
fi

have_shellcheck=0
if command -v shellcheck >/dev/null 2>&1; then
  have_shellcheck=1
else
  echo "static: shellcheck not installed - syntax check only" >&2
fi

fail=0
for f in "${FILES[@]}"; do
  if ! bash -n "$f"; then
    echo "static: bash -n FAILED for $f" >&2
    fail=1
    continue
  fi
  if [[ $have_shellcheck -eq 1 ]]; then
    if ! shellcheck -x -s bash "$f"; then
      echo "static: shellcheck FAILED for $f" >&2
      fail=1
    fi
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "static: FAILED" >&2
  exit 1
fi

echo "static: OK (${#FILES[@]} scripts checked)"
