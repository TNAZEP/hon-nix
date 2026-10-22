pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root
    property bool dnd: false
    property var entries: []
    readonly property var history: entries.filter(entry => !entry.data.transient)
    readonly property int count: history.length
    onDndChanged: { if (dnd) hidePopups(); }

    function hidePopups() {
        for (const entry of entries) entry.popup = false;
    }
    function dismiss(entry) {
        if (!entries.includes(entry)) return;
        entries = entries.filter(item => item !== entry);
        if (entry.notification) entry.notification.dismiss();
        entry.destroy();
    }
    function clear() {
        for (const entry of entries.slice()) dismiss(entry);
    }
    function closed(entry, reason) {
        if (!entries.includes(entry)) return;
        if (entry.data.transient || reason !== NotificationCloseReason.Expired) dismiss(entry);
    }
    property Component factory: Component {
        NotificationEntry {}
    }
    property NotificationServer server: NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true;
            const entry = root.factory.createObject(root, {owner: root, notification});
            root.entries = [entry, ...root.entries];
            entry.refresh();
            if (notification.lastGeneration) entry.popup = false;
            // Bound memory even when clients send only sticky notifications.
            while (root.entries.length > 100) {
                const oldest = root.entries[root.entries.length - 1];
                if (oldest.notification) oldest.notification.expire();
                root.dismiss(oldest);
            }
        }
    }
    property Connections panels: Connections {
        target: ShellState
        function onPanelChanged() {
            if (ShellState.panel === "notifications") root.hidePopups();
        }
        function onScreensChanged() {
            const names = ShellState.screens.map(screen => screen.name);
            for (const entry of root.entries) {
                if (!names.includes(entry.screenName)) entry.popup = false;
            }
        }
    }
    property IpcHandler ipc: IpcHandler {
        target: "notifications"
        function dnd(): void { root.dnd = !root.dnd; }
        function clear(): void { root.clear(); }
        function status(): string {
            return JSON.stringify({dnd: root.dnd, count: root.count, entries: root.entries.map(entry => ({
                id: entry.data.id, live: entry.live, popup: entry.popup, screen: entry.screenName,
                urgency: entry.data.urgency, progress: entry.data.progress,
                actions: entry.actions.map(action => action.identifier)
            }))});
        }
    }
}
