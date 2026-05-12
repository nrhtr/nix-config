{
  config,
  lib,
  pkgs,
  ...
}: let
  BORG_REPO = "hk1090@hk1090.rsync.net:minecraft";
  BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
  BORG_REMOTE_PATH = "borg14"; # Use borg 1.4.x
  BORG_PASSCOMMAND = "cat ${config.age.secrets.borg-phrase.path}";

  heartbeatUrl = "https://up.jenga.xyz/api/v1/endpoints/backups_nix02/external";
  heartbeatToken = config.age.secrets.borg-heartbeat-token.path;
  heartbeatScript = import ../../common/borg-heartbeat.nix {inherit pkgs;};
in {
  age.secrets = {
    borg-phrase = {
      owner = "jenga";
      file = ../../secrets/borg-phrase.age;
      path = "/home/jenga/.secrets/borg-phrase";
    };
    borg-key = {
      owner = "jenga";
      file = ../../secrets/borg-key.age;
      path = "/home/jenga/.secrets/borg-key";
    };
    borg-heartbeat-token = {
      owner = "jenga";
      file = ../../secrets/borg-heartbeat-token.age;
      path = "/home/jenga/.secrets/borg-heartbeat-token";
    };
  };

  services.borgbackup.jobs.main = {
    paths = [
      "/var/lib/minecraft/world"
      "/var/lib/cgit/repos"
    ];
    repo = BORG_REPO;
    user = "root";

    encryption = {
      mode = "repokey";
      passCommand = BORG_PASSCOMMAND;
    };

    compression = "auto,lzma";
    startAt = "hourly";

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

  systemd.services.borgbackup-job-main.unitConfig.OnFailure = "borgbackup-heartbeat-nix02-fail.service";
  systemd.services.borgbackup-heartbeat-nix02-fail = {
    description = "Send borg backup failure heartbeat to Gatus";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${heartbeatScript} ${heartbeatUrl} ${heartbeatToken} false";
    };
  };

  environment.sessionVariables = {
    inherit BORG_REPO BORG_RSH BORG_REMOTE_PATH BORG_PASSCOMMAND;
  };
}
