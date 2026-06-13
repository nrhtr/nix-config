{
  config,
  pkgs,
  lib,
  ...
}: let
  hostName = "nix03";

  authKeys = import ../../common/ssh-keys.nix;

  networkInterface = "eno1";

  ipv4 = {
    address = "51.161.197.172";
    gateway = "51.161.197.254";
    prefixLength = 24;
  };

  hostId = "1145a50a";

  sources = import ../../npins;
  wgNodes = import ../../common/wg-nodes.nix;
  wgIp = wgNodes.nix03.ip;

  qbtInitialConfig = pkgs.writeText "qbittorrent-initial.conf" ''
    [Preferences]
    WebUI\Address=127.0.0.1
    WebUI\Port=8080
    WebUI\BasePath=/torrents
    WebUI\HostHeaderValidation=false
    WebUI\ReverseProxySupportEnabled=true
    WebUI\TrustedReverseProxiesList=127.0.0.1
    Downloads\SavePath=/home/jenga/downloads/
  '';

  bandsnatch = pkgs.rustPlatform.buildRustPackage {
    pname = "bandsnatch";
    version = "unstable";
    src = sources.bandsnatch;
    cargoLock.lockFile = "${sources.bandsnatch}/Cargo.lock";
  };

  beetsConfig = pkgs.writeText "beets-config.yaml" ''
    directory: /home/jenga/music
    library: /home/jenga/.local/share/beets/musiclibrary.blb
    import:
      hardlink: yes
      copy: no
      move: no
    plugins:
      - musicbrainz
      - fetchart
      - embedart
      - mbsync
    fetchart:
      auto: yes
    embedart:
      auto: yes
  '';
in {
  imports = [
    ./disko.nix
    ./borg.nix
    ./wireguard.nix
    "${sources.disko}/module.nix"
    "${sources.microvm-nix}/nixos-modules/host"

    ../../common/shared.nix
    ../../common/wg-hosts.nix
    ../../modules/zfs-unlock.nix
    ../../modules/disk-health.nix
    ../../modules/boot-alerts.nix
    ../../modules/urbit-gateway.nix
    ../../modules/remote-builder.nix
  ];

  networking.hostName = hostName;
  networking.hostId = hostId;

  networking.useDHCP = false;
  networking.interfaces."${networkInterface}" = {
    ipv4.addresses = [{inherit (ipv4) address prefixLength;}];
  };
  networking.defaultGateway = ipv4.gateway;
  networking.nameservers = [wgNodes.nix02.ip "1.1.1.1" "1.0.0.1"];

  boot.supportedFilesystems = ["zfs"];
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    copyKernels = true;
  };
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

  fileSystems."/boot-1".options = ["nofail"];
  fileSystems."/boot-2".options = ["nofail"];

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

  jenga.zfsUnlock = {
    enable = true;
    networkInterface = "eno1";
    networkInterfaceModule = "ixgbe";
    ipv4 = {inherit (ipv4) address gateway;};
    authorizedKeys = authKeys;
  };

  users.users.root.openssh.authorizedKeys.keys = authKeys;

  jenga.remoteBuilder.server.enable = true;

  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  age.secrets.fastmail-nix02.file = ../../secrets/fastmail-nix02.age;
  age.secrets.resend-key.file = ../../secrets/resend-key.age;
  age.secrets.gandi.file = ../../secrets/gandi.age;

  jenga.diskHealth = {
    enable = true;
    smtpPasswordFile = config.age.secrets.fastmail-nix02.path;
  };

  jenga.bootAlerts.enable = true;

  jenga.urbitGateway = {
    enable = true;
    resendApiKeyFile = config.age.secrets.resend-key.path;
    acmeEmail = "jeremy@jenga.xyz";
  };

  # ACME cert for nix03.jenga.xyz via Gandi DNS (used by Caddy for /torrents and /navidrome)
  security.acme = {
    acceptTerms = true;
    defaults.email = "jeremy@jenga.xyz";
    certs."nix03.jenga.xyz" = {
      dnsProvider = "gandiv5";
      credentialsFile = config.age.secrets.gandi.path;
      group = "caddy";
      reloadServices = ["caddy.service"];
      # Internal DNS (nix02 nsd) doesn't have the challenge TXT record;
      # Gandi public NS does. Skip lego's pre-check — Let's Encrypt validates
      # against the public NS directly, so issuance still works.
      dnsPropagationCheck = false;
    };
  };

  # Caddy must wait for cert on first deploy
  systemd.services.caddy = {
    wants = ["acme-nix03.jenga.xyz.service"];
    after = ["acme-nix03.jenga.xyz.service"];
  };

  # qBittorrent (no NixOS module; custom service)
  users.users.qbittorrent = {
    isSystemUser = true;
    group = "qbittorrent";
    home = "/var/lib/qbittorrent";
  };
  users.groups.qbittorrent = {
    members = ["jenga"];
  };

  systemd.services.qbittorrent = {
    description = "qBittorrent-nox daemon";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      HOME = "/var/lib/qbittorrent";
      XDG_CONFIG_HOME = "/var/lib/qbittorrent/.config";
      XDG_DATA_HOME = "/var/lib/qbittorrent/.local/share";
    };
    serviceConfig = {
      User = "qbittorrent";
      Group = "qbittorrent";
      Type = "simple";
      Restart = "on-failure";
      StateDirectory = "qbittorrent";
      UMask = "0002";
      ExecStartPre = pkgs.writeShellScript "qbittorrent-init" ''
        if [ ! -f "$XDG_CONFIG_HOME/qBittorrent/qBittorrent.conf" ]; then
          mkdir -p "$XDG_CONFIG_HOME/qBittorrent"
          cp ${qbtInitialConfig} "$XDG_CONFIG_HOME/qBittorrent/qBittorrent.conf"
        fi
      '';
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --confirm-legal-notice";
    };
  };

  # ProtectHome=true blocks /home entirely; read-only still prevents writes
  systemd.services.navidrome.serviceConfig.ProtectHome = lib.mkForce "read-only";

  # Navidrome (subsonic-compatible server)
  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/home/jenga/music";
      BaseURL = "/navidrome";
    };
  };

  # Music library dir (owned by jenga so beets can write there)
  # Navidrome reads it as world-readable (0755).
  # Downloads dir is owned by qbittorrent:qbittorrent; jenga is in that group.
  systemd.tmpfiles.rules = [
    "d /home/jenga/music 0755 jenga users -"
    "d /home/jenga/downloads 0775 jenga qbittorrent -"
    "d /home/jenga/watch 0775 jenga qbittorrent -"
    "d /home/jenga/.local/share/beets 0755 jenga users -"
    "d /home/jenga/.config/beets 0755 jenga users -"
    "L+ /home/jenga/.config/beets/config.yaml - jenga users - ${beetsConfig}"
  ];

  environment.systemPackages = [pkgs.beets bandsnatch];

  # qBittorrent at /torrents, Navidrome at /navidrome — WireGuard only
  services.caddy.virtualHosts."nix03.jenga.xyz" = {
    extraConfig = ''
      bind ${wgIp}
      tls /var/lib/acme/nix03.jenga.xyz/cert.pem /var/lib/acme/nix03.jenga.xyz/key.pem

      redir /torrents /torrents/ 301

      handle_path /torrents* {
        reverse_proxy 127.0.0.1:8080
      }

      handle /navidrome* {
        reverse_proxy 127.0.0.1:4533
      }

      handle {
        respond 404
      }
    '';
  };

  # Monty project VM (NixOS + Firecracker via microvm)
  microvm.vms.monty = {
    # Plain NixOS module; the host module runs eval-config and auto-imports
    # the microvm guest module for us.
    config = import ./monty-vm.nix;
    autostart = true;
    restartIfChanged = false;
  };

  # Assign 10.0.0.1/24 to the monty tap whenever it appears.
  # udev fires on interface creation, avoiding ExecStartPost race conditions.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="monty", RUN+="${pkgs.iproute2}/bin/ip addr add 10.0.0.1/24 dev monty"
  '';

  # NAT outbound traffic from the VM so it can reach the internet
  networking.nat = {
    enable = true;
    internalInterfaces = ["monty"];
    externalInterface = networkInterface;
  };

  # DNAT: host:2223 -> monty:22 (SSH), host:8443 -> monty:443 (raw TLS
  # passthrough; the VM's yoink proxy terminates TLS, not Caddy),
  # host:8080 -> monty:80 (plain HTTP, e.g. ACME redirects).
  networking.firewall.extraCommands = ''
    iptables -t nat -A PREROUTING -i ${networkInterface} -p tcp --dport 2223 -j DNAT --to-destination 10.0.0.2:22
    iptables -t nat -A PREROUTING -i ${networkInterface} -p tcp --dport 8443 -j DNAT --to-destination 10.0.0.2:443
    iptables -t nat -A PREROUTING -i ${networkInterface} -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.2:80
    iptables -t nat -A OUTPUT -p tcp --dport 2223 -j DNAT --to-destination 10.0.0.2:22
    iptables -t nat -A OUTPUT -p tcp --dport 8443 -j DNAT --to-destination 10.0.0.2:443
    iptables -t nat -A OUTPUT -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.2:80
    iptables -A FORWARD -d 10.0.0.2 -j ACCEPT
  '';

  # SSH (2223) and raw HTTPS forward (8443) to the monty VM.
  # 8443 -> VM:443 is a TCP DNAT: TLS passes through untouched to the
  # yoink proxy on the VM, which terminates it. Caddy handles Urbit only.
  networking.firewall.allowedTCPPorts = [2223 8443 8080];

  time.timeZone = "UTC";

  system.stateVersion = "25.11";
}
