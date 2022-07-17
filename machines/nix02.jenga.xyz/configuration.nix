# Full NixOS configuration for a ZFS server with full disk encryption hosted on Hetzner.
# See <https://mazzo.li/posts/hetzner-zfs.html> for more information.

{ config, pkgs, ... }:
let
  hostName = "nix02";

  rootKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvB0TRd3YN3/aQUCC+lNivZ6pRe8iWfX0+SZdRfKDhO root@thinkpad";
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@thinkpad";

  # From `ls -lh /dev/disk/by-id`
  sda = "nvme-SAMSUNG_MZVLB512HAJQ-00000_S3W8NA0N181217";
  sdb = "nvme-SAMSUNG_MZVLB512HAJQ-00000_S3W8NA0N181248";

  # See <https://major.io/2015/08/21/understanding-systemds-predictable-network-device-names/#picking-the-final-name>
  # for a description on how to find out the network card name reliably.
  networkInterface = "enp34s0";

  # Needed to load the right driver before boot for the initrd SSH session.
  networkInterfaceModule = "r8169";

  # From the Hetzner control panel
  ipv4 = {
    address = "95.217.114.169"; # the ip address
    gateway = "95.217.114.129"; # the gateway ip address
    netmask = "255.255.255.192"; # the netmask -- might not be the same for you!
    prefixLength = 26; # must match the netmask, see <https://www.pawprint.net/designresources/netmask-converter.php>
  };
  ipv6 = {
    address = "2a01:4f9:4a:3020::1"; # the ipv6 addres
    gateway = "fe80::1"; # the ipv6 gateway
    prefixLength = 64; # shown in the control panel
  };

  # See <https://nixos.wiki/wiki/NixOS_on_ZFS> for why we need the
  # hostId and how to generate it
  hostId = "7d3f6bd3";

  # Mail sender / recepient
  emailTo = "jeremy@jenga.xyz"; # where to send the notifications
  emailFrom = "root@${hostName}.jenga.xyz"; # who should be the sender in the emails

  msmtpAccount = {
    auth = "on";
    tls = "on";
    tls_starttls = "off";
    host = "smtp.fastmail.com";
    port = "465";
    user = "jeremy@jenga.xyz";
    passwordeval = "cat ${config.age.secrets.fastmail-nix02.path}";
    from = emailFrom;
  };

  # Sends an email with some heading and the zpool status
  sendEmailEvent = { event }: ''
    printf "Subject: ${hostName} ${event} ''$(${pkgs.coreutils}/bin/date --iso-8601=seconds)\n\nzpool status:\n\n''$(${pkgs.zfs}/bin/zpool status)" | ${pkgs.msmtp}/bin/msmtp -a default ${emailTo}
  '';

  # Enables emails for ZFS
  customizeZfs = zfs:
    (zfs.override { enableMail = true; });
in {
  imports = [
    ./hardware-configuration.nix
    ../../common/shared.nix
  ];

  age.secrets = {
    fastmail-nix02.file = ../../secrets/fastmail-nix02.age;
    twilio-env.file     = ../../secrets/twilio-env.age;
  };

  # We want to still be able to boot without one of these
  fileSystems."/boot-1".options = [ "nofail" ];
  fileSystems."/boot-2".options = [ "nofail" ];

  # Use GRUB2 as the boot loader.
  # We don't use systemd-boot because Hetzner uses BIOS legacy boot.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };

  # This will mirror all UEFI files, kernels, grub menus and
  # things needed to boot to the other drive.
  boot.loader.grub.mirroredBoots = [
    { path = "/boot-1"; devices = [ "/dev/disk/by-id/${sda}" ]; }
    { path = "/boot-2"; devices = [ "/dev/disk/by-id/${sdb}" ]; }
  ];

  # We need email support in ZFS for ZED. If you're using ZFS unstable, you need
  # to patch `zfsUnstable` too.
  nixpkgs.overlays = [
    (self: super: {
      zfsStable = customizeZfs super.zfsStable;
    })
  ];

  networking.hostName = hostName;

  # ZFS options from <https://nixos.wiki/wiki/NixOS_on_ZFS>
  networking.hostId = hostId;
  boot.loader.grub.copyKernels = true;
  boot.supportedFilesystems = [ "zfs" ];

  # Network configuration (Hetzner uses static IP assignments, and we don't use DHCP here)
  networking.useDHCP = false;
  networking.interfaces."${networkInterface}" = {
    ipv4.addresses = [{ inherit (ipv4) address prefixLength; }];
    ipv6.addresses = [{ inherit (ipv4) address prefixLength; }];
  };
  networking.defaultGateway = ipv4.gateway;
  networking.defaultGateway6 = { address = ipv6.gateway; interface = networkInterface; };
  networking.nameservers = [ "8.8.8.8" ];

  # Remote unlocking, see <https://nixos.wiki/wiki/NixOS_on_ZFS>,
  # section "Unlock encrypted zfs via ssh on boot"
  boot.initrd.availableKernelModules = [ networkInterfaceModule ];
  boot.kernelParams = [
    # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
    # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
    # The server ip refers to the NFS server -- we don't need it.
    "ip=${ipv4.address}::${ipv4.gateway}:${ipv4.netmask}:${hostName}-initrd:${networkInterface}:off:8.8.8.8"
  ];
  boot.initrd.network = {
    enable = true;
    ssh = {
       enable = true;

       # To prevent ssh clients from freaking out because a different host key is used,
       # a different port for ssh is useful (assuming the same host has also a regular sshd running)
       port = 2222;

       # hostKeys paths must be unquoted strings, otherwise you'll run into issues
       # with boot.initrd.secrets the keys are copied to initrd from the path specified;
       # multiple keys can be set you can generate any number of host keys using
       # `ssh-keygen -t ed25519 -N "" -f /boot-1/initrd-ssh-key`
       hostKeys = [
         /boot-1/initrd-ssh-key
         /boot-2/initrd-ssh-key
       ];

       authorizedKeys = [
         publicKey
       ];
    };

    # this will automatically load the zfs password prompt on login
    # and kill the other prompt so boot can continue
    postCommands = ''
      cat <<EOF > /root/.profile
      if pgrep -x "zfs" > /dev/null
      then
        zfs load-key -a
        killall zfs
      else
        echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
      fi
      EOF
    '';
  };

  # SSH
  users.users.root.openssh.authorizedKeys.keys = [ publicKey rootKey ];
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

  # mstp setup
  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      aliases = builtins.toFile "aliases" ''
        default: ${emailTo}
      '';
    };
    accounts.default = msmtpAccount;
  };

  # ZED setup (ZFS notifications)
  # Check out <https://github.com/openzfs/zfs/blob/master/cmd/zed/zed.d/zed.rc> for
  # options.
  services.zfs.zed.enableMail = true;
  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [ emailTo ];
    ZED_EMAIL_OPTS = "-a 'FROM:${emailFrom}' -s '@SUBJECT@' @ADDRESS@";
    ZED_NOTIFY_VERBOSE = true;
  };

  # smartd email notifications -- probably redundant given ZED, but
  # you never know.
  services.smartd.enable = true;
  services.smartd.notifications.mail.enable = true;
  services.smartd.notifications.mail.sender = emailFrom;
  services.smartd.notifications.mail.recipient = emailTo;

  # Email alerts on startup, shutdown, and Mondays :).
  #
  # For startup / shutdown messages we have two services that
  # stay alive from boot since shutdown. The boot alert sends
  # a message at the beginning, the shutdown message sends a message
  # at the end (through ExecStop, which in nix is `preStop`).
  #
  # This seems to be the most reliable way of sending messages before
  # shutdown in systemd: the main advantage is that since we specify
  # `after = [ "network.target" ]`, we know that it will be stopped
  # before the network gets stopped, since services are stopped
  # in reverse order. See <https://serverfault.com/a/785355>.
  #
  # Moreover, the RemainAfterExit is needed so that we do not
  # restart the service every time we change the configuration
  # (unless the service has changed).
  systemd.services."boot-mail-alert" = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = sendEmailEvent { event = "just booted"; };
  };
  systemd.services."shutdown-mail-alert" = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = "true";
    preStop = sendEmailEvent { event = "is shutting down"; };
  };
  systemd.services."weekly-mail-alert" = {
    serviceConfig.Type = "oneshot";
    script = sendEmailEvent { event = "is still alive"; };
  };
  systemd.timers."weekly-mail-alert" = {
    wantedBy = [ "timers.target" ];
    partOf = [ "weekly-mail-alert.service" ];
    timerConfig.OnCalendar = "weekly";
  };

  systemd.services."wakeup" = {
    description = "Morning wake up call";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "${config.age.secrets.twilio-env.path}";
      ExecStart = "${pkgs.writers.writePython3 "call.py" { libraries = [ pkgs.python39Packages.twilio ]; } ./call.py}";
      Restart = "on-failure";
    };
    startAt = "*-*-* 06:35:00 Australia/Melbourne";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
