# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
    ./borg.nix
    ../common/shared.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinkpad"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.extraHosts = ''
    10.100.0.1 nix01
  '';

  # Use a swapfile, because we don't want to bother with another LUKS partition
  swapDevices = [
    { device = "/swapfile"; size = 10000; }
  ];

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  services.gpm.enable = true;
  services.tlp.enable = true;
  services.tlp.extraConfig = ''
  CPU_SCALING_GOVERNOR_ON_AC=performance
  CPU_SCALING_GOVERNOR_ON_BAT=powersave

  CPU_BOOST_ON_AC=1
  CPU_BOOST_ON_BAT=0

  DISK_DEVICES="sda"
  DISK_APM_LEVEL_ON_AC="254"
  DISK_APM_LEVEL_ON_BAT="128"

  SATA_LINKPWR_ON_AC=max_performance
  SATA_LINKPWR_ON_BAT=min_power
  '';

  # Disable the OpenSSH server.
  services.sshd.enable = false;
  networking.firewall.logRefusedConnections = true;

  environment.systemPackages = with pkgs; [
      linuxPackages.acpi_call
  ];
}
