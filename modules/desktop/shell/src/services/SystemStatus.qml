pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

QtObject {
    id: root
    property int cpu: -1
    property var previousCpu: null
    property string keyboard: Theme.values.keyboard
    property FileView cpuFile: FileView {
        path: "/proc/stat"
        onLoaded: {
            const fields = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            if (fields.length !== 8 || fields.some(n => !Number.isFinite(n)))
                return;
            const total = fields.reduce((a, b) => a + b, 0);
            const idle = fields[3] + fields[4];
            if (root.previousCpu && total > root.previousCpu.total)
                root.cpu = Math.max(0, Math.min(100, Math.round(100 * (1 - (idle - root.previousCpu.idle) / (total - root.previousCpu.total)))));
            root.previousCpu = {
                total,
                idle
            };
        }
    }
    property Timer cpuTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.cpuFile.reload()
    }
    property Process devices: Process {
        command: [Theme.values.commands.hyprctl, "-j", "devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards || [];
                    const main = keyboards.find(k => k.main) || keyboards[0];
                    if (main)
                        root.keyboard = main.active_keymap;
                } catch (error) {
                    console.warn("Cannot read keyboard layout:", error);
                }
            }
        }
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.devices.running = true;
        }
    }
}
