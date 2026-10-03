import QtQuick
import qs.Commons
import "."

Item {
    id: root

    property string text: ""
    property string accessibleName: ""
    property bool active: false
    property bool enabled: true
    property bool strong: false
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"
    signal clicked()

    implicitWidth: label.implicitWidth + Style.space(root.strong ? 24 : 20)
    implicitHeight: Style.space(root.strong ? 32 : 29)
    opacity: root.enabled ? 1 : 0.48
    scale: tap.pressed ? 0.98 : 1
    activeFocusOnTab: root.enabled || root.activeFocus
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName || root.text

    Keys.onPressed: function(event) {
        if (!root.enabled) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.strong ? root.accentColor : (root.active || hover.hovered ? "#26313d" : "#1b252f")
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.coolTint : (root.active ? root.accentColor : "#303c48")
    }

    PlainText {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.strong ? "white" : "#dce4ec"
        font.family: "sans-serif"
        font.pixelSize: Style.font.caption
        font.bold: root.active || root.strong || root.activeFocus
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus()
            root.clicked()
        }
    }
}
