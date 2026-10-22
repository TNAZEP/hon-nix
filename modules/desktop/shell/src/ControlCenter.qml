import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Services.Mpris
import "components" as Hon
import "services"
import "theme"

FocusScope {
    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
        width: scroll.availableWidth
        spacing: 14
        Text {
            text: "Controls"
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 22
        }
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
        WifiPanel { Layout.fillWidth: true }
        BluetoothPanel { Layout.fillWidth: true }
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
        Hon.Button {
            text: "Notifications (" + Notifications.count + ")" + (Notifications.dnd ? " · DND" : "")
            Layout.fillWidth: true
            onClicked: ShellState.toggle("notifications")
        }
        Hon.Button {
            text: "Close"
            Layout.fillWidth: true
            onClicked: ShellState.close()
        }
    }
}
}
