# Build Firecracker-ready artifacts for the Urbit guest VM.
#
# Usage:
#   nix-build apps/urbit-infra/vm -A vmlinux  → result/vmlinux (uncompressed ELF, use this path in Firecracker)
#   nix-build apps/urbit-infra/vm -A initrd   → result/initrd
#   nix-build apps/urbit-infra/vm -A rootfs   → result (raw ext4, copy-per-ship)
#
# Kernel format note: Firecracker expects vmlinux (uncompressed ELF) on x86_64.
# bzImage support was added in later Firecracker releases but vmlinux is the
# safe default. The nixpkgs kernel build always produces vmlinux in the .dev
# output regardless of platform target, so we use kernel.dev/vmlinux directly.
#
# The rootfs is a writeable raw ext4 image. The gateway copies it
# (cp --sparse=always) when provisioning each new ship, then attaches
# it as vda. The per-ship pier lives on a separate vdb volume.
#
# Building rootfs requires QEMU/KVM on the build host (nix-build runs
# make-disk-image.nix inside a lightweight VM). nix02 has KVM available.
let
  sources = import ../../../npins;
  nixpkgs = sources.nixpkgs;
  pkgs = import nixpkgs {system = "x86_64-linux";};
  lib = pkgs.lib;

  guestEval = import "${nixpkgs}/nixos" {
    configuration = ./guest.nix;
    system = "x86_64-linux";
  };

  config = guestEval.config;

  rootfs = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
    inherit config lib pkgs;
    format = "raw";
    partitionTableType = "none";
    diskSize = 4096; # MiB — covers NixOS store + urbit binary with headroom
  };
in {
  # vmlinux: uncompressed ELF — nix-build -A vmlinux → result/vmlinux
  # Use result/vmlinux as Firecracker's kernel_image_path.
  vmlinux = config.system.build.kernel.dev;
  initrd = config.system.build.initialRamdisk;
  rootfs = rootfs;
}
