{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.jenga.urbitGateway;
  inherit (lib) mkEnableOption mkOption types mkIf;

  sources = import ../npins;
  sourcesJson = builtins.fromJSON (builtins.readFile ../npins/sources.json);

  vmArtifacts = import ../apps/urbit-infra/vm;

  gatewayPkg = pkgs.buildGoModule {
    pname = "urbit-gateway";
    version = "unstable-${builtins.substring 0 8 sourcesJson.pins."urbit-sh".revision}";
    src = sources."urbit-sh";
    subPackages = ["cmd/gateway" "cmd/fcboot"];
    vendorHash = "sha256-0H643eZCu8G/rP1694MKkwm3d/UVnxQ4aV1SKHpr3xs=";
  };
in {
  options.jenga.urbitGateway = {
    enable = mkEnableOption "urbit.sh gateway";

    port = mkOption {
      type = types.port;
      default = 7070;
    };

    urbitsDir = mkOption {
      type = types.str;
      default = "/var/lib/urbit";
      description = "Directory containing urbit piers.";
    };

    resendApiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the Resend API key.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.urbit-gateway = {
      description = "urbit.sh gateway";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "wireguard-wg0.service"];

      path = [pkgs.e2fsprogs pkgs.firecracker pkgs.iptables];

      serviceConfig = {
        ExecStart = pkgs.writeShellScript "urbit-gateway" ''
          ${lib.optionalString (cfg.resendApiKeyFile != null) ''
            export RESEND_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/resend-key")"
          ''}
          exec ${gatewayPkg}/bin/gateway
        '';
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "urbit-gateway urbit-vms";
        WorkingDirectory = "%S/urbit-gateway";
        LoadCredential =
          lib.mkIf (cfg.resendApiKeyFile != null)
          "resend-key:${cfg.resendApiKeyFile}";
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        CapabilityBoundingSet = ["CAP_NET_ADMIN"];
      };

      environment = {
        PORT = "${toString cfg.port}";
        URBITS_DIR = cfg.urbitsDir;
        PUBLIC_FRONTEND_URL = "https://urbit-ssh.fly.dev";
        VM_KERNEL = "${vmArtifacts.vmlinux}/vmlinux";
        VM_INITRD = "${vmArtifacts.initrd}/initrd";
        VM_ROOTFS = "${vmArtifacts.rootfs}";
        VM_BOOT_ARGS = "${vmArtifacts.bootArgs}";
      };
    };

    networking.firewall.interfaces.wg0.allowedTCPPorts = [cfg.port];

    environment.systemPackages = [gatewayPkg];

    # IP forwarding and NAT so Firecracker VMs can reach the internet.
    # The gateway creates/destroys per-VM TAP interfaces named fc-<ship>;
    # they all fall under the fc-+ wildcard for firewall and NAT purposes.
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.nat = {
      enable = true;
      externalInterface = "eno1";
      internalInterfaces = ["fc-+"];
    };

    networking.firewall.trustedInterfaces = ["fc-+"];
  };
}
