# Stubs for NixOS options referenced by activation-script.nix and etc.nix
# that we don't need in a Firecracker guest.  Modelled on not-os/systemd-compat.nix
# but extended for nixos-25.11's additional dependencies.
{
  pkgs,
  lib,
  ...
}: {
  options = {
    systemd = {
      tmpfiles.rules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      user = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      services = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
    };

    nix.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    # system.activatable = false suppresses the systemd.user mkIf block in
    # activation-script.nix, which would otherwise pull in userActivationScripts.
    system.activatable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    # Referenced by the specialfs activation script in activation-script.nix.
    system.build.earlyMountScript = pkgs.writeScript "early-mount" "";
  };
}
