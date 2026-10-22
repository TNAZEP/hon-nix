import QtQuick
import Quickshell
import Quickshell.Io
import "components" as Hon
import "services"

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        NotificationPopup {}
    }
    Osd {}
    IpcHandler {
        target: "shell"
        function launcher(): void {
            ShellState.toggle("launcher");
        }
        function power(): void {
            ShellState.toggle("power");
        }
        function controls(): void {
            ShellState.toggle("controls");
        }
        function notifications(): void {
            ShellState.toggle("notifications");
        }
        function close(): void {
            ShellState.close();
        }
        function status(): string {
            return JSON.stringify({
                panel: ShellState.panel,
                screen: ShellState.panelScreen?.name || "",
                screens: Quickshell.screens.map(s => s.name)
            });
        }
    }
    Hon.Popup {
        panelWidth: ShellState.panel === "power" ? 360 : 620
        panelHeight: ShellState.panel === "power" ? 410 : 540
        content: ShellState.panel === "launcher" ? launcher : ShellState.panel === "power" ? power : ShellState.panel === "notifications" ? notifications : controls
    }
    Component {
        id: launcher
        Launcher {}
    }
    Component {
        id: power
        PowerMenu {}
    }
    Component {
        id: notifications
        NotificationCenter {}
    }
    Component {
        id: controls
        ControlCenter {}
    }
}
