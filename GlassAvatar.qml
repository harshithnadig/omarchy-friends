import QtQuick
import qs.Commons

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
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.selected
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.48)
                    : Qt.rgba(0.46, 0.40, 1.0, 0.16)
            }
            GradientStop {
                position: 0.56
                color: Qt.rgba(0.10, 0.12, 0.24, 0.86)
            }
            GradientStop {
                position: 1
                color: root.selected
                    ? Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b, 0.18)
                    : Qt.rgba(0.04, 0.07, 0.14, 0.92)
            }
        }
        border.width: 1
        border.color: root.selected
            ? Qt.rgba(0.70, 0.66, 1.0, 0.84)
            : Qt.rgba(0.80, 0.88, 1.0, 0.16)

        Rectangle {
            width: parent.width * 0.72
            height: parent.height * 0.34
            radius: height / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 1
            color: Qt.rgba(1, 1, 1, root.selected ? 0.11 : 0.06)
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.emoji || "👾"
        font.pixelSize: root.size * 0.49
    }

    Rectangle {
        visible: root.online
        width: Math.max(Style.space(9), root.size * 0.22)
        height: width
        radius: width / 2
        color: "#34d399"
        border.width: 2
        border.color: "#07101f"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
