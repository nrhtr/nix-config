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

  services.minecraft-server = {
    enable = true;
    declarative = true;
    eula = true;
    openFirewall = false; # manage this ourselves
    whitelist = {
      jenga = "de7e40bc-9fa7-486f-9e7e-cbd337e2ef74";
      balfourine = "3a35d9cf-e22c-4137-bc17-12c89689d8a7";
    };
    serverProperties = {
      difficulty = 1;
      gamemode = 0;
      max-players = 4;
      motd = "NixOS Minecraft server!";
      white-list = true;
    };
    jvmOpts = "-Xmx2560M -Xms1024M -Dfml.readTimeout=60";
  };
}
