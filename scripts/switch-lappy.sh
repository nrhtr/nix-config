#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "Resolving pinned sources..."
NIXPKGS=$(nix-instantiate --eval -E 'toString (import ./npins).nixpkgs' --json | tr -d '"')
CONFIG="$(pwd)/machines/lappy/configuration.nix"

echo "Switching lappy..."
sudo nixos-rebuild switch \
  -I nixpkgs="$NIXPKGS" \
  -I nixos-config="$CONFIG"
