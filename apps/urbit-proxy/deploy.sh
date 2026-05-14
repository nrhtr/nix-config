#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"

echo "==> Fetching pinned urbit-sh source via nix..."
SRC=$(nix-build -E "(import ${REPO}/npins).\"urbit-sh\"" --no-out-link 2>&1 | tail -1)

echo "==> Copying source to build context..."
rm -rf "$DIR/_src"
cp -rL "$SRC" "$DIR/_src"
chmod -R u+w "$DIR/_src"

trap 'echo "==> Cleaning up _src..."; rm -rf "$DIR/_src"' EXIT

echo "==> Deploying..."
fly deploy --local-only --config "$DIR/fly.toml"
