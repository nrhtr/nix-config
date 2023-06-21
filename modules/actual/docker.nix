{pkgs ? import <nixpkgs> {}}: let
  alpine = pkgs.dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:f223d3b51b1eda2d5e693aac27fda364a0bdd3c6f2e1a433378ae41365da3f47";
    sha256 = "sha256-4R4Hk9Evh0mkN+CatoeXHoEheVWH1jpyzHpmGaNDp/Y=";
    finalImageTag = "3.15.5";
    finalImageName = "alpine";
  };
  actual-server = import ./package.nix;
  start-actual = pkgs.writeShellScriptBin "actual-server" ''
    cd "${actual-server.app}/libexec/actual-sync/deps/actual-sync"
    ${actual-server.nodejs}/bin/node app.js
  '';
  name = "actual-server";
  tag = "latest";
in
  with pkgs; {
    name = "${name}:${tag}";
    image = dockerTools.buildLayeredImage {
      inherit name tag;
      fromImage = alpine;
      config = {
        Cmd = ["${start-actual}/bin/actual-server"];
        ExposedPorts."5006" = {};
      };
    };
  }
