{
  config,
  lib,
  pkgs,
  ...
}: {
  networking.nat.enable = true;
  networking.nat.externalInterface = "ens3";
  networking.nat.internalInterfaces = ["wg0"];

  networking.firewall.allowedUDPPortRanges = [
    {
      from = 51820;
      to = 51820;
    }
  ];

  networking.wireguard.interfaces = {
    wg0 = {
      ips = ["10.100.0.1/16"];
      listenPort = 51820;
      privateKeyFile = "/etc/wireguard.privkey";

      peers = [
        {
          # iPhone
          publicKey = "vaD8ITVvM5mNJW4Z+iXZvsN6WJIgi7ZjVxDWIh42XV4=";
          allowedIPs = ["10.100.0.3/32"];
        }
        {
          # Thinkpad
          publicKey = "dIJ1EYTiyRbT5TJQ+5wi04uyFOjvoti09wrNYmwmBUI=";
          allowedIPs = ["10.100.0.4/32"];
        }
        {
          # PC-Engines APU2
          publicKey = "3Px0oJgiRegKzctSdhzfuuUAy62PyN5z65WWVmiyDyM=";
          allowedIPs = ["10.100.0.5/32"];
        }
        {
          # nix02.jenga.xyz
          publicKey = "WbvPXoAJtKFr9A2uiCj+Y++tA8Iyh2Yp5HI7/NTzIxA=";
          allowedIPs = ["10.100.0.6/32"];
        }
      ];
    };
  };
}
