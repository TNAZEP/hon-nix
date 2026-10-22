import "../theme"
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root

    property bool selected: false
    property string hint: ""

    implicitWidth: Math.max(30, label.implicitWidth + 20)
    implicitHeight: 30
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    ToolTip {
        visible: root.hovered && root.hint.length > 0
        text: root.hint
        delay: 500
        padding: 8

        contentItem: Text {
            text: root.hint
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 12
        }

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
        }

    }

    background: Rectangle {
        color: root.selected || root.down ? Theme.accent : root.hovered || root.activeFocus ? Theme.surface : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }

    contentItem: Text {
        id: label

        text: root.text
        textFormat: Text.PlainText
        color: !root.enabled ? Theme.muted : root.selected ? Theme.background : Theme.foreground
        font.family: Theme.font
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

}
