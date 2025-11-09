{
  config,
  lib,
  pkgs,
  ...
}: {
  networking.wireguard.interfaces = {
    wg0 = {
      ips = ["10.100.0.4/16"];
      privateKeyFile = "/etc/wireguard.privkey";

      peers = [
        {
          # nix01.jenga.xyz
          publicKey = "AlkTmqNuOHKyDRq6O4Pxg+fy/YDiAK8sos6Ylvx/aSk=";
          allowedIPs = ["10.100.0.0/16"];
          endpoint = "45.76.124.245:51820";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
