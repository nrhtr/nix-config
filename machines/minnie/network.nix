{lib, ...}: let
  mesh = import ../../common/wg-mesh.nix {inherit lib;};
  nodes = import ../../common/wg-nodes.nix;
  self = mesh.nodes.minnie;
  hostsEntries = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: node: "${node.ip}  ${name}") nodes
  );
in {
  networking.wg-quick.interfaces.wg0 = {
    address = ["${self.ip}/16"];
    privateKeyFile = "/etc/wireguard.privkey";
    peers = mesh.mkPeers "minnie";
  };

  environment.etc."hosts".text = lib.mkAfter hostsEntries;
}
