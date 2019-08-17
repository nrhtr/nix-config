{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/shared.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  networking.hostName = "nixos.jenga.xyz";

  # Enable the OpenSSH server.
  services.sshd.enable = true;
  services.openssh.permitRootLogin = "no";

  services.openssh.ports = [18061];
  security.sudo.wheelNeedsPassword = false;
  networking.firewall.logRefusedConnections = false;
  networking.firewall.allowPing = true;
}