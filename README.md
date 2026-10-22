# 本ーニクス (hon-nix)

A modular, flake-based NixOS workstation configuration managed with **Nix Flakes** and **Home Manager**. Hyprland with a custom Quickshell shell is the primary desktop; Plasma is available as a fallback.

This branch (Koushin) is a massive refactor and restructuring of the entire setup, cleaning up old complex abstractions and replacing them with structures that are easier to use and build upon. Also includes a rewrite of my shell in quickshell, will potentially be split into a sepparate repo in the future.

## Structure

The repository is organized using **flake-parts** and **import-tree** following the Dendritic pattern:

- `hosts/`: machine-specific hardware, disks, and feature selection.
- `modules/`: core, hardware, desktop, and user features.
- `preferences.nix`: identity, locale, application choices, and appearance.
- `assets/`: static configuration files.
- `tests/`: configuration and isolated desktop-shell checks.

## Hosts

| | Hostname | OS | Board | CPU | RAM | GPU | Purpose |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 🖥️ | `midgar` | NixOS | Asus | Ryzen 7 5800X3D | 32 GB | RX 9070 XT | Main desktop for general use, development, and gaming. |


## Installation

Follow these steps to install this configuration on a new machine (specifically targeting `midgar`, my desktop config). 
These commands require Nix flakes and `nix-command` support.

### 1. Prepare the Environment

Boot into the NixOS installation media and switch to the root user:

```bash
sudo su
```

Clone this repository:

```bash
git clone https://github.com/TNAZEP/hon-nix.git
cd hon-nix
```

### 2. Partition the Disk (Disko)

> [!WARNING]
> This step will **FORMAT** the target disk (`/dev/nvme0n1` for midgar). Verify the disk by model and serial, and ensure you have backed up any important data. Do not run this formatting step to reuse an existing installation.

The layout is an EFI partition ending at 2 GiB, 32 GiB swap, and unencrypted Btrfs subvolumes for `/`, `/home`, and `/nix`.

Run Disko to partition, format, and mount the drives:

```bash
nix run github:nix-community/disko -- --mode disko ./hosts/midgar/disko.nix
```

### 3. Install NixOS

Check and build the configuration, then install it:

```bash
nix flake check
nix build .#nixosConfigurations.midgar.config.system.build.toplevel
nixos-install --flake .#midgar
```

### 4. Set Passwords

Enter the new system to set passwords for the root user and your user (`tnazep`):

```bash
# Set root password
nixos-enter --root /mnt -c 'passwd root'

# Set user password
nixos-enter --root /mnt -c 'passwd tnazep'
```

### 5. Finish

Reboot into your new system:

```bash
reboot
```
