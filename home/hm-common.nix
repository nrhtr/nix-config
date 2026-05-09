# Shared home-manager config imported by all user machines.
# Machine-specific things (pinentry, PATH quirks, packages) stay in each machine's home.nix.
{pkgs, ...}: {
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
    shellAliases.upd = "cd ~/git/nix-config && sudo bash scripts/switch.sh";
    functions = {
      gopass.body = "printf 'Deprecated: use rbw instead. To override: command gopass\\n'; return 1";
      pass.body = "printf 'Deprecated: use rbw instead. To override: command pass\\n'; return 1";
    };
  };

  home.packages = with pkgs; [
    helix
  ];
}
