{
  pkgs,
  lib,
}: let
  nodes = import ../../common/wg-nodes.nix;
  servers = lib.filterAttrs (_: n: n ? endpoint) nodes;

  # Extract the IP portion from "host:port"
  endpointIP = endpoint: builtins.elemAt (lib.splitString ":" endpoint) 0;

  validNames = lib.concatStringsSep ", " (lib.attrNames servers);

  caseEntries = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: node: ''
    ${name})
        PEER_KEY="${node.publicKey}"
        ENDPOINT_IP="${endpointIP node.endpoint}"
        RESTORE_ALLOWED_IPS="${node.routedCIDR or "${node.ip}/32"}"
        ;; '')
  servers);
in
  pkgs.writeShellScriptBin "wg-exit-node" ''
    # Toggle exit node routing through a WireGuard peer.
    # Usage: wg-exit-node enable|disable <node>
    set -euo pipefail

    ACTION="''${1:-}"
    NODE="''${2:-}"

    if [[ -z "$ACTION" || -z "$NODE" ]]; then
      echo "Usage: $0 enable|disable <node>"
      echo "Nodes: ${validNames}"
      exit 1
    fi

    case "$NODE" in
      ${caseEntries}
      *)
        echo "Unknown node: $NODE. Valid options: ${validNames}"
        exit 1
        ;;
    esac

    WG_IF=$(sudo wg show interfaces | tr ' ' '\n' | head -1)
    if [[ -z "$WG_IF" ]]; then
      echo "No WireGuard interface found — is the tunnel up?"
      exit 1
    fi

    if [[ "$(uname)" == "Darwin" ]]; then
      DEFAULT_GW=$(route -n get default | awk '/gateway/{print $2}')

      if [[ "$ACTION" == "enable" ]]; then
        sudo wg set "$WG_IF" peer "$PEER_KEY" allowed-ips 0.0.0.0/0,::/0
        sudo route add -host "$ENDPOINT_IP" "$DEFAULT_GW"
        sudo route add -net 0.0.0.0/1 -interface "$WG_IF"
        sudo route add -net 128.0.0.0/1 -interface "$WG_IF"
        echo "Exit node enabled via $NODE ($ENDPOINT_IP)"
      else
        sudo route delete -net 0.0.0.0/1 || true
        sudo route delete -net 128.0.0.0/1 || true
        sudo route delete -host "$ENDPOINT_IP" || true
        sudo wg set "$WG_IF" peer "$PEER_KEY" allowed-ips "$RESTORE_ALLOWED_IPS"
        echo "Exit node disabled"
      fi

    else
      DEFAULT_GW=$(ip route show default | awk '{print $3}' | head -1)
      DEFAULT_IF=$(ip route show default | awk '{print $5}' | head -1)

      if [[ "$ACTION" == "enable" ]]; then
        sudo wg set "$WG_IF" peer "$PEER_KEY" allowed-ips 0.0.0.0/0,::/0
        sudo ip route add "$ENDPOINT_IP/32" via "$DEFAULT_GW" dev "$DEFAULT_IF"
        sudo ip route add 0.0.0.0/1 dev "$WG_IF"
        sudo ip route add 128.0.0.0/1 dev "$WG_IF"
        echo "Exit node enabled via $NODE ($ENDPOINT_IP)"
      else
        sudo ip route del 0.0.0.0/1 || true
        sudo ip route del 128.0.0.0/1 || true
        sudo ip route del "$ENDPOINT_IP/32" || true
        sudo wg set "$WG_IF" peer "$PEER_KEY" allowed-ips "$RESTORE_ALLOWED_IPS"
        echo "Exit node disabled"
      fi
    fi
  ''
