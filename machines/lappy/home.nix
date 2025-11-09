{
  config,
  pkgs,
  ...
}: {
  home-manager.users.jenga = {
    home.shellAliases = {
      buildlappy = "sudo nixos-rebuild --file ~/nix/machines/lappy/eval.nix switch";
    };
  };
}
