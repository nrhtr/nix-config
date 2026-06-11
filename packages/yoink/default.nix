{pkgs}: let
  sources = import ../../npins;
in
  pkgs.rustPlatform.buildRustPackage {
    pname = "yoink";
    version = sources.yoink.revision;
    src = sources.yoink;
    cargoLock.lockFile = "${sources.yoink}/Cargo.lock";
  }
