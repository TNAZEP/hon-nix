# Midgar installation and acceptance

This configuration is still being validated. A successful build checks the
system closure; it does not establish that the workstation works on its hardware.

## Before installation

- Back up the target machine and keep a bootable recovery USB available.
- Review `preferences.nix`, `hosts/midgar/hardware.nix`,
  `hardware-configuration.nix`, and `disko.nix` against the actual machine.
- Check the target disk by model and serial. The configuration names
  `/dev/nvme0n1`; device numbering alone does not identify a disk reliably.
- Confirm the two monitor connector names and modes. The configured primary is
  DP-1, 2560×1440 at 240 Hz; DP-2 is 1920×1080 at 144 Hz.
- Build the configuration before installing:

  ```sh
  nix flake check
  nix build .#nixosConfigurations.midgar.config.system.build.toplevel
  ```

New source files must be included in Git for a Git-backed flake to see them.
The build does not partition disks or activate the system.

Disko describes an EFI partition ending at 2 GiB, 32 GiB swap, and unencrypted
Btrfs with `@`, `@home`, and `@nix` subvolumes. Formatting this layout destroys
existing data on the selected disk. Reusing an existing filesystem requires
checking that its partitions, labels and subvolumes match the configuration;
do not run formatting merely to mount an existing installation.

Install from a NixOS installer after preparing and mounting the intended target
at `/mnt`. With this repository available, the installation step is:

```sh
sudo nixos-install --flake .#midgar
```

Set the normal user's password before rebooting:

```sh
sudo nixos-enter --root /mnt -c 'passwd tnazep'
```

The repository supplies no password hash. Home Manager is integrated into NixOS;
there is no separate Home Manager switch step. This document intentionally does
not prescribe disk formatting commands before the physical target is verified.

## First login

Select Hyprland (UWSM) in SDDM. Plasma is available as a fallback session.
Check the user services and journal if the shell or authentication prompts fail:

```sh
systemctl --user status hon-shell hon-polkit-agent hypridle
journalctl --user -b -u hon-shell -u hon-polkit-agent -u hypridle
systemctl --user --failed
systemctl --failed
```

These Hyprland services follow the compositor session and should stop when it
ends. Log out before testing Plasma; verify its native shell, file chooser,
audio, and Bluetooth settings independently.

## Personal setup

- Sign in to 1Password and enable its SSH agent. Confirm
  `~/.1password/agent.sock` exists. Git uses the configured public signing key;
  its private key must be available through the signed-in vault. Test signing
  in a disposable repository before relying on it.
- Authenticate GitHub CLI and other applications as needed.
- Join the intended Tailscale network interactively with `sudo tailscale up`.
- Configure browser integration and launchers using your own accounts.
- Java 25 is the default. Check `java -version` and the versioned runtimes under
  `/etc/jdks/{8,17,21,25}`. Select the appropriate runtime in Prism per instance.
- Open virt-manager and test a disposable VM on the system libvirt connection.

## Hardware and session acceptance

Record results for each group before treating the workstation as ready:

| Area | Check on Midgar |
| --- | --- |
| Boot/storage | UEFI boot, expected mounts, swap, password login, reboot |
| Displays | Connector placement, refresh rates, scaling, HDR/VRR, hotplug |
| Workspaces | Local 1–10 on both monitors, move windows, wheel cycling |
| Session | Login/logout, shell restart, polkit prompts, Plasma fallback |
| Lock/power | Manual lock, idle lock, display wake, suspend/resume |
| Audio | Output/mic selection, mute, levels, device removal, Bluetooth profiles |
| Network | Wired DNS, Wi-Fi saved/new credentials, wrong-password recovery, VPN |
| Bluetooth | Pair with PIN/passkey, connect, trust, forget, adapter disable |
| Portals | File chooser, browser screen sharing, screenshots |
| Shell | Launcher, tray menus, media controls, notifications/actions/DND |
| Applications | 1Password signing, development tools, games, VM and AppImage launch |

Brightness controls target Linux backlights only. DDC-only external monitors
are not controlled. Bluetooth pairing opens KDE's wizard; advanced Wi-Fi setup
opens KDE Network settings. Notification history is session-only.

Test power actions after saving work. Suspend and hibernation are separate
capabilities: a configured resume device alone does not prove hibernation works.
