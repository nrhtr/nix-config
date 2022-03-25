{ config, pkgs, ... }: {
  services.networking.consul = {
    enable = false;
    webUi = true;
  };

  environment.systemPackages = with pkgs; [ nomad ];
}
