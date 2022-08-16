let
  pkgs =
    import (builtins.fetchTarball {
      name = "nixos-21.11-2022-04-05";
      url = "https://github.com/nixos/nixpkgs/archive/ccb90fb9e11459aeaf83cc28d5f8910816d90dd0.tar.gz";
      sha256 = "sha256:1jlyhw5nf7pcxg22k1bwkv13vm02p86d7jf6znihl3hczz1yfgi0";
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

    deployment.targetUser = "jenga";
    deployment.substituteOnDestination = true;
  };

  "nix02.jenga.xyz" = {
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
