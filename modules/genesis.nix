{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.genesis;

  package = pkgs.genesis;
in {
  options = {
    services.genesis = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          If enabled, start a Genesis ColdC. The server
          database will be loaded from and saved to
          {option}`services.genesis.dataDir`.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "genesis";
        description = "User account under which Genesis runs.";
      };

      group = mkOption {
        type = types.str;
        default = "genesis";
        description = "Group under which Genesis runs.";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/genesis";
        description = lib.mdDoc ''
          Directory to store object database and other state/data files.
        '';
      };

      package = lib.mkPackageOption pkgs "genesis" {};
    };
  };

  config = mkIf cfg.enable {
    users.users = mkIf (cfg.user == "genesis") {
      genesis = {
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = mkIf (cfg.group == "genesis") {
      genesis = {};
    };

    systemd.services.genesis = {
      description = "Genesis ColdC server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/genesis -ld stdout -lg stdout";
        Restart = "always";

        WorkingDirectory = cfg.dataDir;
      };
    };
  };
}
