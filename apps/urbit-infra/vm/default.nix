# Builds Firecracker-ready artifacts for the Urbit guest VM.
# Follows the not-os pattern: evalModules with a minimal subset of NixOS
# modules rather than the full NixOS module system.  This avoids bootloader
# assertions, initrd requirements, and kernel-config guards that don't apply
# to Firecracker guests.
#
# Usage:
#   nix-build apps/urbit-infra/vm -A vmlinux   → result/vmlinux
#   nix-build apps/urbit-infra/vm -A initrd    → result/initrd
#   nix-build apps/urbit-infra/vm -A rootfs    → result  (squashfs)
#   nix-build apps/urbit-infra/vm -A bootArgs  → result  (kernel cmdline file)
#
# Boot sequence (no grub, no NixOS bootloader):
#   Firecracker → vmlinux (kernel) → initrd (stage 1, busybox)
#     → mounts squashfs rootfs from vda, pier ext4 from vdb
#     → switch_root → stage2-init (mounts /proc /sys /dev, activates, execs runit)
#     → runit → dhcpcd → urbit /pier
let
  sources = import ../../../npins;
  nixpkgs = sources.nixpkgs;
  pkgs = import nixpkgs {system = "x86_64-linux";};
  pkgsUnstable = import sources.nixpkgs-unstable {system = "x86_64-linux";};
  lib = pkgs.lib;

  # Firecracker kernel: exact upstream config, vmlinux copied to $out.
  # linuxManualConfig with no CONFIG_MODULES produces only one output;
  # make install copies bzImage but not vmlinux, so we add it in postInstall.
  firecrackerKernel =
    (pkgs.linuxManualConfig {
      inherit (pkgs.linux_6_1) version src;
      configfile = ./microvm-kernel-x86_64-6.1.config;
      allowImportFromDerivation = true;
    })
    .overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          cp vmlinux $out/
        '';
    });

  # Minimal system evaluation — no kernel.nix, no bootloader, no initrd module.
  eval = lib.evalModules {
    modules = [
      ./base.nix
      ./config.nix
      ./compat.nix
      "${nixpkgs}/nixos/modules/system/etc/etc.nix"
      "${nixpkgs}/nixos/modules/system/activation/activation-script.nix"
      "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
      "${nixpkgs}/nixos/modules/misc/assertions.nix"
      "${nixpkgs}/nixos/modules/misc/lib.nix"
      {
        config.nixpkgs.pkgs = pkgs;
        config.nixpkgs.localSystem.system = "x86_64-linux";
        config._module.args.urbit = pkgsUnstable.urbit;
      }
    ];
  };

  cfg = eval.config;
in {
  # Uncompressed ELF kernel for Firecracker's kernel_image_path.
  vmlinux = firecrackerKernel;

  # Tiny busybox initrd: mounts squashfs + pier, switch_roots to stage 2.
  initrd = cfg.system.build.initialRamdisk;

  # Squashfs OS image for vda — shared read-only across all ships.
  rootfs = cfg.system.build.squashfs;

  # Kernel boot args — Firecracker boot_source.boot_args should equal
  # the contents of this file (includes the store-path systemConfig=).
  bootArgs = cfg.system.build.bootArgs;
}
