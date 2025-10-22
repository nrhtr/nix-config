{
  config,
  pkgs,
  lib,
  ...
}: let
  rtmpPort = 1935;
  stripCidr = ip: builtins.elemAt (lib.strings.split "/" ip) 0;
  machine = rec {
    systemd.services.rtmp-socat = {
      after = [
        "network.target"
      ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:${toString rtmpPort},fork TCP4:192.168.0.4:${toString rtmpPort}";
        Restart = "on-failure";
        Type = "simple";
      };
      wantedBy = ["multi-user.target"];
    };

    networking = {
      firewall.allowedTCPPorts = [
        rtmpPort
      ];
      bridges.br0.interfaces = []; # empty = software-only bridge

      interfaces."br0".ipv4.addresses = [
        {
          address = "192.168.0.1";
          prefixLength = 24;
        }
      ];

      nat = let
        ingressIP = "${stripCidr containers.ingress-a.localAddress}";
      in {
        #enable = true;
        #internalInterfaces = [ "br0" ];
        #internalIPs = [ ingressIP ];
        #externalInterface = "enp5s0f0";

        #forwardPorts = [
        #{
        #destination = "${ingressIP}:${toString rtmpPort}";
        #proto = "tcp";
        #sourcePort = rtmpPort;
        #}
        #   {
        #     destination = stripCidr containers.encoder-a.localAddress;
        #     proto = "tcp";
        #     sourcePort = 8443;
        #   }
        #];

        #bridges.br0.interfaces = [ "enp5s0f0" ];
        #interfaces."br0".ipv4.addresses = [
        #{
        #address = "192.168.100.1";
        #prefixLength = 24;
        #}
        #];
      };
    };

    containers = {
      encoder-a = mkEncoder {
        name = "foo";
        localAddress = "192.168.0.2/24";
      };
      encoder-b = mkEncoder {
        name = "bar";
        localAddress = "192.168.0.3/24";
      };
      ingress-a = mkIngress {
        name = "baz";
        localAddress = "192.168.0.4/24";
      };
      ingress-b = mkIngress {
        name = "qux";
        localAddress = "192.168.0.5/24";
      };
    };
  };
  rtmpNginx = pkgs.nginx.override {
    modules = [pkgs.nginxModules.rtmp];
  };
  mkEncoder = {
    name,
    localAddress,
    ...
  }: {
    autoStart = true;
    privateNetwork = true;
    inherit localAddress;
    hostBridge = "br0";

    tmpfs = ["/tmp"];

    config = {
      config,
      pkgs,
      lib,
      ...
    }: {
      system.stateVersion = "25.11";

      networking.firewall.allowedTCPPorts = [
        rtmpPort
        80
      ];

      systemd.services.nginx.serviceConfig.ReadWritePaths = [
        "/var/www"
      ];

      services.nginx = {
        enable = true;
        package = rtmpNginx;
        config = ''
          worker_processes  1;
          error_log  /var/log/nginx/error.log debug;

          events {
              worker_connections  1024;
          }

          rtmp {
              server {
                  listen ${builtins.toString rtmpPort};

                  chunk_size 4000;

                  # HLS

                  # For HLS to work please create a directory in tmpfs (/tmp/hls here)
                  # for the fragments. The directory contents is served via HTTP (see
                  # http{} section in config)
                  #
                  # Incoming stream must be in H264/AAC. For iPhones use baseline H264
                  # profile (see ffmpeg example).
                  # This example creates RTMP stream from movie ready for HLS:
                  #
                  # ffmpeg -loglevel verbose -re -i movie.avi  -vcodec libx264
                  #    -vprofile baseline -acodec libmp3lame -ar 44100 -ac 1
                  #    -f flv rtmp://localhost:1935/hls/movie
                  #
                  # If you need to transcode live stream use 'exec' feature.
                  #
                  application hls {
                      live on;
                      hls on;
                      hls_path /var/www/hls;
                  }

                  # MPEG-DASH is similar to HLS
                  application dash {
                      live on;
                      dash on;
                      dash_path /var/www/dash;
                  }
              }
          }

          # HTTP can be used for accessing RTMP stats
          http {
              server {
                  listen      80;
                  server_name live.jenga.xyz;

                  # This URL provides RTMP statistics in XML
                  location /stat {
                      rtmp_stat all;

                      # Use this stylesheet to view XML as web page
                      # in browser
                      #rtmp_stat_stylesheet stat.xsl;
                  }

                  location /hls {
                      # Serve HLS fragments
                      types {
                          application/vnd.apple.mpegurl m3u8;
                          video/mp2t ts;
                      }
                      root /var/www;
                      add_header Cache-Control no-cache;
                  }

                  location /dash {
                      # Serve DASH fragments
                      root /var/www;
                      add_header Cache-Control no-cache;
                  }
              }
          }
        '';
      };
    };
  };

  mkIngress = {
    name,
    localAddress,
    ...
  }: {
    autoStart = true;
    privateNetwork = true;
    inherit localAddress;
    hostBridge = "br0";

    # bind mount in some secrets
    #bindMounts = {
    #"/tmp/gandi.secret" = {
    #hostPath = "${config.age.secrets.gandi.path}";
    #isReadOnly = true;
    #};
    #};

    #forwardPorts = [
    #{
    #containerPort = rtmpPort;
    #hostPort = rtmpPort;
    #}
    #{
    #containerPort = 443;
    #hostPort = 8443;
    #}
    #];

    config = {
      config,
      pkgs,
      lib,
      ...
    }: {
      system.stateVersion = "25.11";

      networking.firewall.allowedTCPPorts = [
        rtmpPort
        80
      ];

      # security.acme.defaults.email = "jeremy@jenga.xyz";
      # security.acme.acceptTerms = true;
      # security.acme.certs = {
      #   "live.jenga.xyz" = {
      #     group = "nginx";
      #     dnsProvider = "gandiv5";
      #     credentialsFile = "/tmp/gandi.secret";
      #   };
      # };

      services.nginx = {
        enable = true;
        # luajit, TCP streams, etc.
        package = pkgs.openresty;

        virtualHosts = {
          # proxy vhost for serving HLS/DASH
          # TODO: figure out a solution for SSL
          # maybe bind-mount ACME cert from host?
          "live.jenga.xyz" = {
            default = true;
            locations."/" = {
              proxyPass = "http://192.168.0.2:80/";
            };
          };
        };
        # TODO: Implement smart ingest!
        streamConfig = ''
          server {
            listen ${builtins.toString rtmpPort};
            proxy_pass 192.168.0.2:${toString rtmpPort}; # encoder-a
          }
        '';
      };
    };
  };
in
  machine
