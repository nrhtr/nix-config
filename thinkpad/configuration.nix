# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
    ../common/users.nix
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
}
