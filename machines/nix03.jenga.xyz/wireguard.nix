{lib, ...}: let
  mesh = import ../../common/wg-mesh.nix {inherit lib;};
  self = mesh.nodes.nix03;
in {
  networking.firewall.allowedUDPPorts = [self.listenPort];

  networking.wireguard.interfaces.wg0 = {
    ips = ["${self.ip}/16"];
    listenPort = self.listenPort;
    privateKeyFile = "/etc/wireguard.privkey";
    peers = mesh.mkPeers "nix03";
  };
}
