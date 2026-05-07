{pkgs}:
pkgs.writeShellApplication {
  name = "apply-gandi-dns";
  runtimeInputs = [pkgs.curl pkgs.jq];
  text = ''
    usage() {
      printf 'Usage: apply-gandi-dns <records.json> <credentials-file>\n' >&2
      printf 'Tip: apply-gandi-dns "$(gandi-dns-records)" <(agenix -d secrets/gandi.age)\n' >&2
      exit 1
    }

    [[ $# -lt 2 ]] && usage

    payload="$1"

    set -a
    # shellcheck source=/dev/null
    source "$2"
    set +a

    API_KEY="''${GANDIV5_PERSONAL_ACCESS_TOKEN:-''${GANDIV5_APIKEY:-}}"
    [[ -z "$API_KEY" ]] && { printf 'Error: no API key in credentials file\n' >&2; exit 1; }

    count=$(jq '.items | length' "$payload")
    printf 'Applying %s record sets to jenga.xyz...\n' "$count"

    http_code=$(curl -s -o /tmp/gandi-response.json -w "%{http_code}" \
      -X PUT \
      -H "Authorization: Apikey $API_KEY" \
      -H "Content-Type: application/json" \
      -d "@$payload" \
      "https://api.gandi.net/v5/livedns/domains/jenga.xyz/records")

    if [[ "$http_code" == "201" ]] || [[ "$http_code" == "200" ]]; then
      printf 'Done.\n'
    else
      printf 'Error: HTTP %s\n' "$http_code" >&2
      jq . /tmp/gandi-response.json >&2
      exit 1
    fi
  '';
}
