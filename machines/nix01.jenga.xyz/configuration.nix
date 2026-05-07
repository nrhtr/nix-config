{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
    ../../common/shared.nix
    ../../common/wg-hosts.nix
  ];

  # NOTE: Before deploying, add nix01's host key to secrets/secrets.nix and re-key:
  #   ssh root@nix01 cat /etc/ssh/ssh_host_ed25519_key.pub
  #   agenix -r -i ~/.ssh/id_ed25519
  age.secrets.gandi.file = ../../secrets/gandi.age;

  boot.loader.grub.device = "/dev/vda"; # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  system.stateVersion = "21.11";

  networking.hostName = "nix01";

  networking.firewall.allowedTCPPortRanges = [
    {
      from = 80;
      to = 80;
    } # HTTP
    {
      from = 443;
      to = 443;
    } # HTTPS
  ];

  security.acme.defaults.email = "jeremy@jenga.xyz";
  security.acme.acceptTerms = true;
  security.acme.certs."vault.jenga.xyz" = {
    group = "nginx";
    dnsProvider = "gandiv5";
    credentialsFile = "${config.age.secrets.gandi.path}";
  };

  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://vault.jenga.xyz";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = true;
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "boycrisis.net" = {
        serverAliases = ["www.boycrisis.net"];
        forceSSL = true;
        enableACME = true;
        root = "/var/www/boycrisis.net";
      };

      "vault.jenga.xyz" = {
        listenAddresses = ["10.100.0.1"];
        forceSSL = true;
        useACMEHost = "vault.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
        };
      };
    };
  };

  # Store wg peer information
  /*
  containers.wg-etcd01 = {
    privateNetwork = true;
    localAddress = "10.60.0.10";
    hostAddress = "10.60.1.10";
    config = {
      config,
      pkgs,
      ...
    }: {
      networking.firewall.allowedTCPPorts = [2379 2380];
      services.etcd = {
        enable = true;
        name = "wg-etcd01";
        initialAdvertisePeerUrls = ["http://10.60.0.10:2380"];
        listenPeerUrls = ["http://10.60.0.10:2380"];
        advertiseClientUrls = ["http://10.60.0.10:2379"];
        listenClientUrls = ["http://10.60.0.10:2379"];
        initialCluster = [
          "wg-etcd01=http://10.60.0.10:2380"
          "wg-etcd02=http://10.60.0.20:2380"
        ];
      };
      systemd.services.etcd.serviceConfig.Restart = "always";
      systemd.services.etcd.serviceConfig.TimeoutStartSec = 60;
      systemd.services.etcd.serviceConfig.TimeoutStopSec = 60;
    };
  };

  containers.wg-etcd02 = {
    privateNetwork = true;
    localAddress = "10.60.0.20";
    hostAddress = "10.60.1.20";
    config = {
      config,
      pkgs,
      ...
    }: {
      networking.firewall.allowedTCPPorts = [2379 2380];
      services.etcd = {
        enable = true;
        name = "wg-etcd02";
        initialAdvertisePeerUrls = ["http://10.60.0.20:2380"];
        listenPeerUrls = ["http://10.60.0.20:2380"];
        advertiseClientUrls = ["http://10.60.0.20:2379"];
        listenClientUrls = ["http://10.60.0.20:2379"];
        initialCluster = [
          "wg-etcd01=http://10.60.0.10:2380"
          "wg-etcd02=http://10.60.0.20:2380"
        ];
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
    config = {
      config,
      pkgs,
      ...
    }: {};
  };

  containers.wg-node02 = {
    privateNetwork = true;
    localAddress = "10.60.0.2";
    #hostAddress  = "10.60.1.2";
    config = {
      config,
      pkgs,
      ...
    }: {};
  };
  */
}
