# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, fetchFromGitHub, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
    ./borg.nix
    ../../common/shared.nix
  ];

  nixpkgs.overlays = [
    (self: super:
      rec {
        luakit = super.luakit.overrideAttrs ( old: rec {
          version = "2.1";
          src = super.fetchFromGitHub {
            owner = "luakit";
            repo = "luakit";
            rev = version;
            sha256 = "11wd8r8n9y3qd1da52hzhyzxvif3129p2ka7gannkdm7bkjxd4df";
          };
        });
        sonata = super.sonata.overrideAttrs ( old: rec {
          version = "9999";
          src = super.fetchFromGitHub {
            owner = "multani";
            repo = "sonata";
            rev = "d6445e21d20f66edd1d2d53d329e654b4dce3cdc";
            sha256 = "1sqhbwqwiblwf38hljbwnc1163mi8mb5mha65gvmygnc2gij3h38";
          };
        });
        #silk-guardian = self.callPackage ../../packages/silk-guardian/default.nix { };
        obsidian = self.callPackage ../../packages/obsidian/default.nix { };
        xwobf = self.callPackage ./xwobf.nix { };
	python38 = super.python38.override {
	  # Careful, we're using a different self and super here!
	  packageOverrides = self: super: {
	    yt-dlp = super.buildPythonPackage rec {
	      pname = "yt-dlp";
	      version = "2022.1.21";
	      src = super.fetchPypi {
	        inherit pname version;
	        sha256 = "1qm9p1fh9qjma8fk2maw0y89nj23wlq1rhfz4lpafplv703w83i2";
	       };
	    };
	  };
        };

	#python3Packages = python3.pkgs;
      }
    )
    (import "${builtins.fetchTarball https://github.com/vlaci/openconnect-sso/archive/master.tar.gz}/overlay.nix")
  ];

  #nix = {
    #package = pkgs.nixUnstable;
    #extraOptions = "experimental-features = nix-command flakes";
  #};

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };
  environment.variables.EDITOR = "nvim";

  services.lorri.enable = true;
  services.blueman.enable = true;

  virtualisation.docker.enable = true;
  
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #boot.extraModulePackages = [ pkgs.silk-guardian ];
  #boot.kernelModules = [ "silk" ];

  networking = {
    hostName = "thinkpad"; # Define your hostname.
    wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    wireless.interfaces = [ "wlp3s0" ];

    extraHosts = ''
      10.100.0.1 nix01
    '';

    # Act as gateway for T7500
    nat = {
      enable = true;
      internalIPs = [ "172.16.10.0/24" ];
      internalInterfaces = [ "enp0s25" ];
      externalInterface = "wlp3s0";
    };

    interfaces.enp0s25.ipv4.addresses = [ {
      address = "172.16.10.254";
      prefixLength = 24;
    } ];

    firewall = {
      enable = true;
      allowPing = true;
      trustedInterfaces = [ "enp0s25" ];
    };

    #bridges.br0.interfaces = [ "wlp3s0" "enp0s25" ];
  };

  services.dhcpd4 = let
    netMask            = "255.255.255.0";
    gatewayIp          = "172.16.10.254";
    ipRangeFrom        = "172.16.10.10";
    ipRangeTo          = "172.16.10.253";
    broadcastAddress   = "172.16.10.255";
    commaSepDNSServers = "1.1.1.1";
  in {
    enable = true;
    interfaces = [ "enp0s25" ];
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

  # Use a swapfile, because we don't want to bother with another LUKS partition
  swapDevices = [
    { device = "/swapfile"; size = 10000; }
  ];

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  # Auto-login TTY
  services.getty.autologinUser = "jenga";

  services.xserver = {
    enable = true;

    displayManager.startx.enable = true;

    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;

      extraPackages = with pkgs; [
        dmenu i3status i3lock
      ];
    };
  };

  sound.enable = true;
  hardware.bluetooth.enable = true;
  hardware.pulseaudio.enable = true;
  users.extraUsers.jenga.extraGroups = [ "audio" "docker" ];

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

  services.gpm.enable = true;
  services.tlp.enable = true;
  services.tlp.extraConfig = ''
  USB_BLACKLIST="05ac:12a8"
  CPU_SCALING_GOVERNOR_ON_AC=performance
  CPU_SCALING_GOVERNOR_ON_BAT=powersave

  CPU_BOOST_ON_AC=1
  CPU_BOOST_ON_BAT=0

  DISK_DEVICES="sda"
  DISK_APM_LEVEL_ON_AC="254"
  DISK_APM_LEVEL_ON_BAT="128"

  SATA_LINKPWR_ON_AC=max_performance
  SATA_LINKPWR_ON_BAT=min_power
  '';

  # Disable the OpenSSH server.
  # services.openssh.enable = false;
  #networking.firewall.logRefusedConnections = true;

  environment.systemPackages = with pkgs; [
      texlive.combined.scheme-basic
      docker-compose
      cargo # vim-clap
      pinentry-curses # for pass/gpg
      pinentry-gtk2
      neofetch # full unixporn redditeur
      direnv # lorri/nix-shell
      pywal
      file
      luakit
      obsidian # note taking
      python3Packages.yt-dlp
      xwobf
      dejavu_fonts
      st # suckless terminal
      stow
      tmux
      xautolock
      linuxPackages.acpi_call
      xss-lock
      xclip
      pavucontrol
      unzip
      python38
      anki-bin
      signal-desktop
      discord

      # media
      youtube-dl
      sonata
      playerctl
      spotify
      ffmpeg
      vlc
      mpv

      # games
      dwarf-fortress-packages.dwarf-fortress-full

      # unimelb
      protobuf
      slack
      openconnect-sso
      zoom-us
      yubikey-manager
      thunderbird
      virtmanager
      git-review
      jq
      #evolution
      #evolution-ews
  ];

}
