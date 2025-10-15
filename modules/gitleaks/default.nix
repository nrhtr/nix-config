{settings ? {}}: let
  pkgs = import <nixpkgs> {};
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
