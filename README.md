# nixos-config

Each system has a symlink `configuration.nix` in `/etc/nixos/` to `./$hostname/configuration.nix`

## nix01
 * [System config](./nix01/configuration.nix)
 * [Wireguard config](./nix01/wireguard.nix)

## thinkpad
 * [System config](./thinkpad/configuration.nix)
 * [Wireguard config](./thinkpad/wireguard.nix)

## common
 * [User accounts](./common/users.nix)

---

## Provisioning a new OVH bare-metal host

These steps use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) +
[disko](https://github.com/nix-community/disko) to install NixOS over SSH without
needing IPMI or a bootable USB.

### Prerequisites

Add disko to npins (one-time):

```bash
npins add github nix-community disko
```

### 1. Provision Debian via OVH console

In the OVH manager: Bare Metal → your server → Install → Debian.
Add your SSH public key during provisioning. Wait ~10 min for it to come up.

### 2. Collect network info from the Debian install

```bash
ssh debian@<server-ip>
ip link show                   # note the interface name (e.g. eno1, enp2s0)
ip route show default          # note the gateway
head -c8 /etc/machine-id && echo  # hostId for ZFS
```

### 3. Generate a WireGuard keypair

Run locally (the Debian rescue system may not have wireguard-tools):

```bash
wg genkey | tee /tmp/wg.privkey | wg pubkey
```

Save the private key — you'll write it to `/etc/wireguard.privkey` after install.

### 4. Fill in the machine config

Edit `machines/<hostname>/configuration.nix`:
- `networkInterface` — from step 2
- `ipv4.gateway` — from step 2
- `hostId` — from step 2

Edit `common/wg-nodes.nix`:
- Replace the placeholder `publicKey` with the output of `wg pubkey` from step 3

### 5. Evaluate the config locally (pre-flight check)

Before deploying, verify the config evaluates without errors:

```bash
colmena eval -f deploy/colmena.nix -E '{ nodes, ... }: nodes.nix03.config.system.build.toplevel.drvPath'
```

Replace `nix03` with the target hostname.

A store path printed means success. Fix any errors before proceeding.

### 6. Build and install

**Run from lappy** — it has your SSH keys (needed for nixos-anywhere to authenticate to the target) and offloads the Linux build to nix02 via the configured remote builder.

```bash
# nix-build can't extract the store path from npins directly — use nix eval instead
nixpkgs=$(nix eval --raw -f npins nixpkgs)

disko=$(nix-build '<nixpkgs/nixos>' -A config.system.build.diskoScript \
  -I nixpkgs="$nixpkgs" \
  -I nixos-config=$(pwd)/machines/nix03/configuration.nix \
  --no-out-link)

system=$(nix-build '<nixpkgs/nixos>' -A system \
  -I nixpkgs="$nixpkgs" \
  -I nixos-config=$(pwd)/machines/nix03/configuration.nix \
  --no-out-link)

# Install — wipes the disks and reboots into NixOS
nix run github:nix-community/nixos-anywhere -- \
  --store-paths "$disko" "$system" \
  debian@<server-ip>
```

The server will reboot into NixOS when done.

### 7. Post-install

```bash
ssh root@<server-ip>

# Write the WireGuard private key
echo "<privkey>" > /etc/wireguard.privkey
chmod 600 /etc/wireguard.privkey

# Verify ZFS
zpool status
```

### 8. Add the host SSH key to agenix

```bash
# Get the new host's SSH public key
ssh-keyscan -t ed25519 <server-ip>
```

Add it to `secrets/secrets.nix` under `systems`, then re-key:

```bash
agenix -r -i ~/.ssh/id_ed25519
```

Then redeploy:

```bash
colmena apply -f deploy/colmena.nix --on nix03
```
