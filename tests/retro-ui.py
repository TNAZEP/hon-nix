"""Launch ES-DE in private headless Wayland; launch only an inert fixture."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


def wait_for(predicate, label, timeout=30):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.1)
    raise AssertionError(f"Timed out: {label}")


frontend, theme, library, output = map(Path, sys.argv[1:5])
platform = sys.argv[5] if len(sys.argv) > 5 else "gba"
assert platform in ("gba", "ps3")
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
if platform == "ps3":
    game = roms / "Fixture Game"
    fixture_file = game / "PS3_GAME/USRDIR/EBOOT.BIN"
    fixture_file.parent.mkdir(parents=True)
    (game / "PS3_GAME/PARAM.SFO").write_bytes(b"inert metadata")
else:
    game = roms / "Fixture Game.gba"
    fixture_file = game
fixture_file.write_bytes(b"inert test file, not a game")
subprocess.run([sys.executable, str(library), "set-root", str(roms.parent)], check=True)
subprocess.run([sys.executable, str(library), "prepare"], check=True)
app = base / "data/hon-retro/frontend"
os.environ["ESDE_APPDATA_DIR"] = str(app)
(app / "themes").mkdir()
(app / "themes/iisu-interpreted-es-de").symlink_to(theme)
custom = app / "custom_systems"
custom.mkdir()
marker = base / "launched.json"
stub = base / "launch-fixture"
stub.write_text(
    f"#!{sys.executable}\nimport json, sys, time\n"
    f"from pathlib import Path\nPath({str(marker)!r}).write_text(json.dumps(sys.argv[1:]))\ntime.sleep(1)\n"
)
stub.chmod(0o755)
systems = ET.Element("systemList")
ET.SubElement(systems, "loadExclusive")
system = ET.SubElement(systems, "system")
for key, value in {
    "name": platform, "fullname": "PlayStation 3" if platform == "ps3" else "Game Boy Advance",
    "path": f"%ROMPATH%/{platform}", "extension": ".ps3dir" if platform == "ps3" else ".gba",
    "command": f'"{stub}" %ROM%', "platform": platform, "theme": platform,
}.items():
    ET.SubElement(system, key).text = value
ET.ElementTree(systems).write(custom / "es_systems.xml")
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
    subprocess.run(["wtype", "-P", "Return", "-s", "150", "-p", "Return"], check=True, timeout=10)
    wait_for(marker.exists, "inert game launch")
    assert Path(json.loads(marker.read_text())[0]).resolve() == game
    time.sleep(2)
    assert processes[-1].poll() is None, "Frontend exited instead of returning to library"
    subprocess.run(["grim", str(output / "returned.png")], check=True)
    assert fixture_file.read_bytes() == b"inert test file, not a game"
    log_files = list((app / "logs").glob("*.txt"))
    for path in log_files:
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
