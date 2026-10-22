import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: root
    property alias content: loader.sourceComponent
    property int panelWidth: 600
    property int panelHeight: 520
    screen: ShellState.panelScreen
    visible: ShellState.panel !== "" && ShellState.panelScreen !== null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "#66000000"
    WlrLayershell.namespace: "hon-shell-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.close()
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.panelWidth, parent.width - 32)
        height: Math.min(root.panelHeight, parent.height - 64)
        color: Theme.background
        border.color: Theme.accent
        border.width: 1
        // Consume background clicks without dismissing the panel.
        MouseArea {
            anchors.fill: parent
        }
        Loader {
            id: loader
            anchors.fill: parent
            anchors.margins: 20
            active: root.visible
            focus: true
            Keys.onEscapePressed: ShellState.close()
        }
    }
}
