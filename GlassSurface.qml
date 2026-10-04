import QtQuick
import qs.Commons

Item {
    id: root

    property real radius: Style.space(14)
    property real fillOpacity: 0.92
    property real borderOpacity: 0.12
    property real glowOpacity: 0.16
    property bool elevated: false
    property bool selected: false
    property color accentColor: "#8b7cff"
    property color baseColor: "#101820"
    property color secondaryColor: "#17212b"
    property color coolTint: "#55d9ff"
    property color warmTint: "#34d399"

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.selected || root.elevated ? -Style.space(1) : 0
        radius: root.radius + Style.space(1)
        color: "transparent"
        border.width: root.selected || root.elevated ? 1 : 0
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                              root.selected ? 0.30 : root.glowOpacity * 0.35)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.selected
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.13)
            : Qt.rgba(root.secondaryColor.r, root.secondaryColor.g, root.secondaryColor.b,
                      Math.max(0.86, Math.min(1, root.fillOpacity + 0.12)))
        border.width: 1
        border.color: root.selected
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.46)
            : Qt.rgba(0.62, 0.70, 0.78, root.borderOpacity)
    }
}
