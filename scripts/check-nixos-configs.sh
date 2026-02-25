#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "Checking NixOS configurations..."

hosts=("nix01" "nix02")
failed=()

for host in "${hosts[@]}"; do
  printf "  %-10s " "$host"
  if nix-instantiate scripts/check-nixos-eval.nix -A "$host" --quiet 2>/tmp/nixos-check-"$host".log; then
    echo "ok"
  else
    echo "FAILED"
    cat /tmp/nixos-check-"$host".log >&2
    failed+=("$host")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi

echo "All NixOS configurations evaluate OK"
