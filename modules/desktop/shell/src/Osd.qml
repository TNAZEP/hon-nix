import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "theme"

PanelWindow {
    id: root
    property var targetScreen: null
    screen: targetScreen
    property string kind: "volume"
    readonly property int level: kind === "brightness" ? Brightness.percent : kind === "microphone" ? Audio.inputVolume : Audio.volume
    readonly property bool muted: kind === "microphone" ? Audio.inputMuted : kind === "volume" && Audio.muted
    visible: hide.running && targetScreen !== null
    implicitWidth: 280
    implicitHeight: 68
    anchors.bottom: true
    margins.bottom: 96
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "hon-shell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    Connections {
        target: Audio
        function onAvailableChanged() {
            if (!Audio.available && root.kind === "volume") hide.stop();
        }
        function onInputAvailableChanged() {
            if (!Audio.inputAvailable && root.kind === "microphone") hide.stop();
        }
        function onInputAdjusted() {
            root.kind = "microphone";
            root.targetScreen = ShellState.focusedScreen();
            hide.restart();
        }
        function onAdjusted() {
            root.kind = "volume";
            root.targetScreen = ShellState.focusedScreen();
            hide.restart();
        }
    }
    Connections {
        target: Brightness
        function onAdjusted() {
            root.kind = "brightness";
            root.targetScreen = ShellState.focusedScreen();
            hide.restart();
        }
        function onAvailableChanged() {
            if (!Brightness.available && root.kind === "brightness") hide.stop();
        }
    }
    Connections {
        target: ShellState
        function onScreensChanged() {
            if (!ShellState.screens.includes(root.targetScreen)) {
                hide.stop();
                root.targetScreen = null;
            }
        }
    }
    IpcHandler {
        target: "osd"
        function status(): string {
            return JSON.stringify({visible: root.visible, kind: root.kind, screen: root.screen?.name || ""});
        }
    }
    Timer {
        id: hide
        interval: 1800
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.color: Theme.accent
        Text {
            anchors {
                top: parent.top
                left: parent.left
                margins: 14
            }
            text: root.kind === "brightness" ? "Brightness  " + root.level + "%" : root.kind === "microphone" ? (root.muted ? "Microphone muted" : "Microphone  " + root.level + "%") : root.muted ? "Muted" : "Volume  " + root.level + "%"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 14
        }
        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: 14
            }
            height: 4
            color: Theme.surface
            Rectangle {
                width: parent.width * Math.min(root.level, 100) / 100
                height: parent.height
                color: root.muted ? Theme.muted : Theme.accent
            }
        }
    }
}
