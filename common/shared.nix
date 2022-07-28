{
  config,
  pkgs,
  lib,
  ...
}: let
  nix-colors = import <nix-colors>;
  inherit (nix-colors.lib-contrib {inherit pkgs;}) vimThemeFromScheme;
in {
  imports = [<agenix/modules/age.nix>];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    mtr
    mosh
    pass
    tmux
    gnupg
    magic-wormhole
    iotop
    lsof
    go # direnv
    jq
    poetry
    gron
    unzip
    python310
    stow
    tmux
    file
    docker
    nixfmt
    niv
    (pkgs.callPackage <agenix/pkgs/agenix.nix> {})
  ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = "experimental-features = nix-command flakes";
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
  };

  programs.fish.enable = true;
  programs.neovim = {
    enable = true;

    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  services.openssh.enable = lib.mkDefault true;
  services.openssh.permitRootLogin = "prohibit-password";
  services.openssh.ports = [18061];

  security.sudo.wheelNeedsPassword = false;

  #system.autoUpgrade.enable = true;

  networking.firewall.allowPing = true;
  networking.firewall.logRefusedConnections = false;

  networking.extraHosts = ''
    10.100.0.1 nix01
    95.217.114.169 nix02 nix02.deploy
  '';

  # LetsEncrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "jeremy@jenga.xyz";
  };

  users.users.jenga = {
    isNormalUser = true;
    home = "/home/jenga";
    description = "Jeremy Parker";
    shell = pkgs.fish;
    extraGroups = ["wheel" "networkmanager"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@thinkpad"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMETRRIYWUGbdmmSU/b3+hDf15gCqTVxQrpJrY2PKbEndHOW4PZHt61NYReYXOBWgO/z8x40uQ7ZdxwwKKrDQS4= enclave@iPhone"
    ];
  };
}
