# System build machinery: stage1 initrd, stage2 init, toplevel, squashfs.
# Modelled on not-os/base.nix but stripped to Firecracker + Urbit essentials.
{
  pkgs,
  lib,
  config,
  ...
}: let
  # Stage 1: runs inside the initrd (busybox only).
  # Mounts squashfs rootfs from vda into a tmpfs new-root, mounts the
  # per-ship pier ext4 from vdb, then switch_roots to stage 2.
  stage1 = pkgs.writeScript "stage1-init" ''
    #!${pkgs.pkgsStatic.busybox}/bin/ash
    export PATH=${pkgs.pkgsStatic.busybox}/bin

    mkdir -p /proc /sys /dev /mnt

    mount -t devtmpfs devtmpfs /dev
    mount -t proc proc /proc
    mount -t sysfs sysfs /sys

    for o in $(cat /proc/cmdline); do
      case $o in
        systemConfig=*)
          sysconfig="''${o#systemConfig=}"
          ;;
      esac
    done

    # New root on tmpfs (writable layer; store lives on the squashfs below)
    mount -t tmpfs root /mnt -o size=256m
    mkdir -p /mnt/nix/store /mnt/pier

    # OS squashfs (vda) → /mnt/nix/store read-only
    mount -t squashfs /dev/vda /mnt/nix/store -o ro

    # Per-ship pier data (vdb) → /mnt/pier
    # nofail: gateway formats vdb before first boot; fail loudly if missing
    mount -t ext4 /dev/vdb /mnt/pier

    exec switch_root /mnt "''${sysconfig}/init"
  '';

  # Stage 2: PID 1 after switch_root.
  # @systemConfig@ is substituted with the toplevel store path at build time
  # (see system.build.toplevel below), so PATH is available immediately —
  # before /proc is mounted and before any shell builtins are needed.
  bootStage2 = pkgs.writeScript "stage2-init" ''
    #!${pkgs.runtimeShell}
    export PATH=@systemConfig@/sw/bin

    mkdir -p /proc /sys /dev /tmp /var/log /etc /root /run /nix/var/nix/gcroots
    mount -t proc proc /proc
    mount -t sysfs sys /sys
    mount -t devtmpfs devtmpfs /dev
    mkdir -p /dev/pts /dev/shm
    mount -t devpts devpts /dev/pts
    mount -t tmpfs tmpfs /run
    mount -t tmpfs tmpfs /dev/shm

    @systemConfig@/activate

    exec runit
  '';
in {
  options = {
    environment.systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
    };
    environment.pathsToLink = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/bin"];
    };
    system.path = lib.mkOption {internal = true;};
  };

  config = {
    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink;
      ignoreCollisions = true;
    };

    # Dummy activation scripts required by activation-script.nix
    system.activationScripts.users = "# no user management";
    system.activationScripts.groups = "# no group management";
    system.activationScripts.etc =
      lib.stringAfter ["users" "groups"]
      config.system.build.etcActivationCommands;

    system.build.bootStage2 = bootStage2;

    system.build.initialRamdisk = pkgs.makeInitrd {
      contents = [
        {
          object = stage1;
          symlink = "/init";
        }
      ];
    };

    # The toplevel is the active system store path.
    # stage2-init.sh's @systemConfig@ is replaced with $out here.
    system.build.toplevel =
      pkgs.runCommand "urbit-vm" {
        activationScript = config.system.activationScripts.script;
      } ''
        mkdir $out
        cp ${config.system.build.bootStage2} $out/init
        substituteInPlace $out/init --subst-var-by systemConfig $out
        ln -s ${config.system.path} $out/sw
        echo "$activationScript" > $out/activate
        substituteInPlace $out/activate --subst-var out
        chmod u+x $out/activate
        unset activationScript
      '';

    # Squashfs of the complete store closure — shared read-only across all ships.
    system.build.squashfs = pkgs.callPackage (pkgs.path + "/nixos/lib/make-squashfs.nix") {
      storeContents = [config.system.build.toplevel];
    };

    # Firecracker boot_args string, written to a file so the gateway can read it.
    system.build.bootArgs =
      pkgs.writeText "boot-args"
      "console=ttyS0 reboot=k panic=1 pci=off nomodeset systemConfig=${config.system.build.toplevel}";
  };
}
