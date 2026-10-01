import QtQuick

// All text shown by Friends is plain text, including relay and profile data.
// Qt's AutoText can load remote <img> URLs from untrusted messages.
Text {
    textFormat: Text.PlainText
}
