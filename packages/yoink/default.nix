{pkgs}: let
  sources = import ../../npins;
  rust-overlay = import "${sources.rust-overlay}";
  pkgsWithRust = pkgs.extend rust-overlay;
  rustToolchain = pkgsWithRust.rust-bin.stable.latest.default;
in
  (pkgs.rustPlatform.overrideToolchain rustToolchain).buildRustPackage {
    pname = "yoink";
    version = sources.yoink.revision;
    src = sources.yoink;
    cargoLock.lockFile = "${sources.yoink}/Cargo.lock";
  }
