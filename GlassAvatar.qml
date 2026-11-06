import QtQuick
import qs.Commons
import "."

Item {
    id: root

    FriendsPalette { id: palette }

    property string emoji: "👾"
    property bool online: false
    property bool selected: false
    property real size: Style.space(42)
    property color accentColor: palette.primary
    property color coolTint: palette.tertiary

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.selected ? palette.mix(palette.surfaceContainer, root.accentColor, 0.18) : palette.surfaceContainerHigh
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? root.accentColor : palette.outlineVariant
    }

    PlainText {
        anchors.centerIn: parent
        text: root.emoji || "👾"
        font.family: "sans-serif"
        font.pixelSize: root.size * 0.49
    }

    Rectangle {
        visible: root.online
        width: Math.max(Style.space(9), root.size * 0.22)
        height: width
        radius: width / 2
        color: palette.success
        border.width: 2
        border.color: palette.surfaceContainerLow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
