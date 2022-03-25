{ config, lib, pkgs, ... }:

{
  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ "10.100.0.4/16" ];

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/etc/wireguard.privkey";

      peers = [{ # nix01.jenga.xyz
        publicKey = "AlkTmqNuOHKyDRq6O4Pxg+fy/YDiAK8sos6Ylvx/aSk=";

        # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
        allowedIPs = [ "10.100.0.0/16" ];

        endpoint = "45.76.124.245:51820";

        # Send keepalives every 25 seconds. Important to keep NAT tables alive.
        persistentKeepalive = 25;
      }];
    };
  };
}
