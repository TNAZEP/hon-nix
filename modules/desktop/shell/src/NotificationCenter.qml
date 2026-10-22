import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth
import "components" as Hon
import "services"
import "theme"

FocusScope {
    id: root
    ColumnLayout {
        width: parent.width
        height: Math.floor(parent.height * 2 / 3) - 12
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Notifications"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 22
            }

            Hon.Button {
                text: Notifications.dnd ? "DND on" : "DND off"
                hint: "Do not disturb"
                selected: Notifications.dnd
                onClicked: Notifications.dnd = !Notifications.dnd
                Component.onCompleted: Qt.callLater(() => {
                    return forceActiveFocus();
                })
            }

            Hon.Button {
                text: "Clear all"
                enabled: Notifications.count > 0
                onClicked: Notifications.clear()
            }
        }

        ListView {
            id: history

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            model: Notifications.history
            boundsBehavior: Flickable.StopAtBounds

            Text {
                anchors.centerIn: parent
                visible: Notifications.count === 0
                text: Notifications.dnd ? "Do not disturb is on" : "No notifications"
                color: Theme.muted
                font.family: Theme.font
            }

            ScrollBar.vertical: ScrollBar {}

            delegate: Hon.NotificationCard {
                required property var modelData

                width: history.width
                entry: modelData
            }
        }

        Text {
            text: "History clears when the shell restarts"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    Rectangle {
        y: Math.floor(parent.height * 2 / 3)
        width: parent.width
        height: 1
        color: Theme.border
    }
    ScrollView {
        id: quickScroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.floor(parent.height / 3) - 16
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: quickScroll.availableWidth
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Quick settings"
                    font.family: Theme.font
                    font.pixelSize: 18
                    color: Theme.foreground
                }
                Hon.Button {
                    text: "Settings →"
                    onClicked: ShellState.toggle("settings")
                }
            }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 8
                Hon.Button {
                    text: Networking.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                    selected: Networking.wifiEnabled
                    enabled: Networking.wifiHardwareEnabled && Networking.devices.values.some(d => d.type === DeviceType.Wifi)
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
                Hon.Button {
                    text: Bluetooth.defaultAdapter?.enabled ? "Bluetooth on" : "Bluetooth off"
                    selected: Bluetooth.defaultAdapter?.enabled ?? false
                    enabled: !!Bluetooth.defaultAdapter && ![BluetoothAdapterState.Blocked, BluetoothAdapterState.Enabling, BluetoothAdapterState.Disabling].includes(Bluetooth.defaultAdapter.state)
                    onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                }
                Hon.Button {
                    text: Audio.inputMuted ? "Mic muted" : "Mic on"
                    enabled: Audio.inputAvailable
                    selected: Audio.inputMuted
                    onClicked: Audio.toggleInputMute()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Hon.Button {
                    text: Audio.muted ? "Unmute" : "Volume"
                    enabled: Audio.available
                    onClicked: Audio.toggleMute()
                }
                Hon.Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: Audio.volume / 100
                    enabled: Audio.available
                    onMoved: Audio.setVolume(value)
                }
                Text {
                    text: Audio.available ? Audio.volume + "%" : "—"
                    color: Theme.foreground
                    font.family: Theme.font
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: Brightness.available
                Text {
                    text: "Brightness"
                    color: Theme.muted
                    font.family: Theme.font
                }
                Hon.Slider {
                    Layout.fillWidth: true
                    from: 1
                    to: 100
                    stepSize: 1
                    value: Brightness.percent
                    onMoved: Brightness.setPercent(value)
                }
                Text {
                    text: Brightness.percent + "%"
                    color: Theme.foreground
                    font.family: Theme.font
                }
            }
        }
    }
}
