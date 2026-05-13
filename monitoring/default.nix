# Builds a Docker image for Fly.io deployment.
# Includes Gatus (synthetic monitoring) + WireGuard (mesh access).
#
# Build:   nix-build monitoring/default.nix
# Push:    fly auth docker && docker load < result && docker push registry.fly.io/jenga-monitor:latest
# Deploy:  fly deploy --image registry.fly.io/jenga-monitor:latest --app jenga-monitor
#
# Required Fly secrets:
#   WG_PRIVATE_KEY      — WireGuard private key for the fly-monitor peer
#   GATUS_SMTP_PASS     — Fastmail app password for alert emails
#   GATUS_BORG_TOKEN    — Bearer token for borg backup heartbeat endpoints
{system ? "x86_64-linux"}: let
  sources = import ../npins;
  # nixpkgs-unstable for up-to-date Gatus and WireGuard tools
  pkgs = import sources.nixpkgs-unstable {
    inherit system;
    config = {};
  };
  # Stable nixpkgs for Docker image tooling — buildLayeredImage's host-side
  # Python validation script (pythoncheck.sh) is broken on darwin in unstable
  pkgs-stable = import sources.nixpkgs {
    inherit system;
    config = {};
  };
  lib = pkgs.lib;

  nodes = import ../common/wg-nodes.nix;
  flyNode = nodes.fly-monitor;
  servers = lib.filterAttrs (_: n: n ? endpoint) nodes;

  gatusConfig = import ./config.nix {inherit pkgs;};

  # WireGuard config with peers baked in; private key injected at startup
  wgTemplate = pkgs.writeText "wg0.conf.template" ''
    [Interface]
    Address = ${flyNode.ip}/16
    PrivateKey = WG_PRIVATE_KEY_PLACEHOLDER

    ${lib.concatStrings (lib.mapAttrsToList (name: peer: ''
        [Peer]
        # ${name}
        PublicKey = ${peer.publicKey}
        AllowedIPs = ${peer.routedCIDR or "${peer.ip}/32"}
        Endpoint = ${peer.endpoint}
        PersistentKeepalive = 25
      '')
      servers)}
  '';

  # /etc/hosts additions so internal hostnames resolve via WireGuard IPs
  internalHosts = pkgs.writeText "internal-hosts" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        _: node:
          lib.optionalString (node ? aliases)
          "${node.ip} ${lib.concatStringsSep " " node.aliases}"
      )
      nodes
    )
  );

  startScript = pkgs.writeShellApplication {
    name = "start-monitor";
    runtimeInputs = with pkgs; [
      gatus
      wireguard-tools
      iproute2
      iptables
      gnused
      coreutils
    ];
    text = ''
      # Inject private key into WireGuard config
      if [ -n "''${WG_PRIVATE_KEY:-}" ]; then
        mkdir -p /etc/wireguard
        sed "s|WG_PRIVATE_KEY_PLACEHOLDER|''${WG_PRIVATE_KEY}|" \
          ${wgTemplate} > /etc/wireguard/wg0.conf
        chmod 600 /etc/wireguard/wg0.conf

        # Resolve internal hostnames via WireGuard IPs
        cat ${internalHosts} >> /etc/hosts

        wg-quick up wg0
      fi

      cp ${gatusConfig} /etc/gatus-config.yaml
      if [ -n "''${FLY_REGION:-}" ]; then
        sed -i "s|REGION_PLACEHOLDER|''${FLY_REGION}|" /etc/gatus-config.yaml
      fi

      GATUS_CONFIG_PATH=/etc/gatus-config.yaml exec gatus
    '';
  };
in
  pkgs-stable.dockerTools.buildLayeredImage {
    name = "jenga-monitor";
    tag = "latest";
    contents = [startScript];
    extraCommands = ''
      mkdir -p etc tmp data
      printf 'root:x:0:0:root:/root:/bin/sh\nnobody:x:65534:65534:nobody:/var/empty:/bin/sh\n' \
        > etc/passwd
      printf 'root:x:0:\nnobody:x:65534:\n' \
        > etc/group
      printf 'hosts: files dns\n' \
        > etc/nsswitch.conf
    '';
    config = {
      Cmd = ["${startScript}/bin/start-monitor"];
      Env = ["SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"];
    };
  }
