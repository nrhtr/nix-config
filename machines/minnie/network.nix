{
  lib,
  pkgs,
  ...
}: let
  mesh = import ../../common/wg-mesh.nix {inherit lib;};
  nodes = import ../../common/wg-nodes.nix;
  self = mesh.nodes.minnie;
  hostsFile = pkgs.writeText "wg-hosts" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: node: let
        allNames = [name] ++ (node.aliases or []);
      in "${node.ip}  ${lib.concatStringsSep "  " allNames}")
      nodes
    )
  );
in {
  networking.wg-quick.interfaces.wg0 = {
    address = ["${self.ip}/16"];
    privateKeyFile = "/etc/wireguard.privkey";
    peers = mesh.mkPeers "minnie";
  };

  # environment.etc creates a read-only symlink that macOS mDNSResponder
  # won't follow, breaking getaddrinfo (SSH etc). Write directly instead.
  system.activationScripts.wg-hosts.text = ''
    hostfile=/private/etc/hosts
    # Remove previous managed block, append updated entries
    awk '/^# wg-mesh-start$/{skip=1} /^# wg-mesh-end$/{skip=0;next} !skip{print}' \
      "$hostfile" > /tmp/wg-hosts.tmp && mv /tmp/wg-hosts.tmp "$hostfile"
    printf '\n# wg-mesh-start\n' >> "$hostfile"
    cat ${hostsFile} >> "$hostfile"
    printf '\n# wg-mesh-end\n' >> "$hostfile"
  '';
}
