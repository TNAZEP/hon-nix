import QtQuick
import Quickshell.Hyprland
import "../components" as Hon
import "../theme"

Row {
    id: root
    required property var screen
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    spacing: 2
    Repeater {
        model: Theme.values.workspaces.filter(w => w.monitor === root.screen?.name)
        Hon.Button {
            required property var modelData
            readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData.id) || null
            text: String(modelData.label)
            implicitWidth: 28
            selected: root.monitor?.activeWorkspace?.id === modelData.id
            hint: "Workspace " + modelData.label + " · " + modelData.monitor
            onClicked: {
                if (workspace)
                    workspace.activate();
                else
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData.id + " })");
            }
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                width: 12
                height: 2
                visible: !!parent.workspace && (parent.workspace.urgent || parent.workspace.toplevels.values.length > 0)
                color: parent.workspace?.urgent ? Theme.urgent : Theme.muted
            }
        }
    }
}
