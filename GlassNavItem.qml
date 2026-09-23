import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property string icon: ""
    property string badge: ""
    property string accessibleName: ""
    property bool selected: false
    property bool enabled: true
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"
    signal clicked()

    implicitHeight: Style.space(42)
    opacity: root.enabled ? 1 : 0.45
    activeFocusOnTab: root.enabled
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
        radius: Style.space(12)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.selected || root.activeFocus
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.selected ? 0.28 : 0.18)
                    : (hover.hovered ? Qt.rgba(1, 1, 1, 0.070) : "transparent")
            }
            GradientStop {
                position: 1
                color: root.selected || root.activeFocus
                    ? Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b, root.selected ? 0.105 : 0.075)
                    : (hover.hovered ? Qt.rgba(0.24, 0.34, 0.62, 0.055) : "transparent")
            }
        }
        border.width: root.selected || root.activeFocus ? 1 : 0
        border.color: root.activeFocus
            ? Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b, 0.88)
            : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.52)

        Rectangle {
            visible: root.selected
            width: Style.space(3)
            height: parent.height - Style.space(12)
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            gradient: Gradient {
                GradientStop { position: 0; color: "#c084fc" }
                GradientStop { position: 0.52; color: "#8b7cff" }
                GradientStop { position: 1; color: "#55d9ff" }
            }
        }

        Rectangle {
            visible: root.selected || root.activeFocus
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            height: 1
            color: Qt.rgba(1, 1, 1, root.activeFocus ? 0.20 : 0.12)
        }
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(13)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(9)

        Text {
            width: Style.space(20)
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: root.selected || root.activeFocus ? "#e9e5ff" : (hover.hovered ? "#d6e9ff" : "#aab1c7")
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        Text {
            width: parent.width - Style.space(20) - badgeBox.width - Style.space(18)
            text: root.text
            color: root.selected || root.activeFocus ? "#f7f7ff" : (hover.hovered ? "#e7ebf7" : "#bac0d2")
            font.family: Style.font.family
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
            gradient: Gradient {
                GradientStop { position: 0; color: root.selected ? "#a56cff" : Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1; color: root.selected ? "#5b8cff" : Qt.rgba(1, 1, 1, 0.055) }
            }
            border.width: 1
            border.color: root.selected ? Qt.rgba(0.82, 0.84, 1.0, 0.50) : Qt.rgba(1, 1, 1, 0.08)
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                color: "white"
                font.family: Style.font.family
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
