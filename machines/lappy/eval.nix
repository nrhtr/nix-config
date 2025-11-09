let
  sources = import ../../npins;
  nixpkgs = sources.nixpkgs;
  home-manager = sources.home-manager;
in
  import "${nixpkgs}/nixos/lib/eval-config.nix" {
    modules = [
      ./configuration.nix
      "${home-manager}/nixos"
    ];
  }
