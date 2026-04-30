{lib, ...}: let
  nodes = import ./wg-nodes.nix;
in {
  networking.extraHosts = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: node: let
      allNames = [name] ++ (node.aliases or []);
    in "${node.ip}  ${lib.concatStringsSep "  " allNames}")
    nodes
  );
}
