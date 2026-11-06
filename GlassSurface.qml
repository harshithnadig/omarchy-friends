import QtQuick
import qs.Commons
import "."

Item {
    id: root

    FriendsPalette { id: palette }

    property real radius: Style.space(14)
    property real fillOpacity: 1.0
    property real borderOpacity: 1.0
    property real glowOpacity: 0.0
    property bool elevated: false
    property bool selected: false
    property color accentColor: palette.primary
    property color baseColor: palette.surfaceContainer
    property color secondaryColor: palette.surfaceContainerLow
    property color coolTint: palette.tertiary
    property color warmTint: palette.success

    function withOpacity(value, opacity) {
        return Qt.rgba(value.r, value.g, value.b,
                       value.a * Math.max(0, Math.min(1, opacity)))
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.selected || root.elevated ? -Style.space(1) : 0
        radius: root.radius + Style.space(1)
        color: "transparent"
        border.width: root.selected || root.elevated ? 1 : 0
        border.color: root.withOpacity(root.accentColor,
                                       root.selected ? 0.30 : root.glowOpacity * 0.35)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.withOpacity(root.selected
            ? palette.mix(palette.surfaceContainer, root.accentColor, 0.25)
            : root.elevated ? root.baseColor : root.secondaryColor, root.fillOpacity)
        border.width: 1
        border.color: root.withOpacity(root.selected ? root.accentColor : palette.outlineVariant,
                                       root.borderOpacity)
    }
}
