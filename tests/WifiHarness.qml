import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Networking

FocusScope {
    id: root
    property bool radio: true
    property bool present: true
    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const result = findItem(child, name);
            if (result) return result;
        }
        return null;
    }
    QtObject {
        id: network
        property string name: "Test <Wi-Fi>"
        property int security: WifiSecurityType.Wpa2Psk
        property real signalStrength: 0.75
        property bool known: false
        property bool connected: false
        property bool stateChanging: false
        property int attempts: 0
        property int submissions: 0
        property int forgotten: 0
        property bool correctSecret: false
        signal connectionFailed(int reason)
        function connect() {
            attempts++;
            if (known || security === WifiSecurityType.Open) connected = true;
            else connectionFailed(ConnectionFailReason.NoSecrets);
        }
        function disconnect() { connected = false; stateChanging = false; }
        function connectWithPsk(secret) {
            submissions++;
            correctSecret = secret === "fixture-password";
            if (correctSecret) { known = true; connected = true; }
            else connectionFailed(ConnectionFailReason.NoSecrets);
        }
        function forget() { forgotten++; known = false; connected = false; }
    }
    QtObject {
        id: device
        property string name: "fixture-wlan"
        property bool scannerEnabled: false
        property var networks: ({values: [network]})
    }
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        WifiPanel {
            width: parent.width
            devices: root.present ? [device] : []
            radioEnabled: root.radio
        }
    }
    IpcHandler {
        target: "wifi-fixture"
        function focus(name: string): void { root.findItem(root, name)?.forceActiveFocus(); }
        function radio(value: bool): void { root.radio = value; }
        function remove(): void { root.present = false; }
        function security(value: int): void { network.security = value; }
        function fail(): void { network.connectionFailed(ConnectionFailReason.NoSecrets); }
        function status(): string {
            const password = root.findItem(root, "wifi-password");
            return JSON.stringify({
                scanning: device.scannerEnabled, connected: network.connected,
                known: network.known, attempts: network.attempts, submissions: network.submissions,
                forgotten: network.forgotten, correctSecret: network.correctSecret,
                passwordVisible: !!password?.visible, passwordEmpty: !password?.text.length,
                masked: !password || password.echoMode === TextInput.Password
            });
        }
    }
}
