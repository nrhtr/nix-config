{lib, ...}: let
  nodes = import ./wg-nodes.nix;
in {
  networking.extraHosts = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: node: "${node.ip}  ${name}") nodes
  );
}
