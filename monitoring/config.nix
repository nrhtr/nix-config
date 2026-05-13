# Generates the Gatus YAML config from Nix.
# Endpoints are defined here; internal hostnames resolve via /etc/hosts
# entries written at container startup (see default.nix).
{pkgs}: let
  lib = pkgs.lib;

  mkEndpoint = {
    name,
    url,
    group,
    interval ? "5m",
    status ? 200,
  }: {
    inherit name url group interval;
    conditions = [
      "[STATUS] == ${toString status}"
      "[RESPONSE_TIME] < 10000"
      "[CERTIFICATE_EXPIRATION] > 168h"
    ];
    alerts = [
      {
        type = "email";
        failure-threshold = 2;
        success-threshold = 1;
        description = "''${name}'' is down";
      }
    ];
  };

  mkPingEndpoint = {
    name,
    url,
    group,
    interval ? "5m",
  }: {
    inherit name url group interval;
    conditions = [
      "[CONNECTED] == true"
      "[RESPONSE_TIME] < 10000"
    ];
  };

  mkTcpEndpoint = {
    name,
    url,
    group,
    interval ? "5m",
  }: {
    inherit name url group interval;
    conditions = [
      "[CONNECTED] == true"
      "[RESPONSE_TIME] < 10000"
    ];
    alerts = [
      {
        type = "email";
        failure-threshold = 2;
        success-threshold = 1;
        description = "''${name}'' is down";
      }
    ];
  };

  mkBorgEndpoint = name: {
    inherit name;
    group = "Backups";
    token = "\${GATUS_BORG_TOKEN}";
    heartbeat.interval = "168h"; # Alert if no heartbeat received within 1 week
    alerts = [
      {
        type = "email";
        failure-threshold = 1;
        success-threshold = 1;
        send-on-resolved = true;
        description = "${name} borg backup has not run successfully";
      }
    ];
  };

  config = {
    external-endpoints = map mkBorgEndpoint ["minnie" "lappy" "nix01" "nix02"];

    endpoints = [
      # Public sites — checked directly
      (mkEndpoint {
        name = "boycrisis.net";
        url = "https://boycrisis.net";
        group = "Public";
      })
      (mkEndpoint {
        name = "kbfirmware.xyz";
        url = "https://kbfirmware.xyz";
        group = "Public";
      })
      (mkEndpoint {
        name = "share.jenga.dev";
        url = "https://share.jenga.dev";
        group = "Public";
        status = 403; # we expect 403 Forbidden at /
      })
      (mkEndpoint {
        name = "git.jenga.xyz";
        url = "https://git.jenga.xyz";
        group = "Public";
      })
      (mkEndpoint {
        name = "tlon.jenga.xyz";
        url = "https://tlon.jenga.xyz";
        group = "Public";
      })
      (mkTcpEndpoint {
        name = "tlon-mud";
        url = "tcp://tlon.jenga.xyz:1138";
        group = "Public";
      })

      # Internal services — reachable via WireGuard
      (mkEndpoint {
        name = "vault";
        url = "https://vault.jenga.xyz";
        group = "Internal";
      })
      (mkEndpoint {
        name = "spruce";
        url = "https://spruce.jenga.xyz";
        group = "Internal";
      })
      (mkEndpoint {
        name = "actual";
        url = "https://actual.jenga.xyz";
        group = "Internal";
      })
      (mkEndpoint {
        name = "photos";
        url = "https://photos.jenga.xyz";
        group = "Internal";
      })

      # Servers — SSH reachability via WireGuard
      (mkTcpEndpoint {
        name = "nix03-ssh";
        url = "tcp://nix03:22";
        group = "Servers";
      })

      # Personal devices — ICMP ping only, no alerts
      (mkPingEndpoint {
        name = "minnie";
        url = "icmp://minnie";
        group = "Devices";
      })
      (mkPingEndpoint {
        name = "lappy";
        url = "icmp://lappy";
        group = "Devices";
      })
    ];

    alerting.email = {
      from = "gatus@jenga.xyz";
      username = "jeremy@jenga.xyz";
      # Injected at runtime from the GATUS_SMTP_PASS Fly secret
      password = "\${GATUS_SMTP_PASS}";
      host = "smtp.fastmail.com";
      port = 465;
      tls = true;
      to = "jeremy@jenga.xyz";
    };

    ui = {
      title = "up.jenga.xyz | Updog";
      description = "Is it up?";
      header = "up.jenga.xyz";
      dashboard-heading = "Updog";
      logo = "/logo.jpeg";
      dashboard-subheading = "Running in the 'REGION_PLACEHOLDER' fly.io region.";
    };

    web.port = 8080;
  };
in
  (pkgs.formats.yaml {}).generate "gatus.yaml" config
