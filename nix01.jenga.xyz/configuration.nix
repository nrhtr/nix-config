{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./wireguard.nix
    ../common/users.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  # Note: setting fileSystems is generally not
  # necessary, since nixos-generate-config figures them out
  # automatically in hardware-configuration.nix.
  #fileSystems."/".device = "/dev/disk/by-label/nixos";

  system.autoUpgrade.enable = true;
  system.autoUpgrade.channel = "https://nixos.org/channels/nixos-18.09-small";

  # Enable the OpenSSH server.
  services.sshd.enable = true;
  services.openssh.permitRootLogin = "no";

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
      serverAliases = ["www.jenga.xyz"];
      forceSSL = true;
      enableACME = true;
      root = "/var/www/jenga.xyz";

      locations."/nixos-vultr.sh" =
        let file = "${./nixos-vultr.sh}";
        in
        { alias = file;
        };
    };

    "boycrisis.net" = {
      serverAliases = ["www.boycrisis.net"];
      forceSSL = true;
      enableACME = true;
      root = "/var/www/boycrisis.net";
    };

    "paulfl.art" = {
      serverAliases = ["www.paulfl.art"];
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
}