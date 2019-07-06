{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/shared.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  networking.hostName = "minecraft.jenga.xyz";

  # Note: setting fileSystems is generally not
  # necessary, since nixos-generate-config figures them out
  # automatically in hardware-configuration.nix.
  #fileSystems."/".device = "/dev/disk/by-label/nixos";

  # Enable the OpenSSH server.
  services.sshd.enable = true;
  services.openssh.permitRootLogin = "no";

  services.openssh.ports = [18061];
  security.sudo.wheelNeedsPassword = false;
  networking.firewall.logRefusedConnections = false;
  networking.firewall.allowPing = true;

  networking.firewall.allowedTCPPortRanges = [
    { from = 25565;  to = 25565;  } # Minecraft
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 25565;  to = 25565;  } # Minecraft
  ];

  config.services.minecraft-server.enable = true;
  config.services.minecraft-server = {
    declarative = true;
    eula = true;
    openFirewall = false; # manage this ourselves
    whitelist = {
      jenga = "de7e40bc-9fa7-486f-9e7e-cbd337e2ef74";
    };
    serverProperties = {
      server-port = 43000;
      difficulty = 3;
      gamemode = 1;
      max-players = 4;
      motd = "NixOS Minecraft server!";
      white-list = true;
    };
    vmOpts = "-Xmx1024M -Xms1536M";
  };
}
