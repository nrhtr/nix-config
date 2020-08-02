{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
    ../common/shared.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  networking.hostName = "nix01.jenga.xyz";

  networking.firewall.allowedTCPPortRanges = [
    { from = 80;  to = 80;  } # HTTP
    { from = 443; to = 443; } # HTTPS
  ];

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "jenga.xyz" = {
      serverAliases = ["www.jenga.xyz"];
      forceSSL = true;
      enableACME = true;
      root = "/var/www/jenga.xyz";
    };

    "boycrisis.net" = {
      serverAliases = ["www.boycrisis.net"];
      forceSSL = true;
      enableACME = true;
      root = "/var/www/boycrisis.net";
    };

    "paulfl.art" = {
      serverAliases = ["www.paulfl.art"];
      forceSSL = true;
      enableACME = true;
      root = "/var/www/paulfl.art";
    };
  };

  # Store wg peer information
  containers.wg-etcd01 = {
    privateNetwork = true;
    localAddress = "10.60.0.10";
    hostAddress  = "10.60.1.10";
    config = { config, pkgs, ... }:
    {
      networking.firewall.allowedTCPPorts = [ 2379 2380 ];
      services.etcd = {
        enable = true;
        name = "wg-etcd01";
        initialAdvertisePeerUrls = ["http://10.60.0.10:2380"];
        listenPeerUrls           = ["http://10.60.0.10:2380"];
        advertiseClientUrls      = ["http://10.60.0.10:2379"];
        listenClientUrls         = ["http://10.60.0.10:2379"];
        initialCluster           = ["wg-etcd01=http://10.60.0.10:2380"
                                    "wg-etcd02=http://10.60.0.20:2380"];
      };
      systemd.services.etcd.serviceConfig.Restart = "always";
      systemd.services.etcd.serviceConfig.TimeoutStartSec = 60;
      systemd.services.etcd.serviceConfig.TimeoutStopSec = 60;
    };
  };


  containers.wg-etcd02 = {
    privateNetwork = true;
    localAddress = "10.60.0.20";
    hostAddress  = "10.60.1.20";
    config = { config, pkgs, ... }:
    {
      networking.firewall.allowedTCPPorts = [ 2379 2380 ];
      services.etcd = {
        enable = true;
        name = "wg-etcd02";
        initialAdvertisePeerUrls = ["http://10.60.0.20:2380"];
        listenPeerUrls           = ["http://10.60.0.20:2380"];
        advertiseClientUrls      = ["http://10.60.0.20:2379"];
        listenClientUrls         = ["http://10.60.0.20:2379"];
        initialCluster           = ["wg-etcd01=http://10.60.0.10:2380"
                                    "wg-etcd02=http://10.60.0.20:2380"];
      };
      systemd.services.etcd.serviceConfig.Restart = "always";
      systemd.services.etcd.serviceConfig.TimeoutStartSec = 60;
      systemd.services.etcd.serviceConfig.TimeoutStopSec = 60;
    };
  };

  containers.wg-node01 = {
    privateNetwork = true;
    localAddress = "10.60.0.1";
    #hostAddress  = "10.60.1.1";
    config = { config, pkgs, ... }:
    {
    };
  };

  containers.wg-node02 = {
    privateNetwork = true;
    localAddress = "10.60.0.2";
    #hostAddress  = "10.60.1.2";
    config = { config, pkgs, ... }:
    {
    };
  };
}
