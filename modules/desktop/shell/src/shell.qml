import QtQuick
import Quickshell
import Quickshell.Io
import "components" as Hon
import "services"

ShellRoot {
    property string displayedPanel: "launcher"
    Connections {
        target: ShellState
        function onPanelChanged() {
            if (ShellState.panel !== "")
                displayedPanel = ShellState.panel;
        }
    }
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
        function settings(): void {
            ShellState.toggle("settings");
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
        drawer: displayedPanel === "notifications"
        panelWidth: displayedPanel === "power" ? 360 : displayedPanel === "settings" ? 900 : drawer ? 540 : 620
        panelHeight: displayedPanel === "power" ? 410 : displayedPanel === "settings" ? 680 : 540
        content: displayedPanel === "launcher" ? launcher : displayedPanel === "power" ? power : displayedPanel === "notifications" ? notifications : controls
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
