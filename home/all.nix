{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./common.nix
    ./terminal.nix
    ./borg.nix
    ./colours.nix
    ./desktop.nix
    ./gpg.nix
    ./ssh.nix
    ./nvim.nix
  ];
}
