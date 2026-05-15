{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = ["${modulesPath}/profiles/minimal.nix"];

  # Firecracker boot: serial console, no PCI bus, panic-reboot
  boot.kernelParams = [
    "console=ttyS0"
    "reboot=k"
    "panic=1"
    "pci=off"
    "nomodeset"
  ];

  # Explicit Firecracker kernel settings.
  #
  # NixOS common-config.nix already provides:
  #   KVM_GUEST, HYPERVISOR_GUEST, VIRTIO_MMIO_CMDLINE_DEVICES,
  #   DEVTMPFS, RANDOM_TRUST_CPU, SERIAL_8250
  #
  # x86_64 defconfig provides:
  #   SERIAL_8250_CONSOLE, DEVTMPFS_MOUNT
  #
  # What's genuinely absent from NixOS defaults and must be added:
  #   VIRTIO_CONSOLE, VIRTIO_RNG
  #
  # Reference: https://github.com/firecracker-microvm/firecracker/blob/main/resources/guest_configs/microvm-kernel-ci-x86_64-6.1.config
  boot.kernelPatches = [
    {
      name = "firecracker-guest";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        VIRTIO_CONSOLE = module; # virtio console device (absent from NixOS defaults)
        VIRTIO_RNG = module; # entropy from hypervisor (absent from NixOS defaults)
        SERIAL_8250_CONSOLE = yes; # required for console=ttyS0
        DEVTMPFS_MOUNT = yes; # auto-mount /dev before systemd starts
      };
    }
  ];

  # virtio drivers must be in the initrd to mount the rootfs
  boot.initrd.kernelModules = [
    "virtio_mmio"
    "virtio_blk"
    "virtio_net"
    "virtio_console"
    "virtio_rng"
  ];

  # vda: OS rootfs (read-write copy-per-ship)
  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
  };

  # vdb: per-ship pier data volume, provisioned by the gateway
  fileSystems."/pier" = {
    device = "/dev/vdb";
    fsType = "ext4";
    options = ["nofail"];
  };

  # Networking: DHCP on virtio NIC; host provides dnsmasq per TAP
  networking.useDHCP = true;
  networking.firewall.enable = false;

  # Nothing interactive — no SSH, no man pages, no shell completions
  services.openssh.enable = false;
  documentation.enable = false;
  documentation.man.enable = false;
  programs.command-not-found.enable = false;
  security.sudo.enable = false;

  users.users.urbit = {
    isSystemUser = true;
    group = "urbit";
    home = "/pier";
  };
  users.groups.urbit = {};

  systemd.services.urbit = {
    description = "Urbit ship";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "pier.mount"];
    wants = ["network-online.target" "pier.mount"];
    serviceConfig = {
      ExecStart = "${pkgs.urbit}/bin/urbit /pier";
      User = "urbit";
      Group = "urbit";
      Restart = "on-failure";
      RestartSec = "5s";
      WorkingDirectory = "/pier";
    };
  };

  # pkgs.urbit is the Vere runtime from nixpkgs; override if you need a
  # specific release that nixpkgs hasn't caught up to yet.
  environment.systemPackages = [pkgs.urbit];

  system.stateVersion = "25.05";
}
