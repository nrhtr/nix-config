let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {};
  morph = import "${sources.morph}/default.nix" {inherit pkgs;};
in
  pkgs.mkShell {
    preferLocalBuild = true;
    buildInputs = with pkgs; [
      (import ./default.nix).gitleaks
      morph
      npins
    ];
    shellHook = ''
      ${(import ./default.nix).pre-commit-check.shellHook}
      ${(import ./default.nix).gitleaks-cfg.shellHook}
    '';
  }
