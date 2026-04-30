#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Resolving pinned sources..."
NIXPKGS=$(nix-instantiate --eval -E 'toString (import ./npins).nixpkgs' --json | tr -d '"')
HM=$(nix-instantiate --eval -E 'toString (import ./npins).home-manager' --json | tr -d '"')
CONFIG="$(pwd)/machines/lappy/configuration.nix"

echo "Switching lappy..."
sudo nixos-rebuild switch \
  -I nixpkgs="$NIXPKGS" \
  -I home-manager="$HM" \
  -I nixos-config="$CONFIG"
