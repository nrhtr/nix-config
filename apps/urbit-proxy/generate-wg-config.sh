#!/usr/bin/env bash
# Regenerate wg0.conf.template from common/wg-nodes.nix.
# Run this whenever WireGuard peers change, then commit the result.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

nix eval --raw -f - <<EOF > "$(dirname "$0")/wg0.conf.template"
let
  sources = import $REPO/npins;
  pkgs = import sources.nixpkgs { system = "x86_64-linux"; };
  lib = pkgs.lib;
  nodes = import $REPO/common/wg-nodes.nix;
  servers = lib.filterAttrs (_: n: n ? endpoint) nodes;
in ''
[Interface]
Address = WG_IP_PLACEHOLDER/16
PrivateKey = WG_PRIVATE_KEY_PLACEHOLDER

\${lib.concatStrings (lib.mapAttrsToList (name: peer: ''
[Peer]
# \${name}
PublicKey = \${peer.publicKey}
AllowedIPs = \${peer.routedCIDR or "\${peer.ip}/32"}
Endpoint = \${peer.endpoint}
PersistentKeepalive = 25

'') servers)}''
EOF

echo "Wrote wg0.conf.template"
