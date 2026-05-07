# Full NixOS configuration for a ZFS server with full disk encryption hosted on Hetzner.
# See <https://mazzo.li/posts/hetzner-zfs.html> for more information.
{
  config,
  pkgs,
  ...
}: let
  hostName = "nix02";

  # For both initrd SSH server and root on booted system
  authKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvB0TRd3YN3/aQUCC+lNivZ6pRe8iWfX0+SZdRfKDhO root@thinkpad"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@thinkpad"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJBLHeD2QmiFu75rRXYKuhLLY1SpI3LCyUH5TO7iVHr jenga@minnie"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/7jyd975XBaZXTP7LzYGvecE3Hk6dJEWy9miWNzYH1 root@minnie"
  ];

  # See <https://major.io/2015/08/21/understanding-systemds-predictable-network-device-names/#picking-the-final-name>
  # for a description on how to find out the network card name reliably.
  networkInterface = "enp5s0f0";

  # Needed to load the right driver before boot for the initrd SSH session.
  networkInterfaceModule = "ixgbe";

  # From the Hetzner control panel
  ipv4 = {
    address = "51.222.109.62";
    gateway = "51.222.109.254";
    netmask = "255.255.255.0";
    prefixLength = 24; # must match the netmask!
  };
  ipv6 = {
    address = "2607:5300:203:883e::1";
    gateway = "2607:5300:0203:88ff:00ff:00ff:00ff:00ff";
    prefixLength = 128;
  };

  # Required for ZFS, even with only local disks
  # cat /etc/machine-id  | head -c8
  hostId = "cd33d586";

  # Mail sender / recepient
  emailTo = "jeremy@jenga.xyz"; # where to send the notifications
  emailFrom = "root@${hostName}.jenga.xyz"; # who should be the sender in the emails

  msmtpAccount = {
    auth = "on";
    tls = "on";
    tls_starttls = "off";
    host = "smtp.fastmail.com";
    port = "465";
    user = "jeremy@jenga.xyz";
    passwordeval = "cat ${config.age.secrets.fastmail-nix02.path}";
    from = emailFrom;
  };

  cgitrc = pkgs.writeText "cgitrc" ''
    css=/cgit.css
    logo=/cgit.png
    favicon=/favicon.ico
    root-title=git.jenga.xyz
    root-desc=Git repositories
    clone-url=https://git.jenga.xyz/$CGIT_REPO_URL
    enable-index-owner=0
    enable-commit-graph=1
    enable-log-filecount=1
    enable-log-linecount=1
    max-stats=quarter
    snapshots=tar.gz zip
    scan-path=/var/lib/cgit/repos
  '';

  # Sends an email with some heading and the zpool status
  sendEmailEvent = {event}: ''
    printf "Subject: ${hostName} ${event} ''$(${pkgs.coreutils}/bin/date --iso-8601=seconds)\n\nzpool status:\n\n''$(${pkgs.zfs}/bin/zpool status)" | ${pkgs.msmtp}/bin/msmtp -a default ${emailTo}
  '';

  # Enables emails for ZFS
  customizeZfs = zfs: (zfs.override {enableMail = true;});

  sources = import ../../npins;
  dns = import sources."dns.nix" {inherit pkgs;};
in {
  imports = [
    ./hardware-configuration.nix
    ./wireguard.nix
    ./borg.nix
    ./containers/default.nix

    #../../home/terminal.nix

    ../../common/shared.nix
    ../../common/wg-hosts.nix
    ../../modules/genesis.nix
    # override module using python 2 package
    ../../modules/websockify.nix
  ];

  age.secrets = {
    fastmail-nix02 = {
      file = ../../secrets/fastmail-nix02.age;
      group = "smtp-relay";
      mode = "0440";
    };
    twilio-env.file = ../../secrets/twilio-env.age;
    gandi.file = ../../secrets/gandi.age;
    kbfirmware-env.file = ../../secrets/kbfirmware-env.age;
    spruce-env.file = ../../secrets/spruce-env.age;
    kbfirmware-xyz-key = {
      file = ../../secrets/kbfirmware-xyz-key.age;
      group = "nginx";
      mode = "0440";
    };
    jenga-dev-key = {
      file = ../../secrets/jenga-dev-key.age;
      group = "nginx";
      mode = "0440";
    };
  };

  # We want to still be able to boot without one of these
  fileSystems."/boot-1".options = ["nofail"];
  fileSystems."/boot-2".options = ["nofail"];

  # Use GRUB2 as the boot loader.
  # We don't use systemd-boot because I haven't looked into support for mirrored boot
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
  };

  # This will mirror all UEFI files, kernels, grub menus and
  # things needed to boot to the other drive.
  # We set 'nodev' and specify EFI paths since we're booting with UEFI
  boot.loader.grub.mirroredBoots = [
    {
      path = "/boot-1";
      efiSysMountPoint = "/boot-1";
      devices = ["nodev"];
    }
    {
      path = "/boot-2";
      efiSysMountPoint = "/boot-2";
      devices = ["nodev"];
    }
  ];

  # We need email support in ZFS for ZED. If you're using ZFS unstable, you need
  # to patch `zfsUnstable` too.
  nixpkgs.overlays = [
    (self: super: {
      zfsStable = customizeZfs super.zfsStable;
      genesis = self.callPackage ./../../packages/genesis/default.nix {};
      kbfirmware = self.callPackage ./../../packages/kbfirmware/default.nix {};
      spruce = let
        pkgs-unstable = import (import ../../npins).nixpkgs-unstable {
          inherit (self) system;
          config = {};
        };
      in
        self.callPackage ./../../packages/spruce/default.nix {
          buildGoModule = pkgs-unstable.buildGoModule;
        };
      wg-exit-node = self.callPackage ./../../packages/wg-exit-node/default.nix {};
    })
  ];

  networking.hostName = hostName;

  # ZFS options from <https://nixos.wiki/wiki/NixOS_on_ZFS>
  networking.hostId = hostId;
  boot.loader.grub.copyKernels = true;
  boot.supportedFilesystems = ["zfs"];

  # Network configuration (Hetzner uses static IP assignments, and we don't use DHCP here)
  networking.useDHCP = false;
  networking.interfaces."${networkInterface}" = {
    ipv4.addresses = [{inherit (ipv4) address prefixLength;}];
    ipv6.addresses = [{inherit (ipv4) address prefixLength;}];
  };
  networking.defaultGateway = ipv4.gateway;
  networking.defaultGateway6 = {
    address = ipv6.gateway;
    interface = networkInterface;
  };
  networking.nameservers = ["127.0.0.1"];

  # Remote unlocking, see <https://nixos.wiki/wiki/NixOS_on_ZFS>,
  # section "Unlock encrypted zfs via ssh on boot"
  boot.initrd.availableKernelModules = [networkInterfaceModule];
  boot.kernelParams = [
    # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
    # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
    # The server ip refers to the NFS server -- we don't need it.
    "ip=${ipv4.address}::${ipv4.gateway}:${ipv4.netmask}:${hostName}-initrd:${networkInterface}:off:8.8.8.8"
  ];
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;

      # To prevent ssh clients from freaking out because a different host key is used,
      # a different port for ssh is useful (assuming the same host has also a regular sshd running)
      port = 2222;

      # hostKeys paths must be unquoted strings, otherwise you'll run into issues
      # with boot.initrd.secrets the keys are copied to initrd from the path specified;
      # multiple keys can be set you can generate any number of host keys using
      # `ssh-keygen -t ed25519 -N "" -f /boot-1/initrd-ssh-key`
      hostKeys = [
        /boot-1/initrd-ssh-key
        /boot-2/initrd-ssh-key
      ];

      authorizedKeys = authKeys;
    };

    # this will automatically load the zfs password prompt on login
    # and kill the other prompt so boot can continue
    postCommands = ''
      cat <<EOF > /root/.profile
      if pgrep -x "zfs" > /dev/null
      then
        until zfs load-key -a; do
          echo "Incorrect passphrase, try again."
        done
        killall zfs
      else
        echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
      fi
      EOF
    '';
  };

  # SSH
  users.users.root.openssh.authorizedKeys.keys = authKeys;
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

  # mstp setup
  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      aliases = builtins.toFile "aliases" ''
        default: ${emailTo}
      '';
    };
    accounts.default = msmtpAccount;
  };

  # ZED setup (ZFS notifications)
  # Check out <https://github.com/openzfs/zfs/blob/master/cmd/zed/zed.d/zed.rc> for
  # options.
  services.zfs.zed.enableMail = true;
  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [emailTo];
    ZED_EMAIL_OPTS = "-a 'FROM:${emailFrom}' -s '@SUBJECT@' @ADDRESS@";
    ZED_NOTIFY_VERBOSE = true;
  };

  # smartd email notifications -- probably redundant given ZED, but
  # you never know.
  services.smartd.enable = true;
  services.smartd.notifications.mail.enable = true;
  services.smartd.notifications.mail.sender = emailFrom;
  services.smartd.notifications.mail.recipient = emailTo;

  # Email alerts on startup, shutdown, and Mondays :).
  #
  # For startup / shutdown messages we have two services that
  # stay alive from boot since shutdown. The boot alert sends
  # a message at the beginning, the shutdown message sends a message
  # at the end (through ExecStop, which in nix is `preStop`).
  #
  # This seems to be the most reliable way of sending messages before
  # shutdown in systemd: the main advantage is that since we specify
  # `after = [ "network.target" ]`, we know that it will be stopped
  # before the network gets stopped, since services are stopped
  # in reverse order. See <https://serverfault.com/a/785355>.
  #
  # Moreover, the RemainAfterExit is needed so that we do not
  # restart the service every time we change the configuration
  # (unless the service has changed).
  systemd.services."boot-mail-alert" = {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = sendEmailEvent {event = "just booted";};
  };
  systemd.services."shutdown-mail-alert" = {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = "true";
    preStop = sendEmailEvent {event = "is shutting down";};
  };
  systemd.services."weekly-mail-alert" = {
    serviceConfig.Type = "oneshot";
    script = sendEmailEvent {event = "is still alive";};
  };
  systemd.timers."weekly-mail-alert" = {
    wantedBy = ["timers.target"];
    partOf = ["weekly-mail-alert.service"];
    timerConfig.OnCalendar = "weekly";
  };

  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;
  virtualisation.podman.extraPackages = [pkgs.zfs];
  virtualisation.oci-containers.backend = "podman";
  virtualisation.containers.storage.settings = {
    storage = {
      driver = "zfs";
      graphroot = "/var/lib/containers/storage";
      runroot = "/run/containers/storage";
    };
  };

  # Use DNS ACME challenge because I want to serve this only
  # over Wireguard but still have the conveniece of a public CA
  security.acme.defaults.email = "jeremy@jenga.xyz";
  security.acme.acceptTerms = true;
  security.acme.certs = {
    "live.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "actual.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "sorpex.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "tallur.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "fonpub.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "photos.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "share.jenga.dev" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "spruce.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
    "up.jenga.xyz" = {
      group = "nginx";
      dnsProvider = "gandiv5";
      credentialsFile = "${config.age.secrets.gandi.path}";
    };
  };

  services.actual = {
    enable = true;
    settings.hostname = "127.0.0.1";
    settings.port = 5006;
  };

  services.immich = {
    enable = true;
    host = "127.0.0.1";
  };

  networking.firewall.interfaces.wg0.allowedTCPPorts = [
    80
    443
    53
  ];
  networking.firewall.interfaces.wg0.allowedUDPPorts = [53];

  networking.firewall = {
    # genesis terminal / HTTP UI
    allowedTCPPorts =
      [
        80 # HTTP (needed for ACME HTTP-01 challenge)
        443
        1138
      ]
      ++ [25565]; # minecraft
    allowedUDPPorts = [25565]; # minecraft
  };

  users.users.kbfirmware = {
    isSystemUser = true;
    group = "kbfirmware";
    extraGroups = ["smtp-relay"];
  };
  users.groups.kbfirmware = {};

  users.users.spruce = {
    isSystemUser = true;
    group = "spruce";
  };
  users.groups.spruce = {};
  users.groups.smtp-relay = {};

  systemd.services.spruce = {
    description = "Spruce listing scanner";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    environment = {
      SPRUCE_LISTEN_ADDR = "127.0.0.1:8090";
      SPRUCE_DB_PATH = "/var/lib/spruce/spruce.db";
      SPRUCE_SITE_URL = "https://spruce.jenga.xyz";
      SPRUCE_SMTP_HOST = "smtp.fastmail.com";
      SPRUCE_SMTP_PORT = "465";
      SPRUCE_EMAIL_FROM = "spruce@jenga.xyz";
      SPRUCE_EMAIL_TO = "jeremy@jenga.xyz";
      SPRUCE_DIGEST_TZ = "Australia/Sydney";
    };
    serviceConfig = {
      ExecStart = "${pkgs.spruce}/bin/spruce";
      User = "spruce";
      Group = "spruce";
      StateDirectory = "spruce";
      Restart = "on-failure";
      EnvironmentFile = config.age.secrets.spruce-env.path;
    };
  };

  systemd.services.kbfirmware = {
    description = "kbfirmware backend API server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    environment = {
      SITE_URL = "https://kbfirmware.xyz";
      SITE_URL_ALIASES = "kbfirmware.jenga.dev";
      LISTEN_ADDR = "127.0.0.1:8080";
      DB_PATH = "/var/lib/kbfirmware/kbfirmware.db";
    };
    serviceConfig = {
      ExecStart = "${pkgs.kbfirmware}/bin/kbfirmware";
      User = "kbfirmware";
      Group = "kbfirmware";
      StateDirectory = "kbfirmware";
      Restart = "on-failure";
      EnvironmentFile = config.age.secrets.kbfirmware-env.path;
    };
  };

  services.genesis.enable = true;
  services.genesis.hostname = "tlon.jenga.xyz";

  services.bluemap = {
    enable = true;
    eula = true;

    maps = {
      "overworld" = {
        world = "${config.services.minecraft-server.dataDir}/world";
        ambient-light = 0.2;
      };
    };

    enableNginx = false;
  };

  services.minecraft-server = {
    enable = true;
    declarative = true;
    eula = true;
    openFirewall = false; # manage this ourselves
    whitelist = {
      jenga = "de7e40bc-9fa7-486f-9e7e-cbd337e2ef74";
      balfourine = "3a35d9cf-e22c-4137-bc17-12c89689d8a7";
      the_sikness = "5324eaec-1fc7-4fc7-8123-0f077e700cd5";
    };
    serverProperties = {
      difficulty = 4;
      gamemode = 0;
      max-players = 4;
      motd = "NixOS Minecraft server!";
      white-list = true;
    };
    jvmOpts = "-Xmx2560M -Xms1024M -Dfml.readTimeout=60";
  };

  services.nsd = {
    enable = true;
    interfaces = ["127.0.0.1"];
    zones = {
      "jenga.xyz" = {
        data = dns.lib.toString "jenga.xyz" (import ../../common/jenga.xyz.nix {inherit dns;});
      };
    };
  };

  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = ["10.100.0.6" "127.0.0.1"];
        access-control = ["10.100.0.0/16 allow" "127.0.0.0/8 allow"];
        do-not-query-localhost = "no";
        domain-insecure = ["jenga.xyz"];
      };
      stub-zone = [
        {
          name = "jenga.xyz";
          stub-addr = "127.0.0.1";
        }
      ];
      forward-zone = [
        {
          name = ".";
          forward-addr = ["1.1.1.1" "1.0.0.1"];
        }
      ];
    };
  };

  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

    virtualHosts = {
      "minecraft.jenga.xyz" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        enableACME = true;

        root = config.services.bluemap.webRoot;

        locations = {
          "/" = {
            index = "index.html";
            extraConfig = "try_files \$uri \$uri/ =404;";
          };

          "@empty".return = "204";

          "~* ^/maps/[^/]*/tiles/" = {
            extraConfig = ''
              error_page 404 = @empty;
              gzip_static always;
              # Crucial for some browsers to realize these are compressed
              add_header Content-Encoding gzip;
              # Tiles don't change often, cache them!
              expires 7d;
              add_header Cache-Control "public, no-transform";
            '';
          };
        };
      };
      "git.jenga.xyz" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        enableACME = true;
        root = "${pkgs.cgit}/cgit";
        locations = {
          "~* ^/(cgit\\.css|cgit\\.png|favicon\\.ico)$" = {
            extraConfig = "try_files $uri =404;";
          };
          "~* ^/cgit/(.*)" = {
            extraConfig = ''
              alias ${pkgs.cgit}/cgit/$1;
            '';
          };
          "/" = {
            extraConfig = ''
              include ${pkgs.nginx}/conf/fastcgi_params;
              fastcgi_param SCRIPT_FILENAME ${pkgs.cgit}/cgit/cgit.cgi;
              fastcgi_param PATH_INFO $uri;
              fastcgi_param QUERY_STRING $args;
              fastcgi_param CGIT_CONFIG ${cgitrc};
              fastcgi_pass unix:${config.services.fcgiwrap.instances.cgit.socket.address};
            '';
          };
        };
      };
      "actual.jenga.xyz" = {
        listenAddresses = ["10.100.0.6"];
        forceSSL = true;
        useACMEHost = "actual.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:5006/";
        };
      };
      "sorpex.jenga.xyz" = {
        listenAddresses = ["10.100.0.6"];
        forceSSL = true;
        useACMEHost = "sorpex.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:7080/";
        };
      };
      "tallur.jenga.xyz" = {
        listenAddresses = ["10.100.0.6"];
        forceSSL = true;
        useACMEHost = "tallur.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:7081/";
        };
      };
      "fonpub.jenga.xyz" = {
        listenAddresses = ["10.100.0.6"];
        forceSSL = true;
        useACMEHost = "fonpub.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:7082/";
        };
      };
      "photos.jenga.xyz" = {
        listenAddresses = ["10.100.0.6"];
        forceSSL = true;
        useACMEHost = "photos.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:2283/";
          proxyWebsockets = true;
        };
      };
      "spruce.jenga.xyz" = {
        listenAddresses = ["10.100.0.6"];
        forceSSL = true;
        useACMEHost = "spruce.jenga.xyz";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8090/";
        };
      };
      "up.jenga.xyz" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        useACMEHost = "up.jenga.xyz";
        locations = {
          "= /logo.jpeg" = {
            alias = "${../../monitoring/logo.jpeg}";
          };
          "/" = {
            proxyPass = "http://10.100.0.7:8080/";
          };
        };
      };
      "kbfirmware.jenga.dev" = {
        listenAddresses = [ipv4.address];
        addSSL = true;
        sslCertificate = ../../secrets/jenga.dev.cert;
        sslCertificateKey = config.age.secrets.jenga-dev-key.path;
        locations."/" = {
          return = "301 https://kbfirmware.xyz$request_uri";
        };
      };
      "www.kbfirmware.xyz" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        sslCertificate = ../../secrets/kbfirmware.xyz.cert;
        sslCertificateKey = config.age.secrets.kbfirmware-xyz-key.path;
        locations."/" = {
          return = "301 https://kbfirmware.xyz$request_uri";
        };
      };
      "kbfirmware.xyz" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        # use Cloudflare origin cert
        sslCertificate = ../../secrets/kbfirmware.xyz.cert;
        sslCertificateKey = config.age.secrets.kbfirmware-xyz-key.path;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080/";
        };
      };
      # Public Immich access - restricted to share paths only
      "share.jenga.dev" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        useACMEHost = "share.jenga.dev";
        locations = {
          # Share pages
          "/share/" = {
            proxyPass = "http://127.0.0.1:2283";
            proxyWebsockets = true;
          };
          # API endpoints needed for shares to work
          "/api/shared-links/" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          "/api/assets/" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          "/api/albums/" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          "/api/timeline/" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          # Server info endpoints
          "/api/server/config" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          "/api/server/media-types" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          "/api/server/features" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          # Static assets (JS, CSS, etc.)
          "~* \\.(jpg|jpeg|png|gif|css|js|ico|svg|json)$" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          "/_app/" = {
            proxyPass = "http://127.0.0.1:2283";
          };
          # Block everything else
          "/" = {
            return = "403";
          };
        };
      };
      "tlon.jenga.xyz" = {
        listenAddresses = [ipv4.address];
        forceSSL = true;
        enableACME = true;
        root = "/var/www/tlon.jenga.xyz";

        locations = {
          "^~ /file/" = {
            alias = "/var/www/tlon.jenga.xyz/file/";
          };
          "^~ /client/" = {
            alias = "/var/www/tlon.jenga.xyz/client/";
          };
          "/connect" = {
            proxyPass = "http://127.0.0.1:8138";
            proxyWebsockets = true;
          };
          "/" = {
            proxyPass = "http://127.0.0.1:1180/";
            extraConfig = ''
              proxy_redirect http://tlon.jenga.xyz:1180/ /;
              proxy_redirect https://tlon.jenga.xyz:1180/ /;
            '';
          };
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/cgit/repos 0755 root root -"
  ];

  services.fcgiwrap.instances.cgit = {
    socket = {
      inherit (config.services.nginx) user group;
    };
    process = {
      inherit (config.services.nginx) user group;
    };
  };

  services.networking.my_websockify = {
    enable = true;
    portMap = {
      "8138" = 1138;
    };
  };

  environment.systemPackages = [pkgs.claude-code];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
