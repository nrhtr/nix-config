{pkgs, ...}: {
  jenga.borg = {
    enable = true;
    repoName = "minecraft";
    heartbeatEndpoint = "backups_nix02";
    startAt = "hourly";
    paths = [
      "/var/lib/minecraft/world"
      "/var/lib/immich"
      "/tmp/borg-git-bundles"
    ];
    preHook = ''
      rm -rf /tmp/borg-git-bundles
      mkdir -p /tmp/borg-git-bundles
      for repo in /var/lib/cgit/repos/*.git; do
        [ -d "$repo" ] || continue
        name=$(basename "$repo")
        ${pkgs.git}/bin/git --git-dir="$repo" bundle create "/tmp/borg-git-bundles/$name.bundle" --all
      done
    '';
  };
}
