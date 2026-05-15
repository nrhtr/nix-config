#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"

URBIT_URL=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['repository']['url'])")
URBIT_REV=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['revision'])")

if [[ -d "$DIR/_src" ]] && [[ "$(git -C "$DIR/_src" rev-parse HEAD 2>/dev/null)" == "$URBIT_REV" ]]; then
  echo "==> Source already at ${URBIT_REV:0:8}, skipping clone"
else
  echo "==> Cloning urbit-sh at ${URBIT_REV:0:8}..."
  rm -rf "$DIR/_src"
  git clone "$URBIT_URL" "$DIR/_src"
  git -C "$DIR/_src" checkout "$URBIT_REV"
fi

echo "==> Deploying with \`fly deploy --local\`..."
pushd "$DIR"
fly deploy --local-only
popd

echo "==> Done."
