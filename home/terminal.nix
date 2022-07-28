{ config, pkgs, ... }:

{
  imports = [ ./colours.nix ];
  home-manager.users.jenga = rec {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.nix-index.enable = true;

    programs.fish = {
      enable = true;
      functions = {
        mkd = "mkdir -p $argv[1]; and cd $argv[1]";
        gitignore = "curl -sL https://www.gitignore.io/api/$argv";
        nxp = "nix-shell -p $argv[1] --run $argv[1]";
      };
      shellInit = ''
        set --universal pure_check_for_new_release false
        set --universal pure_enable_single_line_prompt true
      '';
      plugins = let
        pure = {
          name = "pure";
          src = pkgs.fetchFromGitHub {
            owner = "pure-fish";
            repo = "pure";
            rev = "c0df5cb4726aa6831c0473556066a4cbf48fc79e";
            sha256 = "sha256-axjkGIMObj+SqS7tZVQT0ZWYlHl7Us3gd2hle5ZZJ84";
          };
        };
        hydro = {
          name = "hydro";
          src = pkgs.fetchFromGitHub {
            owner = "jorgebucaran";
            repo = "hydro";
            rev = "d4875065ceea226f58ead97dd9b2417937344d6e";
            sha256 = "sha256-nXeDnqqOuZyrqGTPEQtYlFvrFvy1bZVMF4CA37b0lsE=";
          };
        };
      in [
        pure
        #hydro
      ];
    };
  };
}
