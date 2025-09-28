let
  pkgs = import <nixpkgs> {};
in
  pkgs.mkShell {
    preferLocalBuild = true;
    buildInputs = with pkgs; [
      (import ./default.nix).gitleaks
      morph
    ];
    shellHook = ''
      ${(import ./default.nix).pre-commit-check.shellHook}
      ${(import ./default.nix).gitleaks-cfg.shellHook}
    '';
  }
