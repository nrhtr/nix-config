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

  # To update vendorHash: set to lib.fakeHash, run nix build, replace with the
  # hash from the error message.
  gatewayPkg = pkgs.buildGoModule {
    pname = "urbit-gateway";
    version = "unstable-${builtins.substring 0 8 sourcesJson.pins."urbit-sh".revision}";
    src = sources."urbit-sh";
    subPackages = ["cmd/gateway"];
    # Set to lib.fakeHash to get the real hash from a failed build, then replace.
    # If the repo has a vendor/ dir committed, null works instead.
    vendorHash = lib.fakeHash;
  };
in {
  options.jenga.urbitGateway = {
    enable = mkEnableOption "urbit.sh gateway";

    port = mkOption {
      type = types.port;
      default = 8080;
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
        SupplementaryGroups = ["urbit"];
      };

      environment = {
        GATEWAY_ADDR = "0.0.0.0:${toString cfg.port}";
        URBITS_DIR = cfg.urbitsDir;
      };
    };

    networking.firewall.interfaces.wg0.allowedTCPPorts = [cfg.port];
  };
}
