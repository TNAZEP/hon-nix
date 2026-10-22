import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "components" as Hon
import "theme"
import "services"

ColumnLayout {
    id: root
    property var devices: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
    property bool radioEnabled: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    spacing: 10
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Wi-Fi networks"
            color: Theme.foreground
            font.family: Theme.font
            Layout.fillWidth: true
        }
        Hon.Button {
            objectName: "wifi-settings"
            text: "Network settings"
            onClicked: {
                Quickshell.execDetached(Theme.values.commands.networkSettings);
                ShellState.close();
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.devices.length === 0 || !root.radioEnabled
        text: root.devices.length === 0 ? "No Wi-Fi adapter" : "Wi-Fi is off or blocked by hardware"
        color: Theme.muted
        font.family: Theme.font
        wrapMode: Text.Wrap
    }
    Repeater {
        model: root.devices
        ColumnLayout {
            id: deviceRow
            required property var modelData
            Layout.fillWidth: true
            Component.onDestruction: { if (modelData) modelData.scannerEnabled = false; }
            Binding {
                target: deviceRow.modelData
                property: "scannerEnabled"
                value: root.radioEnabled
                restoreMode: Binding.RestoreNone
            }
            Text {
                text: deviceRow.modelData?.name || ""
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.font
            }
            Text {
                visible: root.radioEnabled && (deviceRow.modelData?.networks?.values || []).length === 0
                text: "Scanning for networks…"
                color: Theme.muted
                font.family: Theme.font
            }
            Repeater {
                model: deviceRow.modelData?.networks?.values || []
                Hon.WifiNetworkRow {
                    required property var modelData
                    Layout.fillWidth: true
                    network: modelData
                    radioEnabled: root.radioEnabled
                }
            }
        }
    }
}
