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
    property bool drawer: false
    readonly property bool opened: ShellState.panel !== "" && ShellState.panelScreen !== null
    property bool drawerEntered: false
    onOpenedChanged: {
        if (opened)
            Qt.callLater(() => drawerEntered = root.opened);
        else
            drawerEntered = false;
    }
    onDrawerChanged: {
        drawerEntered = false;
        if (opened)
            Qt.callLater(() => drawerEntered = root.opened);
    }
    screen: ShellState.panelScreen
    visible: opened || slide.running
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
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.close()
    }
    Rectangle {
        x: root.drawer ? (root.drawerEntered ? parent.width - width - 8 : parent.width) : (parent.width - width) / 2
        y: root.drawer ? 8 : (parent.height - height) / 2
        width: Math.min(root.panelWidth, parent.width - 32)
        height: root.drawer ? parent.height - 16 : Math.min(root.panelHeight, parent.height - 64)
        Behavior on x {
            enabled: root.drawer
            NumberAnimation {
                id: slide
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        color: Theme.background
        border.color: Theme.muted
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
