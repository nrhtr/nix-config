# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinkpad"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Use a swapfile, because we don't want to bother with another LUKS partition
  swapDevices = [
    { device = "/swapfile"; size = 10000; }
  ];

  system.autoUpgrade.enable = true;
  system.autoUpgrade.channel = "https://nixos.org/channels/nixos-18.09-small";

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  # Disable the OpenSSH server.
  services.sshd.enable = true;
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
