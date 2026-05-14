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
    vendorHash = "sha256-9PiAj3gaXSTb3a7qDfD/iSfdNRRbPB9m5tX+d1qenn8=";
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
  };

  config = mkIf cfg.enable {
    systemd.services.urbit-gateway = {
      description = "urbit.sh gateway";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "wireguard-wg0.service"];

      serviceConfig = {
        ExecStart = "${gatewayPkg}/bin/gateway";
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "urbit-gateway";
        WorkingDirectory = "%S/urbit-gateway";
      };

      environment = {
        PORT = "${toString cfg.port}";
        URBITS_DIR = cfg.urbitsDir;
      };
    };

    networking.firewall.interfaces.wg0.allowedTCPPorts = [cfg.port];
  };
}
