import QtQuick
import qs.Commons

Item {
    id: root

    property real radius: Style.space(18)
    property real fillOpacity: 0.76
    property real borderOpacity: 0.12
    property real glowOpacity: 0.16
    property bool elevated: false
    property bool selected: false
    property color accentColor: "#7c6cff"
    property color baseColor: "#0a0f1d"
    property color secondaryColor: "#11192d"

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.elevated ? -Style.space(5) : -Style.space(2)
        radius: root.radius + Style.space(5)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                              root.selected ? 0.42 : (root.elevated ? root.glowOpacity : root.glowOpacity * 0.5))
        opacity: root.elevated || root.selected ? 1 : 0.72
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(root.secondaryColor.r, root.secondaryColor.g, root.secondaryColor.b,
                               Math.min(1, root.fillOpacity + 0.08))
            }
            GradientStop {
                position: 0.52
                color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, root.fillOpacity)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0.025, 0.04, 0.09, Math.min(1, root.fillOpacity + 0.04))
            }
        }
        border.width: 1
        border.color: root.selected
            ? Qt.rgba(0.58, 0.54, 1.0, 0.40)
            : Qt.rgba(0.84, 0.87, 1.0, root.borderOpacity)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 1
        height: Math.max(1, root.radius * 0.82)
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.selected ? 0.085 : 0.052) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.space(4)
        anchors.rightMargin: Style.space(4)
        height: Math.max(1, root.radius * 0.58)
        radius: root.radius
        color: Qt.rgba(0, 0, 0, root.elevated ? 0.20 : 0.12)
    }
}
