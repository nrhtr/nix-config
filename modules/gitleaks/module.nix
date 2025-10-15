{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config;
  defaultSettings = builtins.fromTOML (builtins.readFile ./gitleaks.default.toml);
  tomlFormat = pkgs.formats.toml {};
  configFile = tomlFormat.generate "gitleaks-config" cfg.rawConfig;
in {
  options = with lib; {
    package = mkOption {
      type = types.package;
      description = ''
        The gitleaks package to use.
      '';
      defaultText = ''
        pkgs.gitleaks
      '';
    };

    settings = mkOption {
      # FIXME: Inappropriate lint
      inherit (tomlFormat) type;
      description = ''
        The gitleaks configuration to be merged with the defaults.
      '';
    };

    installationScript = mkOption {
      type = types.str;
      description = ''
        A bash snippet that configures .gitleaks.toml in the current directory
      '';
      readOnly = true;
    };

    rawConfig = mkOption {
      type = types.attrs;
      description = ''
        The raw configuration before writing to file.
      '';
      internal = true;
    };
  };

  config = {
    rawConfig = lib.mkMerge [defaultSettings cfg.settings];
    installationScript = ''
      if readlink .gitleaks.toml >/dev/null \
        && [[ $(readlink .gitleaks.toml) == ${configFile} ]]; then
        echo 1>&2 "nix-gitleaks: config up to date"
      else
        echo 1>&2 "nix-gitleaks: updating gitleaks settings"

        [ -L .gitleaks.toml ] && unlink .gitleaks.toml

        if [ -e .gitleaks.toml ]; then
          echo 1>&2 "nix-gitleaks: WARNING: Refusing to install because of pre-existing .gitleaks.toml"
        else
          ln -s ${configFile} .gitleaks.toml
        fi
      fi
    '';
  };
}
