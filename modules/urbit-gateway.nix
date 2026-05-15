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

  gatewayPkg = pkgs.buildGoModule {
    pname = "urbit-gateway";
    version = "unstable-${builtins.substring 0 8 sourcesJson.pins."urbit-sh".revision}";
    src = sources."urbit-sh";
    subPackages = ["cmd/gateway"];
    vendorHash = "sha256-08MKdekl+tq0o3M4OpEFWmmwkSu5YiEkTdYzO1zWuR8=";
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

    resendApiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the Resend API key.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.urbit-gateway = {
      description = "urbit.sh gateway";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "wireguard-wg0.service"];

      serviceConfig = {
        ExecStart = pkgs.writeShellScript "urbit-gateway" ''
          ${lib.optionalString (cfg.resendApiKeyFile != null) ''
            export RESEND_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/resend-key")"
          ''}
          exec ${gatewayPkg}/bin/gateway
        '';
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "urbit-gateway";
        WorkingDirectory = "%S/urbit-gateway";
        LoadCredential =
          lib.mkIf (cfg.resendApiKeyFile != null)
          "resend-key:${cfg.resendApiKeyFile}";
      };

      environment = {
        PORT = "${toString cfg.port}";
        URBITS_DIR = cfg.urbitsDir;
        PUBLIC_FRONTEND_URL = "https://urbit-ssh.fly.dev";
      };
    };

    networking.firewall.interfaces.wg0.allowedTCPPorts = [cfg.port];
  };
}
