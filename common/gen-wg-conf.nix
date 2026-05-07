{pkgs}: let
  lib = pkgs.lib;
  nodes = import ./wg-nodes.nix;

  # Nodes with a fixed endpoint that clients can peer with
  servers = lib.filterAttrs (_: n: n ? endpoint) nodes;

  # Nodes without listenPort — these are clients that need a generated config
  clients = lib.filterAttrs (_: n: !(n ? listenPort)) nodes;

  # Full VPN subnet — taken from whichever server has routedCIDR
  hubCIDR = lib.head (
    lib.mapAttrsToList (_: n: n.routedCIDR)
    (lib.filterAttrs (_: n: n ? routedCIDR) nodes)
  );

  # All servers as peers with their natural AllowedIPs (default, no --via)
  mkAllPeers = clientName:
    lib.concatStrings (lib.mapAttrsToList (serverName: server:
      lib.optionalString (serverName != clientName) ''
        printf '\n[Peer]\n'
        printf 'PublicKey = ${server.publicKey}\n'
        printf 'AllowedIPs = ${server.routedCIDR or "${server.ip}/32"}\n'
        printf 'Endpoint = ${server.endpoint}\n'
        printf 'PersistentKeepalive = 25\n'
      '')
    servers);

  # Case branches for --via <server>: one server, full VPN CIDR
  viaCases = lib.concatStrings (lib.mapAttrsToList (serverName: server: ''
      ${serverName})
        printf '\n[Peer]\n'
        printf 'PublicKey = ${server.publicKey}\n'
        printf 'AllowedIPs = ${hubCIDR}\n'
        printf 'Endpoint = ${server.endpoint}\n'
        printf 'PersistentKeepalive = 25\n'
        ;;
    '')
    servers);

  # One case branch per client node
  clientCases = lib.concatStrings (lib.mapAttrsToList (nodeName: node: ''
      ${nodeName})
        printf '[Interface]\n'
        printf 'PrivateKey = %s\n' "$privkey"
        printf 'Address = ${node.ip}/16\n'
        printf 'DNS = 10.100.0.6\n'
        if [[ -n "$via" ]]; then
          case "$via" in
            ${viaCases}
            *) printf 'Unknown --via server: %s\n' "$via" >&2; exit 1 ;;
          esac
        else
          ${mkAllPeers nodeName}
        fi
        ;;
    '')
    clients);
in
  pkgs.writeShellApplication {
    name = "gen-wg-conf";
    runtimeInputs = [pkgs.qrencode];
    text = ''
      usage() {
        printf 'Usage: gen-wg-conf [--qr] [--via <server>] <node>\n' >&2
        printf 'Reads private key from stdin.\n' >&2
        printf 'Nodes:   ${lib.concatStringsSep " " (lib.attrNames clients)}\n' >&2
        printf 'Servers: ${lib.concatStringsSep " " (lib.attrNames servers)}\n' >&2
        exit 1
      }

      qr=0
      node=""
      via=""
      args=("$@")
      i=0
      while [[ $i -lt ''${#args[@]} ]]; do
        arg="''${args[$i]}"
        case "$arg" in
          --qr) qr=1 ;;
          --via)
            i=$((i+1))
            [[ $i -ge ''${#args[@]} ]] && { printf 'Error: --via requires a server name\n' >&2; usage; }
            via="''${args[$i]}"
            ;;
          -*) usage ;;
          *) node="$arg" ;;
        esac
        i=$((i+1))
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
