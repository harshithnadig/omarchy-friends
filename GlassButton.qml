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
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"
    signal clicked()

    implicitWidth: labelRow.implicitWidth + Style.space(root.compact ? 16 : 24)
    implicitHeight: Style.space(root.compact ? 30 : 38)
    opacity: root.enabled ? 1 : 0.42
    scale: tap.pressed ? 0.965 : (hover.hovered ? 1.015 : 1)

    Behavior on scale { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }

    Rectangle {
        visible: root.primary || root.selected
        anchors.fill: parent
        anchors.margins: -Style.space(2)
        radius: Style.space(root.compact ? 12 : 15)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                              root.primary ? 0.28 : 0.18)
    }

    Rectangle {
        anchors.fill: parent
        radius: Style.space(root.compact ? 10 : 13)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.primary
                    ? Qt.rgba(0.58, 0.45, 1.0, 0.98)
                    : (hover.hovered || root.selected
                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                       : Qt.rgba(1, 1, 1, 0.072))
            }
            GradientStop {
                position: 0.58
                color: root.primary
                    ? Qt.rgba(0.38, 0.34, 0.94, 0.97)
                    : (hover.hovered || root.selected
                       ? Qt.rgba(0.24, 0.27, 0.58, 0.19)
                       : Qt.rgba(0.12, 0.16, 0.28, 0.055))
            }
            GradientStop {
                position: 1
                color: root.primary
                    ? Qt.rgba(0.18, 0.56, 0.96, 0.94)
                    : (hover.hovered || root.selected
                       ? Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b, 0.10)
                       : Qt.rgba(1, 1, 1, 0.028))
            }
        }
        border.width: 1
        border.color: root.primary
            ? Qt.rgba(0.82, 0.82, 1.0, 0.76)
            : (root.selected
               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.58)
               : Qt.rgba(1, 1, 1, hover.hovered ? 0.17 : 0.11))

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(2, parent.height * 0.43)
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.primary ? 0.20 : 0.075) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.primary ? "white" : (root.selected ? "#f1eeff" : "#d9e5ff")
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        Text {
            text: root.text
            color: root.primary ? "white" : (root.selected ? "#f7f3ff" : "#e7ebf7")
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
