{ config, lib, pkgs, ... }:

with lib; {
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
      ];
      repo = "20379@hk-s020.rsync.net:backup";
      user = "jenga";

      dateFormat = "+%Y-%m-%dT%H.%M.%S";

      encryption = {
        mode = "repokey";
        passCommand = "cat ${config.age.secrets.borg-phrase.path}";
      };

      compression = "auto,lzma";
      startAt = "*-*-* 00/02:00:00";

      prune.keep = {
        within = "1d"; # Keep all archives from the last day
        daily = 10;
        weekly = 4;
        monthly = -1; # Keep at least one archive for each month
      };

      environment = {
        BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
        BORG_REMOTE_PATH = "borg1"; # Use borg 1.x
      };
    };
  };

  # FIXME: https://github.com/NixOS/nixpkgs/commit/697198834c6a861d30b8fbfe4162525c87155e00
  # persistentTimer = true;
  systemd.timers = flip mapAttrs' config.services.borgbackup.jobs
    (name: value:
      nameValuePair "borgbackup-job-${name}" {
        timerConfig.Persistent = true;
      });
}
