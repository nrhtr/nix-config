{pkgs}: let
  lib = pkgs.lib;
  nodes = import ./wg-nodes.nix;

  # Nodes with a fixed endpoint that clients can peer with
  servers = lib.filterAttrs (_: n: n ? endpoint) nodes;

  # Nodes without listenPort — these are clients that need a generated config
  clients = lib.filterAttrs (_: n: !(n ? listenPort)) nodes;

  # Shell printf commands for each server peer, skipping self
  mkPeerPrintfs = clientName:
    lib.concatStrings (lib.mapAttrsToList (serverName: server:
      lib.optionalString (serverName != clientName) ''
        printf '\n[Peer]\n'
        printf 'PublicKey = ${server.publicKey}\n'
        printf 'AllowedIPs = ${server.routedCIDR or "${server.ip}/32"}\n'
        printf 'Endpoint = ${server.endpoint}\n'
        printf 'PersistentKeepalive = 25\n'
      '')
    servers);

  # One case branch per client node with peer stanzas baked in at eval time
  clientCases = lib.concatStrings (lib.mapAttrsToList (nodeName: node: ''
      ${nodeName})
        printf '[Interface]\n'
        printf 'PrivateKey = %s\n' "$privkey"
        printf 'Address = ${node.ip}/16\n'
        printf 'DNS = 10.100.0.6\n'
        ${mkPeerPrintfs nodeName}
        ;;
    '')
    clients);
in
  pkgs.writeShellApplication {
    name = "gen-wg-conf";
    runtimeInputs = [pkgs.qrencode];
    text = ''
      usage() {
        printf 'Usage: gen-wg-conf [--qr] <node>\n' >&2
        printf 'Reads private key from stdin.\n' >&2
        printf 'Nodes: ${lib.concatStringsSep " " (lib.attrNames clients)}\n' >&2
        exit 1
      }

      qr=0
      node=""
      for arg in "$@"; do
        case "$arg" in
          --qr) qr=1 ;;
          -*) usage ;;
          *) node=$arg ;;
        esac
      done

      [[ -z "$node" ]] && usage

      privkey=$(cat)
      [[ -z "$privkey" ]] && { printf 'Error: no private key on stdin\n' >&2; exit 1; }

      do_gen() {
        case "$node" in
          ${clientCases}
          *) printf 'Unknown node: %s\n' "$node" >&2; exit 1 ;;
        esac
      }

      if [[ "$qr" -eq 1 ]]; then
        do_gen | qrencode -t ansiutf8
      else
        do_gen
      fi
    '';
  }
