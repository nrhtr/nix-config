{
  config,
  lib,
  ...
}: let
  cfg = config.jenga.zfsUnlock;
  inherit (lib) mkEnableOption mkOption types mkIf;
in {
  options.jenga.zfsUnlock = {
    enable = mkEnableOption "initrd SSH ZFS unlock";

    networkInterface = mkOption {
      type = types.str;
      description = "Network interface name (e.g. enp5s0f0, eno1).";
    };

    networkInterfaceModule = mkOption {
      type = types.str;
      description = "Kernel module needed to drive the NIC in initrd (e.g. ixgbe, e1000e).";
    };

    ipv4 = {
      address = mkOption {type = types.str;};
      gateway = mkOption {type = types.str;};
      netmask = mkOption {
        type = types.str;
        default = "255.255.255.0";
      };
    };

    hostName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Hostname used in the initrd ip= kernel param. Defaults to networking.hostName.";
    };

    authorizedKeys = mkOption {
      type = types.listOf types.str;
      description = "SSH public keys allowed to connect to the initrd SSH server.";
    };

    hostKeys = mkOption {
      type = types.listOf types.path;
      default = [/boot-1/initrd-ssh-key /boot-2/initrd-ssh-key];
      description = "Paths to the initrd SSH host keys (generated with ssh-keygen -t ed25519 -N \"\").";
    };

    port = mkOption {
      type = types.port;
      default = 2222;
      description = "Port the initrd SSH server listens on.";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.availableKernelModules = [cfg.networkInterfaceModule];

    # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>
    # https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
    boot.kernelParams = [
      "ip=${cfg.ipv4.address}::${cfg.ipv4.gateway}:${cfg.ipv4.netmask}:${cfg.hostName}-initrd:${cfg.networkInterface}:off:8.8.8.8"
    ];

    boot.initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        port = cfg.port;
        hostKeys = cfg.hostKeys;
        authorizedKeys = cfg.authorizedKeys;
      };
      # Auto-prompt for ZFS passphrase on login; kills the prompt once done so boot continues.
      postCommands = ''
        cat <<EOF > /root/.profile
        if pgrep -x "zfs" > /dev/null
        then
          until zfs load-key -a; do
            echo "Incorrect passphrase, try again."
          done
          killall zfs
        else
          echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
        fi
        EOF
      '';
    };
  };
}
