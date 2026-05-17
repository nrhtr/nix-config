{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./ssh.nix];

  programs.home-manager.enable = true;
  home.stateVersion = "22.05";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index.enable = true;

  programs.rbw = {
    enable = true;
    settings = {
      email = "jeremy@jenga.xyz";
      base_url = "https://vault.jenga.xyz";
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = "fish_add_path $HOME/bin";
    shellAliases = {
      upd = "cd ~/git/nix-config && sudo bash scripts/switch.sh";
      dim-screen = "dpms";
    };
    functions = {
      gopass.body = "printf 'Deprecated: use rbw instead. To override: command gopass\\n'; return 1";
      pass.body = "printf 'Deprecated: use rbw instead. To override: command pass\\n'; return 1";
      import-paypal.body = "scp $argv root@nix02:/var/lib/paypal-import/inbox/";
      import-bank.body = "scp $argv root@nix02:/var/lib/bank-import/inbox/";
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
      advice.defaultBranchName = false;
    };
  };

  home.packages = with pkgs; [
    helix
  ];

  home.activation.dotfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD bash ${config.home.homeDirectory}/git/nix-config/dotfiles/install.sh
  '';
}
