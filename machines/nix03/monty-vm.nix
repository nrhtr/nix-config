{
  config,
  pkgs,
  lib,
  ...
}: {
  microvm = {
    # qemu: the only hypervisor supporting BOTH virtiofs store-sharing
    # AND user-mode networking with host<->guest port forwarding.
    hypervisor = "qemu";
    mem = 2048;
    vcpu = 1;

    # Share the host's /nix/store read-only via virtiofs.
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # Writable overlay so the guest store is mutable (nixos-rebuild etc.)
    writableStoreOverlay = "/nix/.rw-store";

    # Persistent disks: store overlay + /var (docker images, container state).
    # Images live under microvm.stateDir on the host (zroot/enc/monty).
    volumes = [
      {
        image = "store-overlay.img";
        mountPoint = config.microvm.writableStoreOverlay;
        size = 8192;
      }
      {
        image = "var.img";
        mountPoint = "/var";
        size = 20480;
      }
      {
        image = "home.img";
        mountPoint = "/home";
        size = 10240;
      }
    ];

    # User-mode (SLiRP) networking with port forwards to the host.
    interfaces = [
      {
        type = "user";
        id = "qemu";
        mac = "02:00:00:01:01:01";
      }
    ];

    # host:2223 -> guest:22 (SSH), host:8000 -> guest:8000 (app for Caddy)
    forwardPorts = [
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2223;
        guest.port = 22;
      }
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 8000;
        guest.port = 8000;
      }
    ];
  };

  networking.hostName = "monty";

  # Packages
  environment.systemPackages = with pkgs; [
    docker-compose
    git
    curl
    vim
  ];

  # Docker daemon
  virtualisation.docker.enable = true;

  # Users
  users.users.jenga = {
    isNormalUser = true;
    extraGroups = ["docker" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJBLHeD2QmiFu75rRXYKuhLLY1SpI3LCyUH5TO7iVHr jenga@Jeremys-Mini"
    ];
  };

  users.users.tom = {
    isNormalUser = true;
    extraGroups = ["docker" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDummyTomKeyPlaceholderReplaceMe tom@collaborator"
    ];
  };

  # passwordless sudo for wheel (no passwords set on this VM)
  security.sudo.wheelNeedsPassword = false;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;

  # Persist host keys on the /var volume so the VM's identity is stable
  # across reboots (the tmpfs root would otherwise regenerate them).
  services.openssh.hostKeys = [
    {
      path = "/var/lib/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/var/lib/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];
  systemd.tmpfiles.rules = ["d /var/lib/ssh 0755 root root -"];

  system.stateVersion = "25.11";
}
