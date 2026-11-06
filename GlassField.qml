import QtQuick
import QtQuick.Controls
import qs.Commons
import "."

Item {
    id: root

    FriendsPalette { id: palette }

    property alias text: input.text
    property string placeholder: ""
    property string accessibleName: ""
    property bool multiline: false
    property bool readOnly: false
    property color accentColor: palette.primary
    property color coolTint: palette.tertiary
    signal accepted()
    signal edited(string value)

    implicitHeight: Style.space(multiline ? 78 : 40)

    Rectangle {
        anchors.fill: parent
        radius: Style.space(16)
        color: input.activeFocus ? palette.surfaceContainerHighest : palette.surfaceContainerHigh
        border.width: 1
        border.color: input.activeFocus
            ? root.accentColor
            : palette.outlineVariant
    }

    TextInput {
        id: input
        visible: !root.multiline
        Accessible.name: root.accessibleName || root.placeholder || "Text field"
        anchors.fill: parent
        anchors.margins: Style.space(11)
        color: palette.onSurface
        selectionColor: root.accentColor
        selectedTextColor: palette.onColor(root.accentColor)
        font.family: "sans-serif"
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        onAccepted: root.accepted()
        onTextEdited: root.edited(text)

        PlainText {
            visible: input.text === "" && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: palette.onSurfaceVariant
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
        color: palette.onSurface
        placeholderText: root.placeholder
        placeholderTextColor: palette.onSurfaceVariant
        wrapMode: TextArea.Wrap
        background: null
        font.family: "sans-serif"
        font.pixelSize: Style.font.caption
        readOnly: root.readOnly
        onTextEdited: root.edited(text)
    }
}
