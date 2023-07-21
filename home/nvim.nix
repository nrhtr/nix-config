{
  config,
  pkgs,
  ...
}: let
  nix-colors = import <nix-colors> {};
  executeThatThing = pkgs.vimUtils.buildVimPlugin {
    pname = "ExecuteThatThing.vim";
    version = "2021-01-19";
    src = pkgs.fetchgit {
      name = "vim-ExecuteThatThing";
      url = "https://notabug.org/cryptarch/vim-ExecuteThatThing";
      rev = "431fe2a422b82b1c8092279c3bf5d2dd0bbf85fc";
      sha256 = "sha256-/7SxpXZP5sRqyuhnmy1DPFAF0OtqY/RblXhMZwm2CHg=";
    };
  };
  vim-nixhash = pkgs.vimUtils.buildVimPlugin {
    pname = "vim-nixhash";
    version = "2022-02-07";
    src = pkgs.fetchFromGitHub {
      owner = "symphorien";
      repo = "vim-nixhash";
      rev = "d6e3c5161ef2e3fbc4a4b68a785d958d97e25b7e";
    };
  };
  inherit (nix-colors.lib-contrib {inherit pkgs;}) vimThemeFromScheme;
in rec {
  imports = [./colours.nix];
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
        vim-autoformat
        editorconfig-nvim
        #vim-nixhash
        {
          config = ''
            nmap X  <Plug>(ExecThatThingNormal)
            vmap X  <Plug>(ExecThatThingVisual)
            omap il <Plug>(InnerLineMotion)
            omap ic <Plug>(InnerCommandMotion)
            nmap <Return> Xic
          '';
          plugin = executeThatThing;
        }
        {
          plugin = vimThemeFromScheme {scheme = config.colorscheme;};
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

        au BufWrite * :Autoformat
        let g:formatdef_alejandra = '"nix run nixpkgs#alejandra"'
        let g:formatters_nix = ['alejandra']

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
  };
}
