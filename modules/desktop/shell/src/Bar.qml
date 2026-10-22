import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "components" as Hon
import "widgets"
import "services"
import "theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.background
    WlrLayershell.namespace: "hon-shell-bar"
    WlrLayershell.layer: WlrLayer.Top
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    readonly property var links: Networking.devices.values.filter(d => d.connected)
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
        }
        spacing: 8
        Hon.Button {
            text: "本"
            hint: "Applications · Super+Space"
            onClicked: ShellState.toggle("launcher")
        }
        Workspaces {
            screen: root.screen
        }
        Text {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.max(0, root.width / 2 - 440)
            text: Hyprland.activeToplevel?.monitor?.name === root.screen?.name ? Hyprland.activeToplevel.title : ""
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
        }
        Hon.Button {
            visible: root.width >= 1600 && root.player !== null
            Layout.maximumWidth: 190
            text: root.player ? (root.player.isPlaying ? "Ⅱ  " : "▷  ") + (root.player.trackTitle || root.player.identity) : ""
            hint: root.player ? root.player.trackTitle + " · " + root.player.trackArtist : ""
            onClicked: ShellState.toggle("controls")
        }
        Hon.Button {
            visible: root.width >= 1400
            text: SystemStatus.cpu < 0 ? "CPU —" : "CPU " + SystemStatus.cpu + "%"
            hint: "Processor usage"
            onClicked: ShellState.toggle("controls")
        }
        Hon.Button {
            visible: root.width >= 1400
            text: SystemStatus.keyboard
            Layout.maximumWidth: 100
            hint: "Keyboard layout: " + SystemStatus.keyboard
        }
        Hon.Button {
            text: !Audio.available ? "Audio —" : Audio.muted ? "Muted" : "Vol " + Audio.volume + "%"
            hint: "Audio controls; scroll to adjust volume"
            onClicked: ShellState.toggle("controls")
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                onClicked: Audio.toggleMute()
                onWheel: event => Audio.setVolume(Audio.volume / 100 + (event.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
        Hon.Button {
            visible: root.width >= 1200
            text: root.links.length ? "Net" : "Offline"
            hint: root.links.map(d => d.name).join(", ") || "No network connection"
            onClicked: ShellState.toggle("controls")
        }
        Hon.Button {
            visible: root.width >= 1400 && Bluetooth.defaultAdapter !== null
            text: Bluetooth.defaultAdapter?.enabled ? "BT" : "BT off"
            onClicked: ShellState.toggle("controls")
        }
        Hon.Button {
            visible: UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
            text: Math.round(UPower.displayDevice.percentage * 100) + "%"
            hint: "Battery"
        }
        Text {
            visible: root.width < 1200
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 13
        }
        Hon.Button {
            text: Notifications.dnd ? "DND" : "N " + Notifications.count
            hint: "Notifications · Super+N"
            onClicked: ShellState.toggle("notifications")
        }
        Tray {
            window: root
        }
        Hon.Button {
            text: "⏻"
            hint: "Session · Super+Shift+Space"
            onClicked: ShellState.toggle("power")
        }
    }
    Text {
        anchors.centerIn: parent
        visible: root.width >= 1200
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: 13
    }
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Theme.border
    }
}
