import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

PopupCard {
    id: root

    property var hostWidget: null
    anchorItem: hostWidget && hostWidget.button ? hostWidget.button : null
    bar: hostWidget ? hostWidget.bar : null
    owner: hostWidget || root
    open: hostWidget ? hostWidget.cardOpen === true : false
    triggerMode: "click"

    readonly property color canvas: "#070b14"
    readonly property color panel: "#0b1120"
    readonly property color panel2: "#111a2f"
    readonly property color ink: "#f3f5ff"
    readonly property color mutedInk: "#98a2ba"
    readonly property color faintInk: "#68738d"
    readonly property color violet: "#7c6cff"
    readonly property color blue: "#5b8cff"
    readonly property color cyan: "#58d6ff"
    readonly property color success: "#34d399"
    readonly property color warning: "#fbbf24"
    readonly property color danger: "#fb7185"

    readonly property var service: hostWidget && hostWidget.service ? hostWidget.service : null
    readonly property var profile: service && service.profile ? service.profile : ({ handle: "Omarchy Builder", avatar: "👾", status_name: "Ready", status_emoji: "🚀", project_name: "", project_desc: "", project_url: "", interests: [], privacy: ({}) })
    readonly property var world: service && service.globalPeers ? service.globalPeers : []
    readonly property var pings: service && service.globalPings ? service.globalPings : []
    readonly property var friendships: service && service.globalFriendships ? service.globalFriendships : ({})
    readonly property var messages: service && service.globalMessages ? service.globalMessages : []
    readonly property var groups: service && service.globalGroups ? service.globalGroups : []
    readonly property var community: service && service.globalCommunity ? service.globalCommunity : []
    readonly property var worldStatus: service && service.globalStatus ? service.globalStatus : ({ relay_count: 0, relay_total: 0, last_sync_age: "never", last_error: "" })
    readonly property var updateInfo: service && service.updateInfo ? service.updateInfo : ({ available: false, current: "4.15.1", latest: "4.15.1" })
    readonly property string reportUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=bug&title=Omarchy%20Friends%20report"

    property string page: "chats"
    property string requestTab: "received"
    property string chatQuery: ""
    property string worldQuery: ""
    property string worldFilter: "all"
    property string selectedFriendKey: ""
    property string selectedGroupId: ""
    property string messageDraft: ""
    property string mediaDraft: ""
    property string draftConversationKey: ""
    property bool mediaComposerOpen: false
    property string communityDraft: ""
    property string notice: ""
    property bool newChatOpen: false
    property bool groupCreateOpen: false
    property string groupNameDraft: ""
    property var groupMemberKeys: []
    property string handleDraft: ""
    property string projectNameDraft: ""
    property string projectDescDraft: ""
    property string projectUrlDraft: ""
    property var interestsDraft: []
    property bool serviceSignalsConnected: false

    contentWidth: root.fittedContentWidth(Style.space(820))
    contentHeight: root.fittedContentHeight(Style.space(690))

    function showNotice(text) {
        root.notice = text || "Done"
        noticeTimer.restart()
    }

    function connectServiceSignals() {
        if (!root.service || root.serviceSignalsConnected) return
        root.service.actionResult.connect(function(ok, message) { root.showNotice(message || (ok ? "Done" : "Something went wrong")) })
        root.service.eventReceived.connect(function(event) { if (event && event.message) root.showNotice(event.message) })
        root.serviceSignalsConnected = true
    }

    onServiceChanged: connectServiceSignals()
    Component.onCompleted: connectServiceSignals()

    function worldPeer(publicKey) {
        for (var i = 0; i < root.world.length; i++) {
            if (root.world[i] && root.world[i].public_key === publicKey) return root.world[i]
        }
        return null
    }

    function friendsList() {
        var out = []
        for (var key in root.friendships) {
            var f = root.friendships[key]
            if (!f || f.status !== "friends") continue
            var item = Object.assign({}, f)
            item.public_key = key
            var live = root.worldPeer(key)
            if (live) {
                item.handle = live.handle || item.handle
                item.avatar = live.avatar || item.avatar
                item.activity = live.activity || live.status_name || item.activity
                item.online = true
                item.project_name = live.project_name || item.project_name
                item.common_ground = live.common_ground || []
            }
            out.push(item)
        }
        return out
    }

    function incomingFriendRequests() {
        var out = []
        for (var i = 0; i < root.pings.length; i++) {
            if (root.pings[i] && root.pings[i].action === "friend_request") out.push(root.pings[i])
        }
        return out
    }

    function sentFriendRequests() {
        var out = []
        for (var key in root.friendships) {
            var f = root.friendships[key]
            if (!f || f.status !== "pending") continue
            var item = Object.assign({}, f)
            item.public_key = key
            var live = root.worldPeer(key)
            if (live) {
                item.handle = live.handle || item.handle
                item.avatar = live.avatar || item.avatar
                item.online = true
            }
            out.push(item)
        }
        return out
    }

    function groupsList() {
        return root.groups || []
    }

    function directHasHistory(publicKey) {
        for (var i = 0; i < root.messages.length; i++) {
            var m = root.messages[i]
            if (m && !m.group_id && m.public_key === publicKey) return true
        }
        return false
    }

    function groupHasHistory(groupId) {
        for (var i = 0; i < root.messages.length; i++) {
            var m = root.messages[i]
            if (m && m.group_id === groupId) return true
        }
        return false
    }

    function lastMessageIndexForFriend(publicKey) {
        for (var i = root.messages.length - 1; i >= 0; i--) {
            var m = root.messages[i]
            if (m && !m.group_id && m.public_key === publicKey) return i
        }
        return -1
    }

    function lastMessageIndexForGroup(groupId) {
        for (var i = root.messages.length - 1; i >= 0; i--) {
            var m = root.messages[i]
            if (m && m.group_id === groupId) return i
        }
        return -1
    }

    function conversationFriends() {
        var q = root.chatQuery.trim().toLowerCase()
        var out = []
        var list = root.friendsList()
        for (var i = 0; i < list.length; i++) {
            var friend = list[i]
            var active = root.directHasHistory(friend.public_key) || root.selectedFriendKey === friend.public_key
            if (!active) continue
            var hay = ((friend.handle || "") + " " + root.lastMessagePreview(friend.public_key)).toLowerCase()
            if (!q || hay.indexOf(q) >= 0) out.push(friend)
        }
        out.sort(function(a, b) { return root.lastMessageIndexForFriend(b.public_key) - root.lastMessageIndexForFriend(a.public_key) })
        return out
    }

    function conversationGroups() {
        var q = root.chatQuery.trim().toLowerCase()
        var out = []
        var list = root.groupsList()
        for (var i = 0; i < list.length; i++) {
            var group = list[i]
            // A private group is itself a conversation. Keep joined/created
            // groups visible even before anyone sends the first message.
            if (!q || (group.name || "Private group").toLowerCase().indexOf(q) >= 0) out.push(group)
        }
        out.sort(function(a, b) { return root.lastMessageIndexForGroup(b.id) - root.lastMessageIndexForGroup(a.id) })
        return out
    }

    function selectedFriend() {
        if (!root.selectedFriendKey || root.selectedGroupId) return null
        var list = root.friendsList()
        for (var i = 0; i < list.length; i++) if (list[i].public_key === root.selectedFriendKey) return list[i]
        return null
    }

    function selectedGroup() {
        if (!root.selectedGroupId) return null
        var list = root.groupsList()
        for (var i = 0; i < list.length; i++) if (list[i].id === root.selectedGroupId) return list[i]
        return null
    }

    function conversationMessages() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        var out = []
        if (!friend && !group) return out
        for (var i = 0; i < root.messages.length; i++) {
            var m = root.messages[i]
            if (!m) continue
            if (group && m.group_id === group.id) out.push(m)
            else if (friend && !m.group_id && m.public_key === friend.public_key) out.push(m)
        }
        return out.slice(Math.max(0, out.length - 80))
    }

    function lastMessagePreview(publicKey) {
        for (var i = root.messages.length - 1; i >= 0; i--) {
            var m = root.messages[i]
            if (m && !m.group_id && m.public_key === publicKey) {
                var t = m.text || "Shared a link"
                return (m.incoming ? "" : "You · ") + t
            }
        }
        return "Start a private chat"
    }

    function groupLastMessagePreview(groupId) {
        for (var i = root.messages.length - 1; i >= 0; i--) {
            var m = root.messages[i]
            if (m && m.group_id === groupId) return (m.incoming ? "" : "You · ") + (m.text || "Shared a link")
        }
        return "Start the group conversation"
    }

    function prepareDraftForConversation(key) {
        if (root.draftConversationKey && root.draftConversationKey !== key) {
            root.messageDraft = ""
            root.mediaDraft = ""
            root.mediaComposerOpen = false
        }
        root.draftConversationKey = key
    }

    function chooseFriend(friend) {
        root.prepareDraftForConversation("friend:" + (friend && friend.public_key ? friend.public_key : ""))
        root.selectedFriendKey = friend && friend.public_key ? friend.public_key : ""
        root.selectedGroupId = ""
        root.page = "chats"
        root.newChatOpen = false
        Qt.callLater(function() { messageInput.forceActiveFocus() })
    }

    function chooseGroup(group) {
        root.prepareDraftForConversation("group:" + (group && group.id ? group.id : ""))
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
        if (root.selectedFriend() || root.selectedGroup()) return
        var fs = root.conversationFriends()
        var gs = root.conversationGroups()
        if (fs.length > 0 && gs.length > 0) {
            if (root.lastMessageIndexForFriend(fs[0].public_key) >= root.lastMessageIndexForGroup(gs[0].id)) root.chooseFriend(fs[0])
            else root.chooseGroup(gs[0])
        } else if (fs.length > 0) root.chooseFriend(fs[0])
        else if (gs.length > 0) root.chooseGroup(gs[0])
    }

    function sendMessage() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        var text = root.messageDraft.trim()
        var media = root.mediaDraft.trim()
        if (!root.service || (!friend && !group)) { root.showNotice("Choose a conversation first"); return }
        if (!text && !media) return
        if (group) root.service.sendGroupMessage(group.id, text, media)
        else root.service.sendDm(friend.public_key, text, media)
        root.messageDraft = ""
        root.mediaDraft = ""
        root.mediaComposerOpen = false
    }

    function sendCommunity() {
        var text = root.communityDraft.trim()
        if (!text || !root.service) return
        root.service.sendCommunity(text)
        root.communityDraft = ""
    }

    function filteredWorld() {
        var q = root.worldQuery.trim().toLowerCase()
        var out = []
        for (var i = 0; i < root.world.length; i++) {
            var p = root.world[i]
            if (!p) continue
            var friendship = root.friendshipFor(p.public_key)
            if (root.worldFilter === "new" && friendship) continue
            if (root.worldFilter === "friends" && (!friendship || friendship.status !== "friends")) continue
            if (root.worldFilter === "building" && !(p.project_name || "").trim()) continue
            var common = p.common_ground || []
            var hay = [p.handle || "", p.activity || "", p.project_name || "", p.project_desc || "", p.status_name || "", common.join ? common.join(" ") : ""].join(" ").toLowerCase()
            if (!q || hay.indexOf(q) >= 0) out.push(p)
        }
        return out
    }

    function friendshipFor(publicKey) {
        return publicKey && root.friendships[publicKey] ? root.friendships[publicKey] : null
    }

    function requestFor(publicKey) {
        var reqs = root.incomingFriendRequests()
        for (var i = 0; i < reqs.length; i++) if (reqs[i].public_key === publicKey) return reqs[i]
        return null
    }

    function peerActionLabel(peer) {
        var f = root.friendshipFor(peer && peer.public_key)
        if (f && f.status === "friends") return "Message"
        if (root.requestFor(peer && peer.public_key)) return "Accept"
        if (f && f.status === "pending") return "Requested"
        if (peer && peer.can_chat === false) return "Needs update"
        return "Connect"
    }

    function activatePeer(peer) {
        if (!peer || !peer.public_key || !root.service) return
        var f = root.friendshipFor(peer.public_key)
        if (f && f.status === "friends") {
            root.chooseFriend(Object.assign({}, f, { public_key: peer.public_key, handle: peer.handle || f.handle, avatar: peer.avatar || f.avatar }))
            return
        }
        var req = root.requestFor(peer.public_key)
        if (req) {
            root.service.acceptFriendRequest(req.id)
            root.prepareDraftForConversation("friend:" + peer.public_key)
            root.selectedFriendKey = peer.public_key
            root.selectedGroupId = ""
            root.page = "chats"
            return
        }
        if (!f || f.status !== "pending") root.service.requestFriend(peer.public_key)
    }

    function declineFriendRequest(pingId) {
        if (root.service && pingId) root.service.declineFriendRequest(pingId)
    }

    function cancelFriendRequest(publicKey) {
        if (root.service && publicKey) root.service.cancelFriendRequest(publicKey)
    }

    function blockPeer(peer) {
        if (!root.service || !peer || !peer.public_key) return
        root.service.blockGlobal(peer.public_key)
        if (root.selectedFriendKey === peer.public_key) root.selectedFriendKey = ""
        root.showNotice((peer.handle || "Builder") + " blocked")
    }

    function closeConversation() {
        root.selectedFriendKey = ""
        root.selectedGroupId = ""
    }

    function reportPeer(peer) {
        if (!peer || !peer.public_key) return
        var payload = "Omarchy Friends report\n\nHandle: " + (peer.handle || "Unknown") + "\nPublic key: " + peer.public_key + "\n\nWhat happened?\n"
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(payload) + " | wl-copy"])
        Quickshell.execDetached(["xdg-open", root.reportUrl])
        root.showNotice("Copied a report template and opened GitHub")
    }

    function toggleGroupMember(publicKey) {
        var next = (root.groupMemberKeys || []).slice()
        var idx = next.indexOf(publicKey)
        if (idx >= 0) next.splice(idx, 1)
        else if (next.length < 11) next.push(publicKey)
        root.groupMemberKeys = next
    }

    function createGroup() {
        var name = root.groupNameDraft.trim()
        if (!root.service || !name || root.groupMemberKeys.length < 2) {
            root.showNotice("Name the group and choose at least two friends")
            return
        }
        root.service.createGroup(name, root.groupMemberKeys)
        root.groupNameDraft = ""
        root.groupMemberKeys = []
        root.groupCreateOpen = false
    }

    function openProfile() {
        root.page = "profile"
        root.handleDraft = root.profile.handle || ""
        root.projectNameDraft = root.profile.project_name || ""
        root.projectDescDraft = root.profile.project_desc || ""
        root.projectUrlDraft = root.profile.project_url || ""
        root.interestsDraft = (root.profile.interests || []).slice ? (root.profile.interests || []).slice() : []
    }

    function saveProfile() {
        if (!root.service) return
        root.service.setProfile(root.handleDraft, root.projectNameDraft, root.projectDescDraft, root.projectUrlDraft)
        root.service.setInterests(root.interestsDraft)
        root.showNotice("Profile saved")
    }

    function toggleInterest(id) {
        var next = (root.interestsDraft || []).slice()
        var idx = next.indexOf(id)
        if (idx >= 0) next.splice(idx, 1)
        else if (next.length < 4) next.push(id)
        else { root.showNotice("Choose up to four interests"); return }
        root.interestsDraft = next
    }

    function copyInvite() {
        if (!root.profile.public_key) { root.showNotice("Invite is not ready yet"); return }
        var value = "omarchy-friends://invite/" + root.profile.public_key
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(value) + " | wl-copy"])
        root.showNotice("Invite copied")
    }

    function openBuild(tabName) {
        if (root.hostWidget && typeof root.hostWidget.openBuildTab === "function") root.hostWidget.openBuildTab(tabName || "discover")
        else if (root.hostWidget && typeof root.hostWidget.openBuild === "function") root.hostWidget.openBuild()
    }

    function formatVersion() {
        return root.updateInfo.current || "4.15.1"
    }

    Item {
        width: 0
        height: 0
        visible: false
        Timer { id: noticeTimer; interval: 2800; onTriggered: root.notice = "" }
    }

    onOpenChanged: if (root.open) Qt.callLater(root.ensureConversation)

    Rectangle {
        anchors.fill: parent
        radius: Style.space(24)
        color: root.canvas
        border.width: 1
        border.color: Qt.rgba(0.55, 0.60, 1.0, 0.22)
        clip: true

        Rectangle {
            width: Style.space(360)
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -Style.space(170)
            anchors.topMargin: -Style.space(210)
            color: Qt.rgba(0.43, 0.35, 1.0, 0.085)
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: Style.space(64)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(18)
                    anchors.rightMargin: Style.space(16)
                    spacing: Style.space(10)

                    GlassAvatar {
                        size: Style.space(38)
                        emoji: root.profile.avatar || "🦊"
                        online: true
                        selected: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: Style.space(250)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: "Omarchy Friends"
                            color: root.ink
                            font.family: Style.font.family
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                        }
                        Text {
                            text: root.page === "chats" ? "Private conversations" : root.page === "requests" ? "Connection requests" : root.page === "world" ? "Discover Omarchy people" : root.page === "circles" ? "Community room" : "Your profile & presence"
                            color: root.mutedInk
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }

                    Item { width: Math.max(0, parent.width - Style.space(250) - Style.space(38) - versionPill.width - buildButton.width - Style.space(70)); height: 1 }

                    GlassPill {
                        id: versionPill
                        text: "v" + root.formatVersion()
                        active: root.updateInfo.available
                        accentColor: root.updateInfo.available ? root.warning : root.violet
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: if (root.updateInfo.available && root.service) root.service.updatePlugin()
                    }

                    GlassButton {
                        id: buildButton
                        text: "Build Network"
                        icon: "✦"
                        compact: true
                        primary: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.openBuild("discover")
                    }
                }
            }

            GlassSurface {
                visible: root.updateInfo.available
                width: parent.width - Style.space(24)
                height: visible ? Style.space(46) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Style.space(14)
                fillOpacity: 0.90
                selected: true
                accentColor: root.warning

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)
                    Text {
                        width: parent.width - updateNowButton.width - Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "A newer Friends build is available. Update to keep messaging and Build Network compatible."
                        color: "#f7e6a7"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                    GlassButton { id: updateNowButton; text: "Update"; icon: "↻"; compact: true; primary: true; anchors.verticalCenter: parent.verticalCenter; onClicked: if (root.service) root.service.updatePlugin() }
                }
            }

            Item { width: 1; height: root.updateInfo.available ? Style.space(7) : 0 }

            Row {
                width: parent.width
                height: parent.height - Style.space(64) - (root.updateInfo.available ? Style.space(53) : 0) - Style.space(30)
                spacing: Style.space(10)

                Item {
                    width: Style.space(142)
                    height: parent.height

                    GlassSurface {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        radius: Style.space(18)
                        fillOpacity: 0.60
                        borderOpacity: 0.08
                    }

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(17)
                        anchors.rightMargin: Style.space(7)
                        anchors.topMargin: Style.space(12)
                        anchors.bottomMargin: Style.space(10)
                        spacing: Style.space(4)

                        Text { text: "FRIENDS"; color: root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 1.1 }
                        Item { width: 1; height: Style.space(3) }

                        GlassNavItem {
                            width: parent.width
                            text: "Chats"
                            icon: "◉"
                            selected: root.page === "chats"
                            onClicked: { root.page = "chats"; root.ensureConversation() }
                        }
                        GlassNavItem {
                            width: parent.width
                            text: "Requests"
                            icon: "↔"
                            badge: root.incomingFriendRequests().length > 0 ? String(root.incomingFriendRequests().length) : ""
                            selected: root.page === "requests"
                            onClicked: root.page = "requests"
                        }
                        GlassNavItem { width: parent.width; text: "World"; icon: "◎"; selected: root.page === "world"; onClicked: root.page = "world" }
                        GlassNavItem { width: parent.width; text: "Circles"; icon: "◌"; selected: root.page === "circles"; onClicked: root.page = "circles" }
                        GlassNavItem { width: parent.width; text: "Build"; icon: "⌁"; badge: "NEW"; onClicked: root.openBuild("discover") }
                        GlassNavItem { width: parent.width; text: "Me"; icon: "◇"; selected: root.page === "profile"; onClicked: root.openProfile() }

                        Item { width: 1; height: Style.space(11) }
                        Text { text: "QUICK"; color: root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 1.0 }
                        Item { width: 1; height: Style.space(2) }
                        GlassNavItem { width: parent.width; text: "New chat"; icon: "+"; onClicked: { root.newChatOpen = true; root.page = "chats" } }
                        GlassNavItem { width: parent.width; text: "Ask help"; icon: "?"; onClicked: root.openBuild("help") }
                        GlassNavItem { width: parent.width; text: "Share setup"; icon: "⌘"; onClicked: root.openBuild("share") }

                        Item { width: 1; height: Math.max(0, parent.height - Style.space(410)) }

                        GlassSurface {
                            width: parent.width
                            height: Style.space(58)
                            radius: Style.space(13)
                            fillOpacity: 0.46
                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(8)
                                spacing: 1
                                Text { text: root.worldStatus.last_error ? "Reconnecting" : "Connected"; color: root.worldStatus.last_error ? root.warning : root.success; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                Text { width: parent.width; text: (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0) + " relays"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                        }
                    }
                }

                Item {
                    id: contentArea
                    width: parent.width - Style.space(152)
                    height: parent.height

                    // CHATS: only real conversations live here. Requests and the full friends list are separate.
                    Row {
                        visible: root.page === "chats"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(10)

                        GlassSurface {
                            width: Style.space(238)
                            height: parent.height
                            radius: Style.space(18)
                            fillOpacity: 0.67
                            borderOpacity: 0.08

                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(8)

                                Row {
                                    width: parent.width
                                    spacing: Style.space(6)
                                    Column {
                                        width: parent.width - newChatButton.width - Style.space(6)
                                        Text { width: parent.width; text: "Chats"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
                                        Text { width: parent.width; text: "Only conversations you've opened"; color: root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: newChatButton; text: "New"; icon: "+"; compact: true; primary: true; anchors.verticalCenter: parent.verticalCenter; onClicked: root.newChatOpen = true }
                                }

                                GlassField { width: parent.width; placeholder: "Search chats"; text: root.chatQuery; onTextChanged: root.chatQuery = text }

                                Flickable {
                                    width: parent.width
                                    height: parent.height - Style.space(90)
                                    contentWidth: width
                                    contentHeight: convoList.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                    Column {
                                        id: convoList
                                        width: parent.width
                                        spacing: Style.space(6)

                                        Repeater {
                                            model: root.conversationGroups()
                                            GlassSurface {
                                                width: parent.width
                                                height: Style.space(62)
                                                radius: Style.space(13)
                                                selected: root.selectedGroupId === modelData.id
                                                fillOpacity: selected ? 0.78 : 0.48
                                                TapHandler { onTapped: root.chooseGroup(modelData) }
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(8)
                                                    spacing: Style.space(8)
                                                    GlassAvatar { size: Style.space(36); emoji: "🫂"; online: true; selected: root.selectedGroupId === modelData.id }
                                                    Column {
                                                        width: parent.width - Style.space(46)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { width: parent.width; text: modelData.name || "Private group"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        Text { width: parent.width; text: root.groupLastMessagePreview(modelData.id); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: root.conversationFriends()
                                            GlassSurface {
                                                width: parent.width
                                                height: Style.space(62)
                                                radius: Style.space(13)
                                                selected: root.selectedFriendKey === modelData.public_key
                                                fillOpacity: selected ? 0.78 : 0.48
                                                TapHandler { onTapped: root.chooseFriend(modelData) }
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(8)
                                                    spacing: Style.space(8)
                                                    GlassAvatar { size: Style.space(36); emoji: modelData.avatar || "👾"; online: modelData.online === true; selected: root.selectedFriendKey === modelData.public_key }
                                                    Column {
                                                        width: parent.width - Style.space(46)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { width: parent.width; text: modelData.handle || "Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        Text { width: parent.width; text: root.lastMessagePreview(modelData.public_key); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                }
                                            }
                                        }

                                        Column {
                                            visible: root.conversationFriends().length === 0 && root.conversationGroups().length === 0
                                            width: parent.width
                                            spacing: Style.space(8)
                                            topPadding: Style.space(26)
                                            Text { width: parent.width; text: "No chats yet"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            Text { width: parent.width; text: "Start one from New chat. Your full friends list stays out of the way."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                            GlassButton { anchors.horizontalCenter: parent.horizontalCenter; text: "New chat"; icon: "+"; primary: true; onClicked: root.newChatOpen = true }
                                        }
                                    }
                                }
                            }
                        }

                        GlassSurface {
                            width: parent.width - Style.space(248)
                            height: parent.height
                            radius: Style.space(18)
                            fillOpacity: 0.70
                            elevated: true

                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(14)
                                spacing: Style.space(8)

                                Row {
                                    width: parent.width
                                    height: Style.space(46)
                                    spacing: Style.space(9)
                                    readonly property var friend: root.selectedFriend()
                                    readonly property var group: root.selectedGroup()
                                    GlassAvatar { size: Style.space(40); emoji: parent.group ? "🫂" : (parent.friend ? (parent.friend.avatar || "👾") : "✦"); online: parent.group ? true : (parent.friend && parent.friend.online === true); selected: true }
                                    Column {
                                        width: parent.width - focusButton.width - buildTogetherButton.width - closeChatButton.width - reportChatButton.width - Style.space(88)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { width: parent.width; text: parent.parent.group ? (parent.parent.group.name || "Private group") : (parent.parent.friend ? (parent.parent.friend.handle || "Builder") : "Choose a chat"); color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                        Text { width: parent.width; text: parent.parent.group ? "Private group · encrypted" : (parent.parent.friend ? (parent.parent.friend.online ? "Online now" : "Private chat") : "Pick a conversation or start a new one"); color: parent.parent.friend && parent.parent.friend.online ? root.success : root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: focusButton; text: "Focus"; icon: "◷"; compact: true; enabled: root.selectedFriend() !== null; onClicked: if (root.service && root.selectedFriend()) root.service.inviteGlobalFocus(root.selectedFriend().public_key) }
                                    GlassButton { id: buildTogetherButton; text: "Build"; icon: "⌁"; compact: true; enabled: root.selectedFriend() !== null || root.selectedGroup() !== null; onClicked: root.openBuild("create") }
                                    GlassButton { id: closeChatButton; text: "Close"; compact: true; visible: root.selectedFriend() !== null || root.selectedGroup() !== null; enabled: visible; onClicked: root.closeConversation() }
                                    GlassButton { id: reportChatButton; text: "Report"; compact: true; visible: root.selectedFriend() !== null; enabled: visible; onClicked: root.reportPeer(root.selectedFriend()) }
                                }

                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

                                Flickable {
                                    id: messageScroller
                                    width: parent.width
                                    height: parent.height - Style.space(root.mediaComposerOpen ? 176 : 142)
                                    contentWidth: width
                                    contentHeight: messageColumn.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                                    Column {
                                        id: messageColumn
                                        width: parent.width
                                        spacing: Style.space(8)
                                        Item { width: 1; height: Style.space(6) }

                                        Repeater {
                                            model: root.conversationMessages()
                                            Item {
                                                width: messageColumn.width
                                                height: bubble.implicitHeight + Style.space(4)
                                                Rectangle {
                                                    id: bubble
                                                    width: Math.min(parent.width * 0.76, Math.max(Style.space(120), messageBody.implicitWidth + Style.space(22)))
                                                    implicitHeight: messageBody.implicitHeight + Style.space(18)
                                                    anchors.right: modelData.incoming ? undefined : parent.right
                                                    anchors.left: modelData.incoming ? parent.left : undefined
                                                    radius: Style.space(15)
                                                    color: modelData.incoming ? "#121a2c" : "#6258df"
                                                    border.width: 1
                                                    border.color: modelData.incoming ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0.78, 0.75, 1.0, 0.30)
                                                    Column {
                                                        id: messageBody
                                                        width: Math.min(messageScroller.width * 0.70, Math.max(messageText.implicitWidth, mediaText.implicitWidth))
                                                        anchors.centerIn: parent
                                                        spacing: Style.space(5)
                                                        Text { id: messageText; width: parent.width; text: modelData.text || ""; visible: text !== ""; color: "#f4f5ff"; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                                        Text {
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
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Column {
                                            visible: root.conversationMessages().length === 0
                                            width: parent.width
                                            topPadding: Style.space(50)
                                            spacing: Style.space(6)
                                            Text { width: parent.width; text: root.selectedFriend() || root.selectedGroup() ? "Say hi 👋" : "No conversation selected"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            Text { width: parent.width; text: root.selectedFriend() || root.selectedGroup() ? "Messages in this chat stay separate from every other conversation." : "Choose a chat on the left, or start a new one."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                        }
                                    }
                                }

                                GlassSurface {
                                    width: parent.width
                                    height: root.mediaComposerOpen ? Style.space(106) : Style.space(70)
                                    radius: Style.space(16)
                                    fillOpacity: 0.78
                                    borderOpacity: 0.10
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: Style.space(8)
                                        spacing: Style.space(6)
                                        Row {
                                            width: parent.width
                                            spacing: Style.space(7)
                                            GlassButton { text: "Link"; icon: "＋"; compact: true; selected: root.mediaComposerOpen; enabled: root.selectedFriend() !== null || root.selectedGroup() !== null; onClicked: root.mediaComposerOpen = !root.mediaComposerOpen }
                                            GlassField { id: messageInput; width: parent.width - sendButton.width - Style.space(70); placeholder: root.selectedFriend() || root.selectedGroup() ? "Message…" : "Choose a chat first"; enabled: root.selectedFriend() !== null || root.selectedGroup() !== null; text: root.messageDraft; onTextChanged: root.messageDraft = text; onAccepted: root.sendMessage() }
                                            GlassButton { id: sendButton; text: "Send"; icon: "➤"; primary: true; enabled: root.selectedFriend() !== null || root.selectedGroup() !== null; onClicked: root.sendMessage() }
                                        }
                                        GlassField { visible: root.mediaComposerOpen; width: parent.width; placeholder: "Optional https:// link"; text: root.mediaDraft; onTextChanged: root.mediaDraft = text }
                                    }
                                }
                            }
                        }
                    }

                    // REQUESTS
                    Column {
                        visible: root.page === "requests"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(10)

                        Row {
                            width: parent.width
                            height: Style.space(48)
                            Column {
                                width: parent.width - Style.space(190)
                                Text { text: "Requests"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                                Text { text: "Connections stay separate from your actual conversations."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(6)
                                GlassButton { text: "Received " + root.incomingFriendRequests().length; compact: true; selected: root.requestTab === "received"; primary: root.requestTab === "received"; onClicked: root.requestTab = "received" }
                                GlassButton { text: "Sent " + root.sentFriendRequests().length; compact: true; selected: root.requestTab === "sent"; primary: root.requestTab === "sent"; onClicked: root.requestTab = "sent" }
                            }
                        }

                        GlassSurface {
                            width: parent.width
                            height: parent.height - Style.space(58)
                            radius: Style.space(18)
                            fillOpacity: 0.63

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                contentWidth: width
                                contentHeight: requestList.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                Column {
                                    id: requestList
                                    width: parent.width
                                    spacing: Style.space(8)

                                    Repeater {
                                        model: root.requestTab === "received" ? root.incomingFriendRequests() : []
                                        GlassSurface {
                                            width: parent.width
                                            height: Style.space(74)
                                            radius: Style.space(14)
                                            fillOpacity: 0.52
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(10)
                                                spacing: Style.space(10)
                                                GlassAvatar { size: Style.space(42); emoji: modelData.avatar || "👋"; online: true }
                                                Column {
                                                    width: parent.width - acceptRequestButton.width - declineRequestButton.width - Style.space(70)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: "Wants to connect and start a private chat"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                GlassButton {
                                                    id: declineRequestButton
                                                    text: "Decline"
                                                    compact: true
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: root.declineFriendRequest(modelData.id)
                                                }
                                                GlassButton {
                                                    id: acceptRequestButton
                                                    text: "Accept"
                                                    icon: "✓"
                                                    compact: true
                                                    primary: true
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: {
                                                        if (root.service) root.service.acceptFriendRequest(modelData.id)
                                                        root.prepareDraftForConversation("friend:" + (modelData.public_key || ""))
                                                        root.selectedFriendKey = modelData.public_key || ""
                                                        root.selectedGroupId = ""
                                                        root.page = "chats"
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: root.requestTab === "sent" ? root.sentFriendRequests() : []
                                        GlassSurface {
                                            width: parent.width
                                            height: Style.space(72)
                                            radius: Style.space(14)
                                            fillOpacity: 0.48
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(10)
                                                spacing: Style.space(10)
                                                GlassAvatar { size: Style.space(40); emoji: modelData.avatar || "👾"; online: modelData.online === true }
                                                Column {
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
                                            }
                                        }
                                    }

                                    Column {
                                        visible: (root.requestTab === "received" && root.incomingFriendRequests().length === 0) || (root.requestTab === "sent" && root.sentFriendRequests().length === 0)
                                        width: parent.width
                                        topPadding: Style.space(80)
                                        spacing: Style.space(7)
                                        Text { width: parent.width; text: root.requestTab === "received" ? "No new requests" : "No pending sent requests"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                        Text { width: parent.width; text: root.requestTab === "received" ? "New connection requests will appear here instead of cluttering Chats." : "People you connect with from World will appear here until they accept."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                    }
                                }
                            }
                        }
                    }

                    // WORLD
                    Column {
                        visible: root.page === "world"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(10)

                        Row {
                            width: parent.width
                            height: Style.space(48)
                            Column {
                                width: parent.width - worldRefresh.width
                                Text { text: "World"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                                Text { text: "Find people worth talking to — not a wall of tiny action buttons."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            GlassButton { id: worldRefresh; text: "Refresh"; icon: "↻"; compact: true; onClicked: if (root.service) root.service.refreshGlobal() }
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(8)
                            GlassField { width: parent.width - Style.space(312); placeholder: "Search people, projects, interests…"; text: root.worldQuery; onTextChanged: root.worldQuery = text }
                            GlassButton { text: "All"; compact: true; selected: root.worldFilter === "all"; onClicked: root.worldFilter = "all" }
                            GlassButton { text: "New"; compact: true; selected: root.worldFilter === "new"; onClicked: root.worldFilter = "new" }
                            GlassButton { text: "Building"; compact: true; selected: root.worldFilter === "building"; onClicked: root.worldFilter = "building" }
                            GlassButton { text: "Friends"; compact: true; selected: root.worldFilter === "friends"; onClicked: root.worldFilter = "friends" }
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(8)
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(58)
                                radius: Style.space(14)
                                fillOpacity: 0.55
                                Column { anchors.centerIn: parent; Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.world.length); color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true } Text { anchors.horizontalCenter: parent.horizontalCenter; text: "online now"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                            }
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(58)
                                radius: Style.space(14)
                                fillOpacity: 0.55
                                Column { anchors.centerIn: parent; Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.friendsList().length); color: root.violet; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true } Text { anchors.horizontalCenter: parent.horizontalCenter; text: "friends"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                            }
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(58)
                                radius: Style.space(14)
                                fillOpacity: 0.55
                                Column { anchors.centerIn: parent; Text { anchors.horizontalCenter: parent.horizontalCenter; text: (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0); color: root.cyan; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true } Text { anchors.horizontalCenter: parent.horizontalCenter; text: "relays"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                            }
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - Style.space(136)
                            contentWidth: width
                            contentHeight: worldFlow.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            Flow {
                                id: worldFlow
                                width: parent.width
                                spacing: Style.space(8)

                                Repeater {
                                    model: root.filteredWorld()
                                    GlassSurface {
                                        property bool safetyOpen: false
                                        width: (worldFlow.width - Style.space(8)) / 2
                                        height: Math.max(Style.space(144), worldCardColumn.implicitHeight + Style.space(24))
                                        radius: Style.space(17)
                                        fillOpacity: 0.58
                                        elevated: root.peerActionLabel(modelData) === "Message"

                                        Column {
                                            id: worldCardColumn
                                            anchors.fill: parent
                                            anchors.margins: Style.space(12)
                                            spacing: Style.space(8)

                                            Row {
                                                width: parent.width
                                                spacing: Style.space(9)
                                                GlassAvatar { size: Style.space(42); emoji: modelData.avatar || "👾"; online: true }
                                                Column {
                                                    width: parent.width - personAction.width - safetyToggle.width - Style.space(66)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: modelData.project_name ? ("Building · " + modelData.project_name) : ((modelData.status_emoji || "●") + " " + (modelData.status_name || modelData.activity || "Online")); color: modelData.project_name ? root.cyan : root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                GlassButton { id: personAction; text: root.peerActionLabel(modelData); compact: true; primary: root.peerActionLabel(modelData) === "Accept" || root.peerActionLabel(modelData) === "Message"; enabled: root.peerActionLabel(modelData) !== "Requested" && root.peerActionLabel(modelData) !== "Needs update"; onClicked: root.activatePeer(modelData) }
                                                GlassButton { id: safetyToggle; text: "⋯"; compact: true; selected: parent.parent.parent.safetyOpen; onClicked: parent.parent.parent.safetyOpen = !parent.parent.parent.safetyOpen }
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.project_desc ? modelData.project_desc : (modelData.activity ? ("Right now · " + modelData.activity) : "Online in Omarchy")
                                                color: root.mutedInk
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }

                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                Repeater {
                                                    model: modelData.common_ground && modelData.common_ground.slice ? modelData.common_ground.slice(0, 3) : []
                                                    GlassPill { text: String(modelData); accentColor: root.cyan }
                                                }
                                                GlassPill { visible: modelData.common_ground && modelData.common_ground.length > 0; text: "Common ground"; active: true; accentColor: root.violet }
                                            }

                                            Row {
                                                visible: parent.parent.safetyOpen
                                                width: parent.width
                                                spacing: Style.space(6)
                                                GlassButton { text: "Block"; compact: true; onClicked: root.blockPeer(modelData) }
                                                GlassButton { text: "Report"; compact: true; onClicked: root.reportPeer(modelData) }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    visible: root.filteredWorld().length === 0
                                    width: worldFlow.width
                                    topPadding: Style.space(60)
                                    spacing: Style.space(7)
                                    Text { width: parent.width; text: "Nobody matches this view yet"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                    Text { width: parent.width; text: "Try All, clear the search, or refresh. Friends never invents fake online users."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                }
                            }
                        }
                    }

                    // CIRCLES
                    Column {
                        visible: root.page === "circles"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(9)

                        GlassSurface {
                            width: parent.width
                            height: Style.space(74)
                            radius: Style.space(18)
                            fillOpacity: 0.62
                            Row {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(10)
                                GlassAvatar { size: Style.space(44); emoji: "◌"; online: true; selected: true }
                                Column {
                                    width: parent.width - Style.space(176)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Omarchy Circle"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                    Text { width: parent.width; text: "Public community chat"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                }
                            GlassPill { anchors.verticalCenter: parent.verticalCenter; text: String(root.world.length) + " online"; active: true; accentColor: root.success }
                            }
                        }

                        GlassSurface {
                            width: parent.width
                            height: Style.space(34)
                            radius: Style.space(11)
                            fillOpacity: 0.42
                            Row {
                                anchors.fill: parent
                                anchors.margins: Style.space(7)
                                spacing: Style.space(7)
                                Text { text: "ⓘ"; color: root.cyan; font.pixelSize: Style.font.caption }
                                Text { width: parent.width - Style.space(22); text: "Public room · never share private links or personal information."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                        }

                        GlassSurface {
                            width: parent.width
                            height: parent.height - Style.space(166)
                            radius: Style.space(17)
                            fillOpacity: 0.52

                            Flickable {
                                id: circleScroller
                                anchors.fill: parent
                                anchors.margins: Style.space(10)
                                contentWidth: width
                                contentHeight: circleMessages.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                                Column {
                                    id: circleMessages
                                    width: parent.width
                                    spacing: Style.space(10)

                                    Repeater {
                                        model: root.community.slice ? root.community.slice(Math.max(0, root.community.length - 80)) : []
                                        Row {
                                            width: parent.width
                                            spacing: Style.space(9)
                                            GlassAvatar { size: Style.space(34); emoji: modelData.avatar || "👾"; online: false }
                                            Column {
                                                width: parent.width - Style.space(45)
                                                spacing: Style.space(4)
                                                Text { width: parent.width; text: (modelData.handle || modelData.from_name || "Builder") + (modelData.mine ? " · you" : ""); color: modelData.mine ? "#dcd7ff" : root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                Rectangle {
                                                    width: Math.min(parent.width, Math.max(Style.space(150), circleText.implicitWidth + Style.space(20)))
                                                    height: circleText.implicitHeight + Style.space(16)
                                                    radius: Style.space(13)
                                                    color: modelData.mine ? "#322d68" : "#11192a"
                                                    border.width: 1
                                                    border.color: Qt.rgba(1, 1, 1, 0.065)
                                                    Text { id: circleText; width: parent.width - Style.space(18); anchors.centerIn: parent; text: modelData.text || modelData.message || ""; color: "#dfe3ef"; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        visible: root.community.length === 0
                                        width: parent.width
                                        topPadding: Style.space(60)
                                        spacing: Style.space(7)
                                        Text { width: parent.width; text: "The Circle is quiet"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                        Text { width: parent.width; text: "Start with a useful question, a small discovery, or what you're building today."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(8)
                            GlassField { width: parent.width - circleSend.width - Style.space(8); placeholder: "Message the Circle…"; text: root.communityDraft; onTextChanged: root.communityDraft = text; onAccepted: root.sendCommunity() }
                            GlassButton { id: circleSend; text: "Send"; icon: "➤"; primary: true; onClicked: root.sendCommunity() }
                        }
                    }

                    // PROFILE / SETTINGS
                    Flickable {
                        visible: root.page === "profile"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        contentWidth: width
                        contentHeight: profileColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: profileColumn
                            width: parent.width
                            spacing: Style.space(10)

                            GlassSurface {
                                width: parent.width
                                height: Style.space(104)
                                radius: Style.space(20)
                                fillOpacity: 0.70
                                elevated: true
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Style.space(15)
                                    spacing: Style.space(12)
                                    GlassAvatar { size: Style.space(64); emoji: root.profile.avatar || "👾"; online: root.profile.privacy ? root.profile.privacy.share_global !== false : true; selected: true; anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        width: parent.width - Style.space(245)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(3)
                                        Text { width: parent.width; text: root.profile.handle || "Omarchy Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
                                        Text { width: parent.width; text: (root.profile.status_emoji || "🚀") + " " + (root.profile.status_name || "Ready") + (root.profile.project_name ? " · building " + root.profile.project_name : ""); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                        Text { width: parent.width; text: "Your public beacon is pseudonymous. You control what it shares below."; color: root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    Column {
                                        width: Style.space(150)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(6)
                                        GlassButton { width: parent.width; text: "Copy invite"; icon: "↗"; compact: true; primary: true; onClicked: root.copyInvite() }
                                        GlassButton { width: parent.width; text: "Open Build"; icon: "⌁"; compact: true; onClicked: root.openBuild("discover") }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Style.space(10)

                                GlassSurface {
                                    width: (parent.width - Style.space(10)) * 0.56
                                    height: profileBasics.implicitHeight + Style.space(24)
                                    radius: Style.space(18)
                                    fillOpacity: 0.62
                                    Column {
                                        id: profileBasics
                                        anchors.fill: parent
                                        anchors.margins: Style.space(12)
                                        spacing: Style.space(8)
                                        Text { text: "About you"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                        Text { text: "This is what other Omarchy users see when you choose to share it."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                        GlassField { width: parent.width; placeholder: "Display name"; text: root.handleDraft; onTextChanged: root.handleDraft = text }
                                        GlassField { width: parent.width; placeholder: "Project name (optional)"; text: root.projectNameDraft; onTextChanged: root.projectNameDraft = text }
                                        GlassField { width: parent.width; placeholder: "Project link https://…"; text: root.projectUrlDraft; onTextChanged: root.projectUrlDraft = text }
                                        Rectangle {
                                            width: parent.width
                                            height: Style.space(70)
                                            radius: Style.space(12)
                                            color: Qt.rgba(0.06, 0.08, 0.15, 0.72)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.09)
                                            TextArea {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(5)
                                                text: root.projectDescDraft
                                                onTextChanged: root.projectDescDraft = text
                                                placeholderText: "One sentence about what you're building"
                                                placeholderTextColor: root.faintInk
                                                color: root.ink
                                                background: null
                                                wrapMode: TextArea.Wrap
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                            }
                                        }
                                        GlassButton { width: parent.width; text: "Save profile"; icon: "✓"; primary: true; onClicked: root.saveProfile() }
                                    }
                                }

                                Column {
                                    width: (parent.width - Style.space(10)) * 0.44
                                    spacing: Style.space(10)

                                    GlassSurface {
                                        width: parent.width
                                        height: identityPrefs.implicitHeight + Style.space(24)
                                        radius: Style.space(18)
                                        fillOpacity: 0.60
                                        Column {
                                            id: identityPrefs
                                            anchors.fill: parent
                                            anchors.margins: Style.space(12)
                                            spacing: Style.space(8)
                                            Text { text: "Presence"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            Text { text: "Avatar"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                Repeater {
                                                    model: root.service && root.service.availableAvatars ? root.service.availableAvatars : []
                                                    GlassPill { text: String(modelData); active: root.profile.avatar === modelData; onClicked: if (root.service) root.service.setAvatar(String(modelData)) }
                                                }
                                            }
                                            Text { text: "Status"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                Repeater {
                                                    model: root.service && root.service.availableStatuses ? root.service.availableStatuses : []
                                                    GlassPill { text: (modelData.emoji || "•") + " " + (modelData.name || modelData.id || "Status"); active: root.profile.status === modelData.id; onClicked: if (root.service) root.service.setStatus(modelData.id) }
                                                }
                                            }
                                            Text { text: "Interests · up to 4"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                Repeater {
                                                    model: root.service && root.service.availableInterests ? root.service.availableInterests : []
                                                    GlassPill {
                                                        text: (modelData.emoji ? modelData.emoji + " " : "") + (modelData.name || modelData.id || "Interest")
                                                        active: root.interestsDraft.indexOf(modelData.id) >= 0
                                                        onClicked: root.toggleInterest(modelData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    GlassSurface {
                                        width: parent.width
                                        height: privacyPrefs.implicitHeight + Style.space(24)
                                        radius: Style.space(18)
                                        fillOpacity: 0.60
                                        Column {
                                            id: privacyPrefs
                                            anchors.fill: parent
                                            anchors.margins: Style.space(12)
                                            spacing: Style.space(8)
                                            Text { text: "Privacy"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            Text { width: parent.width; text: "Tap a chip to control what your public beacon shares."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                GlassPill { text: "Visible in World"; active: root.profile.privacy && root.profile.privacy.share_global !== false; accentColor: root.success; onClicked: if (root.service) root.service.togglePrivacy("share_global") }
                                                GlassPill { text: "Active app"; active: root.profile.privacy && root.profile.privacy.share_window === true; onClicked: if (root.service) root.service.togglePrivacy("share_window") }
                                                GlassPill { text: "Music"; active: root.profile.privacy && root.profile.privacy.share_music === true; onClicked: if (root.service) root.service.togglePrivacy("share_music") }
                                                GlassPill { text: "Project"; active: root.profile.privacy && root.profile.privacy.share_project === true; onClicked: if (root.service) root.service.togglePrivacy("share_project") }
                                                GlassPill { text: "Interests"; active: root.profile.privacy && root.profile.privacy.share_interests === true; onClicked: if (root.service) root.service.togglePrivacy("share_interests") }
                                                GlassPill { text: "Room"; active: root.profile.privacy && root.profile.privacy.share_room === true; onClicked: if (root.service) root.service.togglePrivacy("share_room") }
                                            }
                                        }
                                    }

                                    GlassSurface {
                                        width: parent.width
                                        height: blockedPeopleColumn.implicitHeight + Style.space(24)
                                        radius: Style.space(18)
                                        fillOpacity: 0.60
                                        Column {
                                            id: blockedPeopleColumn
                                            anchors.fill: parent
                                            anchors.margins: Style.space(12)
                                            spacing: Style.space(8)
                                            Text { text: "Blocked people"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            Text { width: parent.width; text: "Unblock a person to allow future World presence and messages again."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                            Column {
                                                width: parent.width
                                                spacing: Style.space(6)
                                                Repeater {
                                                    model: root.service && root.service.globalBlockedPubkeys ? root.service.globalBlockedPubkeys : []
                                                    Row {
                                                        width: parent.width
                                                        spacing: Style.space(8)
                                                        Text { width: parent.width - unblockButton.width - Style.space(8); text: String(modelData).slice(0, 12) + "…"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                                        GlassButton { id: unblockButton; text: "Unblock"; compact: true; onClicked: if (root.service) root.service.unblockGlobal(String(modelData)) }
                                                    }
                                                }
                                                Text { visible: (!root.service || !root.service.globalBlockedPubkeys || root.service.globalBlockedPubkeys.length === 0); text: "No blocked people"; color: root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                            }
                                        }
                                    }
                                }
                            }

                            GlassSurface {
                                width: parent.width
                                height: Style.space(54)
                                radius: Style.space(15)
                                fillOpacity: 0.54
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Style.space(10)
                                    spacing: Style.space(9)
                                    Column {
                                        width: parent.width - profileUpdateButton.width - Style.space(10)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: root.updateInfo.available ? "Update available" : "Friends is current"; color: root.updateInfo.available ? root.warning : root.success; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                        Text { width: parent.width; text: "Installed v" + root.formatVersion() + (root.updateInfo.latest ? " · latest " + root.updateInfo.latest : ""); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: profileUpdateButton; text: root.updateInfo.available ? "Update" : "Check"; icon: "↻"; compact: true; primary: root.updateInfo.available; anchors.verticalCenter: parent.verticalCenter; onClicked: if (root.service) root.service.updatePlugin() }
                                }
                            }

                            Item { width: 1; height: Style.space(10) }
                        }
                    }

                    // New-chat picker. Full friend list lives here instead of cluttering Chats.
                    GlassSurface {
                        visible: root.newChatOpen && root.page === "chats"
                        width: Math.min(contentArea.width - Style.space(30), Style.space(430))
                        height: Math.min(contentArea.height - Style.space(30), Math.max(Style.space(220), newChatList.implicitHeight + Style.space(105)))
                        anchors.centerIn: parent
                        radius: Style.space(20)
                        fillOpacity: 0.98
                        borderOpacity: 0.22
                        elevated: true
                        selected: true
                        z: 50

                        Column {
                            anchors.fill: parent
                            anchors.margins: Style.space(14)
                            spacing: Style.space(9)
                            Row {
                                width: parent.width
                                Column {
                                    width: parent.width - closeNewChat.width
                                    Text { text: "New chat"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                    Text { width: parent.width; text: "Choose a friend or create a private group."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                }
                                GlassButton { id: closeNewChat; text: "Close"; compact: true; onClicked: root.newChatOpen = false }
                            }
                            GlassButton { width: parent.width; text: "Create private group"; icon: "🫂"; onClicked: { root.newChatOpen = false; root.groupCreateOpen = true } }
                            Flickable {
                                width: parent.width
                                height: parent.height - Style.space(105)
                                contentWidth: width
                                contentHeight: newChatList.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                Column {
                                    id: newChatList
                                    width: parent.width
                                    spacing: Style.space(6)
                                    Repeater {
                                        model: root.friendsList()
                                        GlassSurface {
                                            width: parent.width
                                            height: Style.space(56)
                                            radius: Style.space(13)
                                            fillOpacity: 0.50
                                            TapHandler { onTapped: root.chooseFriend(modelData) }
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(8)
                                                spacing: Style.space(8)
                                                GlassAvatar { size: Style.space(36); emoji: modelData.avatar || "👾"; online: modelData.online === true }
                                                Column {
                                                    width: parent.width - Style.space(90)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { width: parent.width; text: modelData.handle || "Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: modelData.online ? "Online now" : "Friend"; color: modelData.online ? root.success : root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                Text { anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.cyan; font.pixelSize: Style.font.heading }
                                            }
                                        }
                                    }
                                    Text { visible: root.friendsList().length === 0; width: parent.width; text: "No friends yet. Open World to connect with someone first."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption; topPadding: Style.space(30) }
                                }
                            }
                        }
                    }

                    GlassSurface {
                        visible: root.groupCreateOpen && root.page === "chats"
                        width: Math.min(contentArea.width - Style.space(30), Style.space(430))
                        height: Math.min(contentArea.height - Style.space(30), Style.space(470))
                        anchors.centerIn: parent
                        radius: Style.space(20)
                        fillOpacity: 0.98
                        borderOpacity: 0.22
                        elevated: true
                        selected: true
                        z: 51

                        Column {
                            anchors.fill: parent
                            anchors.margins: Style.space(14)
                            spacing: Style.space(9)
                            Row {
                                width: parent.width
                                Column {
                                    width: parent.width - closeGroup.width
                                    Text { text: "New private group"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                    Text { text: "Choose at least two friends"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                }
                                GlassButton { id: closeGroup; text: "Close"; compact: true; onClicked: root.groupCreateOpen = false }
                            }
                            GlassField { width: parent.width; placeholder: "Group name"; text: root.groupNameDraft; onTextChanged: root.groupNameDraft = text }
                            Flickable {
                                width: parent.width
                                height: parent.height - Style.space(140)
                                contentWidth: width
                                contentHeight: memberList.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                Column {
                                    id: memberList
                                    width: parent.width
                                    spacing: Style.space(5)
                                    Repeater {
                                        model: root.friendsList()
                                        GlassSurface {
                                            width: parent.width
                                            height: Style.space(48)
                                            radius: Style.space(12)
                                            selected: root.groupMemberKeys.indexOf(modelData.public_key) >= 0
                                            TapHandler { onTapped: root.toggleGroupMember(modelData.public_key) }
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(7)
                                                spacing: Style.space(8)
                                                GlassAvatar { size: Style.space(30); emoji: modelData.avatar || "👾"; online: modelData.online === true }
                                                Text { width: parent.width - Style.space(66); anchors.verticalCenter: parent.verticalCenter; text: modelData.handle || "Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                Text { anchors.verticalCenter: parent.verticalCenter; text: root.groupMemberKeys.indexOf(modelData.public_key) >= 0 ? "✓" : "+"; color: root.groupMemberKeys.indexOf(modelData.public_key) >= 0 ? root.success : root.mutedInk; font.pixelSize: Style.font.bodySmall }
                                            }
                                        }
                                    }
                                }
                            }
                            GlassButton { width: parent.width; text: "Create encrypted group"; icon: "✦"; primary: true; onClicked: root.createGroup() }
                        }
                    }
                }
            }

            Row {
                width: parent.width - Style.space(36)
                x: Style.space(18)
                height: Style.space(30)
                spacing: Style.space(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "●"; color: root.worldStatus.last_error ? root.warning : root.success; font.pixelSize: Style.font.caption }
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.worldStatus.last_error ? "Reconnecting" : "Friends connected"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                Item { width: Math.max(0, parent.width - Style.space(390) - footerTagline.width); height: 1 }
                Text {
                    id: footerTagline
                    width: Math.min(Style.space(290), Math.max(Style.space(150), parent.width - Style.space(390)))
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Private chats · build together"
                    color: root.faintInk
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.4
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }

        GlassSurface {
            visible: root.notice !== ""
            width: Math.min(parent.width - Style.space(40), Style.space(380))
            height: noticeText.implicitHeight + Style.space(22)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(42)
            radius: Style.space(14)
            fillOpacity: 0.96
            elevated: true
            selected: true
            z: 100
            Text {
                id: noticeText
                anchors.fill: parent
                anchors.margins: Style.space(10)
                text: root.notice
                color: root.ink
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
    }
}
