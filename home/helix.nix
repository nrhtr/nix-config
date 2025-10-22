{
  config,
  pkgs,
  ...
}: {
  home-manager.users.jenga = {
    programs.helix = {
      enable = true;
      defaultEditor = true;
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter = {
            command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
          };
        }
      ];
    };
  };
}
