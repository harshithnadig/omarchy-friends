import QtQuick
import QtQuick.Controls
import qs.Commons
import "."

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
        radius: Style.space(10)
        color: input.activeFocus ? "#18232d" : "#101820"
        border.width: 1
        border.color: input.activeFocus
            ? root.accentColor
            : "#2a3641"
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
        font.family: "sans-serif"
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        onAccepted: root.accepted()

        PlainText {
            visible: input.text === "" && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: "#7c859f"
            font.family: "sans-serif"
            font.pixelSize: Style.font.caption
        }
    }

    TextArea { textFormat: TextEdit.PlainText;
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
        font.family: "sans-serif"
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
    }
}
