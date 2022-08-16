let
  pkgs = import <nixpkgs> {};
  gitleaks = pkgs.callPackage ./packages/gitleaks/default.nix {};
  nix-pre-commit-hooks =
    import (builtins.fetchTarball
      "https://github.com/cachix/pre-commit-hooks.nix/tarball/master");
  nix-gitleaks = import ./modules/gitleaks/default.nix;
in rec {
  inherit gitleaks;
  gitleaks-cfg = nix-gitleaks {
    settings = {
      allowlist = {
        commits = [
          "ff03c996c654b2d8033af4795370903edd955a39"
          "b1f87eafb7a34cb8a5047d25dce8c1b75f2a6cdd"
        ];
      };
    };
  };
  pre-commit-check = nix-pre-commit-hooks.run {
    src = ./.;
    # If your hooks are intrusive, avoid running on each commit with a default_states like this:
    # default_stages = ["manual" "push"];
    hooks = {
      shellcheck.enable = true;
      #statix.enable = true;
      alejandra.enable = true;

      # Custom hooks
      gitleaks = {
        enable = true;
        entry = "${gitleaks}/bin/gitleaks protect --verbose --redact";
        pass_filenames = false;
      };
    };
  };
}
