import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property string icon: ""
    property string badge: ""
    property bool selected: false
    property bool enabled: true
    property color accentColor: "#7c6cff"
    signal clicked()

    implicitHeight: Style.space(42)
    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Style.space(12)
        color: root.selected
            ? Qt.rgba(0.44, 0.39, 1.0, 0.21)
            : (hover.hovered ? Qt.rgba(1, 1, 1, 0.055) : "transparent")
        border.width: root.selected ? 1 : 0
        border.color: Qt.rgba(0.54, 0.49, 1.0, 0.40)

        Rectangle {
            visible: root.selected
            width: Style.space(3)
            height: parent.height - Style.space(14)
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            color: "#8d7dff"
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
            color: root.selected ? "#dcd8ff" : "#aab1c7"
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        Text {
            width: parent.width - Style.space(20) - badgeBox.width - Style.space(18)
            text: root.text
            color: root.selected ? "#f3f4ff" : "#bac0d2"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: root.selected
            elide: Text.ElideRight
        }

        Rectangle {
            id: badgeBox
            visible: root.badge !== ""
            width: visible ? Math.max(Style.space(22), badgeText.implicitWidth + Style.space(10)) : 0
            height: Style.space(22)
            radius: height / 2
            color: root.selected ? "#7969ff" : Qt.rgba(1, 1, 1, 0.075)
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
        onTapped: root.clicked()
    }
}
