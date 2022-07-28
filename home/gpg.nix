{
  config,
  pkgs,
  ...
}: {
  home-manager.users.jenga = rec {
    programs.gpg = {enable = true;};
    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
    };
  };
}
