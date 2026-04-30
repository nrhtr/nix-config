{
  config,
  pkgs,
  lib,
  ...
}: {
  home-manager.users.jenga = {
    programs.ssh.enable = true;
    programs.ssh.matchBlocks = {
      "nix01" = {
        user = "jenga";
        port = 22;
      };
      "nix02" = {
        user = "jenga";
        port = 22;
      };
      "hk-s020.rsync.net" = {extraOptions.UpdateHostKeys = "no";};
    };
  };
}
