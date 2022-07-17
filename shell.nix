let pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  buildInputs = [
    (import ./default.nix).gitleaks
  ];
  shellHook = ''
     ${(import ./default.nix).pre-commit-check.shellHook}
     ${(import ./default.nix).gitleaks-cfg.shellHook}
  '';
 }
