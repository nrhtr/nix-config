{ pkgs, ... }:

{
  nixpkgs.config.packageOverrides = pkgs: rec {
    minecraft-overviewer = pkgs.python3Packages.callPackage ../../packages/minecraft-overviewer {};
  };

  environment.systemPackages = with pkgs; [
    minecraft-overviewer
  ];
}
