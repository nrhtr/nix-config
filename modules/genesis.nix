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

      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Hostname to pass to Genesis server. By default it will use the host's DNS name.";
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
        home = cfg.dataDir;
        createHome = true;
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
        Type = "forking";
        ExecStart =
          "${cfg.package}/bin/genesis -ld stdout -lg stdout "
          + lib.optionalString (cfg.hostname != null) " -n ${cfg.hostname}";
        Restart = "on-failure";
        RestartSec = 5;
        User = cfg.user;
        Group = cfg.group;

        WorkingDirectory = cfg.dataDir;
      };
    };
  };
}
