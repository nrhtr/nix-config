{
  config,
  pkgs,
  fetchFromGitHub,
  lib,
  ...
}: let
  nix-colors = import <nix-colors>;
in {
  imports = [
    ./hardware-configuration.nix

    <home-manager/nixos>

    ./wireguard.nix
    ./borg.nix
    ./borg-notifier.nix

    # ./gateway.nix T7500

    ./../../common/shared.nix

    # stuff with home-manager
    # fixme: still assumes NixOS
    ./../../home/all.nix
  ];

  displayOutput = "LVDS-1";

  nixpkgs.config.permittedInsecurePackages = [
    "python3.9-poetry-1.1.14"
  ];

  nixpkgs.overlays = [
    (self: super: rec {
      discord = super.discord.overrideAttrs (
        _: {src = builtins.fetchTarball "https://discord.com/api/download?platform=linux&format=tar.gz";}
      );
      luakit = super.luakit.overrideAttrs (old: rec {
        version = "2.1";
        src = super.fetchFromGitHub {
          owner = "luakit";
          repo = "luakit";
          rev = version;
          sha256 = "11wd8r8n9y3qd1da52hzhyzxvif3129p2ka7gannkdm7bkjxd4df";
        };
      });
      silk-guardian = self.callPackage ../../packages/silk-guardian/default.nix {};
      jsonfui = self.callPackage ./../../packages/jsonfui/default.nix {};
      darktable = self.callPackage ./../../packages/darktable/default.nix {};
      wine = super.wine.override {wineBuild = "wine64";};
    })
    #(import "${
    #builtins.fetchTarball
    #"https://github.com/vlaci/openconnect-sso/archive/master.tar.gz"
    #}/overlay.nix")
  ];

  services.blueman.enable = true;

  # iphone
  services.usbmuxd.enable = true;

  services.smartd.enable = true;
  services.smartd.defaults.monitored = "-a -o on -s (S/../.././02|L/../../7/04)";

  # Auto-update laptop since we don't deploy with morph
  system.autoUpgrade.enable = true;

  # Distribute builds to nix02 (consider nix01?)
  #nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
  nix.buildMachines = [
    {
      hostName = "local";
      system = "x86_64-linux";
      speedFactor = 1;
    }
    {
      #hostName = "95.217.114.169";
      hostName = "nix02";
      system = "x86_64-linux";
      sshUser = "root";
      sshKey = "/root/.ssh/id_ed25519";
      speedFactor = 4;
    }
  ];

  virtualisation.docker.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmpOnTmpfs = true;

  boot.extraModulePackages = [pkgs.silk-guardian];
  boot.kernelModules = ["silk"];

  age.secrets.wifi.file = ../../secrets/wifi.age;
  age.identityPaths = [/etc/ssh/ssh_host_ed25519_key];
  networking = {
    hostName = "thinkpad";
    wireless = {
      enable = true;
      interfaces = ["wlp3s0"];
      extraConfig = ''
        ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
      '';

      environmentFile = "${config.age.secrets.wifi.path}";
      networks = {
        "Richard Gere 5G Rona".psk = "@PSK_HOME@";
        "Belong0F70DA-5G".psk = "@PSK_A@";
        "Jeremy's iPhone".psk = "@PSK_MOB@";
      };
    };

    firewall = {enable = true;};
  };

  # Use a swapfile, because we don't want to bother with another LUKS partition
  swapDevices = [
    {
      device = "/swapfile";
      size = 10000;
    }
  ];

  services.mpd = {
    enable = true;
    extraConfig = ''
      audio_output {
      type "pulse"
      name "Pulseaudio"
      server "127.0.0.1"
      }
    '';
    musicDirectory = "/home/jenga/music";
    user = "jenga";
  };

  hardware.pulseaudio.extraConfig = "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1";

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
    Host nix02
    Port 18061
  '';

  system.stateVersion = "22.05";

  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse # iphone
    #darktable # photo shit
    cargo # vim-clap
    texlive.combined.scheme-full
    #texlive-combined-full
    docker-compose
    pinentry-curses # for pass/gpg
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

    # ???
    linuxPackages.acpi_call

    # pimutils/khal

    # games
    #dwarf-fortress-packages.dwarf-therapist
    #dwarf-fortress-packages.dwarf-fortress
    dwarf-fortress-packages.dwarf-fortress-full
  ];
}
