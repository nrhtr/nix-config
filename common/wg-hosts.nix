{lib, ...}: let
  nodes = import ./wg-nodes.nix;
in {
  networking.hosts =
    lib.mapAttrs' (name: node: lib.nameValuePair node.ip [name]) nodes;
}
