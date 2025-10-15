{
  config,
  lib,
  pkgs,
  ...
}: {
  age.secrets = {
    borg-phrase = {
      owner = "root";
      file = ../../secrets/borg-phrase.age;
    };
    borg-key = {
      owner = "jenga";
      file = ../../secrets/borg-key.age;
    };
  };

  services.borgbackup.jobs = let
    BORG_REPO = "hk1090@hk1090.rsync.net:minecraft";
    BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
    BORG_REMOTE_PATH = "borg14"; # Use borg 1.4.x
    BORG_PASSCOMMAND = "cat ${config.age.secrets.borg-phrase.path}";
  in {
    main = {
      paths = "/var/lib/minecraft/world";
      repo = BORG_REPO;
      user = "root";

      encryption = {
        mode = "repokey";
        passCommand = BORG_PASSCOMMAND;
      };

      compression = "auto,lzma";
      startAt = "hourly";

      prune.keep = {
        within = "1d"; # Keep all archives from the last day
        daily = 7;
        weekly = 4;
        monthly = -1; # Keep at least one archive for each month
      };

      environment = {
        inherit BORG_RSH BORG_REMOTE_PATH;
      };
    };
  };
}
