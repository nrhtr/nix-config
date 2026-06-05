{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.diskHealth;
  inherit (lib) mkEnableOption mkOption types mkIf;

  # ZED calls its mail program with mail(1)-style flags (-a 'FROM:x' -s 'subject' recipient)
  # but we use msmtp which expects a properly formatted message on stdin.
  # This wrapper translates between the two.
  zedMailWrapper = pkgs.writeShellScript "zed-mail" ''
    from=""
    subject=""
    to=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -a) shift; from="''${1#FROM:}"; shift;;
        -s) shift; subject="$1"; shift;;
        -*) shift; [ $# -gt 0 ] && shift;;
        *) to="$1"; shift;;
      esac
    done
    {
      printf "From: %s\n" "$from"
      printf "To: %s\n" "$to"
      printf "Subject: %s\n" "$subject"
      printf "\n"
      cat
    } | ${pkgs.msmtp}/bin/msmtp "$to"
  '';
in {
  options.jenga.diskHealth = {
    enable = mkEnableOption "disk health monitoring with ZED and smartd email alerts";

    emailTo = mkOption {
      type = types.str;
      default = "jeremy@jenga.xyz";
    };

    emailFrom = mkOption {
      type = types.str;
      default = "root@${config.networking.hostName}.jenga.xyz";
    };

    smtpPasswordFile = mkOption {
      type = types.path;
      description = "Path to file containing the SMTP password (e.g. from agenix).";
    };

    smtpUser = mkOption {
      type = types.str;
      default = "jeremy@jenga.xyz";
    };

    smtpHost = mkOption {
      type = types.str;
      default = "smtp.fastmail.com";
    };

    smtpPort = mkOption {
      type = types.str;
      default = "465";
    };

    enableZed = mkOption {
      type = types.bool;
      default = true;
      description = "Enable ZFS Event Daemon email alerts. Disable on non-ZFS hosts.";
    };

    enableSmartd = mkOption {
      type = types.bool;
      default = true;
      description = "Enable smartd disk monitoring. Disable on VMs with virtualised disks.";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = lib.mkIf cfg.enableZed [
      (_self: super: {
        zfsStable = super.zfsStable.override {enableMail = true;};
      })
    ];

    programs.msmtp = {
      enable = true;
      setSendmail = true;
      defaults.aliases = builtins.toFile "aliases" ''
        default: ${cfg.emailTo}
      '';
      accounts.default = {
        auth = "on";
        tls = "on";
        tls_starttls = "off";
        host = cfg.smtpHost;
        port = cfg.smtpPort;
        user = cfg.smtpUser;
        passwordeval = "cat ${cfg.smtpPasswordFile}";
        from = cfg.emailFrom;
      };
    };

    services.zfs.autoScrub = lib.mkIf cfg.enableZed {
      enable = true;
      interval = "monthly";
    };

    services.zfs.zed.enableMail = lib.mkIf cfg.enableZed true;
    services.zfs.zed.settings = lib.mkIf cfg.enableZed {
      ZED_EMAIL_ADDR = [cfg.emailTo];
      ZED_EMAIL_PROG = "${zedMailWrapper}";
      ZED_EMAIL_OPTS = "-a 'FROM:${cfg.emailFrom}' -s '@SUBJECT@' @ADDRESS@";
      ZED_NOTIFY_VERBOSE = true;
    };

    services.smartd.enable = cfg.enableSmartd;
    services.smartd.notifications.mail = lib.mkIf cfg.enableSmartd {
      enable = true;
      sender = cfg.emailFrom;
      recipient = cfg.emailTo;
    };
  };
}
