{...}: {
  jenga.borg = {
    enable = true;
    repoName = "nix03";
    heartbeatEndpoint = "backups_nix03";
    startAt = "daily";

    paths = [
      "/home/jenga"
      "/var/lib/qbittorrent"
    ];

    # ZFS snapshots for consistent VM volume backups.
    # Snapshot paths are automatically added to the backup.
    zfsSnapshots = [
      {
        dataset = "zroot/enc/vms";
        mountPoint = "/var/lib/microvms";
      }
    ];
  };
}
