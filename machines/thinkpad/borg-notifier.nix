{
  pkgs,
  config,
  lib,
  ...
}:
with lib; {
  config.systemd.services =
    {
      "notify-problems@" = {
        enable = true;
        serviceConfig.User = "jenga";
        environment.SERVICE = "%i";
        script = ''
          export $(cat /proc/$(${pkgs.procps}/bin/pgrep "mako" -u "$USER")/environ |grep -z '^DBUS_SESSION_BUS_ADDRESS=')
          ${pkgs.libnotify}/bin/notify-send -u critical "$SERVICE FAILED!" "Run journalctl -u $SERVICE for details"
        '';
      };
    }
    // flip mapAttrs' config.services.borgbackup.jobs (name: value:
      nameValuePair "borgbackup-job-${name}" {
        unitConfig.OnFailure = "notify-problems@%i.service";
      });
}
