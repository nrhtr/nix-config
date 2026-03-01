let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {};
  agenix = pkgs.callPackage "${sources.agenix}/pkgs/agenix.nix" {};
in
  pkgs.mkShell {
    preferLocalBuild = true;
    buildInputs =
      pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
        (import ./default.nix).gitleaks
        (import "${sources.morph}/default.nix" {inherit pkgs;})
      ]
      ++ (with pkgs; [
        agenix
        npins
      ]);
    shellHook =
      if pkgs.stdenv.isDarwin
      then ""
      else ''
        ${(import ./default.nix).pre-commit-check.shellHook}
        ${(import ./default.nix).gitleaks-cfg.shellHook}
      '';
  }
