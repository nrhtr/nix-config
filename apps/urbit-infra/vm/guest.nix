{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  # Use the exact Firecracker upstream kernel config (all drivers =y, no modules).
  # linuxManualConfig bypasses nixpkgs' config layering and uses this file verbatim.
  # Source is pinned to nixpkgs' linux_6_1 so we don't need a separate hash.
  firecrackerKernel = pkgs.linuxManualConfig {
    inherit (pkgs.linux_6_1) version src;
    configfile = ./microvm-kernel-x86_64-6.1.config;
    allowImportFromDerivation = true;
  };
in {
  imports = ["${modulesPath}/profiles/minimal.nix"];

  boot.kernelPackages = pkgs.linuxPackagesFor firecrackerKernel;

  # No initrd: all drivers are compiled into the kernel, so the kernel
  # can mount the rootfs directly without a ramdisk stage.
  boot.initrd.enable = false;

  boot.kernelParams = [
    "console=ttyS0"
    "root=/dev/vda"
    "rw"
    "reboot=k"
    "panic=1"
    "pci=off"
    "nomodeset"
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
