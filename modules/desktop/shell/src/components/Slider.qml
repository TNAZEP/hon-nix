import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.Slider {
    id: root
    implicitHeight: 30
    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 4
        color: Theme.surface
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            color: root.enabled ? Theme.accent : Theme.muted
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 12
        height: 18
        color: root.enabled ? Theme.foreground : Theme.muted
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
    }
}
