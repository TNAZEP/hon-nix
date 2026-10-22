pragma Singleton
import QtQuick
import Quickshell.Io
import "../theme"

QtObject {
    id: root
    property string device: ""
    property int percent: 0
    property string error: ""
    readonly property bool available: device !== ""
    property int pending: -1
    signal adjusted

    function refresh() {
        if (!reader.running && !writer.running)
            reader.running = true;
    }
    function accept(text) {
        const fields = text.trim().split("\n")[0].split(",");
        const current = Number(fields[2]);
        const maximum = Number(fields[4]);
        if (fields.length !== 5 || fields[1] !== "backlight" || !fields[0]
                || !Number.isFinite(current) || !Number.isFinite(maximum)
                || maximum <= 0 || current < 0 || current > maximum) {
            device = "";
            return;
        }
        const sameDevice = device === fields[0];
        const next = Math.round(current * 100 / maximum);
        const changed = sameDevice && percent !== next;
        if (!sameDevice) error = "";
        device = fields[0];
        percent = next;
        if (changed) adjusted();
    }
    function setPercent(value) {
        if (!available || !Number.isFinite(value)) return;
        pending = Math.max(1, Math.min(100, Math.round(value)));
        flush();
    }
    function flush() {
        if (pending < 0 || writer.running || reader.running) return;
        if (!available) { pending = -1; return; }
        writer.command = [Theme.values.commands.brightnessctl, "--class=backlight", "--device", device, "set", pending + "%"];
        pending = -1;
        writer.running = true;
    }
    property Process reader: Process {
        command: [Theme.values.commands.brightnessctl, "--class=backlight", "--machine-readable", "info"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.accept(text) }
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) root.device = "";
            Qt.callLater(root.flush);
        }
    }
    property Process writer: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (code, status) => {
            root.error = code === 0 ? "" : "Could not change brightness";
            if (code !== 0) root.pending = -1;
            root.refresh();
        }
    }
    property Timer poll: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
    property IpcHandler ipc: IpcHandler {
        target: "brightness"
        function set(value: int): void { root.setPercent(value); }
        function status(): string {
            return JSON.stringify({available: root.available, device: root.device, percent: root.percent, error: root.error});
        }
    }
}
