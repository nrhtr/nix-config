{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  BORG_REPO = "hk1090@hk1090.rsync.net:thinkpad";
  BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
  BORG_REMOTE_PATH = "borg14"; # Use borg 1.4.x
  BORG_PASSCOMMAND = "cat ${config.age.secrets.borg-phrase.path}";
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
  };

  services.borgbackup.jobs = {
    main = {
      paths = "/home/jenga";
      exclude = [
        "/home/jenga/.cache"
        "/home/jenga/.mozilla"
        "/home/jenga/.local"

        "/home/jenga/download"
        "/home/jenga/rtorrent/download"
        "/home/jenga/Desktop"
      ];
      repo = BORG_REPO;
      user = "jenga";

      dateFormat = "+%Y-%m-%dT%H.%M.%S";

      encryption = {
        mode = "repokey";
        passCommand = BORG_PASSCOMMAND;
      };

      compression = "auto,lzma";
      startAt = "*-*-* 00/02:00:00";
      persistentTimer = true;

      prune.keep = {
        within = "1d"; # Keep all archives from the last day
        daily = 10;
        weekly = 4;
        monthly = -1; # Keep at least one archive for each month
      };

      environment = {
        inherit BORG_RSH;
        inherit BORG_REMOTE_PATH;
      };
    };
  };

  home-manager.users.jenga = {
    home.sessionVariables = {
      inherit BORG_PASSCOMMAND;
      inherit BORG_REMOTE_PATH;
      inherit BORG_REPO;
      inherit BORG_RSH;
    };
  };

  # FIXME: https://github.com/NixOS/nixpkgs/commit/697198834c6a861d30b8fbfe4162525c87155e00
  #systemd.timers = flip mapAttrs' config.services.borgbackup.jobs
  #(name: value:
  #nameValuePair "borgbackup-job-${name}" {
  #timerConfig.Persistent = true;
  #});
}
