{lib, ...}: let
  mesh = import ../../common/wg-mesh.nix {inherit lib;};
  self = mesh.nodes.nix02;
in {
  networking.nat.enable = true;
  networking.nat.externalInterface = "enp5s0f0";
  networking.nat.internalInterfaces = ["wg0"];

  networking.firewall.allowedUDPPorts = [self.listenPort];

  networking.wireguard.interfaces.wg0 = {
    ips = ["${self.ip}/16"];
    listenPort = self.listenPort;
    privateKeyFile = "/etc/wireguard.privkey";
    peers = mesh.mkPeers "nix02";
  };
}
