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
            text: (selected ? "*" : workspace?.urgent ? "!" : " ") + String(modelData.label)
            implicitWidth: 42
            flat: true
            fontSize: 16
            textColor: workspace?.urgent ? Theme.urgent : Theme.foreground
            selected: root.monitor?.activeWorkspace?.id === modelData.id
            hint: "Workspace " + modelData.label + " · " + modelData.monitor
            onClicked: {
                if (workspace)
                    workspace.activate();
                else
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData.id + " })");
            }
        }
    }
}
