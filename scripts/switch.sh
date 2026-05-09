#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Fix $HOME when invoked via sudo (inherits user $HOME, confuses nix tools)
export HOME=~root

case "$(hostname -s)" in
  minnie) exec bash scripts/switch-minnie.sh ;;
  lappy)  exec bash scripts/switch-lappy.sh ;;
  *) echo "No switch script for host: $(hostname -s)"; exit 1 ;;
esac
