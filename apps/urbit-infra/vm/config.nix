# Guest system configuration: packages and /etc entries.
# Edit this file to change what runs in the Urbit microVM.
{
  pkgs,
  urbit,
  ...
}: let
  # runit stage 1: nothing to do — networking is configured by the kernel via
  # the ip= cmdline parameter (CONFIG_IP_PNP) before userspace starts.
  runit1 = pkgs.writeScript "runit-1" ''
    #!${pkgs.bash}/bin/bash
    touch /etc/runit/stopit
    chmod 0 /etc/runit/stopit
  '';

  # runit stage 2: start service supervision.
  runit2 = pkgs.writeScript "runit-2" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.runit}/bin/runsvdir -P /etc/service
  '';

  # runit stage 3: shutdown hook (Firecracker kills the VM, so this is minimal).
  runit3 = pkgs.writeScript "runit-3" ''
    #!${pkgs.bash}/bin/bash
    echo "stage 3: shutting down"
  '';

  # Urbit runit service: restarted automatically on crash.
  # pkgs.urbit is the Vere runtime; override if nixpkgs lags behind.
  #
  # First-boot key loading: gateway attaches a small ext2 disk as vdc containing
  # a single .jam keyfile.  Once urbit initialises the pier (.urb/ appears), the
  # gateway no longer needs to attach vdc — subsequent boots skip this block.
  # Called by runit after urbit exits.  If urbitRestart=no is on the kernel
  # cmdline the VM shuts down instead of looping — useful for debugging crashes.
  # A 2-second delay before restart keeps crash output readable in all cases.
  urbitFinish = pkgs.writeScript "urbit-finish" ''
    #!${pkgs.bash}/bin/bash
    RESTART=yes
    for o in $(cat /proc/cmdline); do
      case $o in
        urbitRestart=*) RESTART="''${o#urbitRestart=}" ;;
      esac
    done

    if [ "$RESTART" = "no" ]; then
      echo "urbit: exited with restart disabled, shutting down" >&2
      echo 1 > /proc/sys/kernel/sysrq
      echo b > /proc/sysrq-trigger
      exit 111
    fi

    sleep 2
  '';

  urbitRun = pkgs.writeScript "urbit-run" ''
    #!${pkgs.bash}/bin/bash
    set -e

    PIER=/pier
    KEY_DEV=/dev/vdc
    KEY_MNT=/mnt/keys

    # Prefer the pier's auto-updated vere binary if present.
    # Layout: /pier/.bin/pace (track name) → /pier/.bin/<pace>/vere-*
    # Falls back to the rootfs vere for first boot or fresh piers.
    VERE=${urbit}/bin/urbit
    if [ -f "$PIER/.bin/pace" ]; then
      PACE=$(cat "$PIER/.bin/pace")
      PIER_VERE=$(ls "$PIER/.bin/$PACE/vere-"* 2>/dev/null | head -1)
      if [ -x "$PIER_VERE" ]; then
        VERE="$PIER_VERE"
      fi
    fi

    if [ ! -d "$PIER/.urb" ] && [ -b "$KEY_DEV" ]; then
      mkdir -p "$KEY_MNT"
      mount -t ext2 -o ro "$KEY_DEV" "$KEY_MNT"
      KEYFILE=$(find "$KEY_MNT" -maxdepth 1 -name '*.jam' | head -1)
      if [ -z "$KEYFILE" ]; then
        echo "urbit-run: vdc present but no .jam keyfile found" >&2
        umount "$KEY_MNT"
        exit 1
      fi
      exec "$VERE" -w "$PIER" -k "$KEYFILE" -d
    fi

    "$VERE" -d "$PIER"
    echo "urbit-run: vere exited with code $?" >&2
  '';
in {
  environment.systemPackages = with pkgs; [
    bash
    coreutils
    util-linux
    runit
    urbit
  ];

  environment.pathsToLink = ["/bin"];

  environment.etc = {
    "runit/1" = {
      source = runit1;
      mode = "0755";
    };
    "runit/2" = {
      source = runit2;
      mode = "0755";
    };
    "runit/3" = {
      source = runit3;
      mode = "0755";
    };
    "service/urbit/run" = {
      source = urbitRun;
      mode = "0755";
    };
    "service/urbit/finish" = {
      source = urbitFinish;
      mode = "0755";
    };

    "resolv.conf".text = "nameserver 1.1.1.1\n";
    "passwd".text = "root:x:0:0:root:/root:/bin/sh\n";
    "group".text = "root:x:0:\n";
    "nsswitch.conf".text = ''
      hosts:    files dns
      networks: files dns
    '';
  };
}
