import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property bool active: false
    property bool enabled: true
    property bool strong: false
    property color accentColor: "#7c6cff"
    signal clicked()

    implicitWidth: label.implicitWidth + Style.space(root.strong ? 26 : 20)
    implicitHeight: Style.space(root.strong ? 34 : 30)
    opacity: root.enabled ? 1 : 0.42
    scale: tap.pressed ? 0.97 : 1

    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.strong
                    ? "#8776ff"
                    : (root.active || hover.hovered ? Qt.rgba(0.48, 0.42, 1.0, 0.20) : Qt.rgba(1, 1, 1, 0.065))
            }
            GradientStop {
                position: 1
                color: root.strong
                    ? "#5d54e7"
                    : (root.active || hover.hovered ? Qt.rgba(0.18, 0.24, 0.52, 0.18) : Qt.rgba(1, 1, 1, 0.028))
            }
        }
        border.width: 1
        border.color: root.strong
            ? Qt.rgba(0.76, 0.73, 1.0, 0.70)
            : (root.active ? Qt.rgba(0.56, 0.51, 1.0, 0.48) : Qt.rgba(1, 1, 1, 0.10))

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.topMargin: 1
            height: parent.height * 0.43
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, root.strong ? 0.08 : 0.03)
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.strong ? "white" : (root.active ? "#edeaff" : "#d4d9e8")
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
