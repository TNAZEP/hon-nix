import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root
    required property var owner
    property var notification: null
    property var saved: ({})
    property double receivedAt: Date.now()
    property string screenName: ""
    property bool popup: false
    property bool hovered: false
    readonly property bool live: notification !== null
    readonly property var actions: notification ? notification.actions : []
    readonly property var data: notification ? ({
        id: notification.id,
        appName: notification.appName,
        appIcon: notification.appIcon,
        summary: notification.summary,
        body: notification.body,
        image: notification.image,
        urgency: notification.urgency,
        transient: notification.transient,
        progress: notification.hints.value !== undefined && Number.isFinite(Number(notification.hints.value))
            ? Math.max(0, Math.min(100, Number(notification.hints.value))) : -1
    }) : saved
    // Quickshell 0.3.1 exposes the wire timeout in milliseconds.
    readonly property int timeout: !notification || notification.urgency === NotificationUrgency.Critical
        ? 0 : notification.expireTimeout < 0 ? (notification.urgency === NotificationUrgency.Low ? 4000 : 6000)
        : notification.expireTimeout
    property Timer expiry: Timer {
        interval: Math.max(1, root.timeout)
        running: root.live && root.timeout > 0 && !root.hovered
        onTriggered: { if (root.notification) root.notification.expire(); }
    }
    function refresh() {
        if (!notification) return;
        receivedAt = Date.now();
        screenName = ShellState.focusedScreen()?.name || "";
        popup = !owner.dnd && ShellState.panel !== "notifications" && screenName !== "";
        if (timeout > 0 && !hovered) expiry.restart();
    }
    property Connections changes: Connections {
        target: root.notification
        // Coalesce the field changes from one replacement before restarting it.
        function onSummaryChanged() { Qt.callLater(root.refresh); }
        function onBodyChanged() { Qt.callLater(root.refresh); }
        function onHintsChanged() { Qt.callLater(root.refresh); }
        function onActionsChanged() { Qt.callLater(root.refresh); }
        function onExpireTimeoutChanged() { Qt.callLater(root.refresh); }
        function onUrgencyChanged() { Qt.callLater(root.refresh); }
        function onClosed(reason) {
            root.saved = Object.assign({}, root.data, {image: ""});
            root.notification = null;
            root.popup = false;
            root.owner.closed(root, reason);
        }
    }
}
