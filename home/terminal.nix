{ config, pkgs, ... }:

let
  nix-colors = import <nix-colors>;
  inherit (nix-colors.lib { inherit pkgs; }) vimThemeFromScheme;
in rec {
  imports = [ ./colours.nix ];
  home-manager.users.jenga = rec {
    programs.neovim = {
      enable = true;

      viAlias = true;
      vimAlias = true;

      plugins = with pkgs.vimPlugins; [
        vim-nix
        vim-fugitive
        vim-terraform
        zig-vim
        nerdcommenter
        vim-clap
        {
          plugin = vimThemeFromScheme { scheme = config.colorscheme; };
          config = "colorscheme nix-${config.colorscheme.slug}";
        }
      ];
      extraConfig = ''
        set nocompatible
        filetype off

        filetype plugin indent on

        if has('syntax')
        syntax on
        endif

        set autoindent
        set expandtab
        set sw=4
        set tabstop=4
        set expandtab
        set ruler
        set smarttab
        set incsearch
        set number
        set list

        imap jj <Esc>

        set mouse=n

        let mapleader ="'"
      '';
    };

    home.sessionVariables = {
      BORG_PASSCOMMAND = "cat /home/jenga/.secrets/borg-phrase";
      BORG_REMOTE_PATH = "borg1";
      BORG_REPO = "20379@hk-s020.rsync.net:backup";
      BORG_RSH = "ssh -i /home/jenga/.secrets/borg-key";
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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
