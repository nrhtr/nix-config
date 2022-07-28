{
  pkgs,
  lib,
  ...
}: let
  nix-colors = import <nix-colors> {};
in {
  imports = [nix-colors.homeManagerModule];
  config = {
    colorscheme = nix-colors.colorSchemes.dracula;
    #colorscheme = nix-colors.colorSchemes.solarized-dark;
    #colorscheme = nix-colors.colorSchemes.gruvbox-light-hard;
    #colorscheme = nix-colors.colorSchemes.gruvbox-dark-medium;
    #colorscheme = nix-colors.colorSchemes.solarized-light;
    #colorscheme = nix-colors.colorSchemes.tender;
  };
}
