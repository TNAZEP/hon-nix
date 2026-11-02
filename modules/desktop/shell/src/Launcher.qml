import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "components" as Hon
import "services"
import "theme"

FocusScope {
    id: root
    readonly property var matches: {
        const terms = search.text.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
        return DesktopEntries.applications.values.filter(entry => {
            const text = [entry.name, entry.genericName, entry.comment, ...entry.keywords].join(" ").toLocaleLowerCase();
            return !entry.noDisplay && terms.every(term => text.includes(term));
        }).sort((a, b) => a.name.localeCompare(b.name));
    }
    onMatchesChanged: applications.currentIndex = matches.length ? 0 : -1
    function launch(index) {
        const entry = matches[index];
        if (!entry)
            return;
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [Theme.values.terminal, "-e", ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
        ShellState.close();
    }
    Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())
    ColumnLayout {
        anchors.fill: parent
        spacing: 14
        Text {
            text: "Applications"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 22
        }
        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search applications…"
            color: Theme.foreground
            placeholderTextColor: Theme.muted
            selectionColor: Theme.accent
            font.family: Theme.font
            font.pixelSize: 16
            padding: 12
            background: Rectangle {
                color: Theme.surface
                border.color: search.activeFocus ? Theme.accent : Theme.border
            }
            Keys.onDownPressed: applications.currentIndex = Math.min(root.matches.length - 1, applications.currentIndex + 1)
            Keys.onUpPressed: applications.currentIndex = Math.max(0, applications.currentIndex - 1)
            Keys.onReturnPressed: root.launch(applications.currentIndex)
            Keys.onEnterPressed: root.launch(applications.currentIndex)
        }
        ListView {
            id: applications
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.matches
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Hon.Button {
                required property var modelData
                required property int index
                width: applications.width
                height: 48
                selected: applications.currentIndex === index
                onClicked: root.launch(index)
                contentItem: RowLayout {
                    spacing: 12
                    Image {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        sourceSize.width: 28
                        sourceSize.height: 28
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: index === applications.currentIndex ? Theme.background : Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.matches.length === 0
                text: "No applications found"
                color: Theme.muted
                font.family: Theme.font
            }
        }
        Text {
            text: "↑ ↓  Navigate     Enter  Launch     Esc  Close"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
