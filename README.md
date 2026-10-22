# 本ーニクス (hon-nix)

A NixOS workstation configuration using flake-parts, import-tree, and Home Manager.

The clean rewrite is in progress. The current implementation provides Midgar's
core system, hardware and disk configuration, typed preferences, Zsh/CLI
features, Hyprland, Plasma fallback, audio, portals, and desktop theming.
Alacritty, Firefox, VSCodium, and the KDE application stack are included, along
with communication, media/graphics, development, gaming, and virtualisation features.
The custom Quickshell shell now provides per-monitor bars, workspace controls,
an application launcher, a session menu, and audio/media controls.
Notifications, history, backlight controls, and a brightness OSD are implemented.
Quick settings include audio devices, Wi-Fi, and Bluetooth controls. The full
Midgar system builds successfully; hardware and installed-session acceptance
are still pending.

## Structure

- `preferences.nix` contains personal identity, locale, application choices, and appearance.
- `hosts/midgar/` owns hardware, disks, monitor facts, and explicit capability selection.
- `modules/core/` provides the baseline shared by NixOS hosts.
- `modules/hardware/` provides reusable hardware support.
- `modules/desktop/` owns the compositor, fallback desktop, audio, portals, and theming.
- `modules/features/` owns optional capabilities, including their Home Manager configuration.
- `assets/` contains static configuration such as the preserved Powerlevel10k setup.

Feature files export `flake.nixosModules.<name>`. Only modules and host entry
points are discovered automatically; hardware and disk files are ordinary NixOS
modules imported by their host. Home Manager is integrated once in core, and
features configure `home-manager.users.${config.hon.user.username}` directly.

`pkgs` uses unstable. NixOS modules can request `pkgsStable` for packages from
NixOS 26.05. Versions are pinned by `flake.lock`; state versions are kept at 25.11
and are independent of package channels.

## Midgar

An x86_64-linux workstation with AMD graphics, Bluetooth, the latest packaged
Linux kernel, systemd-boot, and NetworkManager with systemd-resolved. SDDM defaults
to the UWSM-managed Hyprland session; Plasma is available as a fallback.

| Display | Mode | Position | Scale | Depth |
| --- | --- | --- | --- | --- |
| DP-1 (primary) | 2560 × 1440 at 240 Hz | 1920, 0 | 1 | 10-bit |
| DP-2 | 1920 × 1080 at 144 Hz | 0, 360 | 1 | Default |

Disko describes `/dev/nvme0n1`: an EFI partition ending at 2 GiB, 32 GiB swap,
and Btrfs with `/`, `/home`, and `/nix` subvolumes. Swap is configured as the
resume device. No disk encryption is configured. Evaluation and builds do not
partition disks; running Disko in formatting mode would erase the selected disk.

Hyprland uses Lua configuration for the pinned 0.56.2 release. Its package set
includes the locked toolkit overlay and Glaze 7 from the stable input to keep
the build dependencies compatible. The workspace map
is generated once as `hon.workspaces`: DP-1 owns 1–10 and DP-2 owns 11–20.
Super+1…0 selects a local workspace on the focused monitor; adding Shift moves
the active window there. Super+mouse-wheel cycles within that monitor.

KDE/Qt applications use native Breeze Dark settings, GTK uses dark compatibility
settings, and Hyprland/Alacritty/Quickshell use Kanagawa Dragon. Shared fonts, Papirus Dark
icons, and Breeze Snow cursors come from preferences.

`hon-shell` uses Quickshell from the locked unstable package set. Its QML source
lives in `modules/desktop/shell/src/`; Nix supplies theme and monitor data and a
user service that follows the Hyprland session. Each monitor gets a bar with
local workspace labels. Panels open on the focused monitor and close if that
monitor disappears.

- Super+Space: application search; arrows select, Enter launches, Escape closes.
- Super+Shift+Space: lock, suspend, logout, restart, or shutdown. Logout, restart,
  and shutdown require a second activation in the menu.
- Super+A: audio output/input selection, volume and microphone mute, backlight
  controls, Wi-Fi connections, Bluetooth controls and pairing, and MPRIS media.
- Super+N: notification history, clear all, and do-not-disturb.
- Scroll over volume to adjust it; middle-click to mute. Volume changes show an OSD.

The bar also includes a clock, CPU usage, keyboard layout, connection indicators,
tray menus, and battery status when available. Shell functionality that depends
on physical devices still needs a live NixOS session test.

Bluetooth controls include per-adapter power, paired-device connection and battery
status, explicit trust, and confirmed forgetting. Pair new device opens KDE’s
pairing wizard for discovery and PIN/passkey confirmation; Settings opens the
Bluetooth settings module. These actions close the panel to release keyboard
focus. Real device pairing still needs installed-system testing.

Wi-Fi scans while the control center is open. Available networks support
connect/disconnect, reuse of saved credentials, masked password prompts, and
confirmed forgetting of saved settings. Password fields clear after submission,
cancellation, or radio shutdown; NetworkManager manages saved credentials.
Use Network settings for hidden networks, enterprise credentials, and advanced
configuration. Real NetworkManager authentication still needs live testing.

Audio device selection sets the preferred output or microphone through PipeWire.
The selected button follows the actual default chosen by the session manager.
Output and microphone levels are limited to 100%; microphone changes also show
an OSD. Disconnected devices disappear and unavailable controls are disabled.

Notifications appear on the focused monitor and support app icons, progress,
actions, and urgency. Normal notifications expire into session-only history;
sticky and critical notifications remain active until dismissed. History is
capped at 100 entries. DND suppresses popups while preserving history. Transient
notifications are excluded from history, and expired entries have no live actions.

Brightness controls use the first available Linux backlight device and show
changes on the focused display. The slider ranges from 1–100%; device discovery
does not show an OSD, and missing devices disable the controls. Brightness keys
explicitly target backlights. DDC-only external displays are not controlled.

The account is `tnazep` (Jacob Ennaimi), with Swedish keyboard layouts,
`en_GB.UTF-8`, and `Asia/Tokyo`. Set a login password during installation; no
password or password hash is stored in this repository.

## User features

Git and GitHub CLI use the configured identity. Commits and tags use SSH signing
through 1Password with the preserved public signing key. The 1Password GUI starts
silently with the desktop; sign in and enable its SSH agent in 1Password's
settings. SSH uses `~/.1password/agent.sock`; separate SSH agents are disabled.
Vault access and signing still require live acceptance testing.

Java 25 is the default. Java 8, 17, 21, and 25 are also available under
`/etc/jdks/<version>`, with `JAVA_8_HOME`, `JAVA_17_HOME`, `JAVA_21_HOME`, and
`JAVA_25_HOME` environment variables. For example, `$JAVA_17_HOME/bin/java`
selects Java 17 without changing the default. Prism has all four runtimes.

The application groups include Vesktop/Element, KDE multimedia tools, DaVinci
Resolve, Krita, Godot, and Node.js. Gaming includes Steam, GameMode, Gamescope,
MangoHud, Proton utilities, Heroic/Faugus, Prism, and the retained retro games.
Libvirt includes QEMU/KVM, software TPM support, virt-manager, and virt-viewer.
Tailscale is enabled; joining a tailnet requires interactive authentication.
Native AppImage handlers are enabled for executable AppImages.

Installation preparation, personal setup, and hardware acceptance are documented
in [the installation guide](docs/installation.md).

## Development

With Nix installed and flakes enabled, include new source files in Git before
using the Git flake, then run:

```sh
nix fmt
nix flake check
nix eval .#nixosConfigurations.midgar.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.midgar.config.system.build.toplevel
```

A successful evaluation or build of this intermediate configuration does not
establish desktop readiness. The full system build and all three flake checks passed on 2026-10-22.
Shell polish, application acceptance, and hardware session validation remain
outstanding.

The media feature contains a version-guarded DaVinci Resolve 21.1 source-hash
correction for Blackmagic’s `v21.1-1` archive. Review and remove that correction
when updating nixpkgs to a release with the upstream fix.

The flake checks validate module composition, stable package access, Disko
filesystems, invalid monitor definitions, portal selection, and workspace
behavior. The Lua workspace test covers both displays, moving windows, cyclic
navigation, and unavailable monitors.

The shell check runs the pinned Quickshell runtime on two software-rendered
Wayland outputs. It uses private D-Bus sessions, a Hyprland IPC fixture, and
harmless application/session commands to exercise workspace clicks, launcher
search and keyboard navigation, terminal applications, confirmation, dismissal,
and monitor removal. Sway supplies the test surfaces; this does not replace
live Hyprland, audio, network, Bluetooth, tray, or OSD acceptance testing.
