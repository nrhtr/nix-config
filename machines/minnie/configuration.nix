{
  pkgs,
  lib,
  ...
}: {
  imports = [
    <home-manager/nix-darwin>
    ./network.nix
    ./overlays.nix
    ./borg.nix
  ];

  system.stateVersion = 6;
  system.primaryUser = "jenga";

  environment.darwinConfig = "/Users/jenga/git/nix-config/machines/minnie/configuration.nix";

  # Bake npins store paths into the activate script's NIX_PATH check.
  # The activate script uses config.nix.nixPath directly (not the runtime
  # NIX_PATH env var), so these must be set here rather than in the switch script.
  nix.nixPath = let
    pins = import ../../npins;
  in [
    "nixpkgs=${pins.nixpkgs}"
    "darwin=${pins.nix-darwin}"
    "home-manager=${pins.home-manager}"
    "darwin-config=/Users/jenga/git/nix-config/machines/minnie/configuration.nix"
  ];

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

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "nix02";
      system = "x86_64-linux";
      sshUser = "root";
      sshKey = "/var/root/.ssh/id_ed25519";
      speedFactor = 12;
      supportedFeatures = ["big-parallel"];
    }
  ];

  # nix daemon (root) needs to reach nix02 over WireGuard on port 22
  environment.etc."ssh/ssh_config.d/nix02-builder.conf".text = ''
    Host nix02
      Hostname 10.100.0.6
      Port 22
      IdentityFile /var/root/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
  '';

  nix.extraOptions =
    ''
      auto-optimise-store = false
      experimental-features = nix-command flakes
    ''
    + lib.optionalString (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") ''
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
    flyctl
  ];

  fonts.packages = with pkgs; [
    recursive
    nerd-fonts.jetbrains-mono
  ];

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to use TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  # borgbackup with FUSE support for `borg mount`.
  # Note: macFUSE must be installed manually: brew install --cask macfuse --no-quarantine
  # then approve the kernel extension in System Settings → Privacy & Security.
  homebrew = {
    enable = true;
    taps = ["borgbackup/tap"];
    brews = ["borgbackup/tap/borgbackup-fuse"];
  };
}
