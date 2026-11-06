import QtQuick
import qs.Commons
import "."

Item {
    id: root

    FriendsPalette { id: palette }

    property string text: ""
    property string icon: ""
    property string badge: ""
    property string accessibleName: ""
    property bool selected: false
    property bool enabled: true
    property color accentColor: palette.primary
    property color coolTint: palette.tertiary
    signal clicked()

    implicitHeight: Style.space(42)
    opacity: root.enabled ? 1 : 0.48
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
        radius: Style.space(18)
        color: root.selected
            ? palette.mix(palette.surfaceContainer, root.accentColor, 0.18)
            : root.activeFocus || hover.hovered
                ? palette.surfaceContainerHigh
                : "transparent"
        border.width: root.activeFocus ? 2 : (root.selected ? 1 : 0)
        border.color: root.activeFocus ? root.coolTint : root.selected ? root.accentColor : palette.outlineVariant
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(13)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(9)

        PlainText {
            width: Style.space(20)
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: root.selected || root.activeFocus ? root.accentColor : palette.onSurfaceVariant
            font.family: "sans-serif"
            font.pixelSize: Style.font.bodySmall
        }

        PlainText {
            width: parent.width - Style.space(20) - badgeBox.width - Style.space(18)
            text: root.text
            color: root.selected || root.activeFocus ? palette.onSurface : palette.onSurfaceVariant
            font.family: "sans-serif"
            font.pixelSize: Style.font.caption
            font.bold: root.selected || root.activeFocus
            elide: Text.ElideRight
        }

        Rectangle {
            id: badgeBox
            visible: root.badge !== ""
            width: visible ? Math.max(Style.space(22), badgeText.implicitWidth + Style.space(10)) : 0
            height: Style.space(22)
            radius: height / 2
            color: root.selected ? root.accentColor : palette.surfaceContainerHighest
            border.width: 1
            border.color: root.selected ? root.accentColor : palette.outlineVariant
            PlainText {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                color: root.selected ? palette.onColor(root.accentColor) : palette.onSurface
                font.family: "sans-serif"
                font.pixelSize: Style.font.caption
                font.bold: true
            }
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus()
            root.clicked()
        }
    }
}
