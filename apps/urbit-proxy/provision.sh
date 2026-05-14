#!/usr/bin/env bash
# Run once per machine to create a volume and machine with the correct WG_IP.
# After the machine boots, grab the pubkey from logs and update wg-nodes.nix.
#
# Usage: ./provision.sh <region> <wg-ip>
# Example:
#   ./provision.sh syd 10.100.0.9    # fly-urbit-syd-1
#   ./provision.sh syd 10.100.0.10   # fly-urbit-syd-2
#   ./provision.sh iad 10.100.0.11   # fly-urbit-iad-1 (already provisioned)
#   ./provision.sh iad 10.100.0.12   # fly-urbit-iad-2
set -euo pipefail

APP="urbit-ssh"
DIR="$(cd "$(dirname "$0")" && pwd)"

REGION="${1:?usage: $0 <region> <wg-ip>}"
WG_IP="${2:?usage: $0 <region> <wg-ip>}"

echo "==> Creating volume in ${REGION}..."
VOL_ID=$(fly volumes create wg_keys \
  --region "$REGION" \
  --size 1 \
  --app "$APP" \
  --json \
  --yes | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "    Volume: ${VOL_ID}"

echo "==> Building image..."
LABEL="provision-$(date +%s)"
cd "$DIR"
fly deploy --local-only --build-only --image-label "$LABEL"
IMAGE="registry.fly.io/${APP}:${LABEL}"

echo "==> Creating machine (region=${REGION}, WG_IP=${WG_IP})..."
fly machine create \
  --app "$APP" \
  --region "$REGION" \
  --env "WG_IP=${WG_IP}" \
  --volume "${VOL_ID}:/data" \
  --image "$IMAGE" \
  --vm-memory 256 \
  --vm-cpus 1

echo ""
echo "==> Machine created. Wait ~10s then run:"
echo "    fly logs --app ${APP} | grep WIREGUARD_PUBKEY"
echo "    Then update common/wg-nodes.nix and run generate-wg-config.sh"
