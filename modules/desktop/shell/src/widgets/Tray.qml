import QtQuick
import Quickshell.Services.SystemTray
import "../components" as Hon

Row {
    id: root
    required property var window
    spacing: 2
    Repeater {
        model: SystemTray.items
        Hon.Button {
            id: button
            required property var modelData
            implicitWidth: 28
            hint: modelData.tooltipTitle || modelData.title || modelData.id
            function menu() {
                const point = mapToItem(root.window.contentItem, 0, height);
                modelData.display(root.window, point.x, point.y);
            }
            onClicked: modelData.onlyMenu ? menu() : modelData.activate()
            Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: button.modelData.icon
                sourceSize.width: 20
                sourceSize.height: 20
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    if (event.button === Qt.RightButton)
                        button.menu();
                    else
                        button.modelData.secondaryActivate();
                }
                onWheel: event => button.modelData.scroll(event.angleDelta.y || event.angleDelta.x, event.angleDelta.y === 0)
            }
        }
    }
}
