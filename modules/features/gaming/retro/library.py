"""Writable library preferences and a non-destructive ES-DE directory view."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile
import xml.etree.ElementTree as ET


# Folder aliases, not private library paths. Explicit mappings take precedence.
ALIASES = {
    "switch": ["switch", "Switch", "SWITCH"],
    "psvita": ["psvita", "PSVITA", "Vita", "PS Vita"],
    "ps4": ["ps4", "PS4", "PlayStation 4"],
    "atari5200": ["atari5200", "Atari 5200", "A5200"],
    "colecovision": ["colecovision", "ColecoVision", "Coleco"],
    "intellivision": ["intellivision", "Intellivision", "INTV"],
    "odyssey2": ["odyssey2", "Odyssey2", "Videopac"],
    "vectrex": ["vectrex", "Vectrex", "VECTREX"],
    "3do": ["3do", "3DO"],
    "atarijaguar": ["atarijaguar", "Atari Jaguar", "Jaguar"],
    "pcfx": ["pcfx", "PC-FX", "PCFX"],
    "cdimono1": ["cdimono1", "CD-i", "CDI"],
    "mame": ["mame", "MAME"],
    "sg-1000": ["sg-1000", "SG-1000", "SG1000"],
    "virtualboy": ["virtualboy", "Virtual Boy", "VB"],
    "psx": ["psx", "PSX", "PS1", "PlayStation"],
    "saturn": ["saturn", "Saturn", "SATURN"],
    "dreamcast": ["dreamcast", "Dreamcast", "DC"],
    "pcengine": ["pcengine", "PC Engine", "PCE", "TurboGrafx-16"],
    "pcenginecd": ["pcenginecd", "PC Engine CD", "PCECD", "TurboGrafx-CD"],
    "supergrafx": ["supergrafx", "SuperGrafx", "SGX"],
    "neogeo": ["neogeo", "Neo Geo", "NEOGEO"],
    "neogeocd": ["neogeocd", "Neo Geo CD", "NEOGEOCD"],
    "arcade": ["arcade", "Arcade", "FBNeo"],
    "atari2600": ["atari2600", "Atari 2600", "A2600"],
    "atari7800": ["atari7800", "Atari 7800", "A7800"],
    "atarilynx": ["atarilynx", "Atari Lynx", "Lynx", "LYNX"],
    "ngp": ["ngp", "NGP", "Neo Geo Pocket"],
    "ngpc": ["ngpc", "NGPC", "Neo Geo Pocket Color"],
    "wonderswan": ["wonderswan", "WonderSwan", "WS"],
    "wonderswancolor": ["wonderswancolor", "WonderSwan Color", "WSC"],
    "nes": ["nes", "NES", "Famicom"],
    "snes": ["snes", "SNES", "SFC", "Super Famicom"],
    "gb": ["gb", "GB", "Game Boy"],
    "gbc": ["gbc", "GBC", "Game Boy Color"],
    "mastersystem": ["mastersystem", "Master System", "SMS"],
    "megadrive": ["megadrive", "Mega Drive", "Genesis", "MD"],
    "gamegear": ["gamegear", "Game Gear", "GG"],
    "segacd": ["segacd", "Sega CD", "Mega CD", "SEGACD"],
    "sega32x": ["sega32x", "Sega 32X", "32X"],
    "fds": ["fds", "FDS"],
    "n64": ["n64", "N64"],
    "gba": ["gba", "GBA"],
    "gc": ["gc", "GC", "GameCube"],
    "wii": ["wii", "Wii", "WII"],
    "ps2": ["ps2", "PS2"],
    "xbox": ["xbox", "Xbox", "XBOX"],
    "nds": ["nds", "NDS", "DS"],
    "psp": ["psp", "PSP"],
    "ps3": ["ps3", "PS3"],
    "xbox360": ["xbox360", "Xbox360", "Xbox 360", "XBOX360"],
    "wiiu": ["wiiu", "WiiU", "Wii U", "WIIU"],
    "n3ds": ["n3ds", "N3DS", "3DS"],
}
# Canonical ES-DE names work in either lowercase or uppercase for every route.
ALIASES = {system: list(dict.fromkeys([system, system.upper(), *aliases]))
           for system, aliases in ALIASES.items()}


def paths():
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "hon-retro"
    data = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share")) / "hon-retro"
    return config / "library.json", data, data / "frontend"


def load():
    config, _, _ = paths()
    return json.loads(config.read_text()) if config.exists() else {"systems": {}}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as f:
        temporary = Path(f.name)
        json.dump(value, f, indent=2)
        f.write("\n")
    temporary.replace(path)


def directory(value):
    path = Path(value).expanduser().resolve(strict=True)
    if not path.is_dir():
        raise ValueError(f"Not a directory: {path}")
    return str(path)


def validate_source(view, source):
    destination = view.resolve()
    source = source.resolve()
    if source == destination or destination in source.parents or source in destination.parents:
        raise ValueError(f"Library mapping would create a recursive view: {source}")


def validate_links(view, selected, previous):
    if view.is_symlink() or (view.exists() and not view.is_dir()):
        raise ValueError(f"Unmanaged view preserved: {view}")
    for name, target in selected.items():
        validate_source(view, Path(target))
        link = view / name
        if link.is_symlink():
            if os.readlink(link) not in (previous.get(name), target):
                raise ValueError(f"Unmanaged link preserved: {link}")
        elif link.exists():
            raise ValueError(f"Existing directory/file preserved: {link}")


def update_links(view, selected, previous, manifest):
    view.mkdir(parents=True, exist_ok=True)
    for name, target in selected.items():
        link = view / name
        if link.is_symlink() and os.readlink(link) != target:
            link.unlink()
        if not link.is_symlink():
            link.symlink_to(target, target_is_directory=Path(target).is_dir())
    # Missing entries retain their old links and metadata, including disconnected media.
    write_json(manifest, previous | selected)


def directory_entries(source, system):
    layouts = {
        "ps3": ("PS3_GAME/PARAM.SFO", "PS3_GAME/USRDIR/EBOOT.BIN"),
        "ps4": ("sce_sys/param.sfo", "eboot.bin"),
    }
    suffix = f".{system}dir"
    def disc_dump(path):
        return all((path / name).is_file() for name in layouts[system])

    candidates = [source] if disc_dump(source) else sorted(source.iterdir())
    selected = {}
    for path in candidates:
        if path.is_dir() and disc_dump(path):
            name = path.name if path.suffix.lower() == suffix else path.name + suffix
        elif path.is_file() and path.suffix.lower() == (".iso" if system == "ps3" else ".elf"):
            name = path.name
        else:
            continue
        if name in selected:
            raise ValueError(f"Ambiguous {system.upper()} entry: {name}")
        selected[name] = str(path.resolve())
    return selected


def refresh(settings):
    _, data, _ = paths()
    view = data / "roms"
    root = Path(settings["root"]) if settings.get("root") else None
    if root is not None and not root.is_dir():
        raise ValueError(f"Library root is unavailable; existing view preserved: {root}")
    selected = {}
    for system, aliases in ALIASES.items():
        explicit = settings.get("systems", {}).get(system)
        matches = [Path(explicit)] if explicit else [root / a for a in aliases] if root else []
        matches = [p for p in matches if p.is_dir()]
        if len(matches) > 1:
            raise ValueError(f"Ambiguous folders for {system}; use retro-library map {system} PATH")
        if explicit and not matches:
            raise ValueError(f"Mapped directory is unavailable: {explicit}")
        if matches:
            selected[system] = str(matches[0].resolve())
    manifest = data / "library-view.json"
    previous = json.loads(manifest.read_text()) if manifest.exists() else {}
    directory_plans = []
    for system in ("ps3", "ps4"):
        if system not in selected:
            continue
        source = Path(selected[system])
        directory_view = data / system
        # Validate every managed view before inspecting or creating any links.
        validate_links(directory_view, {}, {})
        validate_source(directory_view, source)
        validate_source(view, source)
        directory_manifest = data / f"{system}-view.json"
        directory_previous = json.loads(directory_manifest.read_text()) if directory_manifest.exists() else {}
        directory_selected = directory_entries(source, system)
        validate_links(directory_view, directory_selected, directory_previous)
        directory_plans.append((directory_view, directory_selected, directory_previous, directory_manifest))
        selected[system] = str(directory_view.resolve())
    validate_links(view, selected, previous)
    for plan in directory_plans:
        update_links(*plan)
    update_links(view, selected, previous, manifest)
    return view


def prepare(settings):
    view = refresh(settings)
    _, _, frontend = paths()
    config = frontend / "settings/es_settings.xml"
    if not config.exists():
        config.parent.mkdir(parents=True, exist_ok=True)
        root = ET.Element("settings")
        for key, value in {
            "ROMDirectory": str(view),
            "Theme": "iisu-interpreted-es-de",
            "ThemeColorScheme": "dark",
            "ThemeAspectRatio": "16:9",
            "CollectionSystemsAuto": "all,favorites,recent",
            "InputControllerType": "switchpro",
        }.items():
            ET.SubElement(root, "string", name=key, value=value)
        ET.SubElement(root, "bool", name="ScraperOverwriteData", value="false")
        ET.SubElement(root, "bool", name="InputSwapButtons", value="true")
        # Exclusive creation prevents replacing settings another launch just created.
        try:
            with config.open("xb") as f:
                os.chmod(config, 0o600)
                ET.ElementTree(root).write(f, encoding="utf-8", xml_declaration=True)
        except FileExistsError:
            pass
    return frontend


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status", help="Show writable library settings")
    root = sub.add_parser("set-root", help="Set the library root without moving files")
    root.add_argument("path")
    mapping = sub.add_parser("map", help="Map a supported system to an existing folder")
    mapping.add_argument("system", choices=ALIASES)
    mapping.add_argument("path")
    sub.add_parser("refresh", help="Refresh the managed symlink view")
    sub.add_parser("prepare", help="Initialize missing frontend settings")
    args = parser.parse_args()
    config, _, _ = paths()
    config.parent.mkdir(parents=True, exist_ok=True)
    lock = (config.parent / "library.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX)
    settings = load()
    if args.command == "status":
        print(json.dumps(settings, indent=2))
    elif args.command in ("set-root", "map"):
        if args.command == "set-root":
            settings["root"] = directory(args.path)
        else:
            settings.setdefault("systems", {})[args.system] = directory(args.path)
        refresh(settings)
        write_json(config, settings)
        print(f"Saved library preferences: {config}")
    elif args.command == "refresh":
        print(refresh(settings))
    elif args.command == "prepare":
        print(prepare(settings))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        sys.exit(f"retro-library: {exc}")
