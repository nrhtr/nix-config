{
  config,
  pkgs,
  fetchFromGitHub,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    ./wireguard.nix
    ./borg.nix
    ./borg-notifier.nix

    ./../../common/shared.nix

    # stuff with home-manager
    # fixme: still assumes NixOS
    ./../../home/all.nix
  ];

  #displayOutput = "LVDS-1";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "python3.9-poetry-1.1.14"
  ];

  networking.firewall.interfaces.wg0.allowedTCPPorts = [8080];

  nixpkgs.overlays = [
    (self: super: rec {
      discord = super.discord.overrideAttrs (_: {
        src = builtins.fetchTarball "https://discord.com/api/download?platform=linux&format=tar.gz";
      });
      silk-guardian = self.callPackage ../../packages/silk-guardian/default.nix {
        linuxPackages = config.boot.kernelPackages;
      };
      jsonfui = self.callPackage ./../../packages/jsonfui/default.nix {};
      darktable = self.callPackage ./../../packages/darktable/default.nix {};
      wine = super.wine.override {wineBuild = "wine64";};
      niri = self.callPackage ./../../packages/niri/package.nix {};
      #niri = let
      #src = super.fetchFromGitHub {
      #owner = "axelkar";
      #repo = "niri";
      #rev = "fb27849";
      #hash = "sha256-1oAEmlB5QQay9ljP2YucC1iv5+COK3YzU8zqDH7Md2M=";
      #};
      #in
      #(super.niri.overrideAttrs (oldAttrs: {
      #doCheck = false;
      #inherit src;
      #buildNoDefaultFeature = false;
      ##buildFeatures = oldAttrs.buildFeatures ++ ["xdp-gnome-remote-desktop" "xdp-gnome-input-capture"];
      #cargoDeps = self.rustPlatform.fetchCargoVendor  {
      #inherit src;
      #hash = "sha256-gv87edvnN/j49Zy7bz7oQoj2xN01zLZ7WwjfjaHoOx4=";
      #outputHash = "sha256-";
      #outputHash = "";
      #outputHashAlgo = "sha256";
      #};
      #patches = [
      #(pkgs.fetchpatch {
      #url = "https://github.com/YaLTeR/niri/pull/1966.patch";
      #hash = "sha256-1BV7aSIR1j2CG7Hz5oDA5ZH4zuJkvbyrZlKVrLZytWc=";
      #})
      #];
      #})
      #);
    })
  ];

  services.locate.enable = true;
  services.blueman.enable = true;
  # iphone
  services.usbmuxd.enable = true;
  services.smartd.enable = true;
  services.smartd.defaults.monitored = "-a -o on -s (S/../.././02|L/../../7/04)";

  # Distribute builds to nix02 (consider nix01?)
  nix.distributedBuilds = true;
  nix.settings.trusted-users = ["@wheel"];
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
  nix.buildMachines = [
    {
      hostName = "nix02.wireguard";
      system = "x86_64-linux";
      sshUser = "root";
      sshKey = "/root/.ssh/id_ed25519";
      speedFactor = 12;
      supportedFeatures = ["big-parallel"];
    }
  ];

  virtualisation.docker.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.useTmpfs = true;

  boot.extraModulePackages = [pkgs.silk-guardian];
  boot.kernelModules = ["silk"];

  age.secrets.wifi.file = ../../secrets/wifi.age;
  age.identityPaths = [/etc/ssh/ssh_host_ed25519_key];
  networking = {
    hostName = "lappy";
    wireless = {
      enable = true;
      interfaces = ["wlp3s0"];
      extraConfig = ''
        ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
      '';

      secretsFile = "${config.age.secrets.wifi.path}";
      networks = {
        "TelstraD3CE90".pskRaw = "ext:PSK_TSM";
        #"Richard Gere 5G Rona".psk = "ext:PSK_HOME";
        #"Belong0F70DA-5G".psk = "ext:PSK_A";
        #"Jeremy's iPhone".psk = "ext:PSK_MOB";
      };
    };

    firewall = {
      enable = true;
    };
  };

  # Use a swapfile, because we don't want to bother with another LUKS partition
  swapDevices = [
    {
      device = "/swapfile";
      size = 10000;
    }
  ];

  # PipeWire + MPD setup
  services.mpd = {
    enable = true;
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "Pipewire output"
      }
    '';
    musicDirectory = "/home/jenga/music";
    user = "jenga";
  };

  systemd.services.mpd.environment = {
    XDG_RUNTIME_DIR = "/run/user/1000"; # User-id to look for PipeWire socket
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # leaving JACK disabled
  };

  services.tlp = {
    enable = true;
    settings = {
      USB_BLACKLIST = "05ac:12a8";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_BOOST_ON_AC = "1";
      CPU_BOOST_ON_BAT = "0";

      DISK_DEVICES = "sda";
      DISK_APM_LEVEL_ON_AC = "254";
      DISK_APM_LEVEL_ON_BAT = "128";

      SATA_LINKPWR_ON_AC = "max_performance";
      SATA_LINKPWR_ON_BAT = "min_power";
    };
  };

  # Disable the OpenSSH server.
  services.openssh.enable = false;

  # Make sure we do remote builds on the right port
  programs.ssh.extraConfig = ''
    Host nix02.wireguard
    Port 18061
  '';

  system.stateVersion = "22.05";

  environment.systemPackages = with pkgs; [
    lan-mouse
    libimobiledevice
    ifuse # iphone
    #darktable # photo shit
    cargo # vim-clap
    texlive.combined.scheme-full
    #texlive-combined-full
    docker-compose
    neofetch # full unixporn redditeur
    luakit
    #firefox
    obsidian # note taking
    python3Packages.yt-dlp
    pavucontrol
    anki-bin
    signal-desktop
    discord
    openssl
    morph
    playerctl
    spotify
    ffmpeg
    #vlc
    (vlc.overrideAttrs (old: {
      buildInputs = lib.lists.remove samba old.buildInputs;
    }))
    mpv
    blightmud

    waynergy

    # ???
    linuxPackages.acpi_call

    # pimutils/khal

    # games
    #dwarf-fortress-packages.dwarf-therapist
    #dwarf-fortress-packages.dwarf-fortress
    dwarf-fortress-packages.dwarf-fortress-full
  ];
}
