{
  config,
  lib,
  ...
}: let
  cfg = config.jenga.remoteBuilder;
  inherit (lib) mkEnableOption mkOption types mkIf;

  # SSH public keys for each machine's root Nix daemon.
  # Add a new entry here when a new client machine joins the fleet.
  fleetBuilderKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvB0TRd3YN3/aQUCC+lNivZ6pRe8iWfX0+SZdRfKDhO root@thinkpad" # lappy
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/7jyd975XBaZXTP7LzYGvecE3Hk6dJEWy9miWNzYH1 root@minnie" # minnie
  ];

  builderSubmodule = types.submodule {
    options = {
      hostName = mkOption {
        type = types.str;
        description = "SSH hostname for the builder (used in nix.buildMachines and SSH config).";
      };
      sshAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IP or FQDN to connect to. Generates a Host alias in ssh_config so hostName resolves correctly.";
      };
      sshKey = mkOption {
        type = types.str;
        description = "Path to the SSH private key the Nix daemon uses to connect.";
      };
      speedFactor = mkOption {
        type = types.int;
        default = 8;
      };
      system = mkOption {
        type = types.str;
        default = "x86_64-linux";
      };
    };
  };

  sshSnippetFor = b:
    lib.optionalString (b.sshAddress != null) ''
      Host ${b.hostName}
        Hostname ${b.sshAddress}
        Port 22
        StrictHostKeyChecking accept-new
    '';
in {
  options.jenga.remoteBuilder = {
    client = {
      enable = mkEnableOption "Nix remote builder (client)";
      builders = mkOption {
        type = types.listOf builderSubmodule;
        default = [];
        description = "Remote builders to offload Nix builds to.";
      };
    };

    server = {
      enable = mkEnableOption "Nix remote builder (server)";
      authorizedBuilderKeys = mkOption {
        type = types.listOf types.str;
        default = fleetBuilderKeys;
        description = "SSH public keys allowed to submit builds. Defaults to all known fleet client keys.";
      };
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.client.enable {
      nix.distributedBuilds = true;
      nix.extraOptions = "builders-use-substitutes = true\n";
      nix.buildMachines =
        map (b: {
          hostName = b.hostName;
          system = b.system;
          sshUser = "root";
          sshKey = b.sshKey;
          speedFactor = b.speedFactor;
          supportedFeatures = ["big-parallel"];
        })
        cfg.client.builders;
      programs.ssh.extraConfig = lib.concatMapStrings sshSnippetFor cfg.client.builders;
    })

    (mkIf cfg.server.enable {
      users.users.root.openssh.authorizedKeys.keys = cfg.server.authorizedBuilderKeys;
      nix.settings.trusted-users = ["root"];
    })
  ];
}
