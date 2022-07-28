{
  config,
  pkgs,
  ...
}: {
  home-manager.users.jenga = rec {
    home.sessionVariables = {
      BORG_PASSCOMMAND = "cat /home/jenga/.secrets/borg-phrase";
      BORG_REMOTE_PATH = "borg1";
      BORG_REPO = "20379@hk-s020.rsync.net:backup";
      BORG_RSH = "ssh -i /home/jenga/.secrets/borg-key";
    };
  };
}
