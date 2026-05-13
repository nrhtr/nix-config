{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.bootAlerts;
  inherit (lib) mkEnableOption mkOption types mkIf;
in {
  options.jenga.bootAlerts = {
    enable = mkEnableOption "boot/shutdown/weekly email alerts";

    emailTo = mkOption {
      type = types.str;
      default = "jeremy@jenga.xyz";
    };

    smtpPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to SMTP password file. Configures msmtp when set. Leave null if disk-health is also enabled (it owns msmtp there).";
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
  };

  config = mkIf cfg.enable (let
    sendEmailEvent = event: ''
      printf "Subject: ${config.networking.hostName} ${event} ''$(${pkgs.coreutils}/bin/date --iso-8601=seconds)\n\nzpool status:\n\n''$(${pkgs.zfs}/bin/zpool status)" | ${pkgs.msmtp}/bin/msmtp -a default ${cfg.emailTo}
    '';
  in {
    programs.msmtp = lib.mkIf (cfg.smtpPasswordFile != null) {
      enable = true;
      setSendmail = true;
      defaults.aliases = builtins.toFile "aliases" "default: ${cfg.emailTo}";
      accounts.default = {
        auth = "on";
        tls = "on";
        tls_starttls = "off";
        host = cfg.smtpHost;
        port = cfg.smtpPort;
        user = cfg.smtpUser;
        passwordeval = "cat ${cfg.smtpPasswordFile}";
        from = "root@${config.networking.hostName}.jenga.xyz";
      };
    };

    systemd.services."boot-mail-alert" = {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = sendEmailEvent "just booted";
    };

    systemd.services."shutdown-mail-alert" = {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "true";
      preStop = sendEmailEvent "is shutting down";
    };

    systemd.services."weekly-mail-alert" = {
      serviceConfig.Type = "oneshot";
      script = sendEmailEvent "is still alive";
    };

    systemd.timers."weekly-mail-alert" = {
      wantedBy = ["timers.target"];
      partOf = ["weekly-mail-alert.service"];
      timerConfig.OnCalendar = "weekly";
    };
  });
}
