{
  config,
  pkgs,
  lib,
  ...
}: {
  config = {
    home-manager.users.jenga = {
      imports = [./hm-common.nix];

      programs.home-manager.enable = true;
      home.stateVersion = "22.05";

      programs.rbw.settings.pinentry = pkgs.pinentry-curses;

      home.packages = with pkgs; [fish rbw];
    };
  };
}
