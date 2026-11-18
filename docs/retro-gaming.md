# Retro gaming

The environment provides native ES-DE with the pinned iiSU Interpreted theme,
RetroArch cores for FDS/NES, N64 and GBA, and standalone Dolphin for GameCube/Wii.
Additional native launch routes cover PS2, Xbox, DS, PSP, PS3, Xbox 360, Wii U and
3DS. Shipwright and 2Ship2Harkinian remain installed. Package builds and frontend
routes are verified; game compatibility, broader classic coverage, controller
acceptance and presentation tuning remain in progress.

The `retro` capability owns its system packages and Home Manager configuration.
Midgar receives it through `gaming`. Hosts may set `hon.retro.enable = false`
or override `hon.retro.cores` with a list of `pkgs.libretro` packages.
Set `hon.retro.standalone.enable = false` to omit the eight additional standalone
emulators and their custom frontend routes, retaining Dolphin and the core set.

## Native emulator setup

| Platform | Emulator | Initial setup / current limit |
| --- | --- | --- |
| GameCube / Wii | Dolphin | Native GC adapter selection is automatic; real Wii Remote, IR and game profiles still need testing |
| PS2 | PCSX2 | Supply a dumped PS2 BIOS and complete initial setup |
| Xbox | xemu | Supply MCPX, compatible flash BIOS and HDD data; games need xemu-compatible disc images |
| DS | melonDS | Review firmware/BIOS and boot-mode requirements; touch/mic and dual-screen layouts need testing |
| PSP | PPSSPP | No external BIOS for normal use; controller and fullscreen acceptance pending |
| PS3 | RPCS3 | Install required PS3 firmware yourself; configure content and licenses where applicable |
| Xbox 360 | Native Xenia Canary | Experimental native Linux route; title-specific compatibility and save persistence need testing |
| Wii U | Cemu | Supply dumped games and required keys; GamePad/motion profiles remain pending |
| 3DS | Azahar | Use supported decrypted content; CIA installation stays in Azahar's own UI |

Open the native emulator directly to complete setup before launching firmware-
dependent games from ES-DE. Firmware, keys and credentials are never supplied by
Nix or downloaded automatically. The frontend routes do not complete these setup
wizards. Switch, Vita and PS4 integration remains pending; Xbox One has no route.
PS3 disc dumps receive `.ps3dir` aliases in a separate managed view; original
folder names remain unchanged. Discovery recognizes complete disc layouts with
`PS3_GAME/PARAM.SFO` and `PS3_GAME/USRDIR/EBOOT.BIN` at the platform root or one
directory below it. ISO entries retain their names. Incomplete dumps and other
directory layouts are not automatically indexed. Installed PSN titles still use
RPCS3's own library; this does not install games, firmware or licenses.
Standalone CRT parity, RetroAchievements support and controller policy must be
validated per emulator. The additional native emulators retain their own writable
settings and save locations. `retro-xenia` explicitly uses
`~/.local/share/hon-retro/xenia` for persistent data and
`~/.cache/hon-retro/xenia` for cache, respecting XDG overrides, with Discord
presence disabled. No source library paths enter these defaults.

## Library and launch

After activating a configuration containing this feature, choose your library
directory locally:

```sh
retro-library set-root "/path/to/ROMs"
retro-home
```

Initial aliases include `FDS`/`fds`, `N64`/`n64`, `GBA`/`gba`, and
`GC`/`gc`/`GameCube`. Additional aliases cover Wii, PS2, Xbox, DS/NDS, PSP, PS3,
Xbox 360, Wii U and 3DS/N3DS; `retro-library map --help` lists canonical system
names. To use a different location or resolve ambiguous names:

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
| PS3 per-game aliases / ownership manifest | `~/.local/share/hon-retro/ps3/` and `ps3-view.json` |
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

## Presentation

FDS and N64 offer Mega Bezel's standard Guest-based CRT presentation by default;
GBA offers an LCD grid with GBA colour correction. Each has an **Unfiltered**
alternative in ES-DE's emulator selection. GameCube continues to use Dolphin's
native rendering; a comparable standalone CRT pipeline is still pending.

Manual launches can select the same presentation:

```sh
retro-play --profile n64 --presentation crt [RetroArch arguments]
retro-play --presentation gba-lcd [RetroArch arguments]
retro-play --presentation raw [RetroArch arguments]
```

These options must precede ordinary RetroArch arguments. Omitting presentation
preserves the writable base settings. The CRT choice fills the output viewport
and lets Mega Bezel maintain the inner image ratio; LCD and unfiltered choices
use the core's ratio. Do not copy the CRT viewport setting to other pipelines.
The CRT intro is disabled and reflections are reduced. These are starting
presets, with PVM tuning, real-game performance and actual-display review pending.

Shader assets are pinned under `~/.local/share/hon-retro/shaders/pinned`.
Save experiments beside that link, rather than inside the immutable asset tree.
New base configurations use the writable parent as their shader directory.
Explicit presentation launches select their preset each time; save a custom
preset and pass a later `--set-shader /path/to/custom.slangp` to test it before
promoting the changes into Nix. Menu parameter changes remain available during
the current session. Managed launches disable the separate Qt desktop companion;
RetroArch's controller menu remains available.

## Controllers

The current verified device modes are:

| Controller | Hardware ID | Observed behaviour |
| --- | --- | --- |
| 8BitDo 64, Bluetooth | `2dc8:3019` | A/B, all four C buttons, L/R/Z, Select/Start/Home, full stick range and D-pad verified; no SDL-advertised rumble in this mode |
| Ultimate 2 Wireless, dongle D-input | `2dc8:6012` | Face/shoulder/system/stick buttons, four extra inputs, both sticks, analog triggers and D-pad verified; both rumble motors confirmed by the user |
| Original GameCube controller, official USB adapter | `057e:0337` | Native USB access, port 1, face/system buttons, D-pad, both sticks, separate analog trigger travel/digital L/R clicks, and sustained rumble verified; gameplay checks pending |

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

`retro-dolphin` detects the official adapter at launch and temporarily selects
Dolphin's native adapter type for all four ports. Physical adapter ports retain
their order. If no adapter is present, it uses Dolphin's saved port settings.
The **Dolphin (Configured)** frontend alternative bypasses automatic selection.
For manual launches, `--adapter native` forces native ports even if the adapter
will be plugged in later, and `--adapter configured` preserves the saved choices.
These overrides use Dolphin's command-line layer; they do not rewrite port
settings in Dolphin.ini. Emulator-level hotplug, multiplayer and gameplay still
need acceptance tests. The Pro 3 mapping awaits its physical test.
Both adapter USB plugs are needed for rumble: the grey plug supplies motor power.
With it connected, the user confirmed normal sustained rumble during a five-second
native USB test. Short-pulse tests had been inconclusive.

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
PS3 view tests also cover ordinary dump-folder aliases, ISO preservation, name
collisions, single-dump mappings, missing sources and upgrading the previous
platform-root link without modifying frontend metadata.

The optional manual rendering check opens short-lived Vulkan windows inside a
Wayland desktop, uses generated test images, and keeps all settings temporary:

```sh
python tests/retro-render.py /path/to/retro-play /tmp/retro-render-check
```

It requires a new output directory and records logs and screenshots for CRT,
GBA LCD and unfiltered output. It checks shader compilation, successful exit and
base-config preservation. These pipelines passed on the RX 9070 XT; that is not
a game-performance benchmark or evidence of calibrated PVM reproduction.

Physical acceptance must cover controller navigation, missing/reconnected
controllers, native GameCube adapter trigger/rumble behaviour, DolphinBar IR and
motion, launching owned games, returning to the library, fullscreen transitions,
and save persistence. Do not regard the environment as complete until those
results and the remaining platform/presentation work are recorded.
