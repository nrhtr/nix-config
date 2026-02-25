{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./common.nix
    ./desktop.nix
    ./ssh.nix
  ];
}
