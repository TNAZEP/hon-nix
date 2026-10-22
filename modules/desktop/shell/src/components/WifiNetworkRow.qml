import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Networking
import "../theme"

ColumnLayout {
    id: root
    required property var network
    property bool radioEnabled: true
    property bool requested: false
    property bool askingPassword: false
    property bool forgetArmed: false
    property string message: ""
    readonly property bool pskSupported: [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network?.security)
    readonly property bool busy: attempt.running || !!network?.stateChanging
    spacing: 6

    function reset() {
        requested = false;
        password.clear();
        askingPassword = false;
        forgetArmed = false;
        attempt.stop();
    }
    function start() {
        reset();
        message = "";
        if (!network || !radioEnabled) return;
        if (!network.known && !pskSupported && ![WifiSecurityType.Open, WifiSecurityType.Owe].includes(network?.security)) {
            message = "Set up this network in Network settings.";
            return;
        }
        requested = true;
        attempt.restart();
        network.connect();
    }
    function submit() {
        if (!network || !radioEnabled || busy || !password.text.length) return;
        const secret = password.text;
        reset();
        message = "";
        requested = true;
        attempt.restart();
        network.connectWithPsk(secret);
    }
    onRadioEnabledChanged: { if (!radioEnabled) { reset(); message = ""; } }
    Timer {
        id: attempt
        interval: 30000
        onTriggered: { root.requested = false; root.message = "Connection not completed. Check Network settings or try again."; }
    }
    Connections {
        target: root.network
        function onConnectedChanged() {
            if (root.network?.connected) { root.reset(); root.message = ""; }
        }
        function onConnectionFailed(reason) {
            if (!root.requested) return;
            root.reset();
            if (!root.radioEnabled) return;
            if (reason === ConnectionFailReason.NoSecrets && root.pskSupported) {
                root.askingPassword = true;
                root.message = "Enter the Wi-Fi password. NetworkManager manages saved credentials.";
                Qt.callLater(() => password.forceActiveFocus());
            } else if (reason === ConnectionFailReason.NoSecrets) {
                root.message = "Credentials are required. Open Network settings.";
            } else {
                root.message = "Connection failed: " + ConnectionFailReason.toString(reason);
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.network?.name || "Hidden network"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.font
        }
        Text {
            text: Math.round((root.network?.signalStrength || 0) * 100) + "% · " + WifiSecurityType.toString(root.network?.security ?? WifiSecurityType.Unknown)
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Button {
            objectName: "wifi-connect"
            text: root.network?.connected ? "Disconnect" : root.busy ? "Cancel connection" : "Connect"
            selected: !!root.network?.connected
            enabled: root.radioEnabled
            onClicked: {
                if (root.network?.connected || root.busy) {
                    root.reset();
                    root.message = "";
                    root.network?.disconnect();
                } else root.start();
            }
        }
        Text {
            text: root.busy ? "Connecting…" : root.network?.connected ? "Connected" : root.network?.known ? "Saved" : ""
            color: Theme.muted
            font.family: Theme.font
        }
        Button {
            objectName: "wifi-forget"
            visible: !!root.network?.known
            enabled: !root.busy && root.radioEnabled
            text: root.forgetArmed ? "Confirm forget" : "Forget"
            onClicked: {
                if (!root.forgetArmed) root.forgetArmed = true;
                else { root.reset(); root.message = ""; root.network?.forget(); }
            }
        }
        Button {
            visible: root.forgetArmed
            text: "Cancel"
            onClicked: root.forgetArmed = false
        }
    }
    RowLayout {
        visible: root.askingPassword
        Layout.fillWidth: true
        Controls.TextField {
            id: password
            objectName: "wifi-password"
            Layout.fillWidth: true
            placeholderText: "Wi-Fi password"
            echoMode: Controls.TextField.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            color: Theme.foreground
            placeholderTextColor: Theme.muted
            font.family: Theme.font
            background: Rectangle { color: Theme.background; border.color: password.activeFocus ? Theme.accent : Theme.border }
            onAccepted: root.submit()
            Keys.onEscapePressed: event => { root.reset(); event.accepted = true; }
        }
        Button {
            text: "Join"
            enabled: password.text.length > 0 && !root.busy
            onClicked: root.submit()
        }
        Button {
            text: "Cancel"
            onClicked: root.reset()
        }
    }
    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.message
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 12
    }
}
