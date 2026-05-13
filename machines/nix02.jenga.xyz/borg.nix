{...}: {
  jenga.borg = {
    enable = true;
    repoName = "minecraft";
    heartbeatEndpoint = "backups_nix02";
    startAt = "hourly";
    paths = [
      "/var/lib/minecraft/world"
      "/var/lib/cgit/repos"
    ];
  };
}
