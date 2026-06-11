{pkgs}: let
  sources = import ../../npins;
  fenix = import "${sources.fenix}" {};
  toolchain = fenix.minimal.toolchain;
  customRustPlatform = pkgs.makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
in
  customRustPlatform.buildRustPackage {
    pname = "yoink";
    version = sources.yoink.revision;
    src = sources.yoink;
    cargoLock.lockFile = "${sources.yoink}/Cargo.lock";
    doCheck = false;
  }
