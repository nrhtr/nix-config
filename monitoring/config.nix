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

  config = {
    endpoints = [
      # Public sites — checked directly
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

      # Internal services — reachable via WireGuard
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
      title = "jenga.xyz | Status";
      description = "Uptime status for various jenga.xyz applications";
      dashboard-heading = "Status";
      dashboard-subheading = "This dashboard is running in the 'REGION_PLACEHOLDER' fly.io region.";
    };

    web.port = 8080;
  };
in
  (pkgs.formats.yaml {}).generate "gatus.yaml" config
