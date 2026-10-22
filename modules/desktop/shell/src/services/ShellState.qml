pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

QtObject {
    id: root
    property string panel: ""
    property var panelScreen: null
    readonly property var screens: Quickshell.screens

    function focusedScreen() {
        const focused = Hyprland.focusedMonitor?.name;
        const primary = Theme.values.monitors.find(m => m.primary)?.name;
        return screens.find(s => s.name === focused) || screens.find(s => s.name === primary) || screens[0] || null;
    }
    function toggle(name) {
        if (panel === name) {
            close();
        } else {
            panelScreen = focusedScreen();
            panel = panelScreen ? name : "";
        }
    }
    function close() {
        panel = "";
    }
    onScreensChanged: {
        if (panel !== "" && (!panelScreen || !screens.includes(panelScreen))) {
            close();
            panelScreen = null;
        }
    }
}
