{...}: {
  jenga.borg = {
    enable = true;
    repoName = "thinkpad";
    heartbeatEndpoint = "backups_lappy";
    user = "jenga";
    startAt = "*-*-* 02:00:00";
    persistentTimer = true;
    paths = "/home/jenga";
    exclude = [
      "/home/jenga/.cache"
      "/home/jenga/.mozilla"
      "/home/jenga/.local"
      "/home/jenga/download"
      "/home/jenga/rtorrent/download"
      "/home/jenga/Desktop"
    ];
  };
}
