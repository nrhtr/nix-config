let
  pkgs = import <nixpkgs> {};
  nodejs = pkgs.nodejs-16_x;
  alpine = pkgs.dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:f223d3b51b1eda2d5e693aac27fda364a0bdd3c6f2e1a433378ae41365da3f47";
    sha256 = "sha256-4R4Hk9Evh0mkN+CatoeXHoEheVWH1jpyzHpmGaNDp/Y=";
    finalImageTag = "3.15.5";
    finalImageName = "alpine";
  };
  actual-server = pkgs.callPackage ./package.nix {
    inherit pkgs nodejs;
  };
  start-actual = pkgs.writeShellScriptBin "actual-server" ''
    cd "${actual-server}/libexec/actual-sync/deps/actual-sync"
    ${nodejs}/bin/node app.js
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
        Env = ["ACTUAL_USER_FILES=/data/user"];
        Volumes = {
          "/data" = {};
        };
      };
    };
  }
