{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.bankImport;
  inherit (lib) mkEnableOption mkOption types mkIf;

  pkg = pkgs.buildNpmPackage {
    pname = "bank-import";
    version = "1.0.0";
    src = ../apps/bank-import;
    npmDepsHash = "sha256-UslO/Hnbbcx4cF1pXgPz+U0sT9pbic46mL+sI01UMJ0=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out/bin $out/lib
      cp bank-import.mjs $out/lib/
      cp -r node_modules $out/lib/
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/bank-import \
        --add-flags "$out/lib/bank-import.mjs" \
        --set PDFTOTEXT_PATH "${pkgs.poppler-utils}/bin/pdftotext"
    '';
    nativeBuildInputs = [pkgs.makeWrapper];
  };
in {
  options.jenga.bankImport = {
    enable = mkEnableOption "ME Bank PDF → Actual Budget importer";

    accountName = mkOption {
      type = types.str;
      default = "Bank";
      description = "Name of the Actual Budget account to import into.";
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
      default = "/var/lib/bank-import/inbox";
      description = "Drop ME Bank PDF statement exports here to trigger import.";
    };
  };

  config = mkIf cfg.enable {
    users.groups.bank-import = {};
    users.users.bank-import = {
      isSystemUser = true;
      group = "bank-import";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.inboxDir} 0700 bank-import bank-import -"
    ];

    systemd.services.bank-import = {
      description = "Import ME Bank PDF statement into Actual Budget";
      after = ["network.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkg}/bin/bank-import";
        StateDirectory = "bank-import";
        StateDirectoryMode = "0700";
        User = "bank-import";
        Group = "bank-import";
      };

      environment = {
        ACTUAL_SERVER_URL = cfg.actualServerUrl;
        ACTUAL_SYNC_ID = cfg.actualSyncId;
        ACTUAL_PASSWORD_FILE = cfg.actualPasswordFile;
        ACCOUNT_NAME = cfg.accountName;
        INBOX_DIR = cfg.inboxDir;
      };
    };

    systemd.paths.bank-import = {
      description = "Watch for ME Bank PDF files to import";
      wantedBy = ["multi-user.target"];
      pathConfig = {
        DirectoryNotEmpty = cfg.inboxDir;
        Unit = "bank-import.service";
      };
    };
  };
}
