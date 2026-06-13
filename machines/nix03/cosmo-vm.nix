{
  config,
  pkgs,
  lib,
  ...
}: let
  vmName = "cosmo";
  diskPath = "/var/lib/microvms/${vmName}/disk.img";
  diskSizeG = 10;
  mem = 1024;
  vcpu = 2;
  tapName = vmName;
  hostIp = "10.0.2.1";
  guestIp = "10.0.2.2";
  mac = "02:00:00:02:03:01";
  sshPort = 2225;

  authKeys = import ../../common/ssh-keys.nix;

  # Alpine 3.23.4 cloud image (BIOS, cloudinit variant).
  # On first boot cloud-init provisions the jenga user and SSH keys automatically.
  # The runtime disk is a thin QCOW2 overlay backed by this read-only store path.
  alpineBase = pkgs.fetchurl {
    url = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/generic_alpine-3.23.4-x86_64-bios-cloudinit-r0.qcow2";
    sha256 = "1s197awnzinqn8k0nfs4cjawfx0qd3m4f88fwrs6g4aj9li02fhz";
  };

  # NoCloud seed ISO — cloud-init reads this from vdb on first boot.
  # SSH keys come from common/ssh-keys.nix; updating them here won't affect
  # an already-provisioned VM (cloud-init only runs once).
  userData = pkgs.writeText "${vmName}-user-data" (''
      #cloud-config
      ssh_pwauth: false
      users:
        - name: jenga
          groups: [wheel]
          sudo: ALL=(ALL) NOPASSWD:ALL
          shell: /bin/ash
          lock_passwd: true
          ssh_authorized_keys:
    ''
    + lib.concatMapStrings (key: "      - ${key}\n") authKeys);

  metaData = pkgs.writeText "${vmName}-meta-data" ''
    instance-id: ${vmName}
    local-hostname: ${vmName}
  '';

  networkConfig = pkgs.writeText "${vmName}-network-config" ''
    version: 2
    ethernets:
      eth0:
        addresses:
          - ${guestIp}/30
        gateway4: ${hostIp}
        nameservers:
          addresses:
            - 1.1.1.1
  '';

  cloudInitSeed = pkgs.runCommand "${vmName}-cloud-init-seed.iso" {
    buildInputs = [pkgs.cloud-utils];
  } "cloud-localds --network-config=${networkConfig} $out ${userData} ${metaData}";
in {
  systemd.tmpfiles.rules = [
    "d /var/lib/microvms/${vmName} 0755 root root -"
    "d /run/vm-${vmName} 0700 root root -"
  ];

  # Alpine Linux VM via QEMU/KVM.
  #
  # Connect to serial console:
  #   socat -,raw,echo=0 unix-connect:/run/vm-${vmName}/console.sock   (Ctrl-A x to exit)
  # QEMU monitor:
  #   socat - unix-connect:/run/vm-${vmName}/monitor.sock
  systemd.services."vm-${vmName}" = {
    description = "Alpine Linux VM (${vmName}, QEMU/KVM)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];

    preStart = ''
      if [ ! -f ${diskPath} ]; then
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 \
          -b ${alpineBase} -F qcow2 ${diskPath}
        ${pkgs.qemu}/bin/qemu-img resize ${diskPath} ${toString diskSizeG}G
      fi
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
        # vda: persistent overlay (writes) backed by Alpine base image (read-only)
        "-drive file=${diskPath},format=qcow2,if=virtio,cache=writeback"
        # vdb: NoCloud seed ISO — cloud-init reads this on first boot, ignored after
        "-drive file=${cloudInitSeed},format=raw,if=virtio,read-only=on"
        "-netdev tap,id=net0,ifname=${tapName},script=no,downscript=no"
        "-device virtio-net-pci,netdev=net0,mac=${mac}"
        "-nographic"
        "-serial unix:/run/vm-${vmName}/console.sock,server,nowait"
        "-monitor unix:/run/vm-${vmName}/monitor.sock,server,nowait"
      ];
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="${tapName}", RUN+="${pkgs.iproute2}/bin/ip addr add ${hostIp}/30 dev ${tapName}"
  '';

  networking.nat.internalInterfaces = [tapName];
  networking.nat.forwardPorts = [
    {
      sourcePort = sshPort;
      proto = "tcp";
      destination = "${guestIp}:22";
    }
  ];

  networking.firewall.allowedTCPPorts = [sshPort];
}
