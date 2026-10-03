import QtQuick
import qs.Commons
import "."

Item {
    id: root

    property string emoji: "👾"
    property bool online: false
    property bool selected: false
    property real size: Style.space(42)
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.selected ? "#292439" : "#1b252f"
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? root.accentColor : "#34414d"
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
        color: "#34d399"
        border.width: 2
        border.color: "#101820"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
