import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "components" as Hon
import "widgets"
import "services"
import "theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    margins { top: 8; left: 8; right: 8 }
    implicitHeight: Theme.barHeight
    color: Theme.background
    WlrLayershell.namespace: "hon-shell-bar"
    WlrLayershell.layer: WlrLayer.Top

    SystemClock { id: clock; precision: SystemClock.Minutes }

    component Readout: Hon.Button {
        id: readout
        property string prefix: ""
        implicitWidth: contents.implicitWidth + 8
        implicitHeight: 30
        flat: true
        contentItem: Row {
            id: contents
            spacing: 0
            Text {
                text: readout.prefix
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: readout.text
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    component Separator: Text {
        text: " / "
        color: Theme.surface
        font.family: Theme.font
        font.pixelSize: 16
    }

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
    }

    Readout {
        anchors.centerIn: parent
        visible: root.width >= 1200
        text: "[ " + Qt.formatDateTime(clock.date, "HH:mm ddd, MMM dd").toLowerCase() + " ]"
        hint: "Notifications · Super+N; right-click for Do Not Disturb"
        onClicked: ShellState.toggle("notifications")
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: Notifications.dnd = !Notifications.dnd
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            text: "[ "
            color: Theme.surface
            font.family: Theme.font
            font.pixelSize: 16
        }
        Readout {
            visible: root.width >= 1400
            prefix: "cpu: "
            text: SystemStatus.cpu < 0 ? "—" : SystemStatus.cpuHistory.map(value => "▁▂▃▄▅▆▇█"[Math.min(7, Math.floor(value / 13))]).join("") + " " + String(SystemStatus.cpu).padStart(2, " ") + "%"
            hint: "Processor usage · open controls"
            onClicked: ShellState.toggle("controls")
        }
        Separator { visible: root.width >= 1400 }
        Readout {
            visible: root.width >= 1400
            prefix: "key: "
            text: SystemStatus.keyboard.toLowerCase().includes("swedish") ? "se" : SystemStatus.keyboard
            hint: "Keyboard layout: " + SystemStatus.keyboard
            onClicked: ShellState.toggle("controls")
        }
        Separator { visible: root.width >= 1400 }
        Readout {
            prefix: "vol: "
            text: !Audio.available ? "—" : Audio.muted ? "mute" : Audio.volume + "%"
            hint: "Audio controls; scroll for volume; middle-click to mute"
            onClicked: ShellState.toggle("controls")
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                onClicked: Audio.toggleMute()
                onWheel: event => Audio.setVolume(Audio.volume / 100 + (event.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
        Separator { visible: UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent }
        Readout {
            visible: UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
            prefix: "bat: "
            text: Math.round(UPower.displayDevice.percentage * 100) + "%"
            onClicked: ShellState.toggle("controls")
        }
        Readout {
            visible: Notifications.dnd || Notifications.count > 0
            prefix: " / "
            text: Notifications.dnd ? "dnd" : "n: " + Notifications.count
            hint: "Notifications · Super+N"
            onClicked: ShellState.toggle("notifications")
        }
        Readout {
            visible: root.width < 1200
            text: Qt.formatDateTime(clock.date, "HH:mm")
            onClicked: ShellState.toggle("notifications")
        }
        Tray { window: root; Layout.leftMargin: 6 }
        Readout {
            prefix: " ⏻"
            hint: "Session · Super+Shift+Space"
            onClicked: ShellState.toggle("power")
        }
        Text {
            text: " ]"
            color: Theme.surface
            font.family: Theme.font
            font.pixelSize: 16
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: Theme.muted
    }
}
