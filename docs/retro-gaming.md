# Retro gaming

The environment provides native ES-DE with the pinned iiSU Interpreted theme,
RetroArch cores for NES/FDS, SNES, GB/GBC, N64, GBA, Master System, Mega Drive,
Game Gear, Sega CD, 32X, PlayStation, Saturn, Dreamcast, PC Engine/CD/SuperGrafx,
Neo Geo/CD, FBNeo arcade, Atari 2600/7800/Lynx, Neo Geo Pocket/Color and
WonderSwan/Color, Atari 5200/Jaguar, ColecoVision, Intellivision, Odyssey2,
Vectrex, 3DO, PC-FX, CD-i, SG-1000, Virtual Boy and MAME, and standalone Dolphin
for GameCube/Wii.
Additional native launch routes cover PS2, Xbox, DS, PSP, PS3, Xbox 360, Wii U,
3DS, Switch, Vita and experimental PS4. Shipwright and 2Ship2Harkinian remain installed. Package builds and frontend
routes are verified. Current acceptance focuses on library discovery, frontend
launch/return, metadata/media persistence and platform integration. Actual
gameplay verification is outside the current acceptance gate; configuration
support does not imply compatibility or performance for every title.

The `retro` capability owns its system packages and Home Manager configuration.
Midgar receives it through `gaming`. Hosts may set `hon.retro.enable = false`
or override `hon.retro.cores` with a list of `pkgs.libretro` packages.
Set `hon.retro.standalone.enable = false` to omit the eleven additional standalone
emulators and their custom frontend routes, retaining Dolphin and the core set.

## Classic core setup

| Platform | Core | Initial setup / current limit |
| --- | --- | --- |
| NES / FDS | Mesen | FDS needs `disksys.rom`; ordinary NES cartridges do not |
| SNES | bsnes | Enhancement-chip titles may need matching coprocessor firmware; special cartridge/SGB setups are pending |
| GB / GBC | SameBoy | External boot ROMs are optional; LCD grid is available; link features remain pending |
| Master System / Mega Drive / Game Gear | Genesis Plus GX | Ordinary cartridges generally need no external BIOS; three/six-button and game-specific remaps remain pending |
| Sega CD | Genesis Plus GX | Supply the regional `bios_CD_U.bin`, `bios_CD_E.bin` or `bios_CD_J.bin` in the RetroArch BIOS directory |
| Sega 32X | PicoDrive | Separate core from Genesis Plus GX; controller and gameplay acceptance pending |
| PlayStation | Beetle PSX HW | Supply matching regional `scph5500.bin`, `scph5501.bin` or `scph5502.bin`; PAL titles may need matching `.sbi` sidecars |
| Saturn | Beetle Saturn | Supply `sega_101.bin` for Japan or `mpr-17933.bin` for US/Europe; special cartridges need per-game setup |
| Dreamcast | Flycast | Optional `dc/dc_boot.bin`; writable VMU/NVRAM lives beneath the BIOS directory; Naomi/Atomiswave are not configured |
| PC Engine / CD / SuperGrafx | Beetle PCE | Cartridges need no firmware; CD normally needs `syscard3.pce`, with other system cards for specific titles |
| Neo Geo / Arcade | FinalBurn Neo | Matching ROM sets, parent sets and board BIOS as needed; Neo Geo needs `fbneo/neogeo.zip` |
| Neo Geo CD | NeoCD | A supported original CD BIOS beneath `neocd/` is recommended; built-in high-level fallback and save-state compatibility remain untested |
| Atari 2600 / 7800 | Stella / ProSystem | No 2600 BIOS; `7800 BIOS (U).rom` is optional for ProSystem |
| Atari Lynx | Beetle Lynx | Supply `lynxboot.img`; portrait controls and layouts need per-game testing |
| Neo Geo Pocket / Color | Beetle NGP | No external firmware required; controller acceptance pending |
| WonderSwan / Color | Beetle WonderSwan | No external firmware required; portrait controls and layouts need per-game testing |
| Atari 5200 | Atari800 | Supply `5200.rom`; review core machine selection and keypad controls |
| ColecoVision | Gearcoleco | Supply `colecovision.rom`; keypad controls are core-specific |
| Intellivision | FreeIntv | Supply `exec.bin` and `grom.bin`; keypad controls are core-specific |
| Odyssey2 / Videopac | O2EM | Supply `o2rom.bin` or the appropriate regional/extended BIOS |
| Vectrex | vecx | Raw vector output by default; overlays and vector presentation are separate choices |
| 3DO | Opera | Supply a supported BIOS, such as `panafz1.bin`; cue/CHD/ISO discovery omits individual bin tracks |
| Atari Jaguar | Virtual Jaguar | Cartridge formats only; Jaguar CD is not configured |
| PC-FX | Beetle PC-FX | Supply `pcfx.rom`; cue/CCD/TOC/CHD discovery |
| CD-i | SAME CDi | Supply matching BIOS sets beneath `same_cdi/bios/`; cue/CHD/ISO discovery |
| MAME | Current libretro MAME | Dedicated `mame` directory for matching sets; ZIP/7z/CMD discovery, raw output by default |
| SG-1000 | Genesis Plus GX | Cartridge `.sg` files and ZIP/7z |
| Virtual Boy | Beetle VB | Raw output by default; stereo/palette options remain core settings |
| N64 | Mupen64Plus-Next | Ordinary cartridges need no firmware; 64DD is not configured |
| GBA | mGBA | BIOS optional for normal play; special features remain untested |

Sega CD discovery accepts `.cue`, `.chd` and `.m3u` files, including uppercase
extensions. Keep cue sheets beside their referenced tracks and preserve relative
paths in playlists. PlayStation, Saturn, Dreamcast, PC Engine CD and Neo Geo CD
also omit individual track `.bin` files and disc archives from their game lists.
Dreamcast accepts `.gdi`/`.cdi` as well as `.cue`/`.chd`/`.m3u`; PlayStation also
accepts `.pbp`/`.ccd`/`.toc`/`.exe`. Neo Geo CD accepts `.cue`/`.chd`. Keep required
sidecar files next to their descriptors. No automatic playlist generation or
conversion is performed. NES/SNES and cartridge routes accept ZIP/7z; disc images should remain
in their supported disc formats.

Firmware requirements follow the pinned core-info files. See the upstream
[Genesis Plus GX guide](https://docs.libretro.com/library/genesis_plus_gx/),
[SameBoy guide](https://docs.libretro.com/library/sameboy/),
[bsnes guide](https://github.com/libretro/docs/blob/master/docs/library/bsnes.md)
and [PicoDrive guide](https://docs.libretro.com/library/picodrive/) for core options
and system-specific limits. No firmware is supplied. These are configured launch
routes, with title-specific gameplay, audio and save acceptance still pending.
See also the upstream [PlayStation](https://docs.libretro.com/library/beetle_psx_hw/),
[Saturn](https://docs.libretro.com/library/beetle_saturn/),
[Flycast](https://docs.libretro.com/library/flycast/),
[Beetle PCE](https://docs.libretro.com/library/mednafen_pce/),
[NeoCD](https://github.com/libretro/neocd_libretro/blob/b1e04c738cb48a1dae0574b8877f6a116d270ca1/README.md#bios-files) and
[FBNeo](https://docs.libretro.com/library/fbneo/) documentation. Current upstream
instructions may describe features newer than these locked cores; the configured
PlayStation path expects user-supplied firmware. FBNeo ROM sets must match the
pinned core revision, rather than an arbitrary MAME version. MAME has its own
canonical library directory and core so its sets are kept separate from FBNeo.
Keypad/vector systems retain their core-specific configuration requirements. Arcade defaults to unfiltered output. Its alternatives
include horizontal CRT and two vertical CRT directions; select the appropriate
alternative per game rather than applying a single orientation to the library.
Real-game orientation acceptance remains pending.

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
| Switch | Eden | Supply your own required keys/firmware; native SDL launch route, with the Eden GUI available for setup |
| PS Vita | Vita3K | Install firmware/content in Vita3K; frontend entries use `.psvita` installed-title markers |
| PS4 | shadPS4 | Experimental unpacked-folder/ELF route; supply required dumped modules/content yourself |

Open the native emulator directly to complete setup before launching firmware-
dependent games from ES-DE. Firmware, keys and credentials are never supplied by
Nix or downloaded automatically. The frontend routes do not complete these setup
wizards. Xbox One has no configured emulator route. Platforms beyond the
generation-eight scope, such as PS5 and Xbox Series, are not included.
PS3 disc dumps receive `.ps3dir` aliases in a separate managed view; original
folder names remain unchanged. Discovery recognizes complete disc layouts with
`PS3_GAME/PARAM.SFO` and `PS3_GAME/USRDIR/EBOOT.BIN` at the platform root or one
directory below it. ISO entries retain their names. Incomplete dumps and other
directory layouts are not automatically indexed. Installed PSN titles still use
RPCS3's own library; this does not install games, firmware or licenses.
PS4 uses the same non-destructive directory-view approach: complete folders
with `eboot.bin` and `sce_sys/param.sfo` receive `.ps4dir` aliases, while standalone
ELF names are preserved. A platform mapping can point to one complete game folder
or a parent directory containing games. PKG installation files are not presented
as launchable games. Open shadPS4's own UI with `shadps4 -b` for setup.
For manual artwork, ES-DE retains the directory suffix in media filenames:
`Game.ps4dir` uses `downloaded_media/ps4/covers/Game.ps4dir.png` beneath the
frontend data directory; PS3 directory aliases follow the same convention.
Ordinary game files use their filename without the extension.

For Vita, install the title in Vita3K first, then place a small text marker in
your Vita library directory. For example, `Display Name.psvita` containing the
installed title ID `PCSF00007` becomes a frontend entry. The display filename can
be chosen freely; the helper reads and validates the ID from the file and passes
it as one argument, with fullscreen enabled. Installation archives (`.vpk`, `.zip`,
`.pkg`) are deliberately not launched from the frontend. See the
[ES-DE Vita guide](https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md#sony-playstation-vita).
The pinned Vita3K AppImage uses X11 through Xwayland; `retro-vita3k` selects its
bundled xcb backend. For direct setup use `QT_QPA_PLATFORM=xcb vita3k`. Normal GUI
startup was checked with an empty temporary home. This build's help invocation
can abort on an empty configuration path; its launch flags were checked against
the exact build source. No emulator update or firmware download is performed by
these helpers. Switch uses Eden's native SDL executable (`eden-cli -f -g`), while
`eden` remains available for initial setup and writable settings.

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
Xbox 360, Wii U and 3DS/N3DS. Classic aliases include NES/Famicom,
SNES/SFC/Super Famicom, GB/Game Boy, GBC/Game Boy Color, SMS/Master System,
MD/Mega Drive/Genesis, GG/Game Gear, SEGACD/Sega CD/Mega CD and 32X/Sega 32X.
Additional aliases cover PSX/PS1/PlayStation, Saturn, DC/Dreamcast,
PCE/PC Engine/TurboGrafx-16, PCECD/PC Engine CD/TurboGrafx-CD, SGX/SuperGrafx,
NEOGEO/Neo Geo, NEOGEOCD/Neo Geo CD, Arcade/FBNeo, Atari 2600/7800, Lynx,
NGP/NGPC and WS/WSC. Canonical lowercase directory names also work; `retro-library map --help` lists
canonical system names. Every canonical name also accepts an uppercase directory
(e.g. `ATARI5200`, `COLECOVISION`, `PSVITA`). New aliases cover Switch, Vita, PS4,
MAME, Atari 5200/Jaguar, ColecoVision, Intellivision, Videopac, Vectrex, 3DO,
PC-FX, CD-i, SG-1000 and Virtual Boy. Multiple matching folders require an explicit mapping.
To use a different location or resolve ambiguous names:

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
| PS3 / PS4 per-game aliases and ownership manifests | `~/.local/share/hon-retro/ps3/`, `ps4/`, `ps3-view.json`, `ps4-view.json` |
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

Home-console RetroArch routes, including NES/FDS, SNES, N64, Master System,
Mega Drive, Sega CD, 32X, PlayStation, Saturn, Dreamcast, PC Engine, Neo Geo and
Atari 2600/7800, offer Mega Bezel's standard Guest-based CRT presentation by
default, with an **Unfiltered**
alternative in ES-DE's emulator selection. GBA offers an LCD grid with GBA colour
correction and an unfiltered alternative. GB/GBC, Game Gear, Lynx, Neo Geo
Pocket/Color and WonderSwan/Color now offer a generic LCD grid and an unfiltered alternative.
This grid uses the core's ratio without GBA-specific colour correction; authentic
DMG/panel calibration and portrait-layout acceptance remain pending. GameCube
continues to use Dolphin's native rendering; a comparable standalone CRT pipeline
is still pending.

Manual launches can select the same presentation:

```sh
retro-play --profile n64 --presentation crt [RetroArch arguments]
retro-play --presentation gba-lcd [RetroArch arguments]
retro-play --presentation lcd [RetroArch arguments]
retro-play --presentation crt-vertical [RetroArch arguments]
retro-play --presentation crt-vertical-cw [RetroArch arguments]
retro-play --presentation raw [RetroArch arguments]
```

These options must precede ordinary RetroArch arguments. Omitting presentation
preserves the writable base settings. The CRT choice fills the output viewport
and lets Mega Bezel maintain the inner image ratio; LCD and unfiltered choices
use the core's ratio. Do not copy the CRT viewport setting to other pipelines.
The CRT intro is disabled and reflections are reduced. These are starting
presets, with PVM tuning, real-game performance and actual-display review pending.

For FBNeo vertical games, **CRT Vertical CCW** (`crt-vertical`) follows the
pinned Mega Bezel FBNeo variation: it rotates the raw framebuffer counterclockwise
and uses a vertical 3:4 CRT tube. **CRT Vertical CW** (`crt-vertical-cw`) reverses
that turn. Both disable RetroArch's own rotation to avoid a second rotation;
the shader owns that operation. Keep FBNeo's Vertical Mode at its default
**disabled** when evaluating these choices. This is for a normal landscape
monitor, not a physically rotated display. Test title orientation, controls and
aspect before saving a per-game emulator choice in ES-DE. Synthetic patterns
verify both shader directions; no actual arcade title has been used yet.

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
| Pro 3, 2.4 GHz receiver | `2dc8:310b` | Face/shoulder/system/stick buttons, D-pad, full stick and analog trigger travel verified; user felt both rumble pulses; extra-button and motion limits described below |
| Original GameCube controller, official USB adapter | `057e:0337` | Native USB access, port 1, face/system buttons, D-pad, both sticks, separate analog trigger travel/digital L/R clicks, and sustained rumble verified; gameplay checks pending |

RetroArch normally requests the shared `310b` receiver device for player one.
The Pro 3 and the Ultimate 2 can both identify that way; using either in the same
slot is intentional, with only one connected at a time. Dreamcast's Ultimate
profile retains the previously verified `6012` mode preference and can fall back
to the available `310b` pad. N64 requests the 64. These are preferred, nonexclusive
native VID/PID reservations, rather than joystick enumeration indices. The 64's C buttons also
emit right-stick directions. Its custom profile uses the raw udev layout.
The Ultimate and Pro 3 profiles use RetroArch's standardized SDL GameController
layout; raw SDL joystick and evdev button numbers must not be substituted for it.
SDL advertises Ultimate motion sensors, but sensor behaviour is not yet tested.
Isolated RetroArch sessions confirmed that both custom profiles load and that
the N64 launch reassigns the 64 to player one even when it is enumerated later.
New isolated sessions also confirmed the shared `310b` autoconfig loads in
default, Pro 3 and Ultimate launch profiles, with base configs preserved. These
sessions loaded no game and do not establish gameplay or audio compatibility.

The Pro 3 receiver reports the misleading joystick name **8BitDo Ultimate 2
Wireless Controller**. Its identity was confirmed by switching only the Pro 3
off/on: receiver `310b` changes to idle `3109`, then returns to `310b`; the
Ultimate 2 receiver remains separate. With both pads powered on, the Ultimate 2
also reported `2dc8:310b` and the same
SDL name. The installed `310b` autoconfig is therefore deliberately shared, and
its display label names both controllers. The firmware-version portion of their
SDL GUIDs differs, but no version- or port-based disambiguation is configured.
Manual `--profile pro3` selects this shared preference, not a unique physical pad.
This does not configure other Pro 3 transports/modes. SDL advertises no
accelerometer or gyro in this receiver mode. Star and extra buttons produced no joystick events;
controller keyboard/mouse interfaces were not captured, and extras stay unassigned.
The accepted tests were repeated after charging, with no detach detected during
those captures; earlier disconnecting captures were discarded as provisional.

Profiles can be selected explicitly for a manual RetroArch launch:

```sh
retro-play --profile pro3 [RetroArch arguments]
retro-play --profile ultimate2 [RetroArch arguments]
retro-play --profile n64 [RetroArch arguments]
```

All three profiles configure a Select/Back modifier: Start exits, Home opens
the menu, L/LB saves state and R/RB loads state. On SDL pads the bottom face button
pauses and holding the right face button fast-forwards; on the 64 these are A
and B respectively. These
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
need acceptance tests. Pro 3 gameplay and native-emulator assignments remain pending.
Both adapter USB plugs are needed for rumble: the grey plug supplies motor power.
With it connected, the user confirmed normal sustained rumble during a five-second
native USB test. Short-pulse tests had been inconclusive.

## RetroAchievements

Achievements are off by default. `retro-achievements` can import a login token
saved by RetroArch into private runtime files. It does not implement a separate
login service, store your password or put credentials in Nix. Authentication and
actual achievement unlocks still require user acceptance with supported games.

First use RetroArch's own account UI. Before entering credentials, ensure the
writable configuration is private:

```sh
retro-play --achievements off --version
chmod 600 "${XDG_CONFIG_HOME:-$HOME/.config}/hon-retro/retroarch.cfg"
retro-play --achievements off
```

In RetroArch, enable achievements for that setup session, sign in under
**Settings → User → Accounts → RetroAchievements**, and use **Save Current
Configuration** after RetroArch has obtained its login token. The managed default
remains off on subsequent launches. Then import the private saved config:

```sh
retro-achievements import "${XDG_CONFIG_HOME:-$HOME/.config}/hon-retro/retroarch.cfg"
retro-achievements mode softcore
retro-achievements status
```

Import copies only `cheevos_username` and `cheevos_token`; the source config is
preserved, including any password RetroArch itself saved there. If no token is
present, complete login in RetroArch and save again. Native login/token refresh
has not been tested with the user's account; re-import after refreshing a token.
The helper rejects source files readable by other users, links and malformed
credentials. Status never prints account names or tokens.

The preference applies to `retro-play`, including frontend launches. Switch it
off with `retro-achievements mode off`, or override it for one launch:

```sh
retro-play --achievements off [RetroArch arguments]
retro-play --achievements softcore [RetroArch arguments]
retro-play --achievements hardcore [RetroArch arguments]
```

Hardcore is available only as an explicit launch option; it cannot be saved as
the helper's default. RetroArch enforces its hardcore restrictions on states,
rewind and cheats; automatic state loading is additionally disabled for that
launch. Do not regard the hotkey/state combination as physically accepted yet.
Achievements use the normal service endpoint, with rich presence and verbose
achievement diagnostics disabled. Explicit diagnostic logging is rejected while
authenticated; use `--achievements off` for rendering/debug probes. All helper
options must precede ordinary RetroArch arguments.

Imported credentials and session fragments live under
`~/.config/hon-retro/achievements/` (respecting XDG). The directory is mode 0700
and its files are mode 0600. New RetroArch base configs are private too; an
authenticated launch tightens an existing owned base config to 0600 without
changing its contents. Automatic config saving stays disabled. Explicitly saving
a configuration can merge credentials into the base file, so keep that file
private. Softcore/hardcore session fragments are separate to prevent simultaneous
launches from changing each other's mode. Native standalone emulators retain
their own account configuration and compatibility requirements.

## Read-only library audits

`retro-audit` inventories regular files recursively and uses SHA-256 to report
byte-identical groups. It hashes only files sharing a size with another file.
Filenames do not determine duplicate status, and the report makes no region or
revision judgements. Hard-linked names include a `distinct_inodes` count so they
are not mistaken for independent copies consuming extra disk space.

```sh
retro-audit "/path/to/ROMs" --output "/path/outside/library/duplicates.json"
```

The report must be a new file outside the source library. It is created with
mode 0600; existing files or links are never replaced. Omit `--output` for JSON
on stdout. Source symlinks and special files are skipped, including symlink loops
and links escaping the root. Use a real source directory rather than the managed
symlink view to inspect its contents. The command detects changes before/during
hashing and returns an incomplete report with errors if files become unreadable
or change; use a quiet library for a useful snapshot. Exit codes are 0 for a
completed scan (including scans finding duplicates), 1 for scan/hash errors or
DAT mismatches/incomplete verification, and
2 for invalid input or report-write failure.

The duplicate groups compare whole files. Different archive compression can hide
identical internal ROMs, and identical files may be required in multiple sets.
The tool never deletes, moves, renames, converts or repairs anything; do not treat
a duplicate report as a safe deletion list.

For optional content verification, supply your own UTF-8 Logiqx XML DAT and select
a source directory appropriate to that DAT:

```sh
retro-audit "/path/to/one-system" --dat "/path/to/matching-core.dat" \
  --zip-members --output "/path/outside/library/verification.json"
```

No DAT or game content is downloaded. The report records the DAT's name, version
and SHA-256, plus matching, missing and unrecognized content. Matches require the
declared byte size and every supplied checksum (CRC32, MD5, SHA-1, SHA-256),
independent of filenames. A CRC-only DAT provides weaker evidence than a DAT
containing stronger checksums. DAT dump-status and merge metadata are retained;
a checksum match does not turn a known bad dump into a good dump. Undumped ROMs
are listed separately; entries without checksums remain unverified.

`--zip-members` streams ZIP members for matching without writing extracted files.
Members with traversal-like names are treated as data, never filesystem paths.
Archive symlinks are skipped, and corrupt/encrypted/unsupported archives or changed
sources produce incomplete results. The default decompressed member limit is
512 MiB; use `--max-member-bytes N` for a deliberate different limit. Oversized
members are reported as skipped. Without `--zip-members`, archives are treated as
whole files. 7z/RAR member verification is not implemented.

Keep DAT files and reports outside the source directory. DATs are limited to
64 MiB; internal DTD/entity declarations are rejected and external DTDs are never
resolved. Verification does not establish parent-set, CHD or board completeness,
nor prove compatibility with an emulator. Use a DAT from the exact chosen core
revision where that matters. All audit tests use synthetic fixtures; no audit has
been run on the user's games.

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
frontend check uses the generated system/discovery definitions and real theme
in isolated headless Wayland. GBA, PS3, PS4, Switch, Vita, MAME, Atari 5200 and
PC-FX fixtures route only to an inert command. Paths include spaces, including
the fake emulator path. Checks preserve manual names, favorites, cover images
and launch history across a forced frontend termination/restart. Screenshot
checks require the supplied cover to render before and after restart, while verifying
that source bytes and file lists are unchanged. No emulator game execution or
GPU performance benchmark is involved.
PS3 view tests also cover ordinary dump-folder aliases, ISO preservation, name
collisions, single-dump mappings, missing sources and upgrading the previous
platform-root link without modifying frontend metadata. Classic tests preserve
relative cue-sheet/track/playlist paths and require explicit selection when
regional aliases such as Genesis and Mega Drive both exist.

The optional manual rendering check opens short-lived Vulkan windows inside a
Wayland desktop, uses generated test images, and keeps all settings temporary:

```sh
python tests/retro-render.py /path/to/retro-play /tmp/retro-render-check
```

It requires a new output directory and records logs and screenshots for CRT,
GBA LCD, generic LCD, both vertical CRT directions and unfiltered output. It checks shader compilation,
successful exit and base-config preservation. The original four and both vertical CRT directions passed on the RX 9070 XT;
these checks do not measure game performance or establish calibrated PVM
reproduction.

Further optional acceptance covers controller-only navigation/reconnect,
DolphinBar IR/motion after purchase, presentation tuning and game/save behaviour.
Those gameplay checks are separate from the current library/frontend completion
gate. Xbox One, Jaguar CD and systems beyond generation eight are not claimed
by these routes. Actual titles still depend on emulator compatibility and setup.
