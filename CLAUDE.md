# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Overview

Personal NixOS configuration for multiple machines, using Home Manager, Morph for remote deployment, Agenix for secrets, and nix-colors for theming.

## Development Shell

Enter the development shell to get `morph`, `gitleaks`, and pre-commit hooks:

```bash
nix-shell
```

Pre-commit hooks run automatically on commit: **alejandra** (formatter), **shellcheck**, **gitleaks** (secret scanning).

## Common Commands

**Format Nix files:**
```bash
alejandra .
```

**Check formatting without applying:**
```bash
alejandra --check .
```

**Deploy to remote servers:**
```bash
morph deploy deploy/all.nix switch
```

**Deploy to a specific host:**
```bash
morph deploy deploy/all.nix switch --on nix01.wireguard
```

**Re-key secrets after adding a new host/user:**
```bash
agenix -r -i ~/.ssh/id_ed25519
```

**Add/edit a secret:**
```bash
agenix -e secrets/wifi.age -i ~/.ssh/id_ed25519
```

## Architecture

### Directory Layout

- `machines/<hostname>/` — Per-host NixOS configs. Each imports `common/shared.nix` and optionally `home/all.nix` for Home Manager.
- `common/shared.nix` — Shared system config: base packages, user accounts, SSH, Nix settings, agenix module.
- `home/` — Home Manager modules loaded by `home/all.nix`: terminal (fish, direnv), desktop (sway, waybar, foot), colours (nix-colors/dracula), gpg, ssh, nvim, borg.
- `modules/` — Custom NixOS service modules (genesis ColdC, gitleaks pre-commit, sonata, websockify).
- `packages/` — Custom Nix derivations (gitleaks, jsonfui, silk-guardian, darktable, obsidian, genesis, minecraft-overviewer).
- `deploy/all.nix` — Morph network file; targets nix01 and nix02. Pinned to nixos-23.05.
- `secrets/` — Agenix-encrypted `.age` files. `secrets/secrets.nix` declares which public keys can decrypt each secret.
- `jobs/` — Nomad job files.

### Key Conventions

- **Theming**: All color values come from `nix-colors` (base16 palette), set in `home/colours.nix` (currently dracula). Desktop configs in `home/desktop.nix` reference `config.colorscheme.colors.baseXX`.
- **Secrets**: Encrypted with `agenix`. Secrets are declared in `secrets/secrets.nix` with authorized public keys (user + host keys). Accessed at runtime via `config.age.secrets.<name>.path`.
- **SSH port**: All machines use port `18061` (set in `common/shared.nix`).
- **Display output**: The thinkpad config sets `displayOutput = "LVDS-1"` which is consumed by `home/desktop.nix` for waybar output targeting.
- **Distributed builds**: The thinkpad offloads builds to nix02 via `nix.buildMachines`.
- **Formatter**: Use `alejandra` (not `nixfmt` or `nixpkgs-fmt`).
