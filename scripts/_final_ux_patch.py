from pathlib import Path
import re


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing patch anchor: {label}")
    return text.replace(old, new, 1)


def regex_once(text, pattern, replacement, label):
    out, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"missing/ambiguous regex anchor: {label} ({count})")
    return out


# BarWidget: provide a first-class Build -> existing private-chat handoff.
bar_path = Path("BarWidget.qml")
bar = bar_path.read_text(encoding="utf-8")
if "function openFriendChat(publicKey)" not in bar:
    bar = replace_once(
        bar,
        '    property string pendingBuildTab: "discover"\n    property bool modernUiFailed: false\n',
        '    property string pendingBuildTab: "discover"\n    property string pendingFriendChatKey: ""\n    property bool modernUiFailed: false\n',
        "bar pending friend key",
    )
    bar = replace_once(
        bar,
        '''    function openBuildTab(tabName) {
        root.pendingBuildTab = tabName || "discover"
        cardOpen = false
        buildCardOpen = true
        if (buildPanelLoader.item && buildPanelLoader.item.tab !== undefined)
            buildPanelLoader.item.tab = root.pendingBuildTab
    }

    function closeBuild() { buildCardOpen = false }
''',
        '''    function openBuildTab(tabName) {
        root.pendingBuildTab = tabName || "discover"
        cardOpen = false
        buildCardOpen = true
        if (buildPanelLoader.item && buildPanelLoader.item.tab !== undefined)
            buildPanelLoader.item.tab = root.pendingBuildTab
    }

    function deliverPendingFriendChat() {
        if (!root.pendingFriendChatKey) return false
        if (!modernPanelLoader.item || typeof modernPanelLoader.item.openChatForPublicKey !== "function") return false
        var key = root.pendingFriendChatKey
        root.pendingFriendChatKey = ""
        modernPanelLoader.item.openChatForPublicKey(key)
        return true
    }

    function openFriendChat(publicKey) {
        if (!publicKey) return false
        root.pendingFriendChatKey = publicKey
        buildCardOpen = false
        cardOpen = true
        if (root.deliverPendingFriendChat()) return true
        Qt.callLater(root.deliverPendingFriendChat)
        return true
    }

    function closeBuild() { buildCardOpen = false }
''',
        "bar friend chat handoff",
    )
    bar = replace_once(
        bar,
        '''        onLoaded: if (item) {
            root.modernUiFailed = false
            item.hostWidget = root
            Qt.callLater(function() { if (item) item.hostWidget = root })
        }
''',
        '''        onLoaded: if (item) {
            root.modernUiFailed = false
            item.hostWidget = root
            Qt.callLater(function() {
                if (item) item.hostWidget = root
                root.deliverPendingFriendChat()
            })
        }
''',
        "bar loader delivers pending chat",
    )
bar_path.write_text(bar, encoding="utf-8")


# Friends V3: let the host open a particular existing friend conversation and
# make encrypted media/link attachments actually clickable (HTTP(S) only).
panel_path = Path("FriendsPanelV3.qml")
panel = panel_path.read_text(encoding="utf-8")
if "function openChatForPublicKey(publicKey)" not in panel:
    panel = replace_once(
        panel,
        '''    function chooseGroup(group) {
        root.selectedGroupId = group && group.id ? group.id : ""
        root.selectedFriendKey = ""
        root.page = "chats"
        root.newChatOpen = false
        Qt.callLater(function() { messageInput.forceActiveFocus() })
    }

    function ensureConversation() {
''',
        '''    function chooseGroup(group) {
        root.selectedGroupId = group && group.id ? group.id : ""
        root.selectedFriendKey = ""
        root.page = "chats"
        root.newChatOpen = false
        Qt.callLater(function() { messageInput.forceActiveFocus() })
    }

    function openChatForPublicKey(publicKey) {
        if (!publicKey) return false
        var list = root.friendsList()
        for (var i = 0; i < list.length; i++) {
            if (list[i].public_key === publicKey) {
                root.chooseFriend(list[i])
                return true
            }
        }
        var incoming = root.requestFor(publicKey)
        if (incoming) {
            root.page = "requests"
            root.requestTab = "received"
            root.showNotice("Accept the request to start chatting")
            return false
        }
        var friendship = root.friendshipFor(publicKey)
        if (friendship && friendship.status === "pending") {
            root.page = "requests"
            root.requestTab = "sent"
            root.showNotice("Friend request is still pending")
            return false
        }
        root.page = "world"
        root.showNotice("Connect with this builder before starting a private chat")
        return false
    }

    function openSafeUrl(url) {
        url = String(url || "").trim()
        if (url.indexOf("https://") !== 0 && url.indexOf("http://") !== 0) {
            root.showNotice("Only HTTP(S) links can be opened")
            return false
        }
        Quickshell.execDetached(["xdg-open", url])
        return true
    }

    function ensureConversation() {
''',
        "V3 public-key chat handoff",
    )

if "onClicked: root.openSafeUrl" not in panel:
    media_pattern = r'''Text \{ id: mediaText; width: parent\.width; visible: modelData\.media && modelData\.media\.length > 0; text: visible \? "↗ " \+ \(\(modelData\.media\[0\]\.url \|\| modelData\.media\[0\]\.href \|\| "Shared link"\)\) : ""; color: modelData\.incoming \? root\.cyan : "#e8e5ff"; font\.family: Style\.font\.family; font\.pixelSize: Style\.font\.caption; elide: Text\.ElideMiddle \}'''
    media_replacement = '''Text {
                                                            id: mediaText
                                                            width: parent.width
                                                            visible: modelData.media && modelData.media.length > 0
                                                            text: visible ? "↗ " + ((modelData.media[0].url || modelData.media[0].href || "Shared link")) : ""
                                                            color: modelData.incoming ? root.cyan : "#e8e5ff"
                                                            font.family: Style.font.family
                                                            font.pixelSize: Style.font.caption
                                                            elide: Text.ElideMiddle
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                enabled: parent.visible
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.openSafeUrl(modelData.media[0].url || modelData.media[0].href || "")
                                                            }
                                                        }'''
    panel = regex_once(panel, media_pattern, media_replacement, "clickable media link")
panel_path.write_text(panel, encoding="utf-8")


# Build Network: "Chat" should open an existing friend conversation; otherwise
# show the true Connect/Requested/Accept relationship action.
build_path = Path("BuildNetworkPanelV3.qml")
build = build_path.read_text(encoding="utf-8")
if "function builderActionLabel(publicKey)" not in build:
    old = '''    function connectBuilder(publicKey) {
        if (!publicKey || !root.friendsService) {
            root.notice = "Open Friends to connect with this builder"
            noticeTimer.restart()
            return
        }
        root.friendsService.requestFriend(publicKey)
        root.notice = "Chat invite sent through Friends"
        noticeTimer.restart()
    }
'''
    new = '''    function incomingFriendRequest(publicKey) {
        var pings = root.friendsService && root.friendsService.globalPings ? root.friendsService.globalPings : []
        for (var i = 0; i < pings.length; i++) {
            if (pings[i] && pings[i].action === "friend_request" && pings[i].public_key === publicKey) return pings[i]
        }
        return null
    }

    function builderActionLabel(publicKey) {
        if (!publicKey || !root.friendsService) return "Connect"
        var friendships = root.friendsService.globalFriendships || ({})
        var relation = friendships[publicKey]
        if (relation && relation.status === "friends") return "Chat"
        if (root.incomingFriendRequest(publicKey)) return "Accept"
        if (relation && relation.status === "pending") return "Requested"
        return "Connect"
    }

    function connectBuilder(publicKey) {
        if (!publicKey || !root.friendsService) {
            root.notice = "Open Friends to connect with this builder"
            noticeTimer.restart()
            return
        }
        var friendships = root.friendsService.globalFriendships || ({})
        var relation = friendships[publicKey]
        if (relation && relation.status === "friends") {
            if (root.hostWidget && typeof root.hostWidget.openFriendChat === "function") {
                root.hostWidget.openFriendChat(publicKey)
                root.notice = "Opening private chat"
            } else {
                root.notice = "Open Friends → Chats to continue the conversation"
            }
            noticeTimer.restart()
            return
        }
        var incoming = root.incomingFriendRequest(publicKey)
        if (incoming) {
            root.friendsService.acceptFriendRequest(incoming.id)
            root.notice = "Friend request accepted — Chat will be ready after sync"
            noticeTimer.restart()
            return
        }
        if (relation && relation.status === "pending") {
            root.notice = "Friend request already pending"
            noticeTimer.restart()
            return
        }
        root.friendsService.requestFriend(publicKey)
        root.notice = "Friend request sent through Friends"
        noticeTimer.restart()
    }
'''
    build = replace_once(build, old, new, "Build friend handoff")

# Replace misleading Chat/Connect labels where the card already has a public key.
replacements = {
    'text: modelData.mine ? "You" : "Chat"': 'text: modelData.mine ? "You" : root.builderActionLabel(modelData.public_key)',
    'text: modelData.public_key === build.profile.public_key ? "You" : "Connect"': 'text: modelData.public_key === build.profile.public_key ? "You" : root.builderActionLabel(modelData.public_key)',
    'text: modelData.public_key === build.profile.public_key ? "You" : "Chat"': 'text: modelData.public_key === build.profile.public_key ? "You" : root.builderActionLabel(modelData.public_key)',
    'text: modelData.mine ? "Testing" : "Chat owner"': 'text: modelData.mine ? "Testing" : root.builderActionLabel(modelData.public_key)',
    'text: "Chat privately"': 'text: root.builderActionLabel(modelData.public_key)',
}
for old, new in replacements.items():
    build = build.replace(old, new)
build_path.write_text(build, encoding="utf-8")
