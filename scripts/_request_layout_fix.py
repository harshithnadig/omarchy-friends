from pathlib import Path

path = Path("FriendsPanelV3.qml")
text = path.read_text(encoding="utf-8")
old = '''                                                Column {
                                                    width: parent.width - Style.space(58)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: modelData.online ? "Request sent · online now" : "Request sent · waiting for a reply"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: Style.space(6)
                                                    GlassPill { text: "Pending"; active: true; accentColor: root.warning }
                                                    GlassButton { text: "Cancel"; compact: true; onClicked: root.cancelFriendRequest(modelData.public_key) }
                                                }
'''
new = '''                                                Column {
                                                    width: Math.max(Style.space(80), parent.width - sentRequestActions.width - Style.space(60))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: modelData.online ? "Request sent · online now" : "Request sent · waiting for a reply"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                Row {
                                                    id: sentRequestActions
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: Style.space(6)
                                                    GlassPill { text: "Pending"; active: true; accentColor: root.warning }
                                                    GlassButton { text: "Cancel"; compact: true; onClicked: root.cancelFriendRequest(modelData.public_key) }
                                                }
'''
if old not in text:
    raise SystemExit("sent request layout anchor not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
