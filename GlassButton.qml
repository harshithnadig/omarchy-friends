import QtQuick
import qs.Commons
import "."

Item {
    id: root

    property string text: ""
    property string icon: ""
    property string accessibleName: ""
    property bool primary: false
    property bool selected: false
    property bool enabled: true
    property bool compact: false
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"
    signal clicked()

    implicitWidth: labelRow.implicitWidth + Style.space(root.compact ? 18 : 26)
    implicitHeight: Style.space(root.compact ? 32 : 40)
    opacity: root.enabled ? 1 : 0.48
    scale: tap.pressed ? 0.98 : 1
    activeFocusOnTab: root.enabled || root.activeFocus
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName || root.text || root.icon

    Keys.onPressed: function(event) {
        if (!root.enabled) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked()
            event.accepted = true
        }
    }

    Rectangle {
        visible: root.activeFocus
        anchors.fill: parent
        anchors.margins: -Style.space(2)
        radius: Style.space(root.compact ? 10 : 12)
        color: "transparent"
        border.width: 2
        border.color: root.coolTint
    }

    Rectangle {
        anchors.fill: parent
        radius: Style.space(root.compact ? 8 : 10)
        color: root.primary
            ? root.accentColor
            : (root.selected || hover.hovered || root.activeFocus ? "#273341" : "#1b252f")
        border.width: 1
        border.color: root.primary
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.92)
            : (root.selected || root.activeFocus
               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.70)
               : "#303c48")
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        PlainText {
            visible: root.icon !== ""
            text: root.icon
            color: "#eef1f6"
            font.family: "sans-serif"
            font.pixelSize: Style.font.caption
        }
        PlainText {
            text: root.text
            color: root.primary ? "white" : "#e4eaf0"
            font.family: "sans-serif"
            font.pixelSize: Style.font.caption
            font.bold: root.primary || root.selected
        }
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
