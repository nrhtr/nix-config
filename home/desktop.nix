{
  config,
  pkgs,
  lib,
  ...
}: {
  #options.displayOutput = mkOption {
  #type = types.str;
  #default = null;
  #};

  config = {
    time.timeZone = "Australia/Melbourne";
    programs.sway.enable = true;

    fonts.packages = with pkgs; [
      dejavu_fonts
      font-awesome_4
      #nerdfonts
      terminus_font
      inconsolata
    ];

    age.secrets.sonata = {
      owner = "jenga";
      file = ../secrets/sonata.age;
    };

    # Auto-login TTY
    services.getty.autologinUser = "jenga";

    hardware.bluetooth.enable = true;
    users.extraUsers.jenga.extraGroups = [
      "audio"
      "docker"
    ];

    services.gpm.enable = true;

    home-manager.users.jenga = {
      imports = [../modules/sonata/default.nix];

      gtk.enable = true;
      xdg.portal = {
        enable = true;
        config.common.default = "gnome";
        extraPortals = with pkgs;
          lib.mkForce [
            xdg-desktop-portal-gtk
            xdg-desktop-portal-gnome
          ];
      };

      home.packages = with pkgs; [
        fuzzel # launcher
        niri # wm
        foot # term
        waybar # bar
        deskflow # kvm
        swaybg # set wallpaper

        # local dev
        zig

        killall
        inotify-tools
        #i3status-rust
        rtorrent
        wl-clipboard
        mako # notification daemon
        (mudlet.overrideAttrs (oldAttrs: rec {
          version = "4.19.1";
          src = fetchFromGitHub {
            owner = "Mudlet";
            repo = "Mudlet";
            rev = "Mudlet-${version}";
            fetchSubmodules = true;
            hash = "sha256-I4RRIfHw9kZwxMlc9pvdtwPpq9EvNJU69WpGgZ+0uiw=";
          };
          patches = [];
          cmakeFlags =
            oldAttrs.cmakeFlags
            ++ [
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            ];
        }))
      ];

      services.blueman-applet.enable = true;

      programs.sonata = {
        enable = true;
        package = pkgs.sonata.overrideAttrs (finalAttrs: prevAttrs: {
          version = "1.7.2";
          src = pkgs.fetchFromGitHub {
            owner = "multani";
            repo = "sonata";
            tag = "v1.7.2";
            hash = "sha256-B/2wLNbeVJJA/rMc6ZcLqH4SqyW5NzomrVPctIWGaIY=";
          };
        });

        settings = {
          audioscrobbler = {
            use_audioscrobbler = "True";
            password_md5_file = "${config.age.secrets.sonata.path}";
            username = "spitball123";
          };
          profiles = {
            "names[0]" = "Default Profile";
            "musicdirs[0]" = "/home/jenga/music";
            "hosts[0]" = "localhost";
            "ports[0]" = 6600;
            "passwords[0]" = "";
            "num_profiles" = 1;
          };
        };
      };
    };
  };
}
