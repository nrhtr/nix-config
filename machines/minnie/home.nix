{
  config,
  pkgs,
  lib,
  ...
}: let
  name = "Jeremy Parker";
  userName = "jenga";
  email = "jeremy@jenga.xyz";
in {
  home.stateVersion = "22.05";

  # Direnv, load and unload environment variables depending on the current directory.
  # https://direnv.net
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable
  programs.direnv = {
    enable = true;

    nix-direnv.enable = true;

    # "layout poetry" support
    stdlib = ''
      layout_poetry() {
        PYPROJECT_TOML="''${PYPROJECT_TOML:-pyproject.toml}"
        if [[ ! -f "$PYPROJECT_TOML" ]]; then
            log_status "No pyproject.toml found. Executing \`poetry init\` to create a \`$PYPROJECT_TOML\` first."
            poetry init
        fi

        if [[ -d ".venv" ]]; then
            VIRTUAL_ENV="$(pwd)/.venv"
        else
            VIRTUAL_ENV=$(poetry env info --path 2>/dev/null ; true)
        fi

        if [[ -z $VIRTUAL_ENV || ! -d $VIRTUAL_ENV ]]; then
            log_status "No virtual environment exists. Executing \`poetry install\` to create one."
            poetry install
            VIRTUAL_ENV=$(poetry env info --path)
        fi

        PATH_add "$VIRTUAL_ENV/bin"
        export POETRY_ACTIVE=1
        export VIRTUAL_ENV
      }
    '';
  };

  # Htop
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.htop.enable
  programs.htop.enable = true;
  programs.htop.settings.show_program_path = true;

  home.sessionVariables = {
    NIXPKGS_ALLOW_BROKEN = 1;
    NIX_SHELL_PRESERVE_PROMPT = 1;
    EDITOR = "vim";
  };

  programs.fish = {
    enable = true;

    # FIXME: Dodgy fix for PATH order issues (e.g. vi/vim/git in system paths)
    interactiveShellInit = ''
      fish_add_path -mP /etc/profiles/per-user/${userName}/bin
      fish_add_path /Users/jeremyparker/bin
      fish_add_path /Users/jeremyparker/Library/Python/3.9/bin
      fish_add_path ~/.local/bin

      # homebrew
      eval "$(/opt/homebrew/bin/brew shellenv)"
      export OPS_DIR="$HOME/.ops"
      export PATH="$HOME/.ops/bin:$PATH"
    '';
    shellAliases = {
      upd = "cd ~/git/nix-config && sudo bash scripts/switch-minnie.sh";
    };
    shellAbbrs = {
      "9k" = "k9s";
      k = "kubectl";
    };
  };

  programs.git = {
    enable = true;
    userName = name;
    userEmail = email;
    ignores = [
      "/.direnv"
      "/.envrc"
      ".vscode"
      "/.idea"
    ];
    extraConfig = {
      core = {
        editor = "nvim";
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

  programs.neovim = {
    enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  programs.nix-index.enable = true;

  home.packages = with pkgs;
    [
      # Some basics
      coreutils
      borgbackup
      curl
      wget
      gopass
      gnupg
      helix

      # Dev stuff
      dive
      go
      gopls
      go-tools
      delve
      jsonnet-language-server
      amazon-ecr-credential-helper
      sqlite-utils
      k6

      alejandra

      magic-wormhole
      ssm-session-manager-plugin

      kind
      kubectl
      awscli2
      awscurl
      aws2_wrap
      ffmpeg

      jq
      nodePackages.typescript
      nodejs
      nodejs.pkgs.pnpm
      purescript
      nixfmt

      # Useful nix related tools
      cachix
      comma
      niv
      nodePackages.node2nix
    ]
    ++ lib.optionals stdenv.isDarwin [
      cocoapods
      m-cli
    ];
}
