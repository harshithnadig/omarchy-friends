import QtQuick
import qs.Commons
import "."

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
        radius: Style.space(10)
        color: root.selected ? "#222a35" : (root.activeFocus || hover.hovered ? "#1a232d" : "transparent")
        border.width: root.activeFocus ? 2 : (root.selected ? 1 : 0)
        border.color: root.activeFocus ? root.coolTint : root.accentColor

        Rectangle {
            visible: root.selected
            width: Style.space(3)
            height: parent.height - Style.space(14)
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            color: root.accentColor
        }
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
            color: root.selected || root.activeFocus ? "#f3f1ff" : "#aab5bf"
            font.family: "sans-serif"
            font.pixelSize: Style.font.bodySmall
        }

        PlainText {
            width: parent.width - Style.space(20) - badgeBox.width - Style.space(18)
            text: root.text
            color: root.selected || root.activeFocus ? "#f5f6f8" : "#c2cbd3"
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
            color: root.selected ? root.accentColor : "#29333e"
            border.width: 1
            border.color: root.selected ? root.accentColor : "#394550"
            PlainText {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                color: "white"
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
