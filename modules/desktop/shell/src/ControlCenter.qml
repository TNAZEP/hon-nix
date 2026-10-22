import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Mpris
import "components" as Hon
import "services"
import "theme"

FocusScope {
    id: root
    property int category: 0
    readonly property var categories: ["Audio", "Display", "Network", "Bluetooth", "Media", "Notifications", "Appearance"]
    FolderListModel {
        id: wallpapers
        folder: ShellState.fileUrl(wallpaperPath.text.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
        showDirs: false
        showHidden: false
        showOnlyReadable: true
        caseSensitive: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        sortField: FolderListModel.Name
    }
    RowLayout {
        anchors.fill: parent
        spacing: 24
        ColumnLayout {
            Layout.preferredWidth: 170
            Layout.fillHeight: true
            spacing: 8
            Text {
                text: "Settings"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 24
                Layout.bottomMargin: 20
            }
            Repeater {
                model: root.categories
                Hon.Button {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 40
                    text: modelData
                    selected: root.category === index
                    onClicked: root.category = index
                }
            }
            Item {
                Layout.fillHeight: true
            }
            Hon.Button {
                text: "Back to pane"
                Layout.fillWidth: true
                onClicked: ShellState.toggle("notifications")
            }
        }
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.border
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.categories[root.category]
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: 22
                }
                Hon.Button {
                    text: "Close"
                    onClicked: ShellState.close()
                }
            }
            ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: scroll.availableWidth
                    spacing: 14
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 6
                        spacing: 14
                        Text {
                            text: "Wallpaper"
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: 18
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Choose an image to apply to all monitors. Your selection is saved automatically."
                            wrapMode: Text.Wrap
                            color: Theme.muted
                            font.family: Theme.font
                        }
                        TextField {
                            id: wallpaperPath
                            Layout.fillWidth: true
                            text: ShellState.wallpaperFolder
                            color: Theme.foreground
                            font.family: Theme.font
                            placeholderText: "Wallpaper folder"
                            selectByMouse: true
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: ShellState.wallpaperError !== ""
                            text: ShellState.wallpaperError
                            wrapMode: Text.Wrap
                            color: Theme.urgent
                            font.family: Theme.font
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: wallpapers.status !== FolderListModel.Loading && wallpapers.count === 0
                            text: "No images found. Add pictures to this folder or enter another folder above."
                            wrapMode: Text.Wrap
                            color: Theme.muted
                            font.family: Theme.font
                        }
                        GridView {
                            id: wallpaperGrid
                            Layout.fillWidth: true
                            Layout.preferredHeight: 350
                            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 180)))
                            cellHeight: 140
                            clip: true
                            model: root.category === 6 ? wallpapers : null
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Hon.Button {
                                required property url fileUrl
                                required property string fileName
                                width: wallpaperGrid.cellWidth - 8
                                height: wallpaperGrid.cellHeight - 8
                                selected: ShellState.wallpaper === fileUrl.toString()
                                hint: fileName
                                enabled: thumbnail.status === Image.Ready && !ShellState.wallpaperBusy
                                onClicked: ShellState.selectWallpaper(fileUrl)
                                contentItem: ColumnLayout {
                                    spacing: 4
                                    Image {
                                        id: thumbnail
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        source: fileUrl
                                        sourceSize.width: 320
                                        sourceSize.height: 180
                                        asynchronous: true
                                        fillMode: Image.PreserveAspectCrop
                                        clip: true
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: fileName
                                        textFormat: Text.PlainText
                                        elide: Text.ElideMiddle
                                        color: Theme.foreground
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 0
                        spacing: 14
                        RowLayout {
                            Layout.fillWidth: true
                            Hon.Button {
                                id: mute
                                text: Audio.muted ? "Unmute" : "Mute"
                                enabled: Audio.available
                                onClicked: Audio.toggleMute()
                                Component.onCompleted: Qt.callLater(() => forceActiveFocus())
                            }
                            Hon.Slider {
                                Layout.fillWidth: true
                                from: 0
                                to: 1
                                value: Audio.volume / 100
                                enabled: Audio.available
                                onMoved: Audio.setVolume(value)
                            }
                            Text {
                                text: Audio.available ? Audio.volume + "%" : "Unavailable"
                                color: Theme.foreground
                                font.family: Theme.font
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Audio.sink?.description || "No audio output"
                            elide: Text.ElideRight
                            color: Theme.muted
                            font.family: Theme.font
                        }
                        Text {
                            text: "Output devices"
                            color: Theme.muted
                            font.family: Theme.font
                        }
                        Repeater {
                            model: Audio.outputs
                            Hon.Button {
                                required property var modelData
                                Layout.fillWidth: true
                                text: modelData.description || modelData.nickname || modelData.name
                                selected: modelData === Audio.sink
                                enabled: modelData.ready
                                onClicked: Audio.selectOutput(modelData)
                            }
                        }
                        Text {
                            text: "Microphone"
                            color: Theme.muted
                            font.family: Theme.font
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Hon.Button {
                                text: Audio.inputMuted ? "Unmute mic" : "Mute mic"
                                enabled: Audio.inputAvailable
                                onClicked: Audio.toggleInputMute()
                            }
                            Hon.Slider {
                                Layout.fillWidth: true
                                from: 0
                                to: 1
                                value: Audio.inputVolume / 100
                                enabled: Audio.inputAvailable
                                onMoved: Audio.setInputVolume(value)
                            }
                            Text {
                                text: Audio.inputAvailable ? Audio.inputVolume + "%" : "Unavailable"
                                color: Theme.foreground
                                font.family: Theme.font
                            }
                        }
                        Repeater {
                            model: Audio.inputs
                            Hon.Button {
                                required property var modelData
                                Layout.fillWidth: true
                                text: modelData.description || modelData.nickname || modelData.name
                                selected: modelData === Audio.source
                                enabled: modelData.ready
                                onClicked: Audio.selectInput(modelData)
                            }
                        }
                        Text {
                            visible: Audio.inputs.length === 0
                            text: "No microphone"
                            color: Theme.muted
                            font.family: Theme.font
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 1
                        spacing: 14
                        Text {
                            text: Brightness.available ? "Brightness · " + Brightness.device : "No backlight device"
                            color: Theme.muted
                            font.family: Theme.font
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: Brightness.available
                            Hon.Slider {
                                Layout.fillWidth: true
                                from: 1
                                to: 100
                                stepSize: 1
                                value: Brightness.percent
                                onMoved: Brightness.setPercent(value)
                            }
                            Text {
                                text: Brightness.percent + "%"
                                color: Theme.foreground
                                font.family: Theme.font
                            }
                        }
                        Text {
                            visible: Brightness.error !== "" && Brightness.available
                            text: Brightness.error
                            color: Theme.urgent
                            font.family: Theme.font
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 2
                        spacing: 14
                        RowLayout {
                            Hon.Button {
                                visible: Networking.devices.values.some(d => d.type === DeviceType.Wifi)
                                text: Networking.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                                enabled: Networking.wifiHardwareEnabled
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Networking.devices.values.filter(d => d.connected).map(d => d.name).join(" · ") || "No network connection"
                            color: Theme.muted
                            font.family: Theme.font
                            wrapMode: Text.Wrap
                        }
                        WifiPanel {
                            Layout.fillWidth: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 3
                        spacing: 14
                        BluetoothPanel {
                            Layout.fillWidth: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 4
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            Repeater {
                                model: Mpris.players
                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.trackTitle || modelData.identity
                                        color: Theme.foreground
                                        font.family: Theme.font
                                        font.pixelSize: 16
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.trackArtist || modelData.identity
                                        color: Theme.muted
                                        font.family: Theme.font
                                        elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        Hon.Button {
                                            text: "Previous"
                                            enabled: modelData.canGoPrevious
                                            onClicked: modelData.previous()
                                        }
                                        Hon.Button {
                                            text: modelData.isPlaying ? "Pause" : "Play"
                                            enabled: modelData.canTogglePlaying
                                            onClicked: modelData.togglePlaying()
                                        }
                                        Hon.Button {
                                            text: "Next"
                                            enabled: modelData.canGoNext
                                            onClicked: modelData.next()
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: Mpris.players.values.length === 0
                                text: "No media playing"
                                color: Theme.muted
                                font.family: Theme.font
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.category === 5
                        spacing: 14
                        Hon.Button {
                            text: Notifications.dnd ? "Do not disturb: on" : "Do not disturb: off"
                            selected: Notifications.dnd
                            onClicked: Notifications.dnd = !Notifications.dnd
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Do not disturb silences popups. Notifications remain in the pane until dismissed or the shell restarts."
                            wrapMode: Text.Wrap
                            color: Theme.muted
                            font.family: Theme.font
                        }
                        Hon.Button {
                            text: "Clear notification history"
                            enabled: Notifications.count > 0
                            onClicked: Notifications.clear()
                        }
                    }
                }
            }
        }
    }
}
