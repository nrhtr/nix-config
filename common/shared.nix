{
  config,
  pkgs,
  lib,
  ...
}: let
  sources = import ../npins;
  agenix = sources.agenix;
  sshKeys = import ./ssh-keys.nix;
in {
  imports = [
    "${agenix}/modules/age.nix"
    ../modules/borg.nix
  ];

  environment.systemPackages = with pkgs; [
    screen
    vim
    git
    htop
    mtr
    pass
    rbw
    tmux
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
    nixfmt-classic
    niv
    (pkgs.callPackage "${agenix}/pkgs/agenix.nix" {})
  ];

  nix = {
    package = pkgs.nixVersions.stable;
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

  programs.mosh.enable = true;
  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    function gopass
      printf 'Deprecated: use rbw instead. To override: command gopass\n'
      return 1
    end
    function pass
      printf 'Deprecated: use rbw instead. To override: command pass\n'
      return 1
    end
  '';
  programs.neovim = {
    enable = true;

    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  services.openssh.ports = [22 18061];
  # Prevent openssh from auto-opening ports on all interfaces
  services.openssh.openFirewall = false;

  # 18061 open publicly; port 22 only reachable via WireGuard
  networking.firewall.allowedTCPPorts = [18061];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [22];

  users.users.root.openssh.authorizedKeys.keys = lib.mkDefault sshKeys;

  security.sudo.wheelNeedsPassword = false;

  #system.autoUpgrade.enable = true;

  networking.firewall.allowPing = true;
  networking.firewall.logRefusedConnections = false;

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
    openssh.authorizedKeys.keys = sshKeys;
  };
}
