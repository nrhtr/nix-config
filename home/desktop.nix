{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  base00 = "${config.colorscheme.colors.base00}";
  base01 = "${config.colorscheme.colors.base01}";
  base02 = "${config.colorscheme.colors.base02}";
  base03 = "${config.colorscheme.colors.base03}";
  base04 = "${config.colorscheme.colors.base04}";
  base05 = "${config.colorscheme.colors.base05}";
  base06 = "${config.colorscheme.colors.base06}";
  base07 = "${config.colorscheme.colors.base07}";
  base08 = "${config.colorscheme.colors.base08}";
  base09 = "${config.colorscheme.colors.base09}";
  base0A = "${config.colorscheme.colors.base0A}";
  base0B = "${config.colorscheme.colors.base0B}";
  base0C = "${config.colorscheme.colors.base0C}";
  base0D = "${config.colorscheme.colors.base0D}";
  base0E = "${config.colorscheme.colors.base0E}";
  base0F = "${config.colorscheme.colors.base0F}";
in {
  imports = [./colours.nix];

  options.displayOutput = mkOption {
    type = types.str;
    default = null;
  };

  config = {
    time.timeZone = "Australia/Melbourne";
    programs.sway.enable = true;

    fonts.fonts = with pkgs; [
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

    sound.enable = true;
    hardware.bluetooth.enable = true;
    hardware.pulseaudio.enable = true;
    users.extraUsers.jenga.extraGroups = ["audio" "docker"];

    services.gpm.enable = true;

    home-manager.users.jenga = {
      imports = [../modules/sonata/default.nix];
      home.packages = with pkgs; [
        wl-clipboard
        mako # notification daemon
        dmenu-wayland
      ];

      services.blueman-applet.enable = true;

      programs.rtorrent = {
        enable = true;
        settings = ''
          # Instance layout (base paths)
          method.insert = cfg.basedir,  private|const|string, (cat,"/home/jenga/rtorrent/")
          method.insert = cfg.download, private|const|string, (cat,(cfg.basedir),"download/")
          method.insert = cfg.logs,     private|const|string, (cat,(cfg.basedir),"log/")
          method.insert = cfg.logfile,  private|const|string, (cat,(cfg.logs),"rtorrent-",(system.time),".log")
          method.insert = cfg.session,  private|const|string, (cat,(cfg.basedir),".session/")
          method.insert = cfg.watch,    private|const|string, (cat,(cfg.basedir),"watch/")

          # Create instance directories
          execute.throw = sh, -c, (cat,\
          "mkdir -p \"",(cfg.download),"\" ",\
          "\"",(cfg.logs),"\" ",\
          "\"",(cfg.session),"\" ",\
          "\"",(cfg.watch),"/load\" ",\
          "\"",(cfg.watch),"/start\" ")

          # Listening port for incoming peer traffic (fixed; you can also randomize it)
          network.port_range.set = 50000-50000
          network.port_random.set = no

          # Tracker-less torrent and UDP tracker support
          # (conservative settings for 'private' trackers, change for 'public')
          #dht.mode.set = disable
          #protocol.pex.set = no
          #trackers.use_udp.set = no
          dht.mode.set = auto
          protocol.pex.set = yes

          # Peer settings
          throttle.max_uploads.set = 100
          throttle.max_uploads.global.set = 250

          throttle.min_peers.normal.set = 20
          throttle.max_peers.normal.set = 60
          throttle.min_peers.seed.set = 30
          throttle.max_peers.seed.set = 80
          trackers.numwant.set = 80

          protocol.encryption.set = allow_incoming,try_outgoing,enable_retry

          # Limits for file handle resources, this is optimized for
          # an `ulimit` of 1024 (a common default). You MUST leave
          # a ceiling of handles reserved for rTorrent's internal needs!
          network.http.max_open.set = 50
          network.max_open_files.set = 600
          network.max_open_sockets.set = 300

          # Memory resource usage (increase if you have a large number of items loaded,
          # and/or the available resources to spend)
          pieces.memory.max.set = 1800M
          network.xmlrpc.size_limit.set = 4M

          # Basic operational settings (no need to change these)
          session.path.set = (cat, (cfg.session))
          directory.default.set = (cat, (cfg.download))
          log.execute = (cat, (cfg.logs), "execute.log")
          #log.xmlrpc = (cat, (cfg.logs), "xmlrpc.log")
          execute.nothrow = sh, -c, (cat, "echo >",\
          (session.path), "rtorrent.pid", " ",(system.pid))

          # Other operational settings (check & adapt)
          encoding.add = utf8
          system.umask.set = 0027
          system.cwd.set = (directory.default)
          network.http.dns_cache_timeout.set = 25
          schedule2 = monitor_diskspace, 15, 60, ((close_low_diskspace, 1000M))
          #pieces.hash.on_completion.set = no
          #view.sort_current = seeding, greater=d.ratio=
          #keys.layout.set = qwerty
          #network.http.capath.set = "/etc/ssl/certs"
          #network.http.ssl_verify_peer.set = 0
          #network.http.ssl_verify_host.set = 0

          # Some additional values and commands
          method.insert = system.startup_time, value|const, (system.time)
          method.insert = d.data_path, simple,\
          "if=(d.is_multi_file),\
          (cat, (d.directory), /),\
          (cat, (d.directory), /, (d.name))"
          method.insert = d.session_file, simple, "cat=(session.path), (d.hash), .torrent"

          # Watch directories (add more as you like, but use unique schedule names)
          # Add torrent
          schedule2 = watch_load, 11, 10, ((load.verbose, (cat, (cfg.watch), "load/*.torrent")))
          # Add & download straight away
          schedule2 = watch_start, 10, 10, ((load.start_verbose, (cat, (cfg.watch), "start/*.torrent")))

          # Run the rTorrent process as a daemon in the background
          # (and control via XMLRPC sockets)
          #system.daemon.set = true
          #network.scgi.open_local = (cat,(session.path),rpc.socket)
          #execute.nothrow = chmod,770,(cat,(session.path),rpc.socket)

          # Logging
          # Levels = critical error warn notice info debug
          # Groups = connection_* dht_* peer_* rpc_* storage_* thread_* tracker_* torrent_*
          print = (cat, "Logging to ", (cfg.logfile))
          log.open_file = "log", (cfg.logfile)
          log.add_output = "info", "log"
          #log.add_output = "tracker_debug", "log"
        '';
      };

      programs.i3status-rust = {
        enable = true;
        bars = {
          default = {
            settings = {theme = "solarized-light";};
            blocks = [
              {
                block = "disk_space";
                path = "/";
                alias = "/";
                info_type = "available";
                unit = "GB";
                interval = 60;
                warning = 20.0;
                alert = 10.0;
              }
              {
                block = "memory";
                display_type = "memory";
                format_mem = "{mem_used_percents}";
                format_swap = "{swap_used_percents}";
              }
              {
                block = "cpu";
                interval = 1;
              }
              {
                block = "load";
                interval = 1;
                format = "{1m}";
              }
              {block = "sound";}
              {
                block = "time";
                interval = 60;
                format = "%a %d/%m %R";
              }
            ];
          };
        };
      };

      programs.waybar = {
        enable = true;
        settings = [
          {
            layer = "top";
            position = "top";

            output = ["${config.displayOutput}"];

            modules-left = ["custom/power" "custom/grab" "sway/workspaces" "sway/mode"];
            modules-center = ["sway/window"];
            modules-right = [
              "pulseaudio"
              "mpd"
              "battery"
              "network"
              "custom/wg"
              "clock"
              "tray"
            ];

            "network" = {
              "format-wifi" = " {signalStrength}%";
              "format-ethernet" = "{ifname} ";
              "tooltip-format-wifi" = "{essid}";
            };
            "sway/workspaces" = {
              disable-scroll = true;
              all-outputs = true;
              #current-only = true;
            };
            "custom/grab" = {
              format = "";
              on-click = "sh -c '(sleep 1; ${pkgs.sway-contrib.grimshot}/bin/grimshot copy area)' & disown";
            };
            "custom/power" = {
              format = "";
              #on-click = "${pkgs.sway}/bin/swaynag --background=${base00} -t warning -m 'Power Menu Options' -b '⏻︁ Power off'  'shutdown -P now' -b '↻︁ Restart' 'shutdown -r now' -b '🛌︁ Hibernate' 'systemctl hibernate' -b '🛌︁ Hybrid-sleep' 'systemctl hybrid-sleep' -b '🛌︁ Suspend' 'systemctl suspend' -b '︁ Logout' 'swaymsg exit' -b ' Lock' 'swaylock-fancy'";
              on-click = "${pkgs.sway}/bin/swaynag --background=${base01} -t warning -m 'Power Menu Options' -b '⏻︁ Power off'  'shutdown -P now' -b '↻︁ Restart' 'shutdown -r now' -b '🛌︁ Hibernate' 'systemctl hibernate' -b '🛌︁ Hybrid-sleep' 'systemctl hybrid-sleep' -b '🛌︁ Suspend' 'systemctl suspend' -b '  Logout' 'swaymsg exit' -b ' Lock' 'swaylock-fancy'";
            };
            "custom/wg" = {
              format = "🔒";
              #exec = "sudo ${pkgs.wireguard}/bin/wg show#";
            };
            "mpd" = {
              max-length = 30;
              on-click = "${pkgs.mpc_cli}/bin/mpc toggle";
              format = "{stateIcon} ~ {consumeIcon}{randomIcon}{repeatIcon}{singleIcon}{artist} - {album} - {title}";
              format-disconnected = "Disconnected ";
              format-stopped = "{consumeIcon}{randomIcon}{repeatIcon}{singleIcon}Stopped ";
              interval = 2;
              consume-icons = {on = " ";};
              random-icons = {on = " ";};
              repeat-icons = {on = " ";};
              single-icons = {on = "1 ";};
              state-icons = {
                paused = "";
                playing = "";
              };
            };
            "pulseaudio" = {
              format = "{icon} {volume}%";
              format-icons = {
                "headphones" = "";
                "default" = ["" ""];
              };
            };
            "battery" = {
              format = "{icon} {capacity}%";
              format-icons = ["" "" "" "" ""];
            };
          }
        ];
        style = ''
          * {
              /* `otf-font-awesome` is required to be installed for icons */
              font-family: FontAwesome, Roboto, Helvetica, Arial, sans-serif;
              font-size: 13px;
              color: #${base05};
          }

          window#waybar {
              background-color: #${base01};
              border-bottom: 3px solid #${base02};
              transition-property: background-color;
              transition-duration: .5s;
          }

          window#waybar.hidden {
              opacity: 0.2;
          }

          /*
          window#waybar.empty {
              background-color: transparent;
          }
          window#waybar.solo {
              background-color: #FFFFFF;
          }
          */

          window#waybar.termite {
              background-color: #3F3F3F;
          }

          window#waybar.chromium {
              background-color: #000000;
              border: none;
          }

          #workspaces button {
              padding: 0 5px;
              background-color: transparent;
              /* Use box-shadow instead of border so the text isn't offset */
              box-shadow: inset 0 -3px transparent;
              /* Avoid rounded borders under each workspace name */
              border: none;
              border-radius: 0;
          }

          /* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
          #workspaces button:hover {
              background: rgba(0, 0, 0, 0.2);
              box-shadow: inset 0 -3px #ffffff;
          }

          #workspaces button.focused {
              background-color: #64727D;
              box-shadow: inset 0 -3px #ffffff;
          }

          #workspaces button.urgent {
              background-color: #eb4d4b;
          }

          #mode {
              background-color: #64727D;
              border-bottom: 3px solid #ffffff;
          }

          #clock,
          #battery,
          #cpu,
          #memory,
          #disk,
          #temperature,
          #backlight,
          #network,
          #pulseaudio,
          #custom-media,
          #tray,
          #mode,
          #idle_inhibitor,
          #custom-grab,
          #custom-power,
          #mpd {
              padding: 0 10px;
              color: #${base05};
              background-color: #${base01};
              border-radius: 6px;
          }

          #window,
          #workspaces {
              margin: 0 4px;
          }

          /* If workspaces is the leftmost module, omit left margin */
          .modules-left > widget:first-child > #workspaces {
              margin-left: 0;
          }

          /* If workspaces is the rightmost module, omit right margin */
          .modules-right > widget:last-child > #workspaces {
              margin-right: 0;
          }

          #clock {
              /* background-color: #64727D; */
          }

          #battery {
              /* background-color: #${base0C}; */
          }

          #battery.charging, #battery.plugged {
              color: #ffffff;
              /* background-color: #26A65B; */
          }

          @keyframes blink {
              to {
                  background-color: #ffffff;
                  color: #000000;
              }
          }

          #battery.critical:not(.charging) {
              background-color: #f53c3c;
              color: #ffffff;
              animation-name: blink;
              animation-duration: 0.5s;
              animation-timing-function: linear;
              animation-iteration-count: infinite;
              animation-direction: alternate;
          }

          label:focus {
              background-color: #000000;
          }

          #backlight {
              background-color: #90b1b1;
          }

          #network {
              background-color: #${base02};
          }

          #network.disconnected {
              background-color: #f53c3c;
          }

          #pulseaudio {
              /* background-color: #${base0E}; */
          }

          #temperature {
              background-color: #f0932b;
          }

          #temperature.critical {
              background-color: #eb4d4b;
          }

          #tray {
              background-color: #2980b9;
          }

          #tray > .passive {
              -gtk-icon-effect: dim;
          }

          #tray > .needs-attention {
              -gtk-icon-effect: highlight;
              background-color: #eb4d4b;
          }

          #idle_inhibitor {
              background-color: #2d3436;
          }

          #idle_inhibitor.activated {
              background-color: #ecf0f1;
              color: #2d3436;
          }

          #mpd {
              background-color: #${base07};
          }

          #mpd.disconnected {
              background-color: #f53c3c;
          }

          #mpd.stopped {
              background-color: #90b1b1;
          }

          #mpd.paused {
              background-color: #51a37a;
          }

          #language {
              background: #00b093;
              color: #740864;
              padding: 0 5px;
              margin: 0 5px;
              min-width: 16px;
          }

          #keyboard-state {
              background: #97e1ad;
              color: #000000;
              padding: 0 0px;
              margin: 0 5px;
              min-width: 16px;
          }

          #keyboard-state > label {
              padding: 0 5px;
          }

          #keyboard-state > label.locked {
              background: rgba(0, 0, 0, 0.2);
          }
        '';
      };

      programs.sonata = {
        enable = true;
        #scrobblerPasswordFile = "${config.age.secrets.sonata.path}";

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

      programs.foot = {
        enable = true;
        settings = {
          main = {
            term = "xterm-256color";
            font = "Inconsolata:size=8";
            dpi-aware = "yes";
          };
          colors = {
            background = "${base00}";
            foreground = "${base05}";

            regular0 = "${base00}";
            regular1 = "${base08}";
            regular2 = "${base0B}";
            regular3 = "${base0A}";
            regular4 = "${base0D}";
            regular5 = "${base0E}";
            regular6 = "${base0C}";
            regular7 = "${base05}";

            # Bright colors
            bright0 = "${base03}";
            bright1 = "${base09}";
            bright2 = "${base01}";
            bright3 = "${base02}";
            bright4 = "${base04}";
            bright5 = "${base06}";
            bright6 = "${base0F}";
            bright7 = "${base07}";
          };
          mouse = {hide-when-typing = "yes";};
        };
      };

      wayland.windowManager.sway = {
        enable = true;
        wrapperFeatures.gtk = true; # so that gtk works properly
        config = rec {
          menu =
            "${pkgs.dmenu-wayland}/bin/dmenu-wl_run"
            + " -nb \"#${base01}\""
            + " -nf \"#${base05}\""
            + " -sb \"#${base02}\""
            + " -sf \"#${base04}\"";

          gaps = {
            inner = 5;
            outer = 0;
            smartGaps = true;
          };

          fonts = {
            names = ["DejaVu Sans Mono"];
            size = 11.0;
          };

          bars = [{command = "waybar";}];
          #bars = [
          #{
          #statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-default.toml";
          #}
          #];

          output = let
            "mkbg" = pkgs.writeShellApplication {
              name = "mkbg";
              runtimeInputs = [pkgs.imagemagick pkgs.getopt pkgs.jq];
              text = builtins.readFile ./mkbg.sh;
            };
            imagecolorizer = pkgs.python3Packages.buildPythonApplication {
              name = "ImageColorizer";

              src = pkgs.fetchFromGitHub {
                owner = "kiddae";
                repo = "ImageColorizer";
                rev = "48623031e3106261093723cd536a4dae74309c5d";
                sha256 = "sha256-ucwo5DOMUON9HgQzXmh39RLQH4sWtSfYH7+UWfGIJCo=";
              };

              propagatedBuildInputs = with pkgs.python3Packages; [pillow];
            };
            recolorWallpaper = input: scheme:
              pkgs.stdenv.mkDerivation {
                name = "recoloured-wallpaper-${scheme.slug}.png";
                buildInputs = [imagecolorizer];
                unpackPhase = "true";
                #ImageColorizer ${input} wallpaper.png -p "#${base01}" "#${base05}" "#${base06}" "#${base07}"
                #ImageColorizer ${input} wallpaper.png -p "#${base01}" "#${base05}" "#${base06}" "#${base0B}"
                buildPhase = ''
                  ImageColorizer ${input} wallpaper.png -p "#${base01}" "#${base05}" "#${base06}"
                '';
                installPhase = "install -Dm0644 wallpaper.png $out";
              };
            mkWallpaper = scheme:
              pkgs.stdenv.mkDerivation {
                name = "generated-nix-wallpaper-${scheme.slug}.png";
                buildInputs = [mkbg];
                unpackPhase = "true";
                buildPhase = ''
                  mkbg -c "${base00}:${base07}:${base02}:${base01}"
                '';
                installPhase = "install -Dm0644 wallpaper.png $out";
              };
          in {
            "LVDS-1" = {
              bg = "/home/jenga/jenga/wallpaper/active/gjGGKe9.png fill";
              #bg = "${mkWallpaper config.colorscheme} fill";
              #bg = "${
              #recolorWallpaper
              #/home/jenga/jenga/wallpaper/active/gjGGKe9.png
              #config.colorscheme
              #} fill";
            };
          };

          modifier = "Mod4";
          startup = [];
          terminal = "${pkgs.foot}/bin/foot";
          keybindings = lib.mkOptionDefault {
            "${modifier}+Shift+c" = "reload";
            "${modifier}+p" =
              "exec ${pkgs.pass}/bin/passmenu"
              + " -nb \"#${config.colorscheme.colors.base01}\""
              + " -nf \"#${config.colorscheme.colors.base05}\""
              + " -sb \"#${config.colorscheme.colors.base02}\""
              + " -sf \"#${config.colorscheme.colors.base04}\"";
          };
        };
      };
    };
  };
}
