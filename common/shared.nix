{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim git htop mtr mosh pass tmux
  ];

  users.users.jenga = {
    isNormalUser = true;
    home = "/home/jenga";
    description = "Jeremy Parker";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBroC7fhTdO17jn7U4FE97IFUYE4NfWxFcxax6bwVzsIXBRCQ9mYlNvmYokWTYX+rlSVi1ifpiwaveJHqcZX4hM="
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMGWqY84hz9k9OibHThS8QjqoSmuH2MtbRxR1UkSqrn jparker@sqiphone"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@thinkpad"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBroC7fhTdO17jn7U4FE97IFUYE4NfWxFcxax6bwVzsIXBRCQ9mYlNvmYokWTYX+rlSVi1ifpiwaveJHqcZX4hM= jparker@squiz.net"];
  };
}
