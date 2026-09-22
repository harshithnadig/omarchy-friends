import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property bool active: false
    property bool enabled: true
    property bool strong: false
    property color accentColor: Color.accent
    signal clicked()

    implicitWidth: label.implicitWidth + Style.space(root.strong ? 26 : 20)
    implicitHeight: Style.space(root.strong ? 34 : 30)
    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (root.strong) return root.accentColor
            if (root.active) return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
            if (hover.hovered) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.09)
            return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.055)
        }
        border.width: root.strong ? 0 : 1
        border.color: root.active
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.34)
            : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.strong ? Color.background : (root.active ? root.accentColor : Color.foreground)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: root.active || root.strong
    }

    HoverHandler { id: hover }
    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
