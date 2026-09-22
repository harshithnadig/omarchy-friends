from pathlib import Path

path = Path("FriendsPanelV3.qml")
text = path.read_text(encoding="utf-8")
old = '''        for (var i = 0; i < list.length; i++) {
            var group = list[i]
            var active = root.groupHasHistory(group.id) || root.selectedGroupId === group.id
            if (!active) continue
            if (!q || (group.name || "Private group").toLowerCase().indexOf(q) >= 0) out.push(group)
        }
'''
new = '''        for (var i = 0; i < list.length; i++) {
            var group = list[i]
            // A private group is itself a conversation. Keep joined/created
            // groups visible even before anyone sends the first message.
            if (!q || (group.name || "Private group").toLowerCase().indexOf(q) >= 0) out.push(group)
        }
'''
if old not in text:
    raise SystemExit("conversationGroups anchor not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
