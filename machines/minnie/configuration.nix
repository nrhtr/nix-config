{
  pkgs,
  lib,
  ...
}: {
  imports = [
    <home-manager/nix-darwin>
    ./network.nix
    ./overlays.nix
  ];

  system.stateVersion = 6;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.jenga = import ./home.nix;
  users.users.jenga.home = "/Users/jenga";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;

  nix.settings = {
    trusted-users = ["@admin"];
    substituters = ["https://cache.nixos.org/"];
    trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
  };

  programs.ssh.knownHosts = {
    nixbuild = {
      hostNames = ["eu.nixbuild.net"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    };
  };

  nix.distributedBuilds = false;

  nix.extraOptions =
    ''
      auto-optimise-store = false
      experimental-features = nix-command flakes
    ''
    + lib.optionalString (pkgs.system == "aarch64-darwin") ''
      extra-platforms = x86_64-darwin aarch64-darwin
    '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  users.users.jenga.shell = pkgs.fish;
  programs.fish.enable = true;
  users.knownUsers = ["jenga"];
  users.users.jenga.uid = 501;
  ids.gids.nixbld = 30000;

  # Populate /etc/shells with fish so we can set as default
  environment.shells = [pkgs.fish];

  environment.systemPackages = with pkgs; [
    terminal-notifier
  ];

  fonts.packages = with pkgs; [
    recursive
    nerd-fonts.jetbrains-mono
  ];

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to use TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;
}
