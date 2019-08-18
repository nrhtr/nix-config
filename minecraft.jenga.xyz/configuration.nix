{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./custom-packages.nix
    ./borg.nix
    ../common/shared.nix
  ];

  boot.loader.grub.device = "/dev/vda";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  networking.hostName = "minecraft.jenga.xyz";

  networking.firewall.allowedTCPPortRanges = [
    { from = 25565;  to = 25565;  } # Minecraft
    { from = 80;  to = 80;  } # HTTP
    { from = 443; to = 443; } # HTTPS
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 25565;  to = 25565;  } # Minecraft
  ];

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "minecraft.jenga.xyz" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/www/minecraft-overviewer";
    };
  };

  services.minecraft-server = {
    enable = true;
    declarative = true;
    eula = true;
    openFirewall = false; # manage this ourselves
    whitelist = {
      jenga = "de7e40bc-9fa7-486f-9e7e-cbd337e2ef74";
      balfourine = "3a35d9cf-e22c-4137-bc17-12c89689d8a7";
      the_sikness = "5324eaec-1fc7-4fc7-8123-0f077e700cd5";
    };
    serverProperties = {
      difficulty = 4;
      gamemode = 0;
      max-players = 4;
      motd = "NixOS Minecraft server!";
      white-list = true;
    };
    jvmOpts = "-Xmx2560M -Xms1024M -Dfml.readTimeout=60";
  };
}
