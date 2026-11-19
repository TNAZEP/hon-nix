"""Launch ES-DE in private headless Wayland; launch only an inert fixture."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import struct
import zlib
from PIL import Image


def wait_for(predicate, label, timeout=30):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.1)
    raise AssertionError(f"Timed out: {label}")


frontend, theme, library, output = map(Path, sys.argv[1:5])
platform = sys.argv[5] if len(sys.argv) > 5 else "gba"
fixtures = {"gba": ".gba", "ps3": ".ps3dir", "ps4": ".ps4dir", "switch": ".nsp",
            "psvita": ".psvita", "mame": ".zip", "atari5200": ".a52", "pcfx": ".cue"}
assert platform in fixtures
source_systems, source_rules = map(Path, sys.argv[6:8])
output.mkdir(parents=True)
base = Path.cwd() / f"fixture-{platform}"
base.mkdir()
runtime = base / "run"
runtime.mkdir(mode=0o700)
os.environ.update(
    HOME=str(base), XDG_CONFIG_HOME=str(base / "config"),
    XDG_DATA_HOME=str(base / "data"), XDG_RUNTIME_DIR=str(runtime),
    WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman",
    LIBGL_ALWAYS_SOFTWARE="1", SDL_VIDEODRIVER="wayland", SDL_AUDIODRIVER="dummy",
)
roms = base / "My Stuff/ROMS" / platform.upper()
roms.mkdir(parents=True)
if platform in ("ps3", "ps4"):
    game = roms / "Fixture Game"
    fixture_file = game / ("PS3_GAME/USRDIR/EBOOT.BIN" if platform == "ps3" else "eboot.bin")
    fixture_file.parent.mkdir(parents=True)
    metadata = game / ("PS3_GAME/PARAM.SFO" if platform == "ps3" else "sce_sys/param.sfo")
    metadata.parent.mkdir(parents=True, exist_ok=True)
    metadata.write_bytes(b"inert metadata")
else:
    game = roms / ("Fixture Game" + fixtures[platform])
    fixture_file = game
payload = b"PCSF00007\n" if platform == "psvita" else b"inert test file, not a game"
fixture_file.write_bytes(payload)
original_files = {str(path.relative_to(roms)): path.read_bytes() for path in roms.rglob("*") if path.is_file()}
subprocess.run([sys.executable, str(library), "set-root", str(roms.parent)], check=True)
subprocess.run([sys.executable, str(library), "prepare"], check=True)
app = base / "data/hon-retro/frontend"
os.environ["ESDE_APPDATA_DIR"] = str(app)
(app / "themes").mkdir()
(app / "themes/iisu-interpreted-es-de").symlink_to(theme)
custom = app / "custom_systems"
custom.mkdir()
marker = base / "launched.json"
stub = base / "Emulator With Spaces/launch-fixture"
stub.parent.mkdir()
stub.write_text(
    f"#!{sys.executable}\nimport json, sys, time\n"
    f"from pathlib import Path\nPath({str(marker)!r}).write_text(json.dumps(sys.argv[1:]))\ntime.sleep(1)\n"
)
stub.chmod(0o755)
systems = ET.Element("systemList")
ET.SubElement(systems, "loadExclusive")
system = ET.parse(source_systems).getroot().find(f"system[name='{platform}']")
assert system is not None, f"Missing generated route: {platform}"
systems.append(system)
ET.ElementTree(systems).write(custom / "es_systems.xml")
rules = ET.parse(source_rules)
for entry in rules.findall(".//emulator/rule[@type='staticpath']/entry"):
    entry.text = str(stub)
rules.write(custom / "es_find_rules.xml")
# Preserve a manual title/favorite across a real frontend launch and restart.
frontend_name = "Fixture Game" + fixtures[platform]
# ES-DE retains the suffix when getStem() is called on a directory game.
media_name = frontend_name if platform in ("ps3", "ps4") else "Fixture Game"
cover = app / f"downloaded_media/{platform}/covers/{media_name}.png"
cover.parent.mkdir(parents=True)
def png_chunk(kind, data):
    return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data))
pixels = b"".join(b"\0" + b"".join(bytes((32, 180, 220) if (x // 8 + y // 8) % 2 else (220, 100, 48))
                                  for x in range(64)) for y in range(96))
cover_bytes = (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack("!IIBBBBB", 64, 96, 8, 2, 0, 0, 0))
               + png_chunk(b"IDAT", zlib.compress(pixels)) + png_chunk(b"IEND", b""))
cover.write_bytes(cover_bytes)


def assert_cover_visible(path):
    colors = Image.open(path).convert("RGB").getcolors(1920 * 1080)
    counts = dict((color, count) for count, color in colors)
    assert counts.get((32, 180, 220), 0) > 1000, "Cover art was not rendered"
    assert counts.get((220, 100, 48), 0) > 1000, "Cover art was not rendered"


metadata_path = app / f"gamelists/{platform}/gamelist.xml"
metadata_path.parent.mkdir(parents=True)
gamelist = ET.Element("gameList")
entry = ET.SubElement(gamelist, "game")
for key, value in {"path": f"./{frontend_name}", "name": "Manual Favourite Name",
                   "favorite": "true", "playcount": "7"}.items():
    ET.SubElement(entry, key).text = value
ET.ElementTree(gamelist).write(metadata_path)
sway_config = base / "sway.conf"
sway_config.write_text("xwayland disable\noutput * mode 1920x1080\nseat seat0 fallback true\n")
processes = []
try:
    with (output / "sway.log").open("w") as log:
        processes.append(subprocess.Popen(["sway", "-c", str(sway_config)], stdout=log, stderr=log))
    wait_for(lambda: list(runtime.glob("wayland-*")), "Wayland socket")
    os.environ["WAYLAND_DISPLAY"] = next(p.name for p in runtime.glob("wayland-*") if not p.name.endswith(".lock"))
    wait_for(lambda: list(runtime.glob("sway-ipc.*.sock")), "Sway IPC")
    os.environ["SWAYSOCK"] = str(next(runtime.glob("sway-ipc.*.sock")))
    # Retain keyboard capability/focus between transient wtype invocations.
    # Same headless-Sway fixture requirement as the desktop-shell checks.
    processes.append(subprocess.Popen(["wtype", "-s", "180000"]))
    with (output / "frontend.log").open("w") as log:
        processes.append(subprocess.Popen([str(frontend), "--no-splash", "--debug"], stdout=log, stderr=log))
    def visible():
        if processes[-1].poll() is not None:
            raise AssertionError("Frontend exited during startup")
        tree = subprocess.check_output(["swaymsg", "-t", "get_tree"], text=True)
        return "es-de" in tree.lower() and processes[-1].poll() is None
    wait_for(visible, "frontend window")
    subprocess.run(["swaymsg", '[app_id="es-de"] focus'], check=True, stdout=subprocess.DEVNULL)
    time.sleep(4)
    subprocess.run(["grim", str(output / "system.png")], check=True)
    # Keyboard defaults: Enter selects; no physical input devices are involved.
    subprocess.run(["wtype", "-P", "Return", "-s", "150", "-p", "Return"], check=True, timeout=10)
    time.sleep(1)
    subprocess.run(["grim", str(output / "games.png")], check=True)
    assert_cover_visible(output / "games.png")
    subprocess.run(["wtype", "-P", "Return", "-s", "150", "-p", "Return"], check=True, timeout=10)
    wait_for(marker.exists, "inert game launch")
    arguments = json.loads(marker.read_text())
    assert Path(arguments[-1]).resolve() == game, arguments
    time.sleep(2)
    assert processes[-1].poll() is None, "Frontend exited instead of returning to library"
    subprocess.run(["grim", str(output / "returned.png")], check=True)
    assert fixture_file.read_bytes() == payload
    def history_saved():
        try:
            return ET.parse(metadata_path).findtext("game/playcount") == "8"
        except (OSError, ET.ParseError):
            return False
    wait_for(history_saved, "launch history write")
    # Crash only this private test frontend after its launch-history flush.
    # The restart must preserve manual metadata and the completed launch record.
    processes[-1].kill()
    processes[-1].wait(timeout=10)
    saved = ET.parse(metadata_path).getroot().find("game")
    assert saved.findtext("name") == "Manual Favourite Name", "Manual title changed"
    assert saved.findtext("favorite") == "true", "Favorite was lost"
    assert int(saved.findtext("playcount")) == 8, "Launch history did not persist"
    with (output / "restart.log").open("w") as log:
        processes.append(subprocess.Popen([str(frontend), "--no-splash", "--debug"], stdout=log, stderr=log))
    wait_for(visible, "frontend restart")
    time.sleep(2)
    subprocess.run(["wtype", "-P", "Return", "-s", "150", "-p", "Return"], check=True, timeout=10)
    time.sleep(1)
    subprocess.run(["grim", str(output / "restarted.png")], check=True)
    assert_cover_visible(output / "restarted.png")
    assert ET.parse(metadata_path).findtext("game/favorite") == "true"
    assert cover.read_bytes() == cover_bytes, "Manual cover image changed"
    assert {str(path.relative_to(roms)): path.read_bytes() for path in roms.rglob("*") if path.is_file()} == original_files
    (output / "gamelist.xml").write_bytes(metadata_path.read_bytes())
    (output / "launch-arguments.json").write_text(json.dumps(arguments, indent=2) + "\n")
    log_files = list((app / "logs").glob("*.txt"))
    for path in log_files:
        warnings = [line for line in path.read_text().splitlines() if " Error:" in line or " Warn:" in line]
        assert not warnings, warnings
        (output / path.name).write_text(path.read_text())
finally:
    if sys.exc_info()[0] is not None:
        for path in [output / "sway.log", output / "frontend.log"]:
            if path.exists():
                print(f"{path.name}:\n{path.read_text()[-12000:]}", flush=True)
    for process in reversed(processes):
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
