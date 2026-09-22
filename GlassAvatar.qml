import QtQuick
import qs.Commons

Item {
    id: root

    property string emoji: "👾"
    property bool online: false
    property bool selected: false
    property real size: Style.space(42)
    property color accentColor: "#7c6cff"

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: root.selected ? Qt.rgba(0.48, 0.42, 1.0, 0.36) : Qt.rgba(1, 1, 1, 0.105) }
            GradientStop { position: 1; color: Qt.rgba(0.07, 0.09, 0.17, 0.90) }
        }
        border.width: 1
        border.color: root.selected ? Qt.rgba(0.62, 0.57, 1.0, 0.78) : Qt.rgba(1, 1, 1, 0.12)
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
        border.color: "#0a0f1b"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
