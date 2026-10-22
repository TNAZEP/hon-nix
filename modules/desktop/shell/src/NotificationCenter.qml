import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components" as Hon
import "services"
import "theme"

FocusScope {
    ColumnLayout {
        anchors.fill: parent
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

            ScrollBar.vertical: ScrollBar {
            }

            delegate: Hon.NotificationCard {
                required property var modelData

                width: history.width
                entry: modelData
            }

        }

        Text {
            text: "History is kept for this shell session · Esc to close"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
        }

    }

}
