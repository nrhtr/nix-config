{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        controlMaster = "auto";
        controlPath = "~/.ssh/control/%r@%h:%p";
        controlPersist = "10m";
      };
      "nix01" = {
        user = "jenga";
        port = 22;
      };
      "nix02" = {
        user = "jenga";
        port = 22;
      };
      "nix03" = {
        user = "jenga";
        port = 22;
      };
      "hk-s020.rsync.net" = {extraOptions.UpdateHostKeys = "no";};
      "git.jenga.xyz" = {
        user = "git";
        port = 18061;
        controlMaster = "no";
      };
    };
  };
}
