{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  # Note: setting fileSystems is generally not
  # necessary, since nixos-generate-config figures them out
  # automatically in hardware-configuration.nix.
  #fileSystems."/".device = "/dev/disk/by-label/nixos";

  # Enable the OpenSSH server.
  services.sshd.enable = true;

  services.openssh.ports = [622];
  security.sudo.wheelNeedsPassword = false;
  networking.firewall.logRefusedConnections = false;
  networking.firewall.allowPing = true;

  networking.firewall.allowedTCPPortRanges = [
    { from = 80;  to = 80;  } # HTTP
    { from = 443; to = 443; } # HTTPS
  ];

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "jenga.xyz" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/www/jenga.xyz";
    };

    "boycrisis.net" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/www/boycrisis.net";
    };

    "paulfl.art" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/www/paulfl.art";
    };
  };

  environment.systemPackages = with pkgs; [
      vim
      git
      htop
      mtr
      mosh
  ];

  users.users.jenga = {
    isNormalUser = true;
    home = "/home/jenga";
    description = "Jeremy Parker";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBroC7fhTdO17jn7U4FE97IFUYE4NfWxFcxax6bwVzsIXBRCQ9mYlNvmYokWTYX+rlSVi1ifpiwaveJHqcZX4hM=" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMGWqY84hz9k9OibHThS8QjqoSmuH2MtbRxR1UkSqrn jparker@sqiphone"];
  };
}
