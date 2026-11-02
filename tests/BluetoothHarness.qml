import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

FocusScope {
    id: root
    property bool present: true
    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const found = findItem(child, name);
            if (found) return found;
        }
        return null;
    }
    QtObject {
        id: device
        property string name: "Test <Headphones>"
        property string address: "00:00:00:00:00:01"
        property bool paired: true
        property bool connected: false
        property bool trusted: false
        property bool blocked: false
        property bool batteryAvailable: true
        property real battery: 0.65
        property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected
        property int forgotten: 0
        function forget() { forgotten++; paired = false; connected = false; }
    }
    QtObject {
        id: adapter
        property string name: "Test Bluetooth adapter"
        property bool enabled: true
        property int state: enabled ? BluetoothAdapterState.Enabled : BluetoothAdapterState.Disabled
        property var devices: ({values: [device]})
    }
    BluetoothPanel {
        width: parent.width
        adapters: root.present ? [adapter] : []
    }
    IpcHandler {
        target: "bluetooth-fixture"
        function focus(name: string): void { root.findItem(root, name)?.forceActiveFocus(); }
        function block(): void { adapter.enabled = false; adapter.state = BluetoothAdapterState.Blocked; }
        function remove(): void { root.present = false; }
        function status(): string {
            return JSON.stringify({
                connected: device.connected, trusted: device.trusted, forgotten: device.forgotten,
                powered: adapter.enabled, canPair: root.findItem(root, "bluetooth-pair").enabled,
                canPower: !!root.findItem(root, "bluetooth-power")?.enabled
            });
        }
    }
}
