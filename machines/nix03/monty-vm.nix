{
  config,
  pkgs,
  lib,
  ...
}: {
  microvm = {
    hypervisor = "firecracker";
    mem = 2048;
    vcpu = 1;
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
  };

  sources = import ../../npins;

  imports = [
    "${sources.microvm-nix}/nixos-modules/microvm"
  ];

  # Network: user-mode networking, SSH port forwarded to host 2223
  networking.hostName = "monty";
  networking.useDHCP = true;

  # Packages
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    git
    curl
    vim
  ];

  # Docker daemon
  virtualisation.docker.enable = true;

  # Users
  users.users.jenga = {
    isNormalUser = true;
    extraGroups = ["docker" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJBLHeD2QmiFu75rRXYKuhLLY1SpI3LCyUH5TO7iVHr jenga@Jeremys-Mini"
    ];
  };

  users.users.tom = {
    isNormalUser = true;
    extraGroups = ["docker" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDummyTomKeyPlaceholderReplaceMe tom@collaborator"
    ];
  };

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;

  # Minimal system config
  system.stateVersion = "25.11";
  boot.isContainer = true;
}
