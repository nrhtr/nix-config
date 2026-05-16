{
  config,
  lib,
  ...
}: let
  cfg = config.jenga.remoteBuilder;
  inherit (lib) mkEnableOption mkOption types mkIf;
in {
  options.jenga.remoteBuilder = {
    client = {
      enable = mkEnableOption "nix03 remote builder (client)";

      sshKey = mkOption {
        type = types.str;
        description = "Path to the SSH private key used by the Nix daemon.";
      };

      speedFactor = mkOption {
        type = types.int;
        default = 8;
      };
    };

    server = {
      enable = mkEnableOption "nix03 remote builder (server)";

      authorizedBuilderKeys = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "SSH public keys of remote Nix daemons allowed to use this builder.";
      };
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.client.enable {
      nix.distributedBuilds = true;
      nix.extraOptions = "builders-use-substitutes = true\n";
      nix.buildMachines = [
        {
          hostName = "nix03";
          system = "x86_64-linux";
          sshUser = "root";
          sshKey = cfg.client.sshKey;
          speedFactor = cfg.client.speedFactor;
          supportedFeatures = ["big-parallel"];
        }
      ];
    })

    (mkIf cfg.server.enable {
      users.users.root.openssh.authorizedKeys.keys = cfg.server.authorizedBuilderKeys;
      nix.settings.trusted-users = ["root"];
    })
  ];
}
