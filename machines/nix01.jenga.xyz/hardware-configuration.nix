# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [<nixpkgs/nixos/modules/profiles/qemu-guest.nix>];

  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk"];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/79ecb233-9d3f-44b1-b4c6-0ee1399597eb";
    fsType = "ext4";
  };

  swapDevices = [{device = "/dev/disk/by-uuid/3e0dde28-1bc2-48ce-ac28-3d77bf1657bc";}];

  nix.settings.max-jobs = lib.mkDefault 1;
}
