{
  config,
  pkgs,
  ...
}: {
  age.secrets = {
    borg-phrase = {
      owner = "root";
      file = ../../secrets/borg-phrase.age;
    };
    borg-key = {
      owner = "root";
      file = ../../secrets/borg-key.age;
    };
  };

  services.borgbackup.jobs = let
    BORG_REPO = "hk1090@hk1090.rsync.net:nix01";
    BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
    BORG_REMOTE_PATH = "borg14";
    BORG_PASSCOMMAND = "cat ${config.age.secrets.borg-phrase.path}";
  in {
    main = {
      paths = [
        "/var/www/boycrisis.net"
        "/var/lib/bitwarden_rs"
      ];
      repo = BORG_REPO;
      user = "root";

      encryption = {
        mode = "repokey";
        passCommand = BORG_PASSCOMMAND;
      };

      compression = "auto,lzma";
      startAt = "daily";

      # Flush SQLite WAL into the main db file before backup to ensure
      # a consistent snapshot (bitwarden_rs uses WAL mode).
      preHook = ''
        ${pkgs.sqlite}/bin/sqlite3 /var/lib/bitwarden_rs/db.sqlite3 "PRAGMA wal_checkpoint(TRUNCATE);"
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
  };
}
