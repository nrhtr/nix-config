{
  config,
  pkgs,
  lib,
  ...
}: let
  hostName = "nix03";

  authKeys = import ../../common/ssh-keys.nix;

  networkInterface = "eno1";

  ipv4 = {
    address = "51.161.197.172";
    gateway = "51.161.197.254";
    prefixLength = 24;
  };

  hostId = "1145a50a";

  sources = import ../../npins;
in {
  imports = [
    ./disko.nix
    ./wireguard.nix
    "${sources.disko}/module.nix"

    ../../common/shared.nix
    ../../common/wg-hosts.nix
    ../../modules/zfs-unlock.nix
    ../../modules/disk-health.nix
    ../../modules/boot-alerts.nix
    ../../modules/urbit-gateway.nix
  ];

  networking.hostName = hostName;
  networking.hostId = hostId;

  networking.useDHCP = false;
  networking.interfaces."${networkInterface}" = {
    ipv4.addresses = [{inherit (ipv4) address prefixLength;}];
  };
  networking.defaultGateway = ipv4.gateway;
  networking.nameservers = ["1.1.1.1" "1.0.0.1"];

  boot.supportedFilesystems = ["zfs"];
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    copyKernels = true;
  };
  boot.loader.grub.mirroredBoots = [
    {
      path = "/boot-1";
      efiSysMountPoint = "/boot-1";
      devices = ["nodev"];
    }
    {
      path = "/boot-2";
      efiSysMountPoint = "/boot-2";
      devices = ["nodev"];
    }
  ];

  fileSystems."/boot-1".options = ["nofail"];
  fileSystems."/boot-2".options = ["nofail"];

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

  jenga.zfsUnlock = {
    enable = true;
    networkInterface = "eno1";
    networkInterfaceModule = "ixgbe";
    ipv4 = {inherit (ipv4) address gateway;};
    authorizedKeys = authKeys;
  };

  users.users.root.openssh.authorizedKeys.keys = authKeys;

  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  age.secrets.fastmail-nix02.file = ../../secrets/fastmail-nix02.age;
  age.secrets.resend-key.file = ../../secrets/resend-key.age;

  jenga.diskHealth = {
    enable = true;
    smtpPasswordFile = config.age.secrets.fastmail-nix02.path;
  };

  jenga.bootAlerts.enable = true;

  jenga.urbitGateway = {
    enable = true;
    resendApiKeyFile = config.age.secrets.resend-key.path;
  };

  time.timeZone = "UTC";

  system.stateVersion = "25.11";
}
