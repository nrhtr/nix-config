{pkgs, ...}: {
  jenga.borg = {
    enable = true;
    repoName = "nix01";
    heartbeatEndpoint = "backups_nix01";
    paths = [
      "/var/www/boycrisis.net"
      "/var/lib/bitwarden_rs"
    ];
    readWritePaths = ["/var/lib/bitwarden_rs"];
    preHook = ''
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/bitwarden_rs/db.sqlite3 "PRAGMA wal_checkpoint(TRUNCATE);"
    '';
  };
}
