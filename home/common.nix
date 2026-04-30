{
  config,
  pkgs,
  lib,
  ...
}: {
  config = {
    home-manager.users.jenga = {
      programs.home-manager.enable = true;
      home.stateVersion = "22.05";

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      programs.nix-index.enable = true;

      home.packages = with pkgs; [
        helix
        fish
      ];

      programs.fish = {
        enable = true;
        shellAliases = {
          upd = "cd ~/git/nix-config && sudo bash scripts/switch.sh";
        };
      };
    };
  };
}
