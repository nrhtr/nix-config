{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.diskHealth;
  inherit (lib) mkEnableOption mkOption types mkIf;
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

    services.zfs.zed.enableMail = lib.mkIf cfg.enableZed true;
    services.zfs.zed.settings = lib.mkIf cfg.enableZed {
      ZED_EMAIL_ADDR = [cfg.emailTo];
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
