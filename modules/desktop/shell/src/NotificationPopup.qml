import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "components" as Hon
import "services"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var entries: Notifications.entries.filter(entry => entry.popup && entry.screenName === root.modelData?.name).slice(0, 3)
    visible: entries.length > 0
    anchors { top: true; right: true }
    margins { top: 48; right: 12 }
    implicitWidth: Math.min(384, (modelData?.width || 416) - 32)
    implicitHeight: Math.min(stack.implicitHeight, (modelData?.height || 1080) - 80)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "hon-shell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
    Column {
        id: stack
        width: root.width
        spacing: 8
        Repeater {
            model: root.entries
            Hon.NotificationCard {
                required property var modelData
                width: stack.width
                entry: modelData
                compact: true
            }
        }
    }
}
}
