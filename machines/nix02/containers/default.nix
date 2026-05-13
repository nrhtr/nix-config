{
  config,
  pkgs,
  lib,
  ...
}: let
  rtmpPort = 1935;
  stripCidr = ip: builtins.elemAt (lib.strings.split "/" ip) 0;
  machine = rec {
    systemd.services = {
      "container@encoder-a" = {
        serviceConfig = {
          CPUAffinity = "0-5,24-29";
        };
      };
      "container@encoder-b" = {
        serviceConfig = {
          CPUAffinity = "6-11,30-35";
        };
      };
      "container@encoder-c" = {
        serviceConfig = {
          CPUAffinity = "12-17,36-41";
        };
      };
      "container@encoder-d" = {
        serviceConfig = {
          CPUAffinity = "18-23,42-47";
        };
      };
    };

    # proxy RTMP to ingress-a
    systemd.services.rtmp-socat = {
      after = [
        "network.target"
      ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:${toString rtmpPort},fork TCP4:192.168.10.1:${toString rtmpPort}";
        Restart = "on-failure";
        Type = "simple";
      };
      wantedBy = ["multi-user.target"];
    };

    # proxy HTTPS to ingress-a (simpler TLS setup)
    services.nginx = {
      upstreams."liveview" = {
        extraConfig = ''
          keepalive 8;
        '';
        servers = {
          "192.168.10.1:80" = {};
        };
      };
      virtualHosts = {
        "live.jenga.xyz" = {
          useACMEHost = "live.jenga.xyz";
          forceSSL = true;
          locations."/pub/" = {
            root = "/var/www/live";
            extraConfig = ''
              autoindex on;
            '';
          };
          locations."/upload" = {
            extraConfig = ''
              limit_except POST {
                deny all;
              }

              if ($arg_secret != fooFIGHTERS) {
                return 401 'no';
              }

              return 200 'ok';
            '';
          };
          locations."/" = {
            # proxy to ingress-a
            proxyPass = "http://liveview";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header   "Connection" "";
            '';
          };
        };
      };
    };

    networking = {
      firewall.allowedTCPPorts = [
        rtmpPort
      ];
      bridges.br0.interfaces = []; # empty = software-only bridge

      interfaces."br0".ipv4.addresses = [
        {
          address = "192.168.0.1";
          prefixLength = 16;
        }
      ];
    };

    containers = {
      encoder-a = mkEncoder {
        name = "enc-A";
        localAddress = "192.168.50.1/16";
        cpuPercent = 200;
      };
      encoder-b = mkEncoder {
        name = "enc-B";
        localAddress = "192.168.50.2/16";
        cpuPercent = 200;
      };
      encoder-c = mkEncoder {
        name = "enc-C";
        localAddress = "192.168.50.3/16";
        cpuPercent = 800;
      };
      encoder-d = mkEncoder {
        name = "enc-D";
        localAddress = "192.168.50.4/16";
        cpuPercent = 800;
      };
      ingress-a = mkIngress {
        name = "baz";
        localAddress = "192.168.10.1/16";
      };
      ingress-b = mkIngress {
        name = "qux";
        localAddress = "192.168.10.2/16";
      };
    };
  };
  rtmpNginx = pkgs.nginx.override {
    modules = [pkgs.nginxModules.rtmp];
  };
  mkEncoder = {
    name,
    localAddress,
    cpuPercent ? 0,
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

      environment.systemPackages = with pkgs; [
        ffmpeg
        vim
        htop
      ];

      systemd.services = let
        stats-pkg = pkgs.writeShellApplication {
          name = "stream-stats";
          runtimeInputs = with pkgs; [gawk];
          text = builtins.readFile ./stats.sh;
        };
      in {
        stream-stats = {
          serviceConfig.Type = "simple";
          script = ''
            while true; do ${pkgs.bash}/bin/bash ${stats-pkg}/bin/stream-stats; sleep 5; done
          '';
          wantedBy = ["multi-user.target"];
        };
        nginx.serviceConfig = {
          ReadWritePaths = ["/var/www"];
          #StateDirectory
        };
      };

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
                  application unique {
                    live on;

                    # TODO: atm we can't (?) notify all ingresses, just ingress-a for now
                    on_publish http://192.168.10.1:80/hook_publish;

                    exec ffmpeg -re -i rtmp://localhost:1935/$app/$name -vcodec libx264 -vprofile baseline -acodec copy
                                -preset superfast -tune zerolatency -threads 4
                                -vf "drawtext=text='enc=${name}(${localAddress}) stream=$$name':fontcolor=white:fontsize=24:box=1:boxcolor=black"
                                -f flv rtmp://localhost:1935/hls/$${name};
                  }

                  application hls {
                      live on;

                      # TODO: atm we can't (?) notify all ingresses, just ingress-a for now
                      # disabled.. if we push from another app then remote_addr will be local :()
                      # only include on user ingest app
                      # on_publish http://192.168.10.1:80/hook_publish;

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

                  location = /status {
                    alias /var/www/status.json;
                  }

                  location /hls {
                      # Serve HLS fragments
                      types {
                          application/vnd.apple.mpegurl m3u8;
                          video/mp2t ts;
                      }

                      sendfile on;
                      tcp_nopush on;
                      tcp_nodelay on;

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

      environment.systemPackages = with pkgs; [
        vim
        htop
        ffmpeg
      ];

      systemd.services.nginx.serviceConfig.ReadWritePaths = ["/var/www"];

      services.nginx = let
        lua-resty-balancer = pkgs.stdenv.mkDerivation {
          name = "lua-resty-balancer";
          src = pkgs.fetchFromGitHub {
            name = "lua-resty-balancer";
            owner = "openresty";
            repo = "lua-resty-balancer";
            rev = "1cd4363";
            hash = "sha256-e/kMERZ25e/tWFQVnQjyB15IV6BOLUO6vs+27sQ8Cjc=";
          };
          installPhase = ''
            mkdir -p $out/lib/resty/balancer
            cp lib/resty/*.lua $out/lib/resty
            cp lib/resty/balancer/*.lua $out/lib/resty/balancer
            cp librestychash.so $out/lib
          '';
        };
        lua-resty-http = pkgs.fetchFromGitHub {
          owner = "ledgetech";
          repo = "lua-resty-http";

          rev = "v0.17.2";
          hash = "sha256-Ph3PpzQYKYMvPvjYwx4TeZ9RYoryMsO6mLpkAq/qlHY=";
        };
      in {
        enable = true;
        # luajit, TCP streams, etc.
        package = pkgs.openresty;
        logError = "/var/log/nginx/error.log debug";
        config = ''
          events {
          }

          http {
            lua_package_path "${lua-resty-http}/lib/?.lua;;";
            lua_shared_dict view_route_cache 10m;

            include ${pkgs.openresty}/nginx/conf/mime.types;

            upstream backend {
              server 192.168.50.1:80;

              keepalive 8;

              balancer_by_lua_block {
                local balancer = require "ngx.balancer"

                local m, err = ngx.re.match(ngx.var.uri, "/hls/([^-/\\.]+).*")
                local key = m and m[1] or "default"

                local backend = ngx.shared.view_route_cache:get(key)

                local function serve_placeholder()
                  ngx.log(ngx.WARN, "Backend unavailable, serving placeholder")
                  local ok, err = balancer.set_current_peer("127.0.0.1", 8080)
                  if not ok then
                    ngx.log(ngx.ERR, "failed to set placeholder backend: ", err)
                    return ngx.exit(502)
                  end
                end

                if backend then
                  ngx.log(ngx.NOTICE, "Selected backend: " .. backend)

                  local ok, err = balancer.set_current_peer(backend, 80)
                  if not ok then
                    ngx.log(ngx.ERR, "no backend for stream key: ", key, ", err: ", err)
                    serve_placeholder()
                    return
                  end
                else
                  ngx.log(ngx.ERR, "no backend cached for stream key: ", key)
                  serve_placeholder()
                  return
                end
              }
            }

            server {
                listen 80;

                location /hook_publish {
                  content_by_lua_block {
                    local cjson = require "cjson.safe"

                    ngx.req.read_body()
                    local args = ngx.req.get_post_args()

                    ngx.log(ngx.INFO, "/hook_publish: got args: ", cjson.encode(args))
                    -- we take remote_addr to be the proper encoder for this stream
                    -- TODO: fanout/enrich webhooks for each ingest? include proper encoder arg
                    local backend = ngx.var.remote_addr
                    ngx.shared.view_route_cache:set(args.name, backend)
                    ngx.say("ok")
                  }
                }

                location = /demo {
                  alias ${./demo.html};
                  # set default type because we use an alias, because... nix things
                  default_type text/html;
                }

                location / {
                  proxy_http_version 1.1;
                  proxy_set_header   "Connection" "";

                  proxy_pass http://backend;
                }
            }

            server {
              listen 8080;
              server_name _;

              access_log /var/log/nginx/placeholder_access.log;
              error_log /var/log/nginx/placeholder_error.log debug;

              root /var/www/placeholder_hls;
              index index.m3u8;

              location ~* ^/hls/.*\.m3u8$ {
                default_type application/vndapple.mpegurl;

                add_header Cache-Control no-cache;
                sendfile on;
                tcp_nopush on;
                tcp_nodelay on;

                try_files /hls/index.m3u8 =404;
              }

              location ~* ^/hls/.*\.ts$ {
                default_type video/MP2T;
                try_files $uri /hls/dummy.ts =404;
              }
            }
          }

          stream {
            lua_package_path "${lua-resty-http}/lib/?.lua;;";
            lua_shared_dict route_cache 10m;

            init_worker_by_lua_block {
              local http = require "resty.http"
              local cjson = require "cjson.safe"

              local backends = {
                "192.168.50.1",
                "192.168.50.2",
                "192.168.50.3",
                "192.168.50.4",
              }
              local scores = {}

              package.loaded.backend_scores = scores

              local function update_backend_scores(premature)
                if premature then
                  return
                end

                for _, host in ipairs(backends) do
                  local h = http.new()
                  h:set_timeout(500)

                  local res, err = h:request_uri("http://" .. host .. "/status")
                  if res and res.status == 200 then
                    ngx.log(ngx.INFO, res.status, " Got body from /status: ", res.body)
                    local data = cjson.decode(res.body)
                    if data then
                      local gpu = tonumber(data.gpu_free) or 0
                      local cpu = tonumber(data.cpu_free) or 0

                      -- weighted scores
                      scores[host] = gpu * 0.25 + cpu
                      ngx.log(ngx.INFO, "Updated score for ", host, ": ", scores[host])
                    else
                      ngx.log(ngx.WARN, "Failed to parse score from ", host)
                    end
                  else
                    ngx.log(ngx.ERR, "Failed to fetch /status from ", host, ": ", res and res.status or "no response")
                    scores[host] = 0
                  end
                end

                -- schedule next update in 10 seconds
                local ok, err = ngx.timer.at(19, update_backend_scores)
                if not ok then
                  ngx.log(ngx.ERR, "failed to reschedule score updater: ", err)
                end
              end

              -- start the loop (only once per worker)
              local ok, err = ngx.timer.at(0, update_backend_scores)
              if not ok then
                ngx.log(ngx.ERR, "failed to start backend score updater: ", err)
              end
            }

            upstream rtmp_backends {
              server 192.168.50.1:1935;

              balancer_by_lua_block {
                local balancer = require "ngx.balancer"
                local scores = package.loaded.backend_scores or {}
                local backends = {
                  "192.168.50.1",
                  "192.168.50.2",
                  "192.168.50.3",
                  "192.168.50.4",
                }

                local src_ip = ngx.var.remote_addr
                local src_port = ngx.var.remote_port
                local key = src_ip .. ":" .. src_port

                -- fast path / lookup backend in cache
                local cached_host = ngx.shared.route_cache:get(key)
                if cached_host then
                  local ok, err = balancer.set_current_peer(cached_host, 1935)
                  if not ok then
                    ngx.log(ngx.ERR, "unable to set backend ", cached_host, " for key: ", key)
                    return ngx.exit(500)
                  end

                  ngx.log(ngx.NOTICE, "Selected backend: " .. cached_host)
                  return
                end

                -- slow path / initial publish...

                local total = 0
                for _, host in ipairs(backends) do
                  total = total + (scores[host] or 1)
                end

                -- weighted random selection
                local r = math.random() * total
                local pick
                for _, host in ipairs(backends) do
                  r = r - (scores[host] or 1)
                  if r <= 0 then
                    pick = host
                    break
                  end
                end

                -- fallback
                pick = pick or backends[1]

                ngx.log(ngx.INFO, "Assigning stream ", key, " to backend ", pick)
                ngx.shared.route_cache:set(key, pick, 3600)
                local ok, err = balancer.set_current_peer(pick, 1935)
                if not ok then
                  ngx.log(ngx.ERR, "unable to set backend ", backend, " for src: ", key)
                  return ngx.exit(500)
                end
              }
            }

            server {
              # lua_socket_log_errors off;

              listen 1935;

              proxy_pass rtmp_backends;
            }
          }
        '';
      };
    };
  };
in
  machine
