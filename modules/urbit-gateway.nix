{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.urbitGateway;
  inherit (lib) mkEnableOption mkOption types mkIf;

  sources = import ../npins;
  sourcesJson = builtins.fromJSON (builtins.readFile ../npins/sources.json);

  vmArtifacts = import ../apps/urbit-infra/vm;

  gatewayPkg = pkgs.buildGoModule {
    pname = "urbit-gateway";
    version = "unstable-${builtins.substring 0 8 sourcesJson.pins."urbit-sh".revision}";
    src = sources."urbit-sh";
    subPackages = ["cmd/gateway" "cmd/fcboot"];
    vendorHash = "sha256-E+EMnSLQ2ykD1gEQftQmPSrQPuFS7BFdmOed1gsm3lU=";
  };
in {
  options.jenga.urbitGateway = {
    enable = mkEnableOption "urbit.sh gateway";

    port = mkOption {
      type = types.port;
      default = 7070;
    };

    urbitsDir = mkOption {
      type = types.str;
      default = "/var/lib/urbit";
      description = "Directory containing urbit piers.";
    };

    domain = mkOption {
      type = types.str;
      default = "nock.dev";
      description = "Primary domain for ship vhosts (sets WEB_DOMAIN).";
    };

    caddyServerName = mkOption {
      type = types.str;
      default = "srv0";
      description = "Caddy server name used when addressing the admin API (sets CADDY_SERVER_NAME).";
    };

    acmeEmail = mkOption {
      type = types.str;
      description = "Email address for ACME/Let's Encrypt certificate registration.";
    };

    resendApiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the Resend API key.";
    };
  };

  config = mkIf cfg.enable {
    users.groups.urbit-gateway = {};
    users.users.urbit-gateway = {
      isSystemUser = true;
      group = "urbit-gateway";
      extraGroups = ["kvm"];
    };

    systemd.services.urbit-gateway = {
      description = "urbit.sh gateway";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "wireguard-wg0.service" "caddy.service"];
      wants = ["caddy.service"];

      path = [pkgs.e2fsprogs pkgs.firecracker pkgs.iptables];

      serviceConfig = {
        ExecStart = pkgs.writeShellScript "urbit-gateway" ''
          ${lib.optionalString (cfg.resendApiKeyFile != null) ''
            export RESEND_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/resend-key")"
          ''}
          exec ${gatewayPkg}/bin/gateway
        '';
        Restart = "on-failure";
        User = "urbit-gateway";
        Group = "urbit-gateway";
        StateDirectory = "urbit-gateway urbit-vms";
        StateDirectoryMode = "0750";
        WorkingDirectory = "%S/urbit-gateway";
        LoadCredential =
          lib.mkIf (cfg.resendApiKeyFile != null)
          "resend-key:${cfg.resendApiKeyFile}";
        KillMode = "process";
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        CapabilityBoundingSet = ["CAP_NET_ADMIN"];
      };

      environment = {
        PORT = "${toString cfg.port}";
        URBITS_DIR = cfg.urbitsDir;
        PUBLIC_FRONTEND_URL = "https://urbit.sh";
        CADDY_SERVER_NAME = cfg.caddyServerName;
        WEB_DOMAIN = cfg.domain;
        VM_KERNEL = "${vmArtifacts.vmlinux}/vmlinux";
        VM_INITRD = "${vmArtifacts.initrd}/initrd";
        VM_ROOTFS = "${vmArtifacts.rootfs}";
        VM_BOOT_ARGS = "${vmArtifacts.bootArgs}";
      };
    };

    networking.firewall.interfaces.wg0.allowedTCPPorts = [cfg.port];
    networking.firewall.allowedTCPPorts = [80 443];

    services.caddy = {
      enable = true;
      email = cfg.acmeEmail;
      # Persist Caddy's config to disk after every API change so dynamically
      # added ship vhosts survive restarts.
      resume = true;

      # Enable admin API for gateway to add/remove ship vhosts dynamically.
      # on_demand_tls asks the gateway whether to provision a cert for a given
      # hostname, preventing cert issuance for arbitrary domains.
      globalConfig = ''
        admin localhost:2019
        on_demand_tls {
          ask http://localhost:${toString cfg.port}/tls-ask
        }
      '';

      virtualHosts.${cfg.domain}.extraConfig = ''
                encode gzip
                header Content-Type "text/html; charset=utf-8"
                respond `<!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>${cfg.domain}</title>
          <style>
            *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
            :root{
              --bg:#0a0a12;--surface:#12121e;--border:#1e1e32;
              --purple:#7D56F4;--fg:#c8c8d8;--fg-dim:#555570;--fg-muted:#333348;
              --mono:'SF Mono','Fira Code','Cascadia Code','JetBrains Mono',ui-monospace,monospace;
            }
            html,body{height:100%}
            body{font-family:var(--mono);background:var(--bg);color:var(--fg);
              display:flex;flex-direction:column;align-items:center;justify-content:center;
              min-height:100vh;padding:2rem 1.5rem}
            body::before{content:''';position:fixed;inset:0;
              background-image:linear-gradient(var(--fg-muted) 1px,transparent 1px),
                linear-gradient(90deg,var(--fg-muted) 1px,transparent 1px);
              background-size:48px 48px;opacity:.18;pointer-events:none;z-index:0}
            main{position:relative;z-index:1;text-align:center;max-width:480px;width:100%}
            .logo{font-size:clamp(2.5rem,9vw,4rem);font-weight:700;color:var(--purple);letter-spacing:-.03em}
            .tagline{margin-top:.75rem;font-size:.9rem;color:var(--fg-dim);letter-spacing:.04em}
            .rule{width:100%;height:1px;background:linear-gradient(90deg,transparent,var(--border) 20%,var(--border) 80%,transparent);margin:2rem 0}
            .cmd{display:inline-block;background:var(--surface);border:1px solid var(--border);
              border-radius:6px;padding:.5rem 1.25rem;color:#fff;font-family:var(--mono);font-size:1rem}
            .hint{margin-top:.75rem;font-size:.75rem;color:var(--fg-dim)}
            footer{position:relative;z-index:1;margin-top:3rem;font-size:.7rem;color:var(--fg-muted)}
          </style>
        </head>
        <body>
        <main>
          <div class="logo">${cfg.domain}</div>
          <p class="tagline">Urbit ships — each in a dedicated Firecracker microVM.</p>
          <div class="rule"></div>
          <div class="cmd">ssh urbit.sh</div>
          <p class="hint">Get your planet &nbsp;·&nbsp; No sign-up form required</p>
        </main>
        <footer>urbit.sh &nbsp;—&nbsp; calm computing, terminal-first</footer>
        </body>
        </html>` 200
      '';

      virtualHosts."www.${cfg.domain}".extraConfig = ''
        redir https://${cfg.domain}{uri} permanent
      '';

      # Catch-all HTTPS block: provisions on-demand certs for ship subdomains.
      # Routes added by the gateway via the admin API take precedence.
      # Falls through to this notice page when no ship route is registered.
      virtualHosts.":443".extraConfig = ''
                tls {
                  on_demand
                }
                encode gzip

                # When a ship route is matched but the upstream isn't yet accepting
                # connections (still booting), reverse_proxy emits a 502/504. Serve
                # a friendly maintenance page with auto-refresh instead of the raw
                # error. handle_errors compiles to server-level errors.routes, so it
                # covers dynamically added ship routes as well as this block.
                handle_errors 502 504 {
                  header Content-Type "text/html; charset=utf-8"
                  header Retry-After "10"
                  respond `<!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <meta http-equiv="refresh" content="8">
          <title>Ship starting…</title>
          <style>
            *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
            :root{
              --bg:#0a0a12;--surface:#12121e;--border:#1e1e32;
              --purple:#7D56F4;--fg:#c8c8d8;--fg-dim:#555570;--fg-muted:#333348;
              --mono:'SF Mono','Fira Code','Cascadia Code','JetBrains Mono',ui-monospace,monospace;
            }
            html,body{height:100%}
            body{font-family:var(--mono);background:var(--bg);color:var(--fg);
              display:flex;flex-direction:column;align-items:center;justify-content:center;
              min-height:100vh;padding:2rem 1.5rem}
            body::before{content:''';position:fixed;inset:0;
              background-image:linear-gradient(var(--fg-muted) 1px,transparent 1px),
                linear-gradient(90deg,var(--fg-muted) 1px,transparent 1px);
              background-size:48px 48px;opacity:.18;pointer-events:none;z-index:0}
            main{position:relative;z-index:1;text-align:center;max-width:480px;width:100%}
            .label{font-size:.8rem;color:var(--purple);letter-spacing:.12em;margin-bottom:.75rem}
            .heading{font-size:clamp(1.8rem,7vw,3rem);font-weight:700;color:var(--fg);letter-spacing:-.03em}
            .sub{margin-top:.75rem;font-size:.85rem;color:var(--fg-dim);line-height:1.6}
            .rule{width:100%;height:1px;background:linear-gradient(90deg,transparent,var(--border) 20%,var(--border) 80%,transparent);margin:2rem 0}
            @keyframes spin{to{transform:rotate(360deg)}}
            .spinner{display:inline-block;width:1.1em;height:1.1em;border:2px solid var(--border);
              border-top-color:var(--purple);border-radius:50%;animation:spin .9s linear infinite;
              vertical-align:middle;margin-right:.4em}
            .refresh{font-size:.75rem;color:var(--fg-muted);margin-top:1.25rem}
            footer{position:relative;z-index:1;margin-top:3rem;font-size:.7rem;color:var(--fg-muted)}
          </style>
        </head>
        <body>
        <main>
          <p class="label">starting up</p>
          <div class="heading">Your ship is booting.</div>
          <p class="sub">The Urbit VM is coming online.<br>This usually takes a few seconds.</p>
          <div class="rule"></div>
          <p class="refresh"><span class="spinner"></span>This page will refresh automatically.</p>
        </main>
        <footer>urbit.sh &nbsp;—&nbsp; calm computing, terminal-first</footer>
        </body>
        </html>` 503
                }

                header Content-Type "text/html; charset=utf-8"
                respond `<!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>No ship here</title>
          <style>
            *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
            :root{
              --bg:#0a0a12;--surface:#12121e;--border:#1e1e32;
              --purple:#7D56F4;--fg:#c8c8d8;--fg-dim:#555570;--fg-muted:#333348;
              --mono:'SF Mono','Fira Code','Cascadia Code','JetBrains Mono',ui-monospace,monospace;
            }
            html,body{height:100%}
            body{font-family:var(--mono);background:var(--bg);color:var(--fg);
              display:flex;flex-direction:column;align-items:center;justify-content:center;
              min-height:100vh;padding:2rem 1.5rem}
            body::before{content:''';position:fixed;inset:0;
              background-image:linear-gradient(var(--fg-muted) 1px,transparent 1px),
                linear-gradient(90deg,var(--fg-muted) 1px,transparent 1px);
              background-size:48px 48px;opacity:.18;pointer-events:none;z-index:0}
            main{position:relative;z-index:1;text-align:center;max-width:480px;width:100%}
            .label{font-size:.8rem;color:var(--purple);letter-spacing:.12em;margin-bottom:.75rem}
            .heading{font-size:clamp(1.8rem,7vw,3rem);font-weight:700;color:var(--fg);letter-spacing:-.03em}
            .sub{margin-top:.75rem;font-size:.85rem;color:var(--fg-dim);line-height:1.6}
            .rule{width:100%;height:1px;background:linear-gradient(90deg,transparent,var(--border) 20%,var(--border) 80%,transparent);margin:2rem 0}
            .cmd{display:inline-block;background:var(--surface);border:1px solid var(--border);
              border-radius:6px;padding:.5rem 1.25rem;color:#fff;font-family:var(--mono);font-size:1rem}
            .hint{margin-top:.75rem;font-size:.75rem;color:var(--fg-dim)}
            footer{position:relative;z-index:1;margin-top:3rem;font-size:.7rem;color:var(--fg-muted)}
          </style>
        </head>
        <body>
        <main>
          <p class="label">404</p>
          <div class="heading">No ship here.</div>
          <p class="sub">There is no Urbit ship at this address.<br>It may be powered off, or not yet provisioned.</p>
          <div class="rule"></div>
          <div class="cmd">ssh urbit.sh</div>
          <p class="hint">Get your own planet &nbsp;·&nbsp; Always-on hosting</p>
        </main>
        <footer>urbit.sh &nbsp;—&nbsp; calm computing, terminal-first</footer>
        </body>
        </html>` 404
      '';
    };

    environment.systemPackages = [gatewayPkg];

    # IP forwarding and NAT so Firecracker VMs can reach the internet.
    # The gateway creates/destroys per-VM TAP interfaces named fc-<ship>;
    # they all fall under the fc-+ wildcard for firewall and NAT purposes.
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.nat = {
      enable = true;
      externalInterface = "eno1";
      internalInterfaces = ["fc-+"];
    };

    networking.firewall.trustedInterfaces = ["fc-+"];
  };
}
