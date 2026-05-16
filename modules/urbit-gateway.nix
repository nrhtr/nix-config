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
    vendorHash = "sha256-0H643eZCu8G/rP1694MKkwm3d/UVnxQ4aV1SKHpr3xs=";
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
      description = "Primary domain for ship vhosts (sets SHIP_HOSTNAME).";
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
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        CapabilityBoundingSet = ["CAP_NET_ADMIN"];
      };

      environment = {
        PORT = "${toString cfg.port}";
        URBITS_DIR = cfg.urbitsDir;
        PUBLIC_FRONTEND_URL = "https://urbit-ssh.fly.dev";
        CADDY_SERVER_NAME = cfg.caddyServerName;
        SHIP_HOSTNAME = cfg.domain;
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
            body { font-family: system-ui, sans-serif; max-width: 560px; margin: 5rem auto; padding: 0 1.5rem; color: #111; }
            h1 { margin: 0 0 .75rem; }
            p { color: #555; line-height: 1.6; }
          </style>
        </head>
        <body>
          <h1>${cfg.domain}</h1>
          <p>Urbit ships, each running in a dedicated Firecracker microVM.</p>
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
                header Content-Type "text/html; charset=utf-8"
                respond `<!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>No ship here</title>
          <style>
            body { font-family: system-ui, sans-serif; max-width: 560px; margin: 5rem auto; padding: 0 1.5rem; color: #888; }
            h1 { margin: 0 0 .5rem; }
            p { margin: 0 0 1rem; line-height: 1.5; }
            .notice { font-size: .9rem; color: #aaa; }
            code { font-family: ui-monospace, monospace; font-size: .875rem; background: #1a1a1a; color: #e2e2e2; padding: .25rem .5rem; border-radius: 4px; }
          </style>
        </head>
        <body>
          <h1>No ship here</h1>
          <p>There is no Urbit ship at this address.</p>
          <p class="notice">It might just be powered off. If you&rsquo;re the owner of this ship, you can get it running at <code>ssh urbit.sh</code></p>
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
