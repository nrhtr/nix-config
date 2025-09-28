let
  pkgs =
    import (builtins.fetchTarball {
      name = "nixos-25.05";
      url = "https://github.com/NixOS/nixpkgs/archive/nixos-25.05.tar.gz";
      sha256 = "1zb1hzpzs0i2cx62jv4ck0s5gcfj27fxpvdsqzicj7k8049sdi8p";
    })
    {};
in {
  network = {
    inherit pkgs;
    description = "simple hosts";
    ordering = {
      tags = ["db" "web"];
    };
  };

  "nix01.wireguard" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix01.jenga.xyz/configuration.nix
    ];

    deployment.targetUser = "root";
    deployment.targetPort = 18061;

    deployment.substituteOnDestination = true;
  };

  "nix02" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix02.jenga.xyz/configuration.nix
    ];

    deployment.targetHost = "51.222.109.62";
    deployment.targetUser = "root";
    #deployment.targetPort = 18061;

    deployment.substituteOnDestination = true;
  };

  "nix02.wireguard" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix02.jenga.xyz/configuration.nix
    ];

    deployment.targetUser = "root";
    deployment.targetPort = 18061;

    deployment.substituteOnDestination = true;
  };
}
