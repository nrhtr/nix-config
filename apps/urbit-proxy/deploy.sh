#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"

URBIT_URL=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['repository']['url'])")
URBIT_REV=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['revision'])")

echo "==> Cloning urbit-sh at ${URBIT_REV:0:8}..."
rm -rf "$DIR/_src"
git clone "$URBIT_URL" "$DIR/_src"
git -C "$DIR/_src" checkout "$URBIT_REV"

trap 'echo "==> Cleaning up _src..."; rm -rf "$DIR/_src"' EXIT

echo "==> Deploying..."
cd "$DIR"
fly deploy --local-only
