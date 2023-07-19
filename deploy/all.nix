let
  pkgs =
    import (builtins.fetchTarball {
      name = "nixos-23.05";
      url = "https://github.com/NixOS/nixpkgs/archive/53657afe29748b3e462f1f892287b7e254c26d77.tar.gz";
      sha256 = "sha256:1l9pwclmx7kw7kd5p3dxf67w3arh413pbasfgs1ckmjm9zdajsmv";
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
