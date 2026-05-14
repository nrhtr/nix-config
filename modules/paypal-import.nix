{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.paypalImport;
  inherit (lib) mkEnableOption mkOption types mkIf;

  pkg = pkgs.buildNpmPackage {
    pname = "paypal-import";
    version = "1.0.0";
    src = ../apps/paypal-import;
    npmDepsHash = "sha256-781IvS2OsfdtPlYb2eYMg/arCs/lQqdXYafThmQwEX4=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out/bin $out/lib
      cp paypal-import.mjs $out/lib/
      cp -r node_modules $out/lib/
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/paypal-import \
        --add-flags "$out/lib/paypal-import.mjs"
    '';
    nativeBuildInputs = [pkgs.makeWrapper];
  };
in {
  options.jenga.paypalImport = {
    enable = mkEnableOption "PayPal CSV → Actual Budget importer";

    accountName = mkOption {
      type = types.str;
      default = "Paypal";
      description = "Name of the Actual Budget account to import into.";
    };

    currency = mkOption {
      type = types.str;
      default = "AUD";
      description = "Only import rows with this currency; skip others.";
    };

    dateFormat = mkOption {
      type = types.enum ["DMY" "MDY"];
      default = "DMY";
      description = "PayPal CSV date format: DMY = DD/MM/YYYY (default), MDY = MM/DD/YYYY.";
    };

    actualServerUrl = mkOption {
      type = types.str;
      example = "https://actual.jenga.xyz";
    };

    actualSyncId = mkOption {
      type = types.str;
      description = "Budget sync ID from Actual Budget settings.";
    };

    actualPasswordFile = mkOption {
      type = types.path;
      description = "Path to file containing the Actual server password.";
    };

    inboxDir = mkOption {
      type = types.str;
      default = "/var/lib/paypal-import/inbox";
      description = "Drop PayPal CSV exports here to trigger import.";
    };
  };

  config = mkIf cfg.enable {
    users.groups.paypal-import = {};
    users.users.paypal-import = {
      isSystemUser = true;
      group = "paypal-import";
    };

    systemd.services.paypal-import = {
      description = "Import PayPal CSV into Actual Budget";
      after = ["network.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkg}/bin/paypal-import";
        StateDirectory = "paypal-import";
        StateDirectoryMode = "0700";
        User = "paypal-import";
        Group = "paypal-import";
      };

      environment = {
        ACTUAL_SERVER_URL = cfg.actualServerUrl;
        ACTUAL_SYNC_ID = cfg.actualSyncId;
        ACTUAL_PASSWORD_FILE = cfg.actualPasswordFile;
        ACCOUNT_NAME = cfg.accountName;
        CURRENCY = cfg.currency;
        DATE_FORMAT = cfg.dateFormat;
        INBOX_DIR = cfg.inboxDir;
      };
    };

    systemd.paths.paypal-import = {
      description = "Watch for PayPal CSV files to import";
      wantedBy = ["multi-user.target"];
      pathConfig = {
        DirectoryNotEmpty = cfg.inboxDir;
        Unit = "paypal-import.service";
      };
    };
  };
}
