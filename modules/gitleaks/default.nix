{
  settings ? {},
  pkgs ? import (import ../../npins).nixpkgs {},
}: let
  project = pkgs.lib.evalModules {
    modules = [
      ./module.nix
      {
        config = {
          _module.args.pkgs = pkgs;
          inherit settings;
        };
      }
    ];
  };
  inherit (project.config) installationScript;
in {
  shellHook = installationScript;
}
