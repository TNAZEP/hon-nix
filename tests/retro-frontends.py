"""Validate generated frontend routes against the installed emulator/core paths."""

from pathlib import Path
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
        "segacd", "sega32x"} <= set(names), "Missing classic frontend routes"
# Disc tracks must stay available to their cue sheets without becoming games.
cd_extensions = systems.find("system[name='segacd']/extension").text.split()
assert {".cue", ".chd", ".m3u", ".CUE", ".CHD", ".M3U"} <= set(cd_extensions)
assert not {".bin", ".BIN", ".zip", ".ZIP", ".7z", ".7Z"} & set(cd_extensions)
for system in systems.findall("system"):
    assert system.findtext("path").startswith("%ROMPATH%/"), "Runtime library path required"
    for command in system.findall("command"):
        for name in re.findall(r"%EMULATOR_([\w-]+)%", command.text):
            assert name in emulators, f"Missing emulator rule: {name}"
            assert emulators[name].is_file(), f"Missing executable: {emulators[name]}"
        for name, filename in re.findall(r"%CORE_([\w-]+)%/([^\s]+)", command.text):
            assert name in cores, f"Missing core rule: {name}"
            assert (cores[name] / filename).is_file(), f"Missing core: {filename}"
print(f"Validated {len(names)} custom systems and their installed launch targets")
