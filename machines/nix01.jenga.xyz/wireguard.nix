{ config, lib, pkgs, ... }:

{
  # enable NAT
  networking.nat.enable = true;
  networking.nat.externalInterface = "ens3";
  networking.nat.internalInterfaces = [ "wg0" ];

  networking.firewall.allowedUDPPortRanges = [
    { from = 51820; to = 51820; }
  ];

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ "10.100.0.1/16" ];

      # The port that Wireguard listens to. Must be accessible by the client.
      listenPort = 51820;

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/etc/wireguard.privkey";

      peers = [
        { # iPhone
          publicKey = "vaD8ITVvM5mNJW4Z+iXZvsN6WJIgi7ZjVxDWIh42XV4=";
          allowedIPs = [ "10.100.0.3/32" ];
        }
        { # Thinkpad
          publicKey = "dIJ1EYTiyRbT5TJQ+5wi04uyFOjvoti09wrNYmwmBUI=";
          allowedIPs = [ "10.100.0.4/32" ];
        }
        { # PC-Engines APU2
          publicKey = "3Px0oJgiRegKzctSdhzfuuUAy62PyN5z65WWVmiyDyM=";
          allowedIPs = [ "10.100.0.5/32" ];
        }
      ];
    };
  };
}
