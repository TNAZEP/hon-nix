import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: root

    required property var entry
    property bool compact: false
    readonly property var details: entry.data

    function imageSource(value) {
        if (!value)
            return "";

        if (value.startsWith("/") || value.startsWith("file:") || value.startsWith("image:"))
            return value;

        if (value.includes(":"))
            return "";

        return Quickshell.iconPath(value, true);
    }

    implicitHeight: content.implicitHeight + 24
    color: Theme.surface
    border.color: details.urgency === NotificationUrgency.Critical ? Theme.urgent : Theme.border
    border.width: 1
    Component.onDestruction: {
        if (entry)
            entry.hovered = false;

    }

    HoverHandler {
        onHoveredChanged: root.entry.hovered = hovered
    }

    ColumnLayout {
        id: content

        spacing: 8

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }

        RowLayout {
            Layout.fillWidth: true

            Image {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                source: root.imageSource(root.details.appIcon)
                visible: source.toString() !== ""
                sourceSize.width: 24
                sourceSize.height: 24
            }

            Text {
                Layout.fillWidth: true
                text: root.details.appName || "Notification"
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                text: Qt.formatTime(new Date(root.entry.receivedAt), "HH:mm")
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }

            Button {
                text: "×"
                hint: "Dismiss notification"
                onClicked: Notifications.dismiss(root.entry)
            }

        }

        Text {
            Layout.fillWidth: true
            text: root.details.summary
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 15
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 2 : 4
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.details.body
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 13
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 5 : 12
            elide: Text.ElideRight
        }

        Image {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 100 : 0
            visible: source.toString() !== ""
            source: root.imageSource(root.details.image)
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 512
            sourceSize.height: 200
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.details.progress >= 0

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                color: Theme.background

                Rectangle {
                    width: parent.width * Math.max(0, root.details.progress) / 100
                    height: parent.height
                    color: Theme.accent
                }

            }

            Text {
                text: root.details.progress + "%"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }

        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.entry.actions.length > 0

            Repeater {
                model: root.entry.actions

                Button {
                    required property var modelData

                    text: modelData.text || "Open"
                    width: Math.min(implicitWidth, parent.width)
                    onClicked: {
                        root.entry.popup = false;
                        modelData.invoke();
                    }
                }

            }

        }

    }

}
