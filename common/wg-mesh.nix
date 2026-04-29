{lib}: let
  nodes = import ./wg-nodes.nix;
in {
  inherit nodes;

  # Generate the peers list for a given node.
  # Servers (nodes with listenPort) peer with every other node.
  # Clients peer only with servers (nodes with endpoint), since clients
  # have no fixed endpoint and can't be dialled into.
  mkPeers = selfName: let
    self = nodes.${selfName};
    others = lib.filterAttrs (name: _: name != selfName) nodes;
    reachable =
      if self ? listenPort
      then others
      else lib.filterAttrs (_: n: n ? endpoint) others;
  in
    lib.mapAttrsToList (_: peer: let
      allowedIP = peer.routedCIDR or "${peer.ip}/32";
    in
      {
        publicKey = peer.publicKey;
        allowedIPs = [allowedIP];
      }
      // lib.optionalAttrs (peer ? endpoint) {
        endpoint = peer.endpoint;
        persistentKeepalive = 25;
      })
    reachable;
}
