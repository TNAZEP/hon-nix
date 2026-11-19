"""Validate generated frontend routes against the installed emulator/core paths."""

from pathlib import Path
import ctypes
import re
import sys
import xml.etree.ElementTree as ET

systems = ET.parse(sys.argv[1]).getroot()
rules = ET.parse(sys.argv[2]).getroot()
emulators = {
    node.attrib["name"]: Path(node.find("rule[@type='staticpath']/entry").text)
    for node in rules.findall("emulator")
}
cores = {
    node.attrib["name"]: Path(node.find("rule[@type='corepath']/entry").text)
    for node in rules.findall("core")
}
names = [system.findtext("name") for system in systems.findall("system")]
assert len(names) == len(set(names)), "Duplicate custom frontend system"
assert {"nes", "snes", "gb", "gbc", "mastersystem", "megadrive", "gamegear",
        "segacd", "sega32x", "psx", "saturn", "dreamcast", "pcengine",
        "pcenginecd", "supergrafx", "neogeo", "neogeocd", "arcade", "atari2600",
        "atari7800", "atarilynx", "ngp", "ngpc", "wonderswan", "wonderswancolor"
        } <= set(names), "Missing classic frontend routes"
# Disc tracks must stay available to their cue sheets without becoming games.
cd_extensions = systems.find("system[name='segacd']/extension").text.split()
assert {".cue", ".chd", ".m3u", ".CUE", ".CHD", ".M3U"} <= set(cd_extensions)
assert not {".bin", ".BIN", ".zip", ".ZIP", ".7z", ".7Z"} & set(cd_extensions)
for name in ("psx", "saturn", "dreamcast", "pcenginecd", "neogeocd"):
    extensions = systems.find(f"system[name='{name}']/extension").text.split()
    assert not {".bin", ".BIN", ".zip", ".ZIP", ".7z", ".7Z"} & set(extensions), name
# Vertical arcade output retains the core's geometry until CRT rotation is tested.
assert "--presentation raw" in systems.find("system[name='arcade']/command").text
arcade_commands = {command.attrib["label"]: command.text
                   for command in systems.find("system[name='arcade']").findall("command")}
assert "--presentation crt-vertical -L" in arcade_commands["FinalBurn Neo (CRT Vertical CCW)"]
assert "--presentation crt-vertical-cw -L" in arcade_commands["FinalBurn Neo (CRT Vertical CW)"]
checked_cores = set()
for system in systems.findall("system"):
    assert system.findtext("path").startswith("%ROMPATH%/"), "Runtime library path required"
    for command in system.findall("command"):
        for name in re.findall(r"%EMULATOR_([\w-]+)%", command.text):
            assert name in emulators, f"Missing emulator rule: {name}"
            assert emulators[name].is_file(), f"Missing executable: {emulators[name]}"
        for name, filename in re.findall(r"%CORE_([\w-]+)%/([^\s]+)", command.text):
            assert name in cores, f"Missing core rule: {name}"
            core = cores[name] / filename
            assert core.is_file(), f"Missing core: {filename}"
            if core not in checked_cores:
                # Load the shared library and check its ABI, without initializing
                # the emulator, opening firmware or executing game content.
                library = ctypes.CDLL(str(core))
                assert library.retro_api_version() == 1, f"Unexpected core ABI: {filename}"
                for symbol in ("retro_get_system_info", "retro_init", "retro_load_game", "retro_run"):
                    assert getattr(library, symbol), f"Missing {symbol}: {filename}"
                checked_cores.add(core)
print(f"Validated {len(names)} custom systems and their installed launch targets")
print(f"Loaded {len(checked_cores)} core libraries and checked the libretro ABI")
