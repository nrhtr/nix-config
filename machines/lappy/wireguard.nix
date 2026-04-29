{lib, ...}: let
  mesh = import ../../common/wg-mesh.nix {inherit lib;};
  self = mesh.nodes.lappy;
in {
  networking.wireguard.interfaces.wg0 = {
    ips = ["${self.ip}/16"];
    privateKeyFile = "/etc/wireguard.privkey";
    peers = mesh.mkPeers "lappy";
  };
}
