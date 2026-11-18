# Retro gaming

The first implementation provides native ES-DE with the pinned iiSU Interpreted
theme, RetroArch cores for FDS/NES, N64 and GBA, and standalone Dolphin for
GameCube. Shipwright and 2Ship2Harkinian remain installed. Broader platform
coverage, controller acceptance testing and CRT presets are still in progress.

The `retro` capability owns its system packages and Home Manager configuration.
Midgar receives it through `gaming`. Hosts may set `hon.retro.enable = false`
or override `hon.retro.cores` with a list of `pkgs.libretro` packages.

## Library and launch

After activating a configuration containing this feature, choose your library
directory locally:

```sh
retro-library set-root "/path/to/ROMs"
retro-home
```

The current folder aliases are `FDS`/`fds`, `N64`/`n64`, `GBA`/`gba`, and
`GC`/`gc`/`GameCube`. To use a different location or resolve ambiguous names:

```sh
retro-library map gc "/path/to/GameCube games"
retro-library status
retro-library refresh
```

These commands create a separate symlink view. They never move, rename, convert
or delete source games. Missing or disconnected paths preserve the existing
view. A conflicting unmanaged file or link causes an error instead of replacement.
Library locations are runtime preferences and never enter the Nix store.

Open **Retro Home** from the desktop launcher, or **Retro Console** for the same
fullscreen frontend with idle inhibition. Both run inside the existing desktop;
there is no new login session or change to the default desktop. ES-DE remains a
normal application that can be switched away from. Console mode releases its
idle inhibitor when the process exits; compositor-specific idle behaviour still
needs testing on the actual desktop.

ES-DE scans on startup. Use its **Utilities → Rescan ROM directory** action after
adding games while it is open. Scraping and metadata correction use ES-DE's own
menus. Scraping initially preserves existing metadata; review matches and service
requirements before bulk downloads. No scraper account or paid service is configured.

## Settings and persistence

Defaults are initialized once and then remain writable. Changes made in the
frontend survive rebuilds. The following paths use XDG defaults, respecting
`XDG_CONFIG_HOME` and `XDG_DATA_HOME` when set:

| Data | Default location |
| --- | --- |
| Library directory preferences | `~/.config/hon-retro/library.json` |
| Library view | `~/.local/share/hon-retro/roms/` |
| Frontend settings, metadata, artwork and logs | `~/.local/share/hon-retro/frontend/` |
| RetroArch writable base configuration | `~/.config/hon-retro/retroarch.cfg` |
| RetroArch saves / states | `~/.local/share/hon-retro/saves/` and `states/` |
| Initial RetroArch BIOS directory | `~/.local/share/hon-retro/bios/` |

Home Manager owns only the pinned theme and frontend emulator-discovery/system
definitions. It does not manage save files, artwork or writable settings. Dolphin
continues to use its native user-data locations; no existing Dolphin data is migrated.

`retro-play` starts RetroArch with the separate writable configuration and the
selected pinned cores. It disables automatic config saving on exit and starts
with hardcore achievements disabled. Runtime changes can be tested normally;
**Save Current Configuration** explicitly records desired base changes. Review
successful emulator settings before promoting them into the Nix defaults.
Some menu settings, core options, remaps and presets have separate save actions.
Never replace an existing save or memory card while experimenting.

Supply required firmware yourself. FDS normally needs `disksys.rom` in the BIOS
directory. No ROMs or BIOS files are downloaded by this configuration. Use
RetroArch's directory settings to choose a different BIOS location and save the
configuration explicitly. Existing saves must be located and integrated before
playing a game for which prior progress matters.

## Controllers

The current verified device modes are:

| Controller | Hardware ID | Observed behaviour |
| --- | --- | --- |
| 8BitDo 64, Bluetooth | `2dc8:3019` | A/B, all four C buttons, L/R/Z, Select/Start/Home, full stick range and D-pad verified; no SDL-advertised rumble in this mode |
| Ultimate 2 Wireless, dongle D-input | `2dc8:6012` | Face/shoulder/system/stick buttons, four extra inputs, both sticks, analog triggers and D-pad verified; both rumble motors confirmed by the user |

RetroArch normally requests the Ultimate for player one; N64 launches request
the 64 instead. Both use RetroArch's native VID/PID preference, rather than a
joystick enumeration index. The 64's C buttons also
emit right-stick directions. Its custom profile uses the raw udev layout.
The Ultimate profile uses RetroArch's standardized SDL GameController layout;
raw SDL joystick and evdev button numbers must not be substituted for it.
SDL advertises Ultimate motion sensors, but sensor behaviour is not yet tested.
Isolated RetroArch sessions confirmed that both custom profiles load and that
the N64 launch reassigns the 64 to player one even when it is enumerated later.
These sessions loaded no game and do not establish gameplay compatibility.

The Ultimate profile can be selected explicitly for a manual RetroArch launch:

```sh
retro-play --profile ultimate2 [RetroArch arguments]
```

Both profiles configure a Select/Back modifier: Start exits, Home opens the menu,
L/LB saves state, R/RB loads state, A pauses, and holding B fast-forwards. These
action bindings still need in-game acceptance tests. Extra Ultimate buttons are
detected but left unassigned. Core compatibility and hardcore-mode restrictions
still apply to state operations. Missing-controller, reconnect and multiplayer
behaviour are not yet verified.

The frontend disables SDL's GameCube HIDAPI driver so it does not claim the
official adapter that Dolphin needs for native USB access. Use another pad to
navigate the frontend while using native GameCube adapter mode in Dolphin.
No broad input-group access or new kernel controller driver is introduced.

## Packaging and updates

ES-DE is a local source package because the locked Nixpkgs removed its old
FreeImage dependency. This recipe uses the maintained danoli3 FreeImage fork,
with system codec libraries and upstream regression tests. Its codec choices
omit camera RAW, OpenEXR and JPEG XR support. Updating requires reviewing the
fork's security advisories and rerunning its tests; this is not a guarantee that
all image-decoder vulnerabilities are eliminated.

Application self-updates are disabled. The iiSU Interpreted theme is separately
pinned; upstream provides no blanket redistribution license, so it is treated
as unfree and fetched for local use. Do not distribute its asset output without
reviewing the applicable rights. The theme is an interpretation of iiSU's UI,
not its customizable home-screen implementation or social services.

## Validation

```sh
nix fmt -- --fail-on-change
nix flake check --show-trace
nix build .#nixosConfigurations.midgar.config.system.build.toplevel --no-link
```

The library tests cover path spacing, alias ambiguity, conflicting entries,
unavailable roots, recursive mappings and preservation of settings/saves. The
frontend test launches the real theme in isolated headless Wayland and routes
a synthetic game to an inert command. It does not run copyrighted content,
validate an emulator, test physical controllers or measure GPU performance.

Physical acceptance must cover controller navigation, missing/reconnected
controllers, native GameCube adapter trigger/rumble behaviour, DolphinBar IR and
motion, launching owned games, returning to the library, fullscreen transitions,
and save persistence. Do not regard the environment as complete until those
results and the remaining platform/presentation work are recorded.
