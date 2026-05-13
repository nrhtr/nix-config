{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.jenga.borg;

  BORG_REPO = "hk1090@hk1090.rsync.net:${cfg.repoName}";
  BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
  BORG_REMOTE_PATH = "borg14";
  BORG_PASSCOMMAND = "cat ${config.age.secrets.borg-phrase.path}";

  heartbeatUrl = "https://up.jenga.xyz/api/v1/endpoints/${cfg.heartbeatEndpoint}/external";
  heartbeatToken = config.age.secrets.borg-heartbeat-token.path;
  heartbeatScript = import ../common/borg-heartbeat.nix {inherit pkgs;};
in {
  options.jenga.borg = {
    enable = mkEnableOption "borg backup to rsync.net";

    repoName = mkOption {
      type = types.str;
      description = "rsync.net repository path (hk1090@hk1090.rsync.net:<repoName>)";
    };

    paths = mkOption {
      type = types.either types.str (types.listOf types.str);
      description = "Paths to back up";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Paths/patterns to exclude";
    };

    startAt = mkOption {
      type = types.str;
      default = "daily";
      description = "Systemd calendar expression for backup schedule";
    };

    persistentTimer = mkOption {
      type = types.bool;
      default = false;
      description = "Run on next opportunity if the scheduled time was missed";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "User to run the backup job as";
    };

    heartbeatEndpoint = mkOption {
      type = types.str;
      description = "Gatus endpoint name (e.g. backups_nix01)";
    };

    readWritePaths = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra paths to allow read-write in the backup job sandbox";
    };

    preHook = mkOption {
      type = types.lines;
      default = "";
      description = "Shell commands to run before the backup";
    };
  };

  config = mkIf cfg.enable {
    age.secrets = {
      borg-phrase = {
        owner = "jenga";
        file = ../secrets/borg-phrase.age;
        path = "/home/jenga/.secrets/borg-phrase";
      };
      borg-key = {
        owner = "jenga";
        file = ../secrets/borg-key.age;
        path = "/home/jenga/.secrets/borg-key";
      };
      borg-heartbeat-token = {
        owner = "jenga";
        file = ../secrets/borg-heartbeat-token.age;
        path = "/home/jenga/.secrets/borg-heartbeat-token";
      };
    };

    services.borgbackup.jobs.main = {
      inherit (cfg) paths exclude user readWritePaths preHook persistentTimer;
      repo = BORG_REPO;

      encryption = {
        mode = "repokey";
        passCommand = BORG_PASSCOMMAND;
      };

      compression = "auto,lzma";
      startAt = cfg.startAt;

      postHook = ''
        ${heartbeatScript} "${heartbeatUrl}" "${heartbeatToken}" true
      '';

      prune.keep = {
        within = "1d";
        daily = 7;
        weekly = 4;
        monthly = 12;
        yearly = -1;
      };

      environment = {
        inherit BORG_RSH BORG_REMOTE_PATH;
      };
    };

    systemd.services.borgbackup-job-main.unitConfig.OnFailure = "borgbackup-heartbeat-fail.service";
    systemd.services.borgbackup-heartbeat-fail = {
      description = "Send borg backup failure heartbeat to Gatus";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = "${heartbeatScript} ${heartbeatUrl} ${heartbeatToken} false";
      };
    };

    environment.sessionVariables = {
      inherit BORG_REPO BORG_RSH BORG_REMOTE_PATH BORG_PASSCOMMAND;
    };
  };
}
