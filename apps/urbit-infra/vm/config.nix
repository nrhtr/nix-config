# Guest system configuration: packages and /etc entries.
# Edit this file to change what runs in the Urbit microVM.
{pkgs, ...}: let
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
  urbitRun = pkgs.writeScript "urbit-run" ''
    #!${pkgs.bash}/bin/bash
    set -e

    URBIT=${pkgs.urbit}/bin/urbit
    PIER=/pier
    KEY_DEV=/dev/vdc
    KEY_MNT=/mnt/keys

    if [ ! -d "$PIER/.urb" ] && [ -b "$KEY_DEV" ]; then
      mkdir -p "$KEY_MNT"
      mount -t ext2 -o ro "$KEY_DEV" "$KEY_MNT"
      KEYFILE=$(find "$KEY_MNT" -maxdepth 1 -name '*.jam' | head -1)
      if [ -z "$KEYFILE" ]; then
        echo "urbit-run: vdc present but no .jam keyfile found" >&2
        umount "$KEY_MNT"
        exit 1
      fi
      exec "$URBIT" -w "$PIER" -k "$KEYFILE"
    fi

    exec "$URBIT" "$PIER"
  '';
in {
  environment.systemPackages = with pkgs; [
    bash
    coreutils
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

    "resolv.conf".text = "nameserver 1.1.1.1\n";
    "passwd".text = "root:x:0:0:root:/root:/bin/sh\n";
    "group".text = "root:x:0:\n";
    "nsswitch.conf".text = ''
      hosts:    files dns
      networks: files dns
    '';
  };
}
