import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property bool active: false
    property bool enabled: true
    property bool strong: false
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"
    signal clicked()

    implicitWidth: label.implicitWidth + Style.space(root.strong ? 26 : 20)
    implicitHeight: Style.space(root.strong ? 34 : 30)
    opacity: root.enabled ? 1 : 0.42
    scale: tap.pressed ? 0.97 : (hover.hovered ? 1.015 : 1)

    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.strong
                    ? "#9a72ff"
                    : (root.active || hover.hovered
                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
                       : Qt.rgba(1, 1, 1, 0.072))
            }
            GradientStop {
                position: 0.62
                color: root.strong
                    ? "#6559ef"
                    : (root.active || hover.hovered
                       ? Qt.rgba(0.22, 0.27, 0.58, 0.18)
                       : Qt.rgba(0.14, 0.17, 0.28, 0.040))
            }
            GradientStop {
                position: 1
                color: root.strong
                    ? "#4f8df8"
                    : (root.active || hover.hovered
                       ? Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b, 0.085)
                       : Qt.rgba(1, 1, 1, 0.025))
            }
        }
        border.width: 1
        border.color: root.strong
            ? Qt.rgba(0.82, 0.81, 1.0, 0.72)
            : (root.active
               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.54)
               : Qt.rgba(1, 1, 1, hover.hovered ? 0.16 : 0.10))

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.topMargin: 1
            height: parent.height * 0.44
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.strong ? 0.16 : 0.065) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.strong ? "white" : (root.active ? "#f5f1ff" : "#d9dfef")
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: root.active || root.strong
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
