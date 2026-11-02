pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

QtObject {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var devices: Pipewire.nodes.values.filter(node => node.audio && !node.isStream)
    readonly property var outputs: devices.filter(node => node.isSink)
    readonly property var inputs: devices.filter(node => !node.isSink)
    readonly property bool inputAvailable: !!source?.ready && !!source?.audio
    readonly property int inputVolume: inputAvailable ? Math.round(source.audio.volume * 100) : 0
    readonly property bool inputMuted: inputAvailable ? source.audio.muted : false
    readonly property bool available: !!sink?.ready && !!sink?.audio
    readonly property int volume: available ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: available ? sink.audio.muted : false
    signal adjusted
    signal inputAdjusted
    property bool inputPrimed: false
    onSourceChanged: { inputPrimed = false; inputSettle.restart(); }
    onInputAvailableChanged: { inputPrimed = false; inputSettle.restart(); }
    property Timer inputSettle: Timer {
        interval: 300
        onTriggered: root.inputPrimed = root.inputAvailable
    }
    property Connections inputChanges: Connections {
        target: root.source?.audio || null
        function onVolumeChanged() { if (root.inputPrimed) root.inputAdjusted(); }
        function onMutedChanged() { if (root.inputPrimed) root.inputAdjusted(); }
    }
    property bool primed: false
    onSinkChanged: {
        primed = false;
        settle.restart();
    }
    onAvailableChanged: {
        primed = false;
        settle.restart();
    }
    property Timer settle: Timer {
        interval: 300
        onTriggered: root.primed = root.available
    }
    property Connections changes: Connections {
        target: root.sink?.audio || null
        function onVolumeChanged() {
            if (root.primed)
                root.adjusted();
        }
        function onMutedChanged() {
            if (root.primed)
                root.adjusted();
        }
    }
    property PwObjectTracker tracker: PwObjectTracker {
        objects: root.devices
    }
    function setVolume(value) {
        if (available && Number.isFinite(value))
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }
    function toggleMute() {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }
    function selectOutput(node) {
        if (node?.ready && outputs.includes(node)) Pipewire.preferredDefaultAudioSink = node;
    }
    function selectInput(node) {
        if (node?.ready && inputs.includes(node)) Pipewire.preferredDefaultAudioSource = node;
    }
    function setInputVolume(value) {
        if (inputAvailable && Number.isFinite(value)) source.audio.volume = Math.max(0, Math.min(1, value));
    }
    function toggleInputMute() {
        if (inputAvailable) source.audio.muted = !source.audio.muted;
    }
    property IpcHandler ipc: IpcHandler {
        target: "audio"
        function output(name: string): void { root.selectOutput(root.outputs.find(node => node.name === name)); }
        function input(name: string): void { root.selectInput(root.inputs.find(node => node.name === name)); }
        function volume(percent: int): void { root.setVolume(percent / 100); }
        function microphoneVolume(percent: int): void { root.setInputVolume(percent / 100); }
        function mute(): void { root.toggleMute(); }
        function microphoneMute(): void { root.toggleInputMute(); }
        function status(): string {
            return JSON.stringify({
                output: root.sink?.name || "", input: root.source?.name || "",
                available: root.available, inputAvailable: root.inputAvailable,
                volume: root.volume, muted: root.muted,
                inputVolume: root.inputVolume, inputMuted: root.inputMuted,
                outputs: root.outputs.map(node => ({id: node.id, name: node.name, ready: node.ready})),
                inputs: root.inputs.map(node => ({id: node.id, name: node.name, ready: node.ready}))
            });
        }
    }
}
