# Shared home-manager config imported by all user machines.
# Machine-specific things (pinentry, PATH quirks, packages) stay in each machine's home.nix.
{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index.enable = true;

  # rbw base config — each machine adds its own pinentry
  programs.rbw = {
    enable = true;
    settings = {
      email = "jeremy@jenga.xyz";
      base_url = "https://vault.jenga.xyz";
    };
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      upd = "cd ~/git/nix-config && sudo bash scripts/switch.sh";
      dim-screen = "dpms";
    };
    functions = {
      gopass.body = "printf 'Deprecated: use rbw instead. To override: command gopass\\n'; return 1";
      pass.body = "printf 'Deprecated: use rbw instead. To override: command pass\\n'; return 1";
    };
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  programs.git = {
    enable = true;
    ignores = [
      "/.direnv"
      "/.envrc"
      ".vscode"
      "/.idea"
    ];
    settings = {
      user = {
        name = "Jeremy Parker";
        email = "jeremy@jenga.xyz";
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
    };
  };

  # Reuse existing connections — avoids paying SSH handshake cost on every
  # Nix store operation during deploys.
  programs.ssh = {
    enable = true;
    matchBlocks."*" = {
      controlMaster = "auto";
      controlPath = "~/.ssh/control/%r@%h:%p";
      controlPersist = "10m";
    };
  };

  home.packages = with pkgs; [
    helix
  ];

  # Run install.sh after every switch to keep dotfiles symlinks current.
  # install.sh is idempotent: it removes and relinks existing symlinks.
  home.activation.dotfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD bash ${config.home.homeDirectory}/git/nix-config/dotfiles/install.sh
  '';
}
