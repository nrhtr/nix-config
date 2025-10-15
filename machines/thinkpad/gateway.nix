{
  config,
  pkgs,
  lib,
  ...
}: {
  networking = {
    # Act as gateway for T7500
    nat = {
      enable = true;
      internalIPs = ["172.16.10.0/24"];
      internalInterfaces = ["enp0s25"];
      externalInterface = "wlp3s0";
    };

    interfaces.enp0s25.ipv4.addresses = [
      {
        address = "172.16.10.254";
        prefixLength = 24;
      }
    ];

    firewall = {
      enable = true;
      allowPing = true;
      trustedInterfaces = ["enp0s25"];
    };

    bridges.br0.interfaces = ["wlp3s0" "enp0s25"];
  };

  services.dhcpd4 = let
    netMask = "255.255.255.0";
    gatewayIp = "172.16.10.254";
    ipRangeFrom = "172.16.10.10";
    ipRangeTo = "172.16.10.253";
    broadcastAddress = "172.16.10.255";
    commaSepDNSServers = "1.1.1.1";
  in {
    enable = true;
    interfaces = ["enp0s25"];
    extraConfig = ''
      ddns-update-style none;
      one-lease-per-client true;

      subnet 172.16.10.0 netmask ${netMask} {
        range ${ipRangeFrom} ${ipRangeTo};
        authoritative;

        # Allows clients to request up to a week (although they won't)
        max-lease-time 604800;
        # By default expire lease in 24 hours
        default-lease-time 86400;

        option subnet-mask         ${netMask};
        option broadcast-address   ${broadcastAddress};
        option routers             ${gatewayIp};
        option domain-name-servers ${commaSepDNSServers};
      }
    '';
  };
}
