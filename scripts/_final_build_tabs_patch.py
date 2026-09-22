#!/usr/bin/env python3
from pathlib import Path

path = Path("BuildNetworkPanelV3.qml")
text = path.read_text(encoding="utf-8")
old = '''                        Rectangle {
                            width: (parent.width - Style.space(20)) / 6
                            height: parent.height
                            radius: Style.space(12)
                            color: root.tab === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : "transparent"
                            border.width: root.tab === modelData.id ? 1 : 0
                            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.24)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.tab === modelData.id ? accent : muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: root.tab === modelData.id
                            }
                            HoverHandler { id: tabHover }
                            TapHandler { onTapped: root.tab = modelData.id }
                        }
'''
new = '''                        GlassPill {
                            width: (parent.width - Style.space(20)) / 6
                            height: parent.height
                            text: modelData.label
                            active: root.tab === modelData.id
                            strong: root.tab === modelData.id
                            onClicked: root.tab = modelData.id
                        }
'''
if old not in text:
    raise SystemExit("expected Build tab delegate not found; refusing to patch")
text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")
