{lib, ...}: let
  mesh = import ../../common/wg-mesh.nix {inherit lib;};
  self = mesh.nodes.minnie;
in {
  networking.wg-quick.interfaces.wg0 = {
    address = ["${self.ip}/16"];
    privateKeyFile = "/etc/wireguard.privkey";
    peers = mesh.mkPeers "minnie";
  };
}
