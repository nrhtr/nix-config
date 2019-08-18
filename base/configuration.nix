{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/shared.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  networking.hostName = "nixos.jenga.xyz";
}
