let
  sources = import ../npins;
  eval = cfg:
    (import "${sources.nixpkgs}/nixos" {
      configuration = {
        imports = [cfg];
        nixpkgs.config.allowUnfree = true;
      };
      system = "x86_64-linux";
    })
    .config
    .system
    .build
    .toplevel;
in {
  nix01 = eval ../machines/nix01.jenga.xyz/configuration.nix;
  nix02 = eval ../machines/nix02.jenga.xyz/configuration.nix;
}
