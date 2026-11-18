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
    # Check everything before touching the view. Never replace foreign entries.
    for system, target in selected.items():
        source = Path(target)
        if source == view or view in source.parents or source in view.parents:
            raise ValueError(f"Library mapping would create a recursive view: {source}")
        link = view / system
        if link.is_symlink():
            if os.readlink(link) not in (previous.get(system), target):
                raise ValueError(f"Unmanaged link preserved: {link}")
        elif link.exists():
            raise ValueError(f"Existing directory/file preserved: {link}")
    view.mkdir(parents=True, exist_ok=True)
    for system, target in selected.items():
        link = view / system
        if link.is_symlink() and os.readlink(link) != target:
            link.unlink()
        if not link.is_symlink():
            link.symlink_to(target, target_is_directory=True)
    # Missing systems retain their old link and metadata, including disconnected media.
    write_json(manifest, previous | selected)
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
        }.items():
            ET.SubElement(root, "string", name=key, value=value)
        ET.SubElement(root, "bool", name="ScraperOverwriteData", value="false")
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
