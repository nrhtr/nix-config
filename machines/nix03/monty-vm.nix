{
  config,
  pkgs,
  lib,
  ...
}: {
  microvm = {
    hypervisor = "firecracker";
    mem = 2048;
    vcpu = 1;

    # storeOnDisk = true is implicit when there are no virtiofs shares.
    # The microvm module builds a self-contained store disk image.

    # Persistent disks: /var (docker images, container state) + /home.
    volumes = [
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

    # Firecracker supports tap networking only — the host module creates
    # a tap interface; port forwarding handled via iptables DNAT below.
    interfaces = [
      {
        type = "tap";
        id = "monty";
        mac = "02:00:00:01:01:01";
      }
    ];
  };

  networking.hostName = "monty";

  # Static IP on the tap network (host is 10.0.0.1, guest is 10.0.0.2)
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.0.0.2";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "eth0";
  };
  networking.nameservers = ["1.1.1.1"];

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
