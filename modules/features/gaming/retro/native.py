"""Translate frontend markers/directories into native emulator launch arguments."""

import argparse
import os
from pathlib import Path
import re
import sys


def command(system, emulator, target):
    path = Path(target).expanduser().resolve(strict=True)
    if system == "vita":
        if not path.is_file() or path.suffix.lower() != ".psvita":
            raise ValueError("Vita launch needs a .psvita title-ID marker, not an installation archive")
        with path.open(encoding="utf-8-sig") as stream:
            content = stream.read(129)
        if len(content) > 128:
            raise ValueError("Vita title-ID marker is too large")
        title = content.strip()
        if not re.fullmatch(r"[A-Z0-9_]{1,32}", title):
            raise ValueError("Vita marker must contain only the installed title ID")
        return [emulator, "--fullscreen", "-r", title]
    if path.is_dir():
        if not (path / "sce_sys/param.sfo").is_file():
            raise ValueError("PS4 folder needs sce_sys/param.sfo")
        path = path / "eboot.bin"
    if not path.is_file() or (path.name != "eboot.bin" and path.suffix.lower() != ".elf"):
        raise ValueError("PS4 launch needs an unpacked game folder, eboot.bin or ELF")
    return [emulator, "--fullscreen", "true", "--game", str(path)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("system", choices=("vita", "ps4"))
    parser.add_argument("emulator")
    parser.add_argument("target")
    args = parser.parse_args()
    try:
        argv = command(args.system, args.emulator, args.target)
        os.execv(argv[0], argv)
    except (OSError, ValueError) as error:
        sys.exit(f"retro-native: {error}")


if __name__ == "__main__":
    main()
