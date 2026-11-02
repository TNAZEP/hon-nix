import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../theme"

ColumnLayout {
    id: root
    required property var device
    property bool powered: false
    property bool forgetArmed: false
    property string message: ""
    readonly property bool busy: [BluetoothDeviceState.Connecting, BluetoothDeviceState.Disconnecting].includes(device?.state) || operation.running
    onPoweredChanged: { if (!powered) { operation.stop(); forgetArmed = false; message = ""; } }
    Timer {
        id: operation
        interval: 15000
        onTriggered: root.message = "Operation not completed. Check Bluetooth settings."
    }
    Connections {
        target: root.device
        function onConnectedChanged() { operation.stop(); root.message = ""; }
    }
    Text {
        Layout.fillWidth: true
        text: (root.device?.name || root.device?.address || "Device") + (root.device?.batteryAvailable ? " · " + Math.round(root.device.battery * 100) + "%" : "")
        textFormat: Text.PlainText
        color: Theme.foreground
        font.family: Theme.font
        elide: Text.ElideRight
    }
    Text {
        text: root.device?.blocked ? "Blocked · change in Bluetooth settings" : root.device?.connected ? "Connected" : root.busy ? "Working…" : "Disconnected"
        color: Theme.muted
        font.family: Theme.font
    }
    RowLayout {
        Button {
            objectName: "bluetooth-connect"
            text: root.device?.connected ? "Disconnect" : "Connect"
            enabled: root.powered && !!root.device && !root.device.blocked && !root.busy
            onClicked: {
                root.message = "";
                operation.restart();
                root.device.connected = !root.device.connected;
            }
        }
        Button {
            objectName: "bluetooth-trust"
            text: root.device?.trusted ? "Trusted" : "Trust device"
            hint: "Trusted devices may reconnect without confirmation"
            selected: !!root.device?.trusted
            enabled: root.powered && !!root.device && !root.busy
            onClicked: root.device.trusted = !root.device.trusted
        }
        Button {
            objectName: "bluetooth-forget"
            text: root.forgetArmed ? "Confirm forget" : "Forget"
            enabled: root.powered && !!root.device && !root.busy
            onClicked: {
                if (!root.forgetArmed) root.forgetArmed = true;
                else { root.forgetArmed = false; root.device.forget(); }
            }
        }
        Button {
            visible: root.forgetArmed
            text: "Cancel"
            onClicked: root.forgetArmed = false
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.message !== ""
        text: root.message
        color: Theme.muted
        font.family: Theme.font
        wrapMode: Text.Wrap
    }
}
