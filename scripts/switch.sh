#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

case "$(hostname -s)" in
  minnie) exec sudo bash scripts/switch-minnie.sh ;;
  lappy)  exec sudo bash scripts/switch-lappy.sh ;;
  *) echo "No switch script for host: $(hostname -s)"; exit 1 ;;
esac
