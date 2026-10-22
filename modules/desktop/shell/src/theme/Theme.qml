pragma Singleton
import QtQuick

Settings {
    readonly property color background: values.palette.bg
    readonly property color surface: values.palette.bgAlt
    readonly property color foreground: values.palette.fg
    readonly property color muted: values.palette.muted
    readonly property color accent: values.palette.accent
    readonly property color border: values.palette.borderInactive
    readonly property color urgent: values.palette.error
    readonly property string font: values.font
    readonly property int barHeight: 40
}
