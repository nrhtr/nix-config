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
  };

  config = mkIf cfg.enable (let
    sendEmailEvent = event: ''
      printf "Subject: ${config.networking.hostName} ${event} ''$(${pkgs.coreutils}/bin/date --iso-8601=seconds)\n\nzpool status:\n\n''$(${pkgs.zfs}/bin/zpool status)" | ${pkgs.msmtp}/bin/msmtp -a default ${cfg.emailTo}
    '';
  in {
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
