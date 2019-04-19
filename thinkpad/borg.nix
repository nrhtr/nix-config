{ config, lib, pkgs, ... }:

{
  services.borgbackup = {
    main = {
          paths = "/home/jenga";
          exclude = [ "/home/jenga/.cache" ];
          repo = "20379@hk-s020.rsync.net:~/backup/main";
          user = "jenga";

          encryption = {
            mode = "repokey";
            passCommand = "pass show rsync.net.borg-passphrase";
          };

          compression = "auto,lzma";
          startAt = "daily";

          prune.keep = {
            within = "1d"; # Keep all archives from the last day
            daily = 7;
            weekly = 4;
            monthly = -1;  # Keep at least one archive for each month
          };

          environment = {
            BORG_RSH = "ssh -i /home/jenga/.ssh/hk-s020.rsync.net_ed25519";
            BORG_REMOTE_PATH = "borg1"; # Use borg 1.x
          };
     };
  };
}
