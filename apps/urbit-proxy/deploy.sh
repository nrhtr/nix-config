#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"

URBIT_URL=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['repository']['url'])")
URBIT_REV=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['revision'])")

if [[ ! -d "$DIR/_src/.git" ]]; then
  echo "==> Cloning urbit-sh..."
  git clone "$URBIT_URL" "$DIR/_src"
fi

if [[ "$(git -C "$DIR/_src" rev-parse HEAD 2>/dev/null)" == "$URBIT_REV" ]]; then
  echo "==> Source already at ${URBIT_REV:0:8}, skipping fetch"
else
  echo "==> Fetching and checking out ${URBIT_REV:0:8}..."
  git -C "$DIR/_src" fetch origin
  git -C "$DIR/_src" checkout "$URBIT_REV"
fi

# Ensure a clean tree (no untracked build artifacts etc.) without re-cloning.
git -C "$DIR/_src" clean -fdx --quiet

echo "==> Deploying with \`fly deploy --local\`..."
pushd "$DIR"
fly deploy --local-only
popd

echo "==> Done."
