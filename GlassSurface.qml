import QtQuick
import qs.Commons

Item {
    id: root

    property real radius: Style.space(18)
    property real fillOpacity: 0.72
    property real borderOpacity: 0.16
    property real glowOpacity: 0.10
    property bool elevated: false
    property bool selected: false
    property color accentColor: Color.accent

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.elevated ? -Style.space(3) : -1
        radius: root.radius + Style.space(3)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.selected ? 0.34 : root.glowOpacity)
        opacity: root.elevated || root.selected ? 1 : 0.6
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, root.fillOpacity)
        border.width: 1
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, root.selected ? 0.23 : root.borderOpacity)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(1, root.radius * 0.72)
        radius: root.radius
        color: Qt.rgba(1, 1, 1, root.selected ? 0.055 : 0.032)
        opacity: 0.95
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, root.radius * 0.75)
        radius: root.radius
        color: Qt.rgba(0, 0, 0, root.elevated ? 0.12 : 0.07)
    }
}
