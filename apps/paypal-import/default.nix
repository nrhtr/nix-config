let
  sources = import ../../npins;
  pkgs = import sources.nixpkgs {};
in
  pkgs.buildNpmPackage {
    pname = "paypal-import";
    version = "1.0.0";
    src = ./.;
    npmDepsHash = "sha256-781IvS2OsfdtPlYb2eYMg/arCs/lQqdXYafThmQwEX4=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out/bin $out/lib
      cp paypal-import.mjs $out/lib/
      cp -r node_modules $out/lib/
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/paypal-import \
        --add-flags "$out/lib/paypal-import.mjs"
    '';
    nativeBuildInputs = [pkgs.makeWrapper];
  }
