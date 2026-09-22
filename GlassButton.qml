import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool selected: false
    property bool enabled: true
    property bool compact: false
    property color accentColor: "#7c6cff"
    signal clicked()

    implicitWidth: labelRow.implicitWidth + Style.space(root.compact ? 16 : 24)
    implicitHeight: Style.space(root.compact ? 30 : 38)
    opacity: root.enabled ? 1 : 0.42
    scale: tap.pressed ? 0.97 : 1

    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Style.space(root.compact ? 10 : 13)
        gradient: Gradient {
            GradientStop { position: 0; color: root.primary ? "#8776ff" : (hover.hovered || root.selected ? Qt.rgba(0.48, 0.42, 1.0, 0.20) : Qt.rgba(1, 1, 1, 0.065)) }
            GradientStop { position: 1; color: root.primary ? "#5e55e8" : (hover.hovered || root.selected ? Qt.rgba(0.28, 0.34, 0.72, 0.17) : Qt.rgba(1, 1, 1, 0.035)) }
        }
        border.width: 1
        border.color: root.primary
            ? Qt.rgba(0.78, 0.76, 1.0, 0.72)
            : (root.selected ? Qt.rgba(0.54, 0.49, 1.0, 0.52) : Qt.rgba(1, 1, 1, 0.105))

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(1, parent.height * 0.42)
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, root.primary ? 0.10 : 0.035)
        }
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.primary ? "white" : "#d9ddff"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        Text {
            text: root.text
            color: root.primary ? "white" : (root.selected ? "#eeeaff" : "#e5e8f4")
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: root.primary || root.selected
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
