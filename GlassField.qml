import QtQuick
import QtQuick.Controls
import qs.Commons

Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string accessibleName: ""
    property bool multiline: false
    property bool readOnly: false
    property color accentColor: "#8b7cff"
    property color coolTint: "#55d9ff"
    signal accepted()

    implicitHeight: Style.space(multiline ? 78 : 40)

    Rectangle {
        anchors.fill: parent
        radius: Style.space(12)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: input.activeFocus
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.13)
                    : Qt.rgba(0.08, 0.10, 0.18, 0.70)
            }
            GradientStop {
                position: 1
                color: input.activeFocus
                    ? Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b, 0.055)
                    : Qt.rgba(0.035, 0.055, 0.12, 0.58)
            }
        }
        border.width: 1
        border.color: input.activeFocus
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.76)
            : Qt.rgba(1, 1, 1, 0.105)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.topMargin: 1
            height: Math.max(1, parent.height * 0.34)
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.09 : 0.045) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    TextInput {
        id: input
        visible: !root.multiline
        Accessible.name: root.accessibleName || root.placeholder || "Text field"
        anchors.fill: parent
        anchors.margins: Style.space(11)
        color: "#f2f5ff"
        selectionColor: root.accentColor
        selectedTextColor: "white"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        onAccepted: root.accepted()

        Text {
            visible: input.text === "" && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: "#7c859f"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }

    TextArea {
        id: area
        visible: root.multiline
        Accessible.name: root.accessibleName || root.placeholder || "Text field"
        anchors.fill: parent
        anchors.margins: Style.space(5)
        text: root.multiline ? input.text : ""
        onTextChanged: if (root.multiline && input.text !== text) input.text = text
        color: "#f2f5ff"
        placeholderText: root.placeholder
        placeholderTextColor: "#7c859f"
        wrapMode: TextArea.Wrap
        background: null
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
    }
}
