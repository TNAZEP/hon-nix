"""Exercise the real shell in headless Wayland with private buses and inert actions.

Sway supplies software-rendered layer-shell surfaces. A small Hyprland IPC fixture
supplies monitor/workspace events; the compositor dispatchers have separate Lua
checks. No session action or application from the developer's machine is run.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time


def wait_for(predicate, description, timeout=10):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(f"Timed out: {description}")


class HyprlandFixture:
    def __init__(self, runtime):
        directory = runtime / "hypr" / "fixture"
        directory.mkdir(parents=True)
        self.listeners = []
        self.requests = []
        self.focused = 0
        self.workspaces = [
            {"id": i + 1, "name": str(i + 1), "monitor": f"HEADLESS-{i // 10 + 1}", "monitorID": i // 10}
            for i in range(20)
        ]
        for name, events in [(".socket.sock", False), (".socket2.sock", True)]:
            server = socket.socket(socket.AF_UNIX)
            server.bind(str(directory / name))
            server.listen()
            threading.Thread(target=self.serve, args=(server, events), daemon=True).start()

    def serve(self, server, events):
        while True:
            client, _ = server.accept()
            if events:
                self.listeners.append(client)
                continue
            with client:
                request = client.recv(65536).decode()
                self.requests.append(request)
                responses = {
                    "j/status": {"configProvider": "lua"},
                    "j/workspaces": self.workspaces,
                    "j/clients": [],
                    "j/monitors": [
                        {"id": i, "name": f"HEADLESS-{i + 1}", "description": "Test output",
                         "x": i * 1920, "y": 0, "width": 1920, "height": 1080, "scale": 1,
                         "focused": i == self.focused,
                         "activeWorkspace": {"id": i * 10 + 1, "name": str(i * 10 + 1)}}
                        for i in range(2)
                    ],
                }
                response = json.dumps(responses[request]) if request in responses else "ok"
                client.sendall(response.encode())

    def focus(self, index):
        self.focused = index
        for client in self.listeners:
            client.sendall(f"focusedmon>>HEADLESS-{index + 1},{index * 10 + 1}\n".encode())
        time.sleep(0.15)


def run_session(source, directory):
    runtime = directory / "run"
    os.environ["DBUS_SYSTEM_BUS_ADDRESS"] = os.environ["DBUS_SESSION_BUS_ADDRESS"]
    os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "fixture"
    os.environ.update(WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="2", WLR_RENDERER="pixman",
                      QT_QPA_PLATFORM="wayland", QT_QUICK_BACKEND="software")
    ui = directory / "ui"
    shutil.copytree(source, ui)
    ui.chmod(0o755)
    for path in ui.rglob("*"):
        path.chmod(0o755 if path.is_dir() else 0o644)
    for harness in ["WifiHarness.qml", "BluetoothHarness.qml"]:
        shutil.copyfile(Path(__file__).with_name(harness), ui / harness)
    entrypoint = ui / "shell.qml"
    entrypoint.write_text(entrypoint.read_text().replace(
        '        function launcher(): void {',
        '        function bluetoothTest(): void { ShellState.toggle("bluetooth-test"); }\n        function wifiTest(): void { ShellState.toggle("wifi-test"); }\n        function launcher(): void {'
    ).replace('        content: ShellState.panel === "launcher"',
              '        content: ShellState.panel === "bluetooth-test" ? bluetoothTest : ShellState.panel === "wifi-test" ? wifiTest : ShellState.panel === "launcher"'
    ).replace('    Osd {}', '    Component { id: bluetoothTest; BluetoothHarness {} }\n    Component { id: wifiTest; WifiHarness {} }\n    Osd {}'))
    settings = ui / "theme/Settings.qml"
    original = settings.read_text()
    data = json.loads(original.split("values: (", 1)[1].rsplit(")", 1)[0])
    assert [w["label"] for w in data["workspaces"]] == list(range(1, 11)) * 2
    # Keep generated IDs/labels; only virtual connector names differ from Midgar.
    names = {m["name"]: f"HEADLESS-{i + 1}" for i, m in enumerate(sorted(data["monitors"], key=lambda m: not m["primary"]))}
    for monitor in data["monitors"]:
        monitor["name"] = names[monitor["name"]]
    for workspace in data["workspaces"]:
        workspace["monitor"] = names[workspace["monitor"]]
    marker = directory / "launched"
    executable = directory / "fixture-app"
    executable.write_text(f'#!{shutil.which("bash")}\nprintf "%s\\n" "$@" > {marker}\n')
    executable.chmod(0o755)
    terminal = directory / "fixture-terminal"
    terminal.write_text(f'#!{shutil.which("bash")}\ntest "$1" = -e || exit 1\nshift\nexec "$@"\n')
    terminal.chmod(0o755)
    data["terminal"] = str(terminal)
    data["commands"] = {name: [str(executable), name] for name in data["commands"]}
    hyprctl = directory / "hyprctl"
    hyprctl.write_text(f'#!{shutil.which("bash")}\nprintf \'%s\\n\' \'{{"keyboards":[{{"main":true,"active_keymap":"Swedish"}}]}}\'\n')
    hyprctl.chmod(0o755)
    data["commands"]["hyprctl"] = str(hyprctl)
    brightness_state = directory / "brightness.json"
    brightness_state.write_text(json.dumps({"device": "", "value": 50}))
    brightnessctl = directory / "brightnessctl"
    brightnessctl.write_text(f'''#!{sys.executable}
import json, sys
from pathlib import Path
path = Path({str(brightness_state)!r})
state = json.loads(path.read_text())
assert "--class=backlight" in sys.argv
if not state["device"]:
    sys.exit(1)
if "set" in sys.argv:
    assert sys.argv[sys.argv.index("--device") + 1] == state["device"]
    if state.get("reject"):
        sys.exit(1)
    state["value"] = int(sys.argv[-1].removesuffix("%"))
    path.write_text(json.dumps(state))
else:
    if state.get("malformed"):
        print("bad,input")
    else:
        print(f"{{state['device']}},backlight,{{state['value']}},{{state['value']}}%,100")
''')
    brightnessctl.chmod(0o755)
    data["commands"]["brightnessctl"] = str(brightnessctl)
    settings.write_text('import QtQml\nQtObject { readonly property var values: (' + json.dumps(data) + ') }\n')
    apps = directory / "data/applications"
    apps.mkdir(parents=True)
    for label in ["Alpha", "Beta", "Terminal", "Hidden"]:
        (apps / f"hon-{label}.desktop").write_text(
            f'[Desktop Entry]\nType=Application\nName=Hon Test {label}\nExec={executable} {label} "two words"\n'
            f'Keywords=sample;orbit;\nTerminal={str(label == "Terminal").lower()}\n'
            f'NoDisplay={str(label == "Hidden").lower()}\n'
        )
    fixture = HyprlandFixture(runtime)
    config = directory / "sway.conf"
    config.write_text("xwayland disable\noutput * bg #181616 solid_color\noutput HEADLESS-1 mode 1920x1080 position 0 0\noutput HEADLESS-2 mode 1920x1080 position 1920 0\nseat seat0 fallback true\n")
    processes = []
    log = directory / "shell.log"
    try:
        with (directory / "sway.log").open("w") as output:
            processes.append(subprocess.Popen(["sway", "--config", str(config)], stdout=output, stderr=output))
        wait_for(lambda: list(runtime.glob("wayland-*")), "Wayland socket")
        os.environ["WAYLAND_DISPLAY"] = next(p.name for p in runtime.glob("wayland-*") if p.is_socket())
        wait_for(lambda: list(runtime.glob("sway-ipc.*.sock")), "Sway socket")
        os.environ["SWAYSOCK"] = str(next(runtime.glob("sway-ipc.*.sock")))
        # Keep a keyboard attached: removing the last input device can make Qt
        # drop focus between separate wtype invocations under headless Sway.
        processes.append(subprocess.Popen(["wtype", "-s", "180000"]))
        # Private PipeWire with null devices; no hardware/session-manager access.
        for name in ["PIPEWIRE_CONFIG_DIR", "PIPEWIRE_CONFIG_NAME", "PIPEWIRE_CONFIG_PREFIX", "PIPEWIRE_REMOTE"]:
            os.environ.pop(name, None)
        os.environ["PIPEWIRE_RUNTIME_DIR"] = str(runtime)
        os.environ["PIPEWIRE_REMOTE"] = "pipewire-0"
        pipewire_root = directory / "config/pipewire"
        pipewire_defaults = Path(shutil.which("pipewire")).resolve().parent.parent / "share/pipewire"
        shutil.copytree(pipewire_defaults, pipewire_root)
        for path in pipewire_root.rglob("*"):
            path.chmod(0o755 if path.is_dir() else 0o644)
        pipewire_root.chmod(0o755)
        os.environ["PIPEWIRE_CONFIG_DIR"] = str(pipewire_root)
        pipewire_config = pipewire_root / "pipewire.conf.d"
        pipewire_config.mkdir(exist_ok=True)
        (pipewire_config / "99-fixture.conf").write_text('''
context.objects = [
    { factory = metadata args = { metadata.name = default } }
''' + "\n".join(
            '{ factory = adapter args = { factory.name = support.null-audio-sink '
            f'node.name = {name} node.description = "{label}" media.class = "{kind}" '
            'audio.position = "FL,FR" } }'
            for name, label, kind in [
                ("hon_sink_a", "Test Speakers", "Audio/Sink"),
                ("hon_sink_b", "Test Headphones", "Audio/Sink"),
                ("hon_mic_a", "Test Microphone", "Audio/Source"),
                ("hon_mic_b", "Test Headset Microphone", "Audio/Source"),
                ("hon_stream", "Test Application Stream", "Stream/Output/Audio"),
            ]) + "\n]\n")
        with (directory / "pipewire.log").open("w") as output:
            processes.append(subprocess.Popen(["pipewire"], stdout=output, stderr=output))
        wait_for(lambda: (runtime / "pipewire-0").exists(), "private PipeWire socket")
        for kind, name in [("sink", "hon_sink_a"), ("source", "hon_mic_a")]:
            subprocess.run(["pw-metadata", "-n", "default", "0", "default.audio." + kind,
                            json.dumps({"name": name}), "Spa:String:JSON"], check=True, stdout=subprocess.DEVNULL)
        with log.open("w") as output:
            processes.append(subprocess.Popen(["qs", "--path", str(ui), "--no-color"], stdout=output, stderr=output))
        wait_for(lambda: "Configuration Loaded" in log.read_text() or processes[-1].poll() is not None, "QML loading")
        assert processes[-1].poll() is None, log.read_text()

        def ipc(method):
            return subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "shell", method], text=True).strip()

        def status():
            return json.loads(ipc("status"))

        def key(name):
            subprocess.run(["wtype", "-s", "200", "-k", name, "-s", "100"], check=True)
            time.sleep(0.1)

        def query(text):
            subprocess.run(["wtype", "-M", "ctrl", "-k", "a", "-m", "ctrl", text], check=True)
            time.sleep(0.15)

        wait_for(lambda: len(status()["screens"]) == 2 and fixture.listeners, "two bars and Hyprland IPC")
        time.sleep(0.5)
        for output, workspace in [(0, 2), (1, 12)]:
            subprocess.run(["swaymsg", f"seat seat0 cursor set {output * 1920 + 90} 18"], check=True, stdout=subprocess.DEVNULL)
            time.sleep(0.15)
            subprocess.run(["wlrctl", "pointer", "click", "left"], check=True, stdout=subprocess.DEVNULL)
            wait_for(lambda: any(f'workspace = "{workspace}"' in request for request in fixture.requests), f"local workspace 2 selects global {workspace}")
        fixture.focus(0)
        ipc("launcher")
        wait_for(lambda: status()["screen"] == "HEADLESS-1", "focused monitor launcher")
        time.sleep(0.25)
        evidence = os.environ.get("HON_SHELL_EVIDENCE")
        if evidence:
            Path(evidence).mkdir(parents=True, exist_ok=True)
            subprocess.run(["grim", "-o", "HEADLESS-1", str(Path(evidence) / "launcher.png")], check=True)
        query("bEtA ORBIT")
        key("Return")
        wait_for(marker.exists, "case-insensitive application search and launch")
        assert marker.read_text() == "Beta\ntwo words\n"
        assert status()["panel"] == ""
        marker.unlink()
        ipc("launcher")
        time.sleep(0.25)
        query("hon test")
        key("Down")
        key("Return")
        wait_for(marker.exists, "keyboard navigation")
        assert marker.read_text().startswith("Beta\n")
        marker.unlink()
        ipc("launcher")
        time.sleep(0.25)
        query("hidden")
        key("Return")
        assert not marker.exists() and status()["panel"] == "launcher"
        query("terminal")
        key("Return")
        wait_for(marker.exists, "terminal desktop entry")
        assert marker.read_text() == "Terminal\ntwo words\n"
        marker.unlink()
        ipc("launcher")
        key("Escape")
        wait_for(lambda: status()["panel"] == "", "Escape dismissal")
        fixture.focus(1)
        ipc("power")
        wait_for(lambda: status()["screen"] == "HEADLESS-2", "power menu on second monitor")
        time.sleep(0.25)
        key("Tab")
        key("Tab")
        key("space")
        assert not marker.exists(), "Logout requires a second activation"
        key("space")
        wait_for(marker.exists, "confirmed session action")
        assert marker.read_text() == "logout\n"
        marker.unlink()
        ipc("controls")
        time.sleep(0.25)
        assert status()["panel"] == "notifications", "Controls opens the unified pane"
        ipc("notifications")
        wait_for(lambda: status()["panel"] == "", "Both shortcuts toggle the same pane")
        ipc("settings")
        wait_for(lambda: status()["panel"] == "settings", "Dedicated settings view")
        time.sleep(0.25)
        key("Escape")
        wait_for(lambda: status()["panel"] == "", "settings dismissal")
        def brightness(method="status", *args):
            result = subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "brightness", method, *map(str, args)], text=True).strip()
            return json.loads(result) if method == "status" else result

        def osd():
            return json.loads(subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "osd", "status"], text=True))

        def audio(method="status", *args):
            result = subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "audio", method, *map(str, args)], text=True).strip()
            return json.loads(result) if method == "status" else result

        def metadata(key, name):
            subprocess.run(["pw-metadata", "-n", "default", "0", key, json.dumps({"name": name}), "Spa:String:JSON"],
                           check=True, stdout=subprocess.DEVNULL)

        wait_for(lambda: audio()["available"] and audio()["inputAvailable"], "initial audio devices")
        assert len(audio()["outputs"]) == 2 and len(audio()["inputs"]) == 2, "Exclude application streams"
        assert not osd()["visible"], "Device discovery must not show volume OSD"
        ipc("settings")
        time.sleep(0.3)
        key("Tab")  # Output volume slider.
        key("Tab")  # First output.
        key("Tab")  # Second output.
        key("space")
        key("Escape")
        audio("input", "hon_mic_b")
        wait_for(lambda: "hon_sink_b" in subprocess.check_output(["pw-metadata", "-n", "default", "0", "default.configured.audio.sink"], text=True), "output preference metadata")
        wait_for(lambda: "hon_mic_b" in subprocess.check_output(["pw-metadata", "-n", "default", "0", "default.configured.audio.source"], text=True), "input preference metadata")
        # A real session manager applies preferences. Here its result is explicit
        # so we can also check that the UI does not assume requests succeeded.
        assert audio()["output"] == "hon_sink_a" and audio()["input"] == "hon_mic_a"
        metadata("default.audio.sink", "hon_sink_b")
        metadata("default.audio.source", "hon_mic_b")
        wait_for(lambda: audio()["output"] == "hon_sink_b" and audio()["input"] == "hon_mic_b", "selected device acknowledgement")
        time.sleep(0.4)
        audio("volume", 42)
        wait_for(lambda: audio()["volume"] == 42 and osd()["visible"], "output volume and OSD")
        assert osd()["kind"] == "volume"
        audio("microphoneVolume", 37)
        wait_for(lambda: audio()["inputVolume"] == 37 and osd()["kind"] == "microphone", "microphone volume and OSD")
        audio("microphoneMute")
        wait_for(lambda: audio()["inputMuted"], "microphone mute")
        if evidence:
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "microphone-osd.png")], check=True)
        audio("volume", 175)
        audio("microphoneVolume", -20)
        wait_for(lambda: audio()["volume"] == 100 and audio()["inputVolume"] == 0, "audio volume clamps")
        ipc("controls")
        time.sleep(0.3)
        if evidence:
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "audio-controls.png")], check=True)
        key("Escape")
        microphone_id = next(node["id"] for node in audio()["inputs"] if node["name"] == "hon_mic_b")
        subprocess.run(["pw-cli", "destroy", str(microphone_id)], check=True, stdout=subprocess.DEVNULL)
        wait_for(lambda: len(audio()["inputs"]) == 1 and not audio()["inputAvailable"], "microphone removal")
        audio("microphoneMute")
        audio("microphoneVolume", 50)
        metadata("default.audio.source", "hon_mic_a")
        wait_for(lambda: audio()["inputAvailable"] and audio()["input"] == "hon_mic_a", "microphone fallback")
        audio("output", "missing-device")
        assert audio()["output"] == "hon_sink_b"
        output_id = next(node["id"] for node in audio()["outputs"] if node["name"] == "hon_sink_b")
        subprocess.run(["pw-cli", "destroy", str(output_id)], check=True, stdout=subprocess.DEVNULL)
        wait_for(lambda: len(audio()["outputs"]) == 1 and not audio()["available"], "output removal")
        audio("mute")
        audio("volume", 50)
        metadata("default.audio.sink", "hon_sink_a")
        wait_for(lambda: audio()["available"] and audio()["output"] == "hon_sink_a", "output fallback")
        wait_for(lambda: not osd()["visible"], "audio OSD timeout")
        assert not brightness()["available"] and not osd()["visible"]
        brightness_state.write_text(json.dumps({"device": "fixture_backlight", "value": 50}))
        wait_for(lambda: brightness()["available"], "backlight discovery")
        assert brightness()["percent"] == 50 and not osd()["visible"], "Discovery must not show an OSD"
        brightness_state.write_text(json.dumps({"device": "fixture_backlight", "value": 60}))
        wait_for(lambda: osd()["visible"], "external brightness change OSD")
        assert osd()["kind"] == "brightness" and osd()["screen"] == "HEADLESS-2"
        if evidence:
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "brightness-osd.png")], check=True)
        wait_for(lambda: not osd()["visible"], "brightness OSD timeout")
        for value in [40, 70, 90]:
            brightness("set", value)
        wait_for(lambda: brightness()["percent"] == 90, "latest queued brightness write")
        brightness("set", 0)
        wait_for(lambda: brightness()["percent"] == 1, "minimum brightness clamp")
        brightness_state.write_text(json.dumps({"device": "fixture_backlight", "value": 1, "reject": True}))
        brightness("set", 75)
        wait_for(lambda: brightness()["error"] != "", "write failure reporting")
        assert brightness()["percent"] == 1
        brightness_state.write_text(json.dumps({"device": "fixture_backlight", "value": 1}))
        brightness("set", 175)
        wait_for(lambda: brightness()["percent"] == 100 and not brightness()["error"], "write recovery and maximum clamp")
        ipc("controls")
        time.sleep(0.25)
        if evidence:
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "brightness-controls.png")], check=True)
        key("Escape")
        brightness_state.write_text(json.dumps({"device": "fixture_backlight", "value": 100, "malformed": True}))
        wait_for(lambda: not brightness()["available"], "malformed backlight response")
        assert not osd()["visible"]
        brightness_state.write_text(json.dumps({"device": "", "value": 100}))
        brightness("set", 50)
        time.sleep(0.2)
        assert json.loads(brightness_state.read_text())["value"] == 100

        def wifi(method="status", *args):
            result = subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "wifi-fixture", method, *map(str, args)], text=True).strip()
            return json.loads(result) if method == "status" else result

        def wifi_action(name):
            wifi("focus", name)
            key("space")

        ipc("wifiTest")
        wait_for(lambda: wifi()["scanning"], "Wi-Fi scanning while panel open")
        wifi("fail")
        assert not wifi()["passwordVisible"], "Unrequested failures must not prompt"
        wifi_action("wifi-connect")
        wait_for(lambda: wifi()["passwordVisible"], "password prompt after missing credentials")
        assert wifi()["masked"]
        query("wrong-password")
        key("Return")
        wait_for(lambda: wifi()["submissions"] == 1 and wifi()["passwordVisible"], "password retry")
        assert wifi()["passwordEmpty"]
        query("cancelled-password")
        key("Escape")
        assert wifi()["passwordEmpty"] and not wifi()["passwordVisible"] and status()["panel"] == "wifi-test"
        wifi_action("wifi-connect")
        query("fixture-password")
        if evidence:
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "wifi-password.png")], check=True)
        key("Return")
        wait_for(lambda: wifi()["connected"], "password connection")
        assert wifi()["correctSecret"] and wifi()["passwordEmpty"] and not wifi()["passwordVisible"]
        wifi_action("wifi-connect")
        assert not wifi()["connected"]
        wifi_action("wifi-connect")
        assert wifi()["connected"] and wifi()["submissions"] == 2, "Saved connection avoids password submission"
        wifi_action("wifi-forget")
        assert wifi()["forgotten"] == 0, "Forget needs confirmation"
        wifi_action("wifi-forget")
        assert wifi()["forgotten"] == 1 and not wifi()["known"]
        wifi_action("wifi-connect")
        query("discard-on-radio-off")
        wifi("radio", "false")
        wait_for(lambda: not wifi()["scanning"] and wifi()["passwordEmpty"], "radio-off stops scan and clears credentials")
        wifi("radio", "true")
        wifi("security", 2)  # WPA2 enterprise requires advanced settings.
        attempts = wifi()["attempts"]
        wifi_action("wifi-connect")
        assert wifi()["attempts"] == attempts and not wifi()["passwordVisible"]
        wifi_action("wifi-settings")
        wait_for(marker.exists, "advanced network settings action")
        assert marker.read_text() == "networkSettings\n"
        marker.unlink()
        wait_for(lambda: status()["panel"] == "", "external settings release panel focus")
        ipc("wifiTest")
        time.sleep(0.2)
        wifi("security", 10)  # Open network.
        wifi_action("wifi-connect")
        assert wifi()["connected"]
        wifi("remove")
        wait_for(lambda: not wifi()["scanning"], "adapter removal stops scanning")
        key("Escape")

        def bluetooth(method="status", *args):
            result = subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "bluetooth-fixture", method, *map(str, args)], text=True).strip()
            return json.loads(result) if method == "status" else result

        def bluetooth_action(name):
            bluetooth("focus", name)
            key("space")

        ipc("bluetoothTest")
        time.sleep(0.2)
        assert bluetooth()["canPair"] and not bluetooth()["trusted"]
        bluetooth_action("bluetooth-pair")
        wait_for(marker.exists, "KDE pairing wizard launch")
        assert marker.read_text() == "bluetoothPair\n"
        marker.unlink()
        wait_for(lambda: status()["panel"] == "", "external settings release panel focus")
        ipc("bluetoothTest")
        time.sleep(0.2)
        bluetooth_action("bluetooth-connect")
        assert bluetooth()["connected"] and not bluetooth()["trusted"], "Connecting must not silently trust a device"
        bluetooth_action("bluetooth-trust")
        assert bluetooth()["trusted"]
        if evidence:
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "bluetooth-controls.png")], check=True)
        bluetooth_action("bluetooth-connect")
        assert not bluetooth()["connected"]
        bluetooth_action("bluetooth-forget")
        assert bluetooth()["forgotten"] == 0
        bluetooth_action("bluetooth-forget")
        assert bluetooth()["forgotten"] == 1
        bluetooth_action("bluetooth-power")
        assert not bluetooth()["powered"] and not bluetooth()["canPair"]
        bluetooth_action("bluetooth-power")
        assert bluetooth()["powered"]
        bluetooth_action("bluetooth-settings")
        wait_for(marker.exists, "Bluetooth settings launch")
        assert marker.read_text() == "bluetoothSettings\n"
        marker.unlink()
        wait_for(lambda: status()["panel"] == "", "external settings release panel focus")
        ipc("bluetoothTest")
        time.sleep(0.2)
        bluetooth("block")
        assert not bluetooth()["canPower"] and not bluetooth()["canPair"]
        bluetooth("remove")
        assert not bluetooth()["canPair"]
        key("Escape")

        def notifications(method="status"):
            result = subprocess.check_output(["qs", "--path", str(ui), "ipc", "call", "notifications", method], text=True).strip()
            return json.loads(result) if method == "status" else result

        def notify(timeout=0, replaces=0, hints="{}", actions="[]"):
            result = subprocess.check_output([
                "gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                "--object-path", "/org/freedesktop/Notifications", "--method",
                "org.freedesktop.Notifications.Notify", "Hon Test", str(replaces), "",
                "Build complete", "Notification body", actions, hints, str(timeout)
            ], text=True)
            return int(result.split("uint32 ")[1].split(",")[0])

        def close_notification(identifier):
            subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                            "--object-path", "/org/freedesktop/Notifications", "--method",
                            "org.freedesktop.Notifications.CloseNotification", str(identifier)], check=True,
                           stdout=subprocess.DEVNULL)

        signals = directory / "notification-signals.log"
        with signals.open("w") as output:
            processes.append(subprocess.Popen([
                "dbus-monitor", "--session", "type='signal',interface='org.freedesktop.Notifications'"
            ], stdout=output, stderr=output))
        time.sleep(0.2)
        capabilities = subprocess.check_output([
            "gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications", "--method",
            "org.freedesktop.Notifications.GetCapabilities"
        ], text=True)
        assert all("'" + cap + "'" in capabilities for cap in ["body", "actions", "persistence"])
        assert "body-markup" not in capabilities
        identifier = notify(timeout=150)
        wait_for(lambda: notifications()["count"] == 1 and not notifications()["entries"][0]["live"], "expired notification history")
        wait_for(lambda: f"uint32 {identifier}\n   uint32 1" in signals.read_text(), "expiry close reason")
        notifications("clear")
        notify(timeout=150, hints="{'transient': <true>}")
        wait_for(lambda: not notifications()["entries"], "transient expiry")
        identifier = notify(hints="{'value': <int32 20>}")
        assert notify(replaces=identifier, hints="{'value': <int32 75>}") == identifier
        wait_for(lambda: notifications()["count"] == 1 and notifications()["entries"][0]["progress"] == 75, "replacement progress")
        assert notifications()["entries"][0]["popup"]
        if evidence:
            time.sleep(0.2)
            subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "notification-popup.png")], check=True)
        notifications("dnd")
        notify(timeout=50, hints="{'urgency': <byte 2>}")
        time.sleep(0.25)
        assert all(entry["live"] and not entry["popup"] for entry in notifications()["entries"])
        notifications("dnd")
        assert not any(entry["popup"] for entry in notifications()["entries"])
        close_notification(identifier)
        wait_for(lambda: notifications()["count"] == 1, "client retraction")
        wait_for(lambda: f"uint32 {identifier}\n   uint32 3" in signals.read_text(), "client close reason")
        notifications("clear")
        for resident in [False, True]:
            action_id = notify(actions="['open', 'Open']", hints="{'resident': <true>}" if resident else "{}")
            ipc("notifications")
            time.sleep(0.3)
            if evidence:
                subprocess.run(["grim", "-o", "HEADLESS-2", str(Path(evidence) / "notifications.png")], check=True)
            key("Tab")
            key("Tab")
            key("Tab")
            key("space")
            wait_for(lambda: notifications()["count"] == int(resident), "notification action residency")
            wait_for(lambda: f'uint32 {action_id}\n   string "open"' in signals.read_text(), "D-Bus action delivery")
            key("Escape")
            notifications("clear")
        for _ in range(102):
            notify()
        assert notifications()["count"] == 100, "Bounded notification history"
        notifications("clear")
        notify()
        assert notifications()["entries"][0]["screen"] == "HEADLESS-2"
        brightness_state.write_text(json.dumps({"device": "fixture_backlight", "value": 50}))
        wait_for(lambda: brightness()["available"], "backlight reappearance")
        brightness("set", 60)
        wait_for(lambda: osd()["visible"], "brightness OSD before output removal")
        ipc("launcher")
        subprocess.run(["swaymsg", "output", "HEADLESS-2", "disable"], check=True, stdout=subprocess.DEVNULL)
        wait_for(lambda: len(status()["screens"]) == 1 and status()["panel"] == "", "removed monitor dismisses panel")
        ipc("launcher")
        wait_for(lambda: status()["screen"] == "HEADLESS-1", "fallback after monitor removal")
        ipc("close")
        assert not notifications()["entries"][0]["popup"]
        assert not osd()["visible"], "Removed output must dismiss the OSD"
        notify()
        assert notifications()["entries"][0]["screen"] == "HEADLESS-1"
        notifications("clear")
        errors = [line for line in log.read_text().splitlines() if any(term in line for term in ["ERROR: Failed", "TypeError", "ReferenceError", "Unable to assign", "Binding loop", "Cannot assign", "is not a function"])]
        assert not errors, "\n".join(errors)
        assert "fixture-password" not in log.read_text() and "wrong-password" not in log.read_text(), "Wi-Fi secrets must not be logged"
        print("Shell checks passed: local workspace clicks, launcher search/navigation/terminal entries, dismissal, power confirmation, focused monitor placement, notifications/expiry/replacement/DND/actions/history limit, brightness discovery/change/clamping/errors, audio selection/volume/microphone/removal, Wi-Fi credentials/saved/open/forget/radio/adapter cases, Bluetooth controls/pairing handoff, hot-unplug fallback.")
    except Exception:
        evidence = os.environ.get("HON_SHELL_EVIDENCE")
        if evidence:
            Path(evidence).mkdir(parents=True, exist_ok=True)
            subprocess.run(["grim", "-o", "HEADLESS-1", str(Path(evidence) / "failure.png")])
        if (directory / "pipewire.log").exists():
            print((directory / "pipewire.log").read_text(), file=sys.stderr)
            subprocess.run(["pw-metadata", "-n", "default"], timeout=3)
            subprocess.run(["qs", "--path", str(ui), "ipc", "call", "audio", "status"], timeout=3)
        print("Hyprland requests:", fixture.requests, file=sys.stderr)
        if log.exists():
            print(log.read_text(), file=sys.stderr)
        raise
    finally:
        for process in reversed(processes):
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    if len(sys.argv) == 4:
        run_session(Path(sys.argv[1]), Path(sys.argv[3]))
    else:
        with tempfile.TemporaryDirectory(prefix="hs-", dir="/tmp") as path:
            directory = Path(path)
            (directory / "run").mkdir(mode=0o700)
            bus_config = directory / "bus.conf"
            bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            env = os.environ.copy()
            for name in ["DISPLAY", "WAYLAND_DISPLAY", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS"]:
                env.pop(name, None)
            env.update(XDG_RUNTIME_DIR=str(directory / "run"), XDG_DATA_HOME=str(directory / "data"),
                       XDG_DATA_DIRS=str(directory / "data-system"), XDG_CONFIG_HOME=str(directory / "config"),
                       XDG_CACHE_HOME=str(directory / "cache"), QT_QPA_PLATFORMTHEME="")
            subprocess.run(["dbus-run-session", "--config-file", str(bus_config), "--", sys.executable, __file__, sys.argv[1], "--session", path], env=env, check=True)
