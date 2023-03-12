{
  config,
  pkgs,
  lib,
  ...
}: {
  config = {
    home-manager.users.jenga = {
      programs.home-manager.enable = true;
      home.stateVersion = "22.11";
    };
  };
}
