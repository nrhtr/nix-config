# Shared borg backup heartbeat script.
# Usage: borg-heartbeat <endpoint-url> <token-path> <true|false>
{pkgs}:
pkgs.writeShellScript "borg-heartbeat" ''
  ${pkgs.curl}/bin/curl -s -o /dev/null -X POST \
    "$1?success=$3" \
    -H "Authorization: Bearer $(cat "$2")" || true
''
