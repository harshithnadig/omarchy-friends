import QtQuick
import QtQuick.Controls
import qs.Commons

Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool multiline: false
    property bool readOnly: false
    property color accentColor: "#7c6cff"
    signal accepted()

    implicitHeight: Style.space(multiline ? 78 : 40)

    Rectangle {
        anchors.fill: parent
        radius: Style.space(12)
        color: Qt.rgba(0.06, 0.08, 0.15, input.activeFocus ? 0.88 : 0.68)
        border.width: 1
        border.color: input.activeFocus ? Qt.rgba(0.48, 0.42, 1.0, 0.72) : Qt.rgba(1, 1, 1, 0.10)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Qt.rgba(1, 1, 1, 0.055)
        }
    }

    TextInput {
        id: input
        visible: !root.multiline
        anchors.fill: parent
        anchors.margins: Style.space(11)
        color: "#edf0fb"
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
            color: "#707890"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }

    TextArea {
        id: area
        visible: root.multiline
        anchors.fill: parent
        anchors.margins: Style.space(5)
        text: root.multiline ? input.text : ""
        onTextChanged: if (root.multiline && input.text !== text) input.text = text
        color: "#edf0fb"
        placeholderText: root.placeholder
        placeholderTextColor: "#707890"
        wrapMode: TextArea.Wrap
        background: null
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
    }
}
