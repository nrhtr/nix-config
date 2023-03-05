let
  pkgs =
    import (builtins.fetchTarball {
      name = "nixos-22.05";
      url = "https://github.com/nixos/nixpkgs/archive/ce6aa13369b667ac2542593170993504932eb836.tar.gz";
      sha256 = "sha256:0d643wp3l77hv2pmg2fi7vyxn4rwy0iyr8djcw1h5x72315ck9ik";
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

  #"nix02" = { config, pkgs, ... }: {
  #}
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
