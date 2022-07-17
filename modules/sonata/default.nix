{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.sonata;
  cfgFile = "sonata/sonatarc";
  iniFormat = pkgs.formats.ini { };

  runWithPassword = secretPath:
    pkgs.writeShellScript "sonata-pre-start" ''
      export SONATA_SCROBBLER_PASSWORD="$(cat ${secretPath})"
      echo "$SONATA_SCROBBLER_PASSWORD"
    '';

  patchSonata = pkg: pkg.overrideAttrs
    (old: { patches = [ ./audioscrobbler-password-env.patch ]; });
in {
  options.programs.sonata = {
    enable = mkEnableOption "Sonata";

    package = mkOption {
      type = types.package;
      default = pkgs.sonata;
      defaultText = literalExpression "pkgs.sonata";
      description = "The Sonata package to install.";
    };

    settings = mkOption {
      inherit (iniFormat) type;
      default = { };
      example = literalExpression ''
        {
          audioscrobbler = {
            use_audioscrobbler = True
            password_md5 = foo
            username = adam
          };
        }
      '';
      description = ''
        Configuration written to
        <filename>$XDG_CONFIG_HOME/sonata/sonatarc</filename>.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ (patchSonata cfg.package) ];

    xdg.configFile."${cfgFile}" = mkIf (cfg.settings != { }) {
      source = iniFormat.generate "sonatarc" cfg.settings;
    };
  };
}
