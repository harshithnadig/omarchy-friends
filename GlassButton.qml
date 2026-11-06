import QtQuick
import qs.Commons
import "."

Item {
    id: root

    FriendsPalette { id: palette }

    property string text: ""
    property string icon: ""
    property string accessibleName: ""
    property bool primary: false
    property bool selected: false
    property bool enabled: true
    property bool compact: false
    property color accentColor: palette.primary
    property color coolTint: palette.tertiary
    signal clicked()

    implicitWidth: labelRow.implicitWidth + Style.space(root.compact ? 24 : 30)
    implicitHeight: Style.space(root.compact ? 38 : 44)
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
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: root.coolTint
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.primary
            ? root.accentColor
            : root.selected
                ? palette.mix(palette.surfaceContainer, root.accentColor, 0.20)
                : hover.hovered || root.activeFocus
                    ? palette.surfaceContainerHigh
                    : palette.surfaceContainerLow
        border.width: root.primary ? 0 : 1
        border.color: root.selected || root.activeFocus ? root.accentColor : palette.outlineVariant
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        PlainText {
            visible: root.icon !== ""
            text: root.icon
            color: root.primary ? palette.onColor(root.accentColor) : palette.onSurfaceVariant
            font.family: "sans-serif"
            font.pixelSize: Style.font.caption
        }
        PlainText {
            text: root.text
            color: root.primary ? palette.onColor(root.accentColor) : palette.onSurface
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
