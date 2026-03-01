#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "Resolving pinned sources..."
NIXPKGS=$(nix-instantiate --eval -E 'toString (import ./npins).nixpkgs' --json | tr -d '"')
DARWIN=$(nix-instantiate --eval -E 'toString (import ./npins).nix-darwin' --json | tr -d '"')
HM=$(nix-instantiate --eval -E 'toString (import ./npins).home-manager' --json | tr -d '"')
CONFIG="$(pwd)/machines/minnie/configuration.nix"

echo "Switching minnie..."
sudo darwin-rebuild switch \
  -I nixpkgs="$NIXPKGS" \
  -I darwin="$DARWIN" \
  -I home-manager="$HM" \
  -I darwin-config="$CONFIG"
