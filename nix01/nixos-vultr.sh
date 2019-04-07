#!/bin/sh
limit=2000
mem=$(free -tm | awk '/Total:/ {print $2}')
dev="/dev/vda"
swap=$(( mem*2 < limit ? mem*2 : limit ))

parted "$dev" -- mklabel msdos
parted "$dev" -- mkpart primary 1MiB -"$swap"MiB
parted "$dev" -- mkpart primary linux-swap -"$swap"MiB 100%

mkfs.ext4 -L nixos "$dev"1
mkswap -L swap "$dev"2
swapon "$dev"2
#mkfs.fat -F 32 -n boot "$dev"3        # (for UEFI systems only)
mount /dev/disk/by-label/nixos /mnt
#mkdir -p /mnt/boot                      # (for UEFI systems only)
#mount /dev/disk/by-label/boot /mnt/boot # (for UEFI systems only)
nixos-generate-config --root /mnt

cat << EOF > /mnt/etc/nixos/configuration.nix
{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  boot.loader.grub.device = "$dev";   # (for BIOS systems only)
  #boot.loader.systemd-boot.enable = true; # (for UEFI systems only)

  # Note: setting fileSystems is generally not
  # necessary, since nixos-generate-config figures them out
  # automatically in hardware-configuration.nix.
  #fileSystems."/".device = "/dev/disk/by-label/nixos";

  # Enable the OpenSSH server.
  services.sshd.enable = true;

  # Security settings
  security.sudo.wheelNeedsPassword = false;
  services.sshd.permitRootLogin = no;

  users.users.jenga = {
    isNormalUser = true;
    home = "/home/jenga";
    description = "Jeremy Parker";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBroC7fhTdO17jn7U4FE97IFUYE4NfWxFcxax6bwVzsIXBRCQ9mYlNvmYokWTYX+rlSVi1ifpiwaveJHqcZX4hM=" ];
  };
}
EOF

nixos-install --no-root-passwd
read -p "Unmount ISO and reboot..."
