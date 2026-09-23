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

    property string page: "chats"
    property string worldQuery: ""
    property string selectedFriendKey: ""
    property string selectedGroupId: ""
    property string draftConversationKey: ""
    property bool sendingMessage: false
    property bool sendingCommunity: false
    property bool creatingGroup: false
    property string messageDraft: ""
    property string mediaDraft: ""
    property string communityDraft: ""
    property string notice: ""
    property bool groupCreateOpen: false
    property string groupNameDraft: ""
    property var groupMemberKeys: []
    property string handleDraft: ""
    property string projectNameDraft: ""
    property string projectDescDraft: ""
    property string projectUrlDraft: ""
    property var interestsDraft: []
    property bool serviceSignalsConnected: false

    contentWidth: root.fittedContentWidth(Style.space(760))
    contentHeight: root.fittedContentHeight(Style.space(680))

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

    function groupsList() {
        return root.groups || []
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
        return out.slice(Math.max(0, out.length - 60))
    }

    function lastMessagePreview(publicKey) {
        for (var i = root.messages.length - 1; i >= 0; i--) {
            var m = root.messages[i]
            if (m && !m.group_id && m.public_key === publicKey) {
                var t = m.text || "Shared something"
                return (m.incoming ? "" : "You · ") + t
            }
        }
        return "Say hello"
    }

    function chooseFriend(friend) {
        root.prepareDraftForConversation("friend:" + (friend && friend.public_key ? friend.public_key : ""))
        root.selectedFriendKey = friend && friend.public_key ? friend.public_key : ""
        root.selectedGroupId = ""
    }

    function chooseGroup(group) {
        root.prepareDraftForConversation("group:" + (group && group.id ? group.id : ""))
        root.selectedGroupId = group && group.id ? group.id : ""
        root.selectedFriendKey = ""
    }

    function prepareDraftForConversation(key) {
        if (root.draftConversationKey && root.draftConversationKey !== key) {
            root.messageDraft = ""
            root.mediaDraft = ""
        }
        root.draftConversationKey = key
    }

    function ensureConversation() {
        if (root.selectedFriend() || root.selectedGroup()) return
        var fs = root.friendsList()
        if (fs.length > 0) root.chooseFriend(fs[0])
        else if (root.groupsList().length > 0) root.chooseGroup(root.groupsList()[0])
    }

    function sendMessage() {
        if (root.sendingMessage) return
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        var text = root.messageDraft.trim()
        var media = root.mediaDraft.trim()
        if (!root.service || (!friend && !group)) { root.showNotice("Choose a conversation first"); return }
        if (!text && !media) return
        var conversationKey = root.draftConversationKey
        root.sendingMessage = true
        function finishSend(ok) {
            root.sendingMessage = false
            if (!ok || root.draftConversationKey !== conversationKey) return
            if (root.messageDraft.trim() !== text || root.mediaDraft.trim() !== media) return
            root.messageDraft = ""
            root.mediaDraft = ""
        }
        if (group) root.service.sendGroupMessage(group.id, text, media, finishSend)
        else root.service.sendDm(friend.public_key, text, media, finishSend)
    }

    function sendCommunity() {
        if (root.sendingCommunity) return
        var text = root.communityDraft.trim()
        if (!text || !root.service) return
        root.sendingCommunity = true
        root.service.sendCommunity(text, function(ok) {
            root.sendingCommunity = false
            if (ok && root.communityDraft.trim() === text) root.communityDraft = ""
        })
    }

    function visibleWorld() {
        var q = root.worldQuery.trim().toLowerCase()
        if (!q) return root.world
        var out = []
        for (var i = 0; i < root.world.length; i++) {
            var p = root.world[i]
            var common = p.common_ground || []
            var hay = [p.handle || "", p.activity || "", p.project_name || "", p.status_name || "", common.join ? common.join(" ") : ""].join(" ").toLowerCase()
            if (hay.indexOf(q) >= 0) out.push(p)
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
        if (f && f.status === "friends") return "Chat"
        if (root.requestFor(peer && peer.public_key)) return "Accept"
        if (f && f.status === "pending") return "Requested"
        if (peer && peer.can_chat === false) return "Needs update"
        return "Add"
    }

    function activatePeer(peer) {
        if (!peer || !peer.public_key || !root.service) return
        var f = root.friendshipFor(peer.public_key)
        if (f && f.status === "friends") {
            root.chooseFriend(Object.assign({}, f, { public_key: peer.public_key, handle: peer.handle || f.handle, avatar: peer.avatar || f.avatar }))
            root.page = "chats"
            return
        }
        var req = root.requestFor(peer.public_key)
        if (req) {
            root.service.acceptFriendRequest(req.id)
            root.prepareDraftForConversation("friend:" + peer.public_key)
            root.selectedFriendKey = peer.public_key
            root.page = "chats"
            return
        }
        if (!f || f.status !== "pending") root.service.requestFriend(peer.public_key)
    }

    function toggleGroupMember(publicKey) {
        var next = (root.groupMemberKeys || []).slice()
        var idx = next.indexOf(publicKey)
        if (idx >= 0) next.splice(idx, 1)
        else if (next.length < 11) next.push(publicKey)
        root.groupMemberKeys = next
    }

    function createGroup() {
        if (root.creatingGroup) return
        var name = root.groupNameDraft.trim()
        if (!root.service || !name || root.groupMemberKeys.length < 2) {
            root.showNotice("Name the group and choose at least two friends")
            return
        }
        var members = root.groupMemberKeys.slice()
        root.creatingGroup = true
        root.service.createGroup(name, members, function(ok) {
            root.creatingGroup = false
            if (!ok || root.groupNameDraft.trim() !== name || JSON.stringify(root.groupMemberKeys) !== JSON.stringify(members)) return
            root.groupNameDraft = ""
            root.groupMemberKeys = []
            root.groupCreateOpen = false
        })
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

    // Full product-owned visual shell. We intentionally do not inherit the active Omarchy
    // theme background here; Friends keeps a stable midnight/violet identity across themes.
    Rectangle {
        anchors.fill: parent
        radius: Style.space(24)
        color: root.canvas
        border.width: 1
        border.color: Qt.rgba(0.55, 0.60, 1.0, 0.24)
        clip: true

        Rectangle {
            width: Style.space(340)
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -Style.space(150)
            anchors.topMargin: -Style.space(190)
            color: Qt.rgba(0.43, 0.35, 1.0, 0.10)
        }
        Rectangle {
            width: Style.space(260)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: -Style.space(130)
            anchors.bottomMargin: -Style.space(150)
            color: Qt.rgba(0.20, 0.55, 1.0, 0.07)
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Top chrome
            Item {
                width: parent.width
                height: Style.space(68)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(18)
                    anchors.rightMargin: Style.space(16)
                    spacing: Style.space(11)

                    GlassAvatar {
                        size: Style.space(40)
                        emoji: root.profile.avatar || "🦊"
                        online: true
                        anchors.verticalCenter: parent.verticalCenter
                        selected: true
                    }

                    Column {
                        width: Style.space(220)
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
                            text: "Build together · share more · go further"
                            color: root.mutedInk
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }

                    Item { width: Math.max(0, parent.width - Style.space(220) - Style.space(40) - versionPill.width - menuPill.width - Style.space(70)); height: 1 }

                    GlassPill {
                        id: versionPill
                        text: "v" + root.formatVersion()
                        active: root.updateInfo.available
                        accentColor: root.updateInfo.available ? root.warning : root.violet
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: if (root.updateInfo.available && root.service) root.service.updatePlugin()
                    }

                    GlassButton {
                        id: menuPill
                        text: "Build"
                        icon: "✦"
                        compact: true
                        primary: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.openBuild("discover")
                    }
                }
            }

            // Persistent update banner. It cannot be dismissed while the installed client is stale.
            GlassSurface {
                visible: root.updateInfo.available
                width: parent.width - Style.space(24)
                height: visible ? Style.space(48) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Style.space(14)
                fillOpacity: 0.92
                borderOpacity: 0.20
                selected: true
                accentColor: root.warning

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(10)
                    Text {
                        width: parent.width - updateButton.width - Style.space(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "A newer Friends build is available · update to keep modern DMs and Build Network compatible."
                        color: "#f7e6a7"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                    GlassButton {
                        id: updateButton
                        text: "Update now"
                        icon: "↻"
                        compact: true
                        primary: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: if (root.service) root.service.updatePlugin()
                    }
                }
            }

            Item { width: 1; height: root.updateInfo.available ? Style.space(8) : 0 }

            // Main app body
            Row {
                width: parent.width
                height: parent.height - Style.space(68) - (root.updateInfo.available ? Style.space(56) : 0) - Style.space(34)
                spacing: Style.space(10)

                // Sidebar
                Item {
                    width: Style.space(148)
                    height: parent.height

                    GlassSurface {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        radius: Style.space(18)
                        fillOpacity: 0.64
                        borderOpacity: 0.09
                    }

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(18)
                        anchors.rightMargin: Style.space(8)
                        anchors.topMargin: Style.space(12)
                        anchors.bottomMargin: Style.space(10)
                        spacing: Style.space(3)

                        Text {
                            text: "WORKSPACE"
                            color: root.faintInk
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.letterSpacing: 1.1
                        }
                        Item { width: 1; height: Style.space(4) }

                        GlassNavItem {
                            width: parent.width
                            text: "Chats"
                            icon: "◉"
                            badge: String(root.incomingFriendRequests().length || "")
                            selected: root.page === "chats"
                            onClicked: { root.page = "chats"; root.ensureConversation() }
                        }
                        GlassNavItem { width: parent.width; text: "World"; icon: "◎"; selected: root.page === "world"; onClicked: root.page = "world" }
                        GlassNavItem { width: parent.width; text: "Circles"; icon: "◌"; selected: root.page === "circles"; onClicked: root.page = "circles" }
                        GlassNavItem { width: parent.width; text: "Build"; icon: "⌁"; badge: "NEW"; onClicked: root.openBuild("discover") }
                        GlassNavItem { width: parent.width; text: "Me"; icon: "◇"; selected: root.page === "profile"; onClicked: root.openProfile() }

                        Item { width: 1; height: Style.space(12) }
                        Text {
                            text: "QUICK ACTIONS"
                            color: root.faintInk
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.letterSpacing: 1.0
                        }
                        Item { width: 1; height: Style.space(3) }

                        GlassNavItem { width: parent.width; text: "Create build"; icon: "+"; onClicked: root.openBuild("create") }
                        GlassNavItem { width: parent.width; text: "Share setup"; icon: "⌘"; onClicked: root.openBuild("share") }
                        GlassNavItem { width: parent.width; text: "Ask for help"; icon: "?"; onClicked: root.openBuild("help") }
                        GlassNavItem { width: parent.width; text: "Find people"; icon: "⌖"; onClicked: root.page = "world" }

                        Item { width: 1; height: Math.max(0, parent.height - Style.space(425)) }

                        GlassSurface {
                            width: parent.width
                            height: Style.space(66)
                            radius: Style.space(13)
                            fillOpacity: 0.50
                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(9)
                                spacing: 2
                                Text {
                                    text: root.worldStatus.last_error ? "World reconnecting" : "Connected"
                                    color: root.worldStatus.last_error ? root.warning : root.success
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }
                                Text {
                                    text: (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0) + " relays · " + (root.worldStatus.last_sync_age || "never")
                                    color: root.mutedInk
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: "v" + root.formatVersion()
                                    color: root.faintInk
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }
                        }
                    }
                }

                // Content area
                Item {
                    id: contentArea
                    width: parent.width - Style.space(158)
                    height: parent.height

                    // CHATS
                    Row {
                        visible: root.page === "chats"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(10)

                        GlassSurface {
                            width: Style.space(220)
                            height: parent.height
                            radius: Style.space(18)
                            fillOpacity: 0.69
                            borderOpacity: 0.09

                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(9)

                                Row {
                                    width: parent.width
                                    Text {
                                        width: parent.width - newGroupButton.width
                                        text: "Messages"
                                        color: root.ink
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.heading
                                        font.bold: true
                                    }
                                    GlassButton {
                                        id: newGroupButton
                                        text: "+ Group"
                                        compact: true
                                        onClicked: root.groupCreateOpen = !root.groupCreateOpen
                                    }
                                }

                                GlassField {
                                    width: parent.width
                                    placeholder: "Search conversations"
                                    // visual-only local search for v4.15; conversation filtering can be added
                                    // later without touching transport/state.
                                }

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
                                            model: root.incomingFriendRequests()
                                            GlassSurface {
                                                width: parent.width
                                                height: Style.space(62)
                                                radius: Style.space(13)
                                                selected: true
                                                accentColor: root.cyan
                                                fillOpacity: 0.58
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(9)
                                                    spacing: Style.space(8)
                                                    GlassAvatar { size: Style.space(34); emoji: modelData.avatar || "👋"; online: true }
                                                    Column {
                                                        width: parent.width - acceptButton.width - Style.space(48)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { width: parent.width; text: modelData.handle || "New builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        Text { width: parent.width; text: "Wants to connect"; color: root.cyan; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                    GlassButton {
                                                        id: acceptButton
                                                        text: "Accept"
                                                        compact: true
                                                        primary: true
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        onClicked: {
                                                            if (root.service) root.service.acceptFriendRequest(modelData.id)
                                                            root.prepareDraftForConversation("friend:" + (modelData.public_key || ""))
                                                            root.selectedFriendKey = modelData.public_key || ""
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: root.groupsList()
                                            GlassSurface {
                                                width: parent.width
                                                height: Style.space(64)
                                                radius: Style.space(13)
                                                selected: root.selectedGroupId === modelData.id
                                                fillOpacity: selected ? 0.78 : 0.50
                                                TapHandler { onTapped: root.chooseGroup(modelData) }
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(9)
                                                    spacing: Style.space(9)
                                                    GlassAvatar { size: Style.space(36); emoji: "🫂"; online: true; selected: root.selectedGroupId === modelData.id }
                                                    Column {
                                                        width: parent.width - Style.space(48)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { width: parent.width; text: modelData.name || "Private group"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        Text { width: parent.width; text: ((modelData.members || []).length || 0) + " people · encrypted"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: root.friendsList()
                                            GlassSurface {
                                                width: parent.width
                                                height: Style.space(64)
                                                radius: Style.space(13)
                                                selected: root.selectedFriendKey === modelData.public_key
                                                fillOpacity: selected ? 0.78 : 0.50
                                                TapHandler { onTapped: root.chooseFriend(modelData) }
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(9)
                                                    spacing: Style.space(9)
                                                    GlassAvatar { size: Style.space(36); emoji: modelData.avatar || "👾"; online: modelData.online === true; selected: root.selectedFriendKey === modelData.public_key }
                                                    Column {
                                                        width: parent.width - Style.space(48)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text { width: parent.width; text: modelData.handle || "Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        Text { width: parent.width; text: root.lastMessagePreview(modelData.public_key); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            visible: root.friendsList().length === 0 && root.groupsList().length === 0 && root.incomingFriendRequests().length === 0
                                            width: parent.width
                                            text: "No conversations yet.\nOpen World and meet a builder."
                                            color: root.mutedInk
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            topPadding: Style.space(24)
                                        }
                                    }
                                }
                            }
                        }

                        GlassSurface {
                            width: parent.width - Style.space(230)
                            height: parent.height
                            radius: Style.space(18)
                            fillOpacity: 0.72
                            elevated: true

                            Item {
                                anchors.fill: parent
                                anchors.margins: Style.space(14)

                                Column {
                                    anchors.fill: parent
                                    spacing: Style.space(8)

                                    Row {
                                        width: parent.width
                                        height: Style.space(48)
                                        spacing: Style.space(9)
                                        readonly property var friend: root.selectedFriend()
                                        readonly property var group: root.selectedGroup()
                                        GlassAvatar {
                                            size: Style.space(40)
                                            emoji: parent.group ? "🫂" : (parent.friend ? (parent.friend.avatar || "👾") : "✦")
                                            online: parent.group ? true : (parent.friend && parent.friend.online === true)
                                            selected: true
                                        }
                                        Column {
                                            width: parent.width - focusButton.width - buildTogetherButton.width - Style.space(66)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { width: parent.width; text: parent.parent.group ? (parent.parent.group.name || "Private group") : (parent.parent.friend ? (parent.parent.friend.handle || "Builder") : "Choose a conversation"); color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                            Text { width: parent.width; text: parent.parent.group ? "Private group · modern encrypted transport" : (parent.parent.friend ? ((parent.parent.friend.activity || "Friend") + (parent.parent.friend.online ? " · online" : "")) : "Your chats stay here"); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                        }
                                        GlassButton {
                                            id: focusButton
                                            text: "Focus"
                                            icon: "◷"
                                            compact: true
                                            enabled: root.selectedFriend() !== null
                                            onClicked: if (root.service && root.selectedFriend()) root.service.inviteGlobalFocus(root.selectedFriend().public_key)
                                        }
                                        GlassButton {
                                            id: buildTogetherButton
                                            text: "Build"
                                            icon: "⌁"
                                            compact: true
                                            onClicked: root.openBuild("create")
                                        }
                                    }

                                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                                    Flickable {
                                        id: messageScroller
                                        width: parent.width
                                        height: parent.height - Style.space(154)
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

                                            Item { width: 1; height: Style.space(8) }

                                            Repeater {
                                                model: root.conversationMessages()
                                                Item {
                                                    width: messageColumn.width
                                                    height: bubble.implicitHeight + Style.space(6)

                                                    Rectangle {
                                                        id: bubble
                                                        width: Math.min(parent.width * 0.73, Math.max(Style.space(120), messageText.implicitWidth + Style.space(26)))
                                                        implicitHeight: messageText.implicitHeight + (mediaText.visible ? mediaText.implicitHeight + Style.space(8) : 0) + Style.space(20)
                                                        anchors.right: modelData.incoming ? undefined : parent.right
                                                        anchors.left: modelData.incoming ? parent.left : undefined
                                                        radius: Style.space(15)
                                                        gradient: Gradient {
                                                            GradientStop { position: 0; color: modelData.incoming ? "#131c30" : "#7566f5" }
                                                            GradientStop { position: 1; color: modelData.incoming ? "#0f1627" : "#5a54d8" }
                                                        }
                                                        border.width: 1
                                                        border.color: modelData.incoming ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.76, 0.73, 1.0, 0.34)

                                                        Column {
                                                            anchors.fill: parent
                                                            anchors.margins: Style.space(10)
                                                            spacing: Style.space(5)
                                                            Text {
                                                                id: messageText
                                                                width: parent.width
                                                                text: modelData.text || ""
                                                                visible: text !== ""
                                                                color: "#f4f5ff"
                                                                font.family: Style.font.family
                                                                font.pixelSize: Style.font.caption
                                                                wrapMode: Text.WordWrap
                                                            }
                                                            Text {
                                                                id: mediaText
                                                                width: parent.width
                                                                visible: modelData.media && modelData.media.length > 0
                                                                text: visible ? "↗ " + ((modelData.media[0].url || modelData.media[0].href || "Shared link")) : ""
                                                                color: modelData.incoming ? root.cyan : "#e3e1ff"
                                                                font.family: Style.font.family
                                                                font.pixelSize: Style.font.caption
                                                                elide: Text.ElideMiddle
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: root.conversationMessages().length === 0
                                                width: parent.width
                                                text: root.selectedFriend() || root.selectedGroup() ? "Start the conversation ✦" : "Pick a person or group from the left."
                                                color: root.faintInk
                                                horizontalAlignment: Text.AlignHCenter
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                topPadding: Style.space(38)
                                            }
                                        }
                                    }

                                    GlassSurface {
                                        width: parent.width
                                        height: Style.space(74)
                                        radius: Style.space(16)
                                        fillOpacity: 0.82
                                        borderOpacity: 0.12

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: Style.space(8)
                                            spacing: Style.space(5)
                                            Row {
                                                width: parent.width
                                                spacing: Style.space(7)
                                                GlassField {
                                                    id: messageInput
                                                    width: parent.width - sendButton.width - Style.space(7)
                                                    placeholder: "Message…"
                                                    text: root.messageDraft
                                                    onTextChanged: root.messageDraft = text
                                                    onAccepted: root.sendMessage()
                                                }
                                                GlassButton {
                                                    id: sendButton
                                                    text: "Send"
                                                    icon: "➤"
                                                    primary: true
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: root.sendMessage()
                                                }
                                            }
                                            GlassField {
                                                width: parent.width
                                                implicitHeight: Style.space(26)
                                                placeholder: "Optional https:// image / video / audio / file link"
                                                text: root.mediaDraft
                                                onTextChanged: root.mediaDraft = text
                                            }
                                        }
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
                            height: Style.space(46)
                            Column {
                                width: parent.width - worldRefresh.width
                                spacing: 1
                                Text { text: "World"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                                Text { text: "Live Omarchy builders · projects · status · help"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            GlassButton { id: worldRefresh; text: "Refresh"; icon: "↻"; compact: true; onClicked: if (root.service) root.service.refreshGlobal() }
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(8)
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(64)
                                radius: Style.space(14)
                                fillOpacity: 0.62
                                Column { anchors.centerIn: parent; Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.world.length); color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true } Text { anchors.horizontalCenter: parent.horizontalCenter; text: "builders live"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                            }
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(64)
                                radius: Style.space(14)
                                fillOpacity: 0.62
                                Column { anchors.centerIn: parent; Text { anchors.horizontalCenter: parent.horizontalCenter; text: (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0); color: root.cyan; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true } Text { anchors.horizontalCenter: parent.horizontalCenter; text: "relays healthy"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                            }
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(64)
                                radius: Style.space(14)
                                fillOpacity: 0.62
                                Column { anchors.centerIn: parent; Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.friendsList().length); color: root.violet; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true } Text { anchors.horizontalCenter: parent.horizontalCenter; text: "friends"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                            }
                        }

                        GlassField {
                            width: parent.width
                            placeholder: "Search builders, projects, interests…"
                            text: root.worldQuery
                            onTextChanged: root.worldQuery = text
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - Style.space(148)
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
                                    model: root.visibleWorld()
                                    GlassSurface {
                                        width: (worldFlow.width - Style.space(8)) / 2
                                        height: Style.space(126)
                                        radius: Style.space(16)
                                        fillOpacity: 0.62
                                        elevated: modelData.public_key && root.friendshipFor(modelData.public_key) && root.friendshipFor(modelData.public_key).status === "friends"

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: Style.space(11)
                                            spacing: Style.space(7)

                                            Row {
                                                width: parent.width
                                                spacing: Style.space(8)
                                                GlassAvatar { size: Style.space(38); emoji: modelData.avatar || "👾"; online: true }
                                                Column {
                                                    width: parent.width - peerAction.width - Style.space(50)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: (modelData.status_emoji || "•") + " " + (modelData.status_name || modelData.activity || "Online"); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                GlassButton {
                                                    id: peerAction
                                                    text: root.peerActionLabel(modelData)
                                                    compact: true
                                                    primary: root.peerActionLabel(modelData) === "Accept"
                                                    enabled: root.peerActionLabel(modelData) !== "Requested" && root.peerActionLabel(modelData) !== "Needs update"
                                                    onClicked: root.activatePeer(modelData)
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.project_name ? ("Building · " + modelData.project_name) : (modelData.activity || "Exploring Omarchy")
                                                color: modelData.project_name ? "#d8d4ff" : root.mutedInk
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                width: parent.width
                                                spacing: Style.space(6)
                                                GlassPill { text: "Wave"; onClicked: if (root.service) root.service.pingGlobal(modelData.public_key, "hello") }
                                                GlassPill { text: "Focus"; onClicked: if (root.service) root.service.inviteGlobalFocus(modelData.public_key) }
                                                GlassPill { text: "Build"; onClicked: root.openBuild("create") }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // CIRCLES
                    Column {
                        visible: root.page === "circles"
                        anchors.fill: parent
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(10)

                        Row {
                            width: parent.width
                            height: Style.space(44)
                            Column {
                                width: parent.width
                                Text { text: "Circles"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                                Text { text: "The public room for updated Friends clients"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                        }

                        GlassSurface {
                            width: parent.width
                            height: Style.space(42)
                            radius: Style.space(13)
                            fillOpacity: 0.58
                            Row {
                                anchors.fill: parent
                                anchors.margins: Style.space(9)
                                spacing: Style.space(8)
                                Text { text: "◉"; color: root.success; font.pixelSize: Style.font.caption }
                                Text { width: parent.width - Style.space(24); text: "Public room · do not share passwords, private links or personal information."; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                        }

                        Flickable {
                            id: circleScroller
                            width: parent.width
                            height: parent.height - Style.space(154)
                            contentWidth: width
                            contentHeight: circleMessages.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                            Column {
                                id: circleMessages
                                width: parent.width
                                spacing: Style.space(8)
                                Repeater {
                                    model: root.community.slice ? root.community.slice(Math.max(0, root.community.length - 50)) : []
                                    GlassSurface {
                                        width: parent.width
                                        height: circleMessageBody.implicitHeight + Style.space(22)
                                        radius: Style.space(14)
                                        fillOpacity: 0.54
                                        Row {
                                            id: circleMessageBody
                                            anchors.fill: parent
                                            anchors.margins: Style.space(10)
                                            spacing: Style.space(9)
                                            GlassAvatar { size: Style.space(32); emoji: modelData.avatar || "👾"; online: false }
                                            Column {
                                                width: parent.width - Style.space(43)
                                                spacing: Style.space(3)
                                                Text { width: parent.width; text: (modelData.handle || modelData.from_name || "Builder") + (modelData.mine ? " · you" : ""); color: modelData.mine ? "#dcd7ff" : root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                Text { width: parent.width; text: modelData.text || modelData.message || ""; color: "#d7dbea"; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Style.space(8)
                            GlassField {
                                width: parent.width - circleSend.width - Style.space(8)
                                placeholder: "Say something useful to everyone…"
                                text: root.communityDraft
                                onTextChanged: root.communityDraft = text
                                onAccepted: root.sendCommunity()
                            }
                            GlassButton { id: circleSend; text: "Send"; icon: "➤"; primary: true; onClicked: root.sendCommunity() }
                        }
                    }

                    // PROFILE
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
                                height: Style.space(112)
                                radius: Style.space(20)
                                fillOpacity: 0.72
                                elevated: true
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Style.space(16)
                                    spacing: Style.space(13)
                                    GlassAvatar { size: Style.space(66); emoji: root.profile.avatar || "👾"; online: true; selected: true; anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        width: parent.width - Style.space(205)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(3)
                                        Text { width: parent.width; text: root.profile.handle || "Omarchy Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
                                        Text { width: parent.width; text: (root.profile.status_emoji || "🚀") + " " + (root.profile.status_name || "Ready"); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                        Text { width: parent.width; text: root.profile.project_name ? ("Building · " + root.profile.project_name) : "Add a project so builders know what you care about."; color: root.profile.project_name ? root.cyan : root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    Column {
                                        width: Style.space(120)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(6)
                                        GlassButton { width: parent.width; text: "Share invite"; compact: true; onClicked: root.copyInvite() }
                                        GlassButton { width: parent.width; text: "Open Build"; compact: true; primary: true; onClicked: root.openBuild("discover") }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Style.space(10)

                                GlassSurface {
                                    width: (parent.width - Style.space(10)) * 0.58
                                    height: profileFields.implicitHeight + Style.space(24)
                                    radius: Style.space(18)
                                    fillOpacity: 0.64
                                    Column {
                                        id: profileFields
                                        anchors.fill: parent
                                        anchors.margins: Style.space(12)
                                        spacing: Style.space(8)
                                        Text { text: "Profile beacon"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                        GlassField { width: parent.width; placeholder: "Display name"; text: root.handleDraft; onTextChanged: root.handleDraft = text }
                                        GlassField { width: parent.width; placeholder: "Project name"; text: root.projectNameDraft; onTextChanged: root.projectNameDraft = text }
                                        GlassField { width: parent.width; placeholder: "Project link https://…"; text: root.projectUrlDraft; onTextChanged: root.projectUrlDraft = text }
                                        Rectangle {
                                            width: parent.width
                                            height: Style.space(78)
                                            radius: Style.space(12)
                                            color: Qt.rgba(0.06, 0.08, 0.15, 0.72)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.10)
                                            TextArea {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(5)
                                                text: root.projectDescDraft
                                                onTextChanged: root.projectDescDraft = text
                                                placeholderText: "One sentence about what you are building"
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

                                GlassSurface {
                                    width: (parent.width - Style.space(10)) * 0.42
                                    height: profileSide.implicitHeight + Style.space(24)
                                    radius: Style.space(18)
                                    fillOpacity: 0.64
                                    Column {
                                        id: profileSide
                                        anchors.fill: parent
                                        anchors.margins: Style.space(12)
                                        spacing: Style.space(9)
                                        Text { text: "Interests"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                        Text { text: "Choose up to four"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                        Flow {
                                            width: parent.width
                                            spacing: Style.space(5)
                                            Repeater {
                                                model: root.service && root.service.availableInterests ? root.service.availableInterests : ["linux", "open-source", "plugins", "ricing", "coding", "design", "hardware", "music"]
                                                GlassPill {
                                                    text: typeof modelData === "string" ? modelData : ((modelData.emoji ? modelData.emoji + " " : "") + (modelData.name || modelData.label || modelData.id || "Interest"))
                                                    active: root.interestsDraft.indexOf(typeof modelData === "string" ? modelData : (modelData.id || modelData.label)) >= 0
                                                    onClicked: root.toggleInterest(typeof modelData === "string" ? modelData : (modelData.id || modelData.label))
                                                }
                                            }
                                        }
                                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                                        Text { text: "Status"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                        Flow {
                                            width: parent.width
                                            spacing: Style.space(5)
                                            Repeater {
                                                model: root.service && root.service.availableStatuses ? root.service.availableStatuses : []
                                                GlassPill {
                                                    text: (modelData.emoji || "•") + " " + (modelData.name || modelData.label || modelData.id || "Status")
                                                    active: root.profile.status === modelData.id
                                                    onClicked: if (root.service) root.service.setStatus(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            GlassSurface {
                                width: parent.width
                                height: updateRow.implicitHeight + Style.space(22)
                                radius: Style.space(16)
                                fillOpacity: 0.58
                                Row {
                                    id: updateRow
                                    anchors.fill: parent
                                    anchors.margins: Style.space(11)
                                    spacing: Style.space(9)
                                    Column {
                                        width: parent.width - updateMe.width - Style.space(10)
                                        Text { text: root.updateInfo.available ? "Update available" : "Friends is current"; color: root.updateInfo.available ? root.warning : root.success; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                        Text { width: parent.width; text: "Installed v" + root.formatVersion() + (root.updateInfo.latest ? " · latest " + root.updateInfo.latest : ""); color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: updateMe; text: root.updateInfo.available ? "Update now" : "Check update"; icon: "↻"; compact: true; primary: root.updateInfo.available; onClicked: if (root.service) root.service.updatePlugin() }
                                }
                            }

                            Item { width: 1; height: Style.space(12) }
                        }
                    }

                    // Group creator overlay
                    GlassSurface {
                        visible: root.groupCreateOpen && root.page === "chats"
                        width: Math.min(contentArea.width - Style.space(30), Style.space(420))
                        height: Math.min(contentArea.height - Style.space(30), Style.space(430))
                        anchors.centerIn: parent
                        radius: Style.space(20)
                        fillOpacity: 0.98
                        borderOpacity: 0.22
                        elevated: true
                        selected: true
                        z: 40

                        Column {
                            anchors.fill: parent
                            anchors.margins: Style.space(14)
                            spacing: Style.space(9)
                            Row {
                                width: parent.width
                                Text { width: parent.width - closeGroup.width; text: "New private group"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                                GlassButton { id: closeGroup; text: "Close"; compact: true; onClicked: root.groupCreateOpen = false }
                            }
                            GlassField { width: parent.width; placeholder: "Group name"; text: root.groupNameDraft; onTextChanged: root.groupNameDraft = text }
                            Text { text: "Choose at least two friends"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            Flickable {
                                width: parent.width
                                height: parent.height - Style.space(136)
                                contentWidth: width
                                contentHeight: memberList.implicitHeight
                                clip: true
                                Column {
                                    id: memberList
                                    width: parent.width
                                    spacing: Style.space(5)
                                    Repeater {
                                        model: root.friendsList()
                                        GlassSurface {
                                            width: parent.width
                                            height: Style.space(46)
                                            radius: Style.space(12)
                                            selected: root.groupMemberKeys.indexOf(modelData.public_key) >= 0
                                            TapHandler { onTapped: root.toggleGroupMember(modelData.public_key) }
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(7)
                                                spacing: Style.space(8)
                                                GlassAvatar { size: Style.space(30); emoji: modelData.avatar || "👾"; online: modelData.online === true }
                                                Text { width: parent.width - Style.space(64); anchors.verticalCenter: parent.verticalCenter; text: modelData.handle || "Builder"; color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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

            // Bottom status rail
            Row {
                width: parent.width - Style.space(36)
                x: Style.space(18)
                height: Style.space(34)
                spacing: Style.space(10)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "●"; color: root.worldStatus.last_error ? root.warning : root.success; font.pixelSize: Style.font.caption }
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.worldStatus.last_error ? "Reconnecting" : "Friends connected"; color: root.mutedInk; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                Item { width: Math.max(0, parent.width - Style.space(390)); height: 1 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "People × setups × ideas × builds"; color: root.faintInk; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 0.6 }
            }
        }

        GlassSurface {
            visible: root.notice !== ""
            width: Math.min(parent.width - Style.space(40), Style.space(360))
            height: noticeText.implicitHeight + Style.space(22)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(45)
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
