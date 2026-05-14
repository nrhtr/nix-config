#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"

URBIT_URL=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['repository']['url'])")
URBIT_REV=$(python3 -c "import json; d=json.load(open('${REPO}/npins/sources.json')); print(d['pins']['urbit-sh']['revision'])")

echo "==> Fetching pinned urbit-sh source via nix (ref=main, rev=${URBIT_REV:0:8})..."
SRC=$(nix-build --no-out-link -E "builtins.fetchGit { url = \"$URBIT_URL\"; rev = \"$URBIT_REV\"; ref = \"main\"; submodules = false; }")

echo "==> Copying source to build context..."
rm -rf "$DIR/_src"
cp -rL "$SRC" "$DIR/_src"
chmod -R u+w "$DIR/_src"

trap 'echo "==> Cleaning up _src..."; rm -rf "$DIR/_src"' EXIT

echo "==> Deploying..."
fly deploy --local-only --config "$DIR/fly.toml"
