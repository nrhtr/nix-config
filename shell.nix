let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {};
  agenix = pkgs.callPackage "${sources.agenix}/pkgs/agenix.nix" {};
  gen-wg-conf = import ./common/gen-wg-conf.nix {inherit pkgs;};
in
  pkgs.mkShell {
    preferLocalBuild = true;
    buildInputs =
      pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
        (import "${sources.morph}/default.nix" {inherit pkgs;})
      ]
      ++ (with pkgs; [
        agenix
        npins
        prek
        gen-wg-conf
        (import ./default.nix).gitleaks
      ]);
    shellHook = ''
      ${(import ./default.nix).pre-commit-check.shellHook}
      ${(import ./default.nix).gitleaks-cfg.shellHook}
    '';
  }
