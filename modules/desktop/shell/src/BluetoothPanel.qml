import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "components" as Hon
import "theme"
import "services"

ColumnLayout {
    id: root
    property var adapters: Bluetooth.adapters.values
    spacing: 10
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Bluetooth"
            color: Theme.foreground
            font.family: Theme.font
        }
        Hon.Button {
            objectName: "bluetooth-pair"
            text: "Pair new device"
            enabled: root.adapters.some(adapter => adapter.enabled)
            hint: "Open KDE’s pairing wizard for discovery and PIN/passkey confirmation"
            onClicked: {
                Quickshell.execDetached(Theme.values.commands.bluetoothPair);
                ShellState.close();
            }
        }
        Hon.Button {
            objectName: "bluetooth-settings"
            text: "Settings"
            onClicked: {
                Quickshell.execDetached(Theme.values.commands.bluetoothSettings);
                ShellState.close();
            }
        }
    }
    Text {
        visible: root.adapters.length === 0
        text: "No Bluetooth adapter"
        color: Theme.muted
        font.family: Theme.font
    }
    Repeater {
        model: root.adapters
        ColumnLayout {
            id: adapterRow
            required property var modelData
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: adapterRow.modelData?.name || "Bluetooth adapter"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: Theme.font
                }
                Hon.Button {
                    objectName: "bluetooth-power"
                    text: adapterRow.modelData?.state === BluetoothAdapterState.Blocked ? "Hardware blocked" : adapterRow.modelData?.enabled ? "Turn off" : "Turn on"
                    enabled: !!adapterRow.modelData && ![BluetoothAdapterState.Blocked, BluetoothAdapterState.Enabling, BluetoothAdapterState.Disabling].includes(adapterRow.modelData.state)
                    onClicked: adapterRow.modelData.enabled = !adapterRow.modelData.enabled
                }
            }
            Repeater {
                model: (adapterRow.modelData?.devices?.values || []).filter(device => device.paired)
                Hon.BluetoothDeviceRow {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                    powered: !!adapterRow.modelData?.enabled
                }
            }
            Text {
                visible: !(adapterRow.modelData?.devices?.values || []).some(device => device.paired)
                text: "No paired devices"
                color: Theme.muted
                font.family: Theme.font
            }
        }
    }
}
