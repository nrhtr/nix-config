{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
  ];

  #boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  # Note: setting fileSystems is generally not
  # necessary, since nixos-generate-config figures them out
  # automatically in hardware-configuration.nix.
  #fileSystems."/".device = "/dev/disk/by-label/nixos";

  system.autoUpgrade.enable = true;
  system.autoUpgrade.channel = "https://nixos.org/channels/nixos-18.09-small";

  # Disable the OpenSSH server.
  services.sshd.enable = false;
  security.sudo.wheelNeedsPassword = false;
  networking.firewall.logRefusedConnections = true;

  environment.systemPackages = with pkgs; [
      vim
      git
      htop
      mtr
      mosh
  ];

  users.users.jenga = {
    isNormalUser = true;
    home = "/home/jenga";
    description = "Jeremy Parker";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBroC7fhTdO17jn7U4FE97IFUYE4NfWxFcxax6bwVzsIXBRCQ9mYlNvmYokWTYX+rlSVi1ifpiwaveJHqcZX4hM=" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMGWqY84hz9k9OibHThS8QjqoSmuH2MtbRxR1UkSqrn jparker@sqiphone"];
  };
}
