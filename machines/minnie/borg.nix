{
  config,
  lib,
  pkgs,
  ...
}: let
  sources = import ../../npins;
  agenix = sources.agenix;

  BORG_REPO = "hk1090@hk1090.rsync.net:minnie";
  BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path}";
  BORG_REMOTE_PATH = "borg14"; # Use borg 1.4.x
  BORG_PASSCOMMAND = "cat ${config.age.secrets.borg-phrase.path}";

  heartbeatUrl = "https://up.jenga.xyz/api/v1/endpoints/backups_minnie/external";
  heartbeatToken = config.age.secrets.borg-heartbeat-token.path;
  heartbeatScript = import ../../common/borg-heartbeat.nix {inherit pkgs;};

  borgScript = pkgs.writeShellScript "borgbackup-minnie" ''
    export BORG_RSH="${BORG_RSH}"
    export BORG_REMOTE_PATH="${BORG_REMOTE_PATH}"
    export BORG_PASSCOMMAND="${BORG_PASSCOMMAND}"

    ARCHIVE="${BORG_REPO}::minnie-main-$(date '+%Y-%m-%dT%H.%M.%S')"

    trap '${heartbeatScript} "${heartbeatUrl}" "${heartbeatToken}" false' ERR

    ${pkgs.borgbackup}/bin/borg create \
      --compression auto,lzma \
      --exclude-caches \
      --exclude '/Users/jenga/Downloads' \
      --exclude '/Users/jenga/media' \
      --exclude '/Users/jenga/Movies' \
      --exclude '/Users/jenga/.cache' \
      --exclude '/Users/jenga/Library/Caches' \
      --exclude '/Users/jenga/Library/CloudStorage' \
      --exclude '/Users/jenga/Library/Developer/CoreSimulator' \
      --exclude '/Users/jenga/Library/Developer/Xcode/DerivedData' \
      --exclude '/Users/jenga/Library/Containers' \
      --exclude '/Users/jenga/.Trash' \
      --exclude 'sh:**/node_modules' \
      --exclude 'sh:**/.npm' \
      --exclude 'sh:**/.pnpm-store' \
      --exclude 'sh:**/go/pkg/mod' \
      --exclude 'sh:**/.direnv' \
      --exclude 'sh:**/__pycache__' \
      --exclude 'sh:**/*.pyc' \
      --exclude 'sh:**/.venv' \
      "$ARCHIVE" \
      /Users/jenga

    ${pkgs.borgbackup}/bin/borg prune \
      --keep-within 1d \
      --keep-daily 7 \
      --keep-weekly 4 \
      --keep-monthly 12 \
      --keep-yearly -1 \
      "${BORG_REPO}"

    ${heartbeatScript} "${heartbeatUrl}" "${heartbeatToken}" true
  '';
in {
  imports = ["${agenix}/modules/age.nix"];

  age.secrets = {
    borg-phrase = {
      owner = "jenga";
      file = ../../secrets/borg-phrase.age;
      path = "/Users/jenga/.secrets/borg-phrase";
    };
    borg-key = {
      owner = "jenga";
      file = ../../secrets/borg-key.age;
      path = "/Users/jenga/.secrets/borg-key";
    };
    borg-heartbeat-token = {
      owner = "jenga";
      file = ../../secrets/borg-heartbeat-token.age;
      path = "/Users/jenga/.secrets/borg-heartbeat-token";
    };
  };

  launchd.user.agents.borgbackup-main = {
    serviceConfig = {
      Label = "org.nixos.borgbackup-main";
      ProgramArguments = ["${borgScript}"];
      # Odd hours to avoid colliding with lappy (even hours), both back up to rsync.net
      StartCalendarInterval = map (h: {
        Hour = h;
        Minute = 0;
      }) [1 3 5 7 9 11 13 15 17 19 21 23];
      StandardOutPath = "/Users/jenga/Library/Logs/borgbackup.log";
      StandardErrorPath = "/Users/jenga/Library/Logs/borgbackup.log";
      RunAtLoad = false;
    };
  };

  home-manager.users.jenga = {
    home.sessionVariables = {
      inherit BORG_PASSCOMMAND BORG_REMOTE_PATH BORG_REPO BORG_RSH;
    };
  };
}
