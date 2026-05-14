#!/usr/bin/env bash
# Build the image and roll it out to all machines one at a time.
# Add new machine IDs here after provisioning with provision.sh.
set -euo pipefail

APP="urbit-ssh"
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"

# Fixed machine IDs — one per WireGuard peer
MACHINES=(
  0803791c155e48  # syd-1 (10.100.0.9)
  0803792a1e33e8  # syd-2 (10.100.0.10)
  e2862ee1c0e098  # iad-1 (10.100.0.11)
  5683e220fe9978  # iad-2 (10.100.0.12)
)

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

echo "==> Building and pushing image..."
LABEL="deploy-$(date +%s)"
cd "$DIR"
fly deploy --local-only --build-only --push --image-label "$LABEL"
IMAGE="registry.fly.io/${APP}:${LABEL}"

if [[ ${#MACHINES[@]} -eq 0 ]]; then
  echo "No machines configured in MACHINES array — update deploy.sh with machine IDs."
  exit 1
fi

echo "==> Rolling out ${IMAGE} to ${#MACHINES[@]} machine(s)..."
for ID in "${MACHINES[@]}"; do
  echo "    Updating ${ID}..."
  fly machine update "$ID" --image "$IMAGE" --app "$APP" --yes
done

echo "==> Done."
