# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [<nixpkgs/nixos/modules/installer/scan/not-detected.nix>];

  boot.initrd.availableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/957f1802-c454-40b4-ab8d-6c18565df3d7";
    options = ["defaults" "noatime" "discard"];
    fsType = "ext4";
  };

  boot.initrd.luks.devices."crypted-nixos" = {
    device = "/dev/disk/by-uuid/0e29cd22-0241-43ee-9926-6333aa1a3576";
    # security schmurity
    allowDiscards = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/F755-93D3";
    fsType = "vfat";
  };

  swapDevices = [];

  nix.settings.max-jobs = lib.mkDefault 4;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
