import QtQuick
import QtQuick.Layouts
import Quickshell
import "components" as Hon
import "services"
import "theme"

FocusScope {
    id: root
    property string pending: ""
    readonly property var actions: [
        {
            label: "Lock",
            command: "lock",
            confirm: false
        },
        {
            label: "Suspend",
            command: "suspend",
            confirm: false
        },
        {
            label: "Log out",
            command: "logout",
            confirm: true
        },
        {
            label: "Restart",
            command: "reboot",
            confirm: true
        },
        {
            label: "Shut down",
            command: "shutdown",
            confirm: true
        }
    ]
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Text {
            text: "Session"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 22
        }
        Repeater {
            model: root.actions
            Hon.Button {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 44
                text: root.pending === modelData.command ? "Confirm " + modelData.label.toLowerCase() : modelData.label
                selected: root.pending === modelData.command
                Component.onCompleted: {
                    if (index === 0)
                        Qt.callLater(() => forceActiveFocus());
                }
                onClicked: {
                    if (modelData.confirm && root.pending !== modelData.command)
                        root.pending = modelData.command;
                    else {
                        Quickshell.execDetached(Theme.values.commands[modelData.command]);
                        ShellState.close();
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
        Hon.Button {
            Layout.fillWidth: true
            text: "Cancel"
            onClicked: ShellState.close()
        }
    }
}
