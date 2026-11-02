pragma Singleton
import QtQuick
import QtCore as Core
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

QtObject {
    id: root
    property string panel: ""
    property var panelScreen: null
    readonly property string wallpaper: appearance.wallpaper
    property string wallpaperError: ""
    readonly property bool wallpaperBusy: wallpaperWriter.running || wallpaperProbe.status === Image.Loading
    readonly property string wallpaperFolder: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    property Core.Settings appearance: Core.Settings {
        location: root.fileUrl((Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hon-shell/appearance.ini")
        property string wallpaper: ""
    }
    function selectWallpaper(url) {
        if (wallpaperBusy)
            return;
        wallpaperError = "";
        wallpaperProbe.source = "";
        wallpaperProbe.source = url;
    }
    property Image wallpaperProbe: Image {
        visible: false
        asynchronous: true
        sourceSize.width: 64
        sourceSize.height: 64
        onStatusChanged: {
            if (status === Image.Ready) {
                root.applyWallpaper(source.toString());
            } else if (status === Image.Error) {
                root.wallpaperError = "Could not read this image. Choose another wallpaper.";
            }
        }
    }
    function applyWallpaper(url) {
        if (!url.startsWith("file://") || wallpaperWriter.running)
            return;
        wallpaperWriter.selection = url;
        wallpaperWriter.command = [Theme.values.commands.awww || "awww", "img", decodeURIComponent(url.slice(7))];
        wallpaperWriter.running = true;
    }
    property Process wallpaperWriter: Process {
        property string selection: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code === 0) {
                appearance.wallpaper = selection;
                appearance.sync();
                root.wallpaperError = "";
            } else {
                root.wallpaperError = "awww could not apply this wallpaper. Check that its daemon is running and the image is readable.";
            }
        }
    }
    Component.onCompleted: Qt.callLater(() => {
        if (appearance.wallpaper !== "")
            root.applyWallpaper(appearance.wallpaper);
    })
    readonly property var screens: Quickshell.screens

    function focusedScreen() {
        const focused = Hyprland.focusedMonitor?.name;
        const primary = Theme.values.monitors.find(m => m.primary)?.name;
        return screens.find(s => s.name === focused) || screens.find(s => s.name === primary) || screens[0] || null;
    }
    function toggle(name) {
        // Both shortcuts and bar entry points open the unified pane.
        if (name === "controls")
            name = "notifications";
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
