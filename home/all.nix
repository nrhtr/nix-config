{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./common.nix
    ./terminal.nix
    ./colours.nix
    ./desktop.nix
    ./gpg.nix
    ./ssh.nix
    ./nvim.nix
    ./helix.nix
  ];
}
