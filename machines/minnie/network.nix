{
  pkgs,
  lib,
  ...
}: {
  networking.wg-quick.interfaces = {
    wg0 = {
      address = ["10.100.0.2"];
      privateKeyFile = "/etc/wireguard.privkey";

      peers = [
        {
          # nix01.jenga.xyz
          publicKey = "AlkTmqNuOHKyDRq6O4Pxg+fy/YDiAK8sos6Ylvx/aSk=";
          allowedIPs = ["10.100.0.0/16"];
          endpoint = "45.76.124.245:51820";

          persistentKeepalive = 25;
        }
      ];
    };
  };
}
