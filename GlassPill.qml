import QtQuick
import qs.Commons
import "."

Item {
    id: root

    FriendsPalette { id: palette }

    property string text: ""
    property string accessibleName: ""
    property bool active: false
    property bool enabled: true
    property bool strong: false
    property bool compact: false
    property bool displayOnly: false
    property color accentColor: palette.primary
    property color coolTint: palette.tertiary
    signal clicked()

    implicitWidth: label.implicitWidth + Style.space(root.compact ? 18 : root.strong ? 26 : 22)
    implicitHeight: Style.space(root.compact ? 30 : root.strong ? 38 : 34)
    opacity: root.enabled || root.displayOnly ? 1 : 0.48
    scale: tap.pressed ? 0.98 : 1
    activeFocusOnTab: (root.enabled && !root.displayOnly) || root.activeFocus
    Accessible.role: root.displayOnly ? Accessible.StaticText : Accessible.Button
    Accessible.name: root.accessibleName || root.text

    Keys.onPressed: function(event) {
        if (!root.enabled || root.displayOnly) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.strong
            ? root.accentColor
            : root.active
                ? palette.mix(palette.surfaceContainer, root.accentColor, 0.18)
                : hover.hovered || root.activeFocus
                    ? palette.surfaceContainerHigh
                    : palette.surfaceContainerLow
        border.width: root.activeFocus ? 2 : (root.active || root.strong ? 0 : 1)
        border.color: root.activeFocus ? root.coolTint : root.active ? root.accentColor : palette.outlineVariant
    }

    PlainText {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.strong ? palette.onColor(root.accentColor) : root.active ? palette.onColor(palette.mix(palette.surfaceContainer, root.accentColor, 0.18)) : palette.onSurfaceVariant
        font.family: "sans-serif"
        font.pixelSize: Style.font.caption
        font.bold: root.active || root.strong || root.activeFocus
    }

    HoverHandler { id: hover; enabled: !root.displayOnly }
    TapHandler {
        id: tap
        enabled: root.enabled && !root.displayOnly
        onTapped: {
            root.forceActiveFocus()
            root.clicked()
        }
    }
}
