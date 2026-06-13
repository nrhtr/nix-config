{
  config,
  pkgs,
  lib,
  ...
}: let
  vmName = "openbsd";
  diskPath = "/var/lib/microvms/${vmName}/disk.img";
  diskSizeG = 10;
  mem = 1024; # MB
  vcpu = 1;
  tapName = vmName; # "openbsd" tap interface
  hostIp = "10.0.1.1";
  guestIp = "10.0.1.2";
  mac = "02:00:00:02:02:01";
in {
  # Storage directory for the persistent disk image
  systemd.tmpfiles.rules = [
    "d /var/lib/qemu/${vmName} 0755 root root -"
    "d /run/vm-${vmName} 0700 root root -"
  ];

  # QEMU KVM service.
  #
  # First-time install: stop this service and run the installer manually:
  #   systemctl stop vm-openbsd
  #   qemu-system-x86_64 -enable-kvm -m ${toString mem} -smp ${toString vcpu} \
  #     -drive file=${diskPath},format=qcow2,if=virtio \
  #     -cdrom /path/to/install76.iso -boot d \
  #     -netdev tap,id=net0,ifname=${tapName},script=no,downscript=no \
  #     -device virtio-net-pci,netdev=net0,mac=${mac} \
  #     -nographic
  #
  # Connect to the serial console of a running VM:
  #   socat -,raw,echo=0 unix-connect:/run/vm-openbsd/console.sock
  # Ctrl-A x to exit socat. QEMU monitor:
  #   socat - unix-connect:/run/vm-openbsd/monitor.sock
  systemd.services."vm-${vmName}" = {
    description = "OpenBSD VM (QEMU/KVM)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];

    preStart = ''
      # Create persistent disk image on first run
      if [ ! -f ${diskPath} ]; then
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 ${diskPath} ${toString diskSizeG}G
      fi
      # Create tap interface (udev assigns host IP when it appears)
      ${pkgs.iproute2}/bin/ip tuntap add mode tap name ${tapName} 2>/dev/null || true
    '';

    postStop = ''
      ${pkgs.iproute2}/bin/ip tuntap del mode tap name ${tapName} 2>/dev/null || true
    '';

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      ExecStart = lib.strings.concatStringsSep " " [
        "${pkgs.qemu}/bin/qemu-system-x86_64"
        "-enable-kvm"
        "-M q35"
        "-name ${vmName}"
        "-m ${toString mem}"
        "-smp ${toString vcpu}"
        "-drive file=${diskPath},format=qcow2,if=virtio,cache=writeback"
        "-netdev tap,id=net0,ifname=${tapName},script=no,downscript=no"
        "-device virtio-net-pci,netdev=net0,mac=${mac}"
        "-nographic"
        "-serial unix:/run/vm-${vmName}/console.sock,server,nowait"
        "-monitor unix:/run/vm-${vmName}/monitor.sock,server,nowait"
      ];
    };
  };

  # Assign the host side of the tap when it appears (mirrors monty pattern)
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="${tapName}", RUN+="${pkgs.iproute2}/bin/ip addr add ${hostIp}/24 dev ${tapName}"
  '';

  # NAT masquerade for outbound VM traffic; port forward SSH in
  networking.nat.internalInterfaces = [tapName];
  networking.nat.forwardPorts = [
    {
      sourcePort = 2224;
      proto = "tcp";
      destination = "${guestIp}:22";
    }
  ];

  networking.firewall.allowedTCPPorts = [2224];
}
