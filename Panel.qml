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

    readonly property color fg: Color.foreground
    readonly property color bg: Color.background
    readonly property color accent: Color.accent
    readonly property color muted: Color.muted
    readonly property color soft: Qt.rgba(fg.r, fg.g, fg.b, 0.055)
    readonly property color line: Qt.rgba(fg.r, fg.g, fg.b, 0.11)
    readonly property var service: hostWidget && hostWidget.service ? hostWidget.service : null
    readonly property var profile: service && service.profile ? service.profile : ({ handle: "quiet-builder", avatar: "👾", status: "coding", status_name: "In The Zone", status_emoji: "🚀", project_name: "", project_desc: "", project_url: "", interests: [], privacy: ({ share_global: true }) })
    readonly property var world: service && service.globalPeers ? service.globalPeers : []
    readonly property var pulse: service && service.worldPulse ? service.worldPulse : []
    readonly property var pings: service && service.globalPings ? service.globalPings : []
    readonly property var friendships: service && service.globalFriendships ? service.globalFriendships : ({})
    readonly property var messages: service && service.globalMessages ? service.globalMessages : []
    readonly property var worldStatus: service && service.globalStatus ? service.globalStatus : ({ visible: true, last_error: "" })

    property string tab: "world"
    property string worldQuery: ""
    property int selectedPeer: 0
    property bool ideaOpen: false
    property string ideaText: ""
    property bool feedbackOpen: false
    property string feedbackText: ""
    property bool bugOpen: false
    property string bugText: ""
    property string handleDraft: ""
    property string projectNameDraft: ""
    property string projectDescDraft: ""
    property string projectUrlDraft: ""
    property var interestsDraft: []
    property string notice: ""
    property string messageDraft: ""
    property string mediaDraft: ""
    property string inviteDraft: ""
    property string selectedFriendKey: ""
    property string lastReadMessageId: ""

    readonly property string issueUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=enhancement&title=Feature%20idea"
    readonly property string feedbackUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=feedback&title=Omarchy%20Friends%20feedback"
    readonly property string bugUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=bug&title=Omarchy%20Friends%20bug"

    contentWidth: root.fittedContentWidth(Style.space(460))
    contentHeight: root.fittedContentHeight(deck.implicitHeight)

    function tabList() {
        return ["world", "friends", "messages", "showcase", "profile"]
    }

    function moveTab(delta) {
        var list = tabList()
        var index = list.indexOf(root.tab)
        root.tab = list[(index + delta + list.length) % list.length]
    }

    function visibleWorld() {
        var query = root.worldQuery.trim().toLowerCase()
        if (query === "") return root.world
        var result = []
        for (var i = 0; i < root.world.length; i++) {
            var peer = root.world[i]
            var ground = peer.common_ground || []
            var groundText = ground.join ? ground.join(" ") : String(ground)
            var haystack = [peer.handle || "", peer.project_name || "", peer.activity || "", groundText].join(" ").toLowerCase()
            if (haystack.indexOf(query) !== -1) result.push(peer)
        }
        return result
    }

    function projects() {
        var result = []
        for (var i = 0; i < root.world.length; i++) {
            var peer = root.world[i]
            if (peer.project_name || peer.project_desc || peer.project_url) result.push(peer)
        }
        return result
    }

    function friendsList() {
        var result = []
        for (var key in root.friendships) {
            var friend = root.friendships[key]
            if (friend && friend.status === "friends") {
                var item = Object.assign({}, friend)
                item.public_key = key
                result.push(item)
            }
        }
        return result
    }

    function incomingFriendRequests() {
        var result = []
        for (var i = 0; i < root.pings.length; i++) {
            var ping = root.pings[i]
            if (ping && ping.action === "friend_request") result.push(ping)
        }
        return result
    }

    // Keep an actionable chat invite visible even when older waves are still buffered.
    function primaryPing() {
        for (var i = root.pings.length - 1; i >= 0; i--) {
            if (root.pings[i] && root.pings[i].action === "friend_request") return root.pings[i]
        }
        return root.pings.length > 0 ? root.pings[root.pings.length - 1] : null
    }

    function friendshipFor(publicKey) {
        return publicKey && root.friendships[publicKey] ? root.friendships[publicKey] : null
    }

    function requestFor(publicKey) {
        var requests = root.incomingFriendRequests()
        for (var i = 0; i < requests.length; i++) {
            if (requests[i].public_key === publicKey) return requests[i]
        }
        return null
    }

    function selectedFriend() {
        var list = root.friendsList()
        for (var i = 0; i < list.length; i++) {
            if (list[i].public_key === root.selectedFriendKey) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    function conversationMessages() {
        var friend = root.selectedFriend()
        if (!friend) return []
        var result = []
        for (var i = 0; i < root.messages.length; i++) {
            var message = root.messages[i]
            if (message && message.public_key === friend.public_key) result.push(message)
        }
        return result.slice(Math.max(0, result.length - 16))
    }

    function unreadMessageCount() {
        var afterMarker = root.lastReadMessageId === ""
        var count = 0
        for (var i = 0; i < root.messages.length; i++) {
            var message = root.messages[i]
            if (!message) continue
            if (message.id === root.lastReadMessageId) {
                afterMarker = true
                continue
            }
            if (afterMarker && message.incoming) count++
        }
        return count
    }

    function legacyPeerCount() {
        var count = 0
        for (var i = 0; i < root.world.length; i++) {
            if (root.world[i] && root.world[i].can_chat === false) count++
        }
        return count
    }

    function markMessagesRead() {
        if (root.messages.length > 0) root.lastReadMessageId = root.messages[root.messages.length - 1].id || ""
    }

    function chooseFriend(peer) {
        if (!peer || !peer.public_key) return
        root.selectedFriendKey = peer.public_key
    }

    function friendActionLabel(peer) {
        var friendship = root.friendshipFor(peer && peer.public_key)
        if (friendship && friendship.status === "friends") return "Chat"
        if (friendship && friendship.status === "pending") return "Chat requested"
        if (root.requestFor(peer && peer.public_key)) return "Accept"
        if (peer && peer.can_chat === false) return "Invite update"
        return "Invite to chat"
    }

    function activateFriend(peer) {
        if (!peer || !peer.public_key) return
        var friendship = root.friendshipFor(peer.public_key)
        if (friendship && friendship.status === "friends") {
            root.chooseFriend(peer)
            root.tab = "messages"
            return
        }
        var request = root.requestFor(peer.public_key)
        if (request && root.service) {
            root.service.acceptFriendRequest(request.id)
            return
        }
        if (!friendship || friendship.status !== "pending") root.askToBeFriends(peer)
        else root.showNotice("Friend request is waiting for acceptance")
    }

    function sendMessage() {
        var friend = root.selectedFriend()
        var text = root.messageDraft.trim()
        var media = root.mediaDraft.trim()
        if (!friend || !root.service) {
            root.showNotice("Accept a friend request before messaging")
            return
        }
        if (!text && !media) {
            root.showNotice("Write a message or paste a media link")
            return
        }
        root.service.sendDm(friend.public_key, text, media)
        root.messageDraft = ""
        root.mediaDraft = ""
    }

    function openSharedUrl(url) {
        if (url && (url.indexOf("https://") === 0 || url.indexOf("http://") === 0)) {
            Quickshell.execDetached(["xdg-open", url])
        }
    }

    onTabChanged: {
        if (root.tab === "messages") Qt.callLater(root.markMessagesRead)
    }

    function showNotice(message) {
        root.notice = message
        noticeTimer.restart()
    }

    function sayHi(peer) {
        if (root.service && peer && peer.public_key) root.service.pingGlobal(peer.public_key, "hello")
    }

    function askToBeFriends(peer) {
        if (root.service && peer && peer.public_key) root.service.requestFriend(peer.public_key)
    }

    function openProfile() {
        root.tab = "profile"
        root.handleDraft = root.profile.handle || ""
        root.projectNameDraft = root.profile.project_name || ""
        root.projectDescDraft = root.profile.project_desc || ""
        root.projectUrlDraft = root.profile.project_url || ""
        root.interestsDraft = (root.profile.interests || []).slice ? (root.profile.interests || []).slice() : []
    }

    function saveProfile() {
        if (!root.service) return
        root.service.setProfile(root.handleDraft, root.projectNameDraft, root.projectDescDraft, root.projectUrlDraft)
    }

    function toggleInterest(id) {
        var next = (root.interestsDraft || []).slice()
        var index = next.indexOf(id)
        if (index >= 0) {
            next.splice(index, 1)
        } else if (next.length < 5) {
            next.push(id)
        } else {
            showNotice("Choose up to five interests")
            return
        }
        root.interestsDraft = next
        if (root.service) root.service.setInterests(next)
    }

    function submitIdea() {
        if (root.ideaText.trim() === "") {
            showNotice("Write an idea first")
            return
        }
        var payload = "Omarchy Friends feature idea:\n\n" + root.ideaText.trim()
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(payload) + " | wl-copy"])
        Quickshell.execDetached(["xdg-open", root.issueUrl])
        root.ideaOpen = false
        showNotice("Copied and opened GitHub")
    }

    function submitFeedback() {
        if (root.feedbackText.trim() === "") {
            showNotice("Write a little feedback first")
            return
        }
        var payload = "Omarchy Friends feedback:\n\n" + root.feedbackText.trim()
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(payload) + " | wl-copy"])
        Quickshell.execDetached(["xdg-open", root.feedbackUrl])
        root.feedbackOpen = false
        showNotice("Copied feedback and opened GitHub")
    }

    function submitBug() {
        if (root.bugText.trim() === "") {
            showNotice("Describe what went wrong first")
            return
        }
        var payload = "Omarchy Friends bug report:\n\n" + root.bugText.trim()
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(payload) + " | wl-copy"])
        Quickshell.execDetached(["xdg-open", root.bugUrl])
        root.bugOpen = false
        showNotice("Copied bug report and opened GitHub")
    }

    function copyInviteLink() {
        if (!root.profile.public_key) {
            showNotice("Your invite link is not ready yet")
            return
        }
        var invite = "omarchy-friends://invite/" + root.profile.public_key
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(invite) + " | wl-copy"])
        showNotice("Invite link copied")
    }

    function connectInvite() {
        var value = root.inviteDraft.trim()
        var prefix = "omarchy-friends://invite/"
        if (value.indexOf(prefix) === 0) value = value.substring(prefix.length)
        if (!/^[0-9a-fA-F]{64}$/.test(value)) {
            showNotice("Paste a valid Omarchy Friends invite link")
            return
        }
        if (root.service) root.service.requestFriendDirect(value.toLowerCase())
        root.inviteDraft = ""
    }

    function keyPressed(event) {
        if (!root.open) return
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Left || event.text === "h") {
            moveTab(-1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Right || event.text === "l") {
            moveTab(1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_1) {
            root.tab = "world"
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_2) {
            root.tab = "friends"
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_3) {
            root.tab = "messages"
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_4) {
            root.tab = "showcase"
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_5) {
            openProfile()
            event.accepted = true
            return
        }
        if (event.text === "r" && root.tab === "world" && root.service) {
            root.service.refreshGlobal()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down || event.text === "j") {
            root.selectedPeer = Math.min(Math.max(0, root.visibleWorld().length - 1), root.selectedPeer + 1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Up || event.text === "k") {
            root.selectedPeer = Math.max(0, root.selectedPeer - 1)
            event.accepted = true
            return
        }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.tab === "world" && root.visibleWorld().length > 0) {
            sayHi(root.visibleWorld()[root.selectedPeer])
            event.accepted = true
        }
    }

    Item {
        width: 1
        height: 1
        visible: false
        focus: root.open

        Timer {
            id: noticeTimer
            interval: 2600
            onTriggered: root.notice = ""
        }

        Keys.onPressed: function(event) {
            root.keyPressed(event)
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) Qt.callLater(function() { parent.forceActiveFocus() })
            }
        }

        Connections {
            target: root.service
            function onActionResult(ok, message) {
                root.showNotice(message || (ok ? "Done" : "Something went wrong"))
            }
            function onEventReceived(event) {
                root.showNotice(event && event.message ? event.message : "A builder sent a signal")
            }
        }
    }

    Flickable {
        id: contentScroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: deck.implicitHeight
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: deck
            width: contentScroller.width
            spacing: 0

        Row {
            width: parent.width
            height: Style.space(40)

            Text {
                id: titleText
                text: "Omarchy Friends"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - titleText.width - settingsButton.width
                height: 1
            }

            Rectangle {
                id: settingsButton
                width: Style.space(34)
                height: Style.space(30)
                radius: height / 2
                color: soft

                Text {
                    anchors.centerIn: parent
                    text: "⋯"
                    color: muted
                    font.pixelSize: Style.space(18)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openProfile()
                }
            }
        }

        Row {
            width: parent.width
            height: Style.space(70)
            spacing: Style.space(12)

            Rectangle {
                width: Style.space(52)
                height: Style.space(52)
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.55)

                Text {
                    anchors.centerIn: parent
                    text: root.profile.avatar || "👾"
                    font.pixelSize: Style.space(26)
                }

                Rectangle {
                    width: Style.space(12)
                    height: width
                    radius: width / 2
                    color: "#31c48d"
                    border.width: 2
                    border.color: bg
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                }
            }

            Column {
                width: parent.width - Style.space(64)
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: root.profile.handle || "quiet-builder"
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: (root.profile.status_emoji || "•") + " " + (root.profile.status_name || "Ready")
                    color: muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: line
        }

        Row {
            width: parent.width
            height: Style.space(42)

            Repeater {
                model: [
                    { id: "world", label: "World" },
                    { id: "friends", label: "Friends" },
                    { id: "messages", label: "Messages" },
                    { id: "showcase", label: "Showcase" },
                    { id: "profile", label: "Profile" }
                ]

                Item {
                    width: parent.width / 5
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: modelData.id === "friends" && root.incomingFriendRequests().length > 0
                            ? modelData.label + " (" + root.incomingFriendRequests().length + ")"
                            : modelData.id === "messages" && root.unreadMessageCount() > 0
                                ? modelData.label + " (" + root.unreadMessageCount() + ")"
                                : modelData.label
                        color: root.tab === modelData.id ? accent : muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: root.tab === modelData.id
                    }

                    Rectangle {
                        visible: root.tab === modelData.id
                        width: parent.width - Style.space(18)
                        height: Style.space(2)
                        radius: height / 2
                        color: accent
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.id === "profile") root.openProfile()
                            else root.tab = modelData.id
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.notice !== ""
            width: parent.width
            height: visible ? noticeText.implicitHeight + Style.space(14) : 0
            radius: Style.space(7)
            color: Qt.rgba(accent.r, accent.g, accent.b, 0.11)

            Text {
                id: noticeText
                width: parent.width - Style.space(14)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: root.notice
                color: accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }

        Column {
            id: worldPanel
            visible: root.tab === "world"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Style.space(12)

            Item { width: 1; height: Style.space(18) }

            Row {
                width: parent.width
                // Three status lines need real vertical room; otherwise the
                // relay-health line is rendered but clipped by the header.
                height: Style.space(54)

                Column {
                    width: parent.width - refreshButton.width - Style.space(8)
                    spacing: Style.space(2)

                    Text {
                        text: root.worldStatus.last_error ? "World is resting" : "Find your people."
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }

                    Text {
                        text: root.worldStatus.last_error ? "Refresh in a moment" : (root.worldStatus.visible ? root.world.length + " builders on Omarchy" : "You are hidden from World")
                        color: muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Text {
                        text: root.worldStatus.last_error
                            ? root.worldStatus.last_error
                            : "● " + (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0) + " relays · synced " + (root.worldStatus.last_sync_age || "never")
                        color: root.worldStatus.last_error ? "#f59e0b" : muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: refreshButton
                    width: refreshText.implicitWidth + Style.space(20)
                    height: Style.space(30)
                    radius: height / 2
                    color: accent
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: refreshText
                        anchors.centerIn: parent
                        text: "Refresh"
                        color: bg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) root.service.refreshGlobal()
                    }
                }
            }

            Rectangle {
                visible: root.pings.length > 0
                width: parent.width
                height: visible ? pingRow.implicitHeight + Style.space(16) : 0
                radius: Style.space(9)
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.11)

                Row {
                    id: pingRow
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(9)

                    Text {
                        text: "👋"
                        font.pixelSize: Style.space(17)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - pingButton.width - Style.space(36)
                        text: root.primaryPing() && root.primaryPing().action === "friend_request"
                            ? (root.primaryPing().handle || "Someone") + " wants to chat"
                            : (root.primaryPing() && root.primaryPing().handle ? root.primaryPing().handle + " waved at you" : "Someone waved at you")
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: pingButton
                        width: pingText.implicitWidth + Style.space(14)
                        height: Style.space(26)
                        radius: height / 2
                        color: accent
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: pingText
                            anchors.centerIn: parent
                            text: root.primaryPing() && root.primaryPing().action === "friend_request" ? "Accept" : "Wave back"
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.service && root.primaryPing()) {
                                if (root.primaryPing().action === "friend_request") root.service.acceptFriendRequest(root.primaryPing().id)
                                else root.service.pingGlobal(root.primaryPing().public_key, "hello")
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.world.length === 0
                width: parent.width
                height: emptyWorld.implicitHeight + Style.space(42)
                radius: Style.space(12)
                color: soft
                border.width: 1
                border.color: line

                Column {
                    id: emptyWorld
                    anchors.centerIn: parent
                    width: parent.width - Style.space(44)
                    spacing: Style.space(8)

                    Text {
                        width: parent.width
                        text: "◌"
                        color: accent
                        font.pixelSize: Style.space(40)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: root.worldStatus.last_error ? "World is taking a break." : (root.worldStatus.visible ? "Builders on Omarchy, making things." : "You are hidden from World.")
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: root.worldStatus.last_error ? "Try again in a moment, or finish your profile while it reconnects." : (root.worldStatus.visible ? "You will appear here when another builder is online." : "Open Profile whenever you are ready to appear.")
                        color: muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: emptyActionText.implicitWidth + Style.space(24)
                        height: Style.space(32)
                        radius: height / 2
                        color: accent

                        Text {
                            id: emptyActionText
                            anchors.centerIn: parent
                            text: root.worldStatus.last_error ? "Try again" : (root.worldStatus.visible ? "Refresh World" : "Open Profile")
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service) root.service.refreshGlobal()
                                if (!root.worldStatus.visible) root.openProfile()
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.legacyPeerCount() > 0
                width: parent.width
                height: Style.space(52)
                radius: Style.space(9)
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.1)

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(8)

                    Text {
                        text: "↻"
                        color: accent
                        font.pixelSize: Style.space(18)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - updateWorldButton.width - Style.space(34)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        Text { text: root.legacyPeerCount() + " builder" + (root.legacyPeerCount() === 1 ? " needs" : "s need") + " an update for DMs"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                        Text { text: "Update Friends to keep chat invites compatible."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                    }

                    Rectangle {
                        id: updateWorldButton
                        width: updateWorldText.implicitWidth + Style.space(16)
                        height: Style.space(28)
                        radius: height / 2
                        color: accent
                        anchors.verticalCenter: parent.verticalCenter
                        Text { id: updateWorldText; anchors.centerIn: parent; text: "Update"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.updatePlugin() }
                    }
                }
            }

            Rectangle {
                visible: root.world.length > 3
                width: parent.width
                height: Style.space(32)
                radius: height / 2
                color: soft
                border.width: root.worldQuery !== "" ? 1 : 0
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.4)

                Text {
                    visible: root.worldQuery === ""
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(13)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search builders or projects"
                    color: muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(13)
                    anchors.rightMargin: Style.space(13)
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.worldQuery
                    onTextChanged: root.worldQuery = text
                }
            }

            Repeater {
                model: root.visibleWorld()

                Rectangle {
                    width: parent.width
                    height: peerRow.implicitHeight + Style.space(18)
                    radius: Style.space(9)
                    color: index === root.selectedPeer ? Qt.rgba(accent.r, accent.g, accent.b, 0.1) : soft
                    border.width: index === root.selectedPeer ? 1 : 0
                    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.35)

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selectedPeer = index
                    }

                    Row {
                        id: peerRow
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(10)

                        Text {
                            text: modelData.avatar || "👾"
                            font.pixelSize: Style.space(24)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - hiButton.width - Style.space(44)
                            spacing: Style.space(3)
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                spacing: Style.space(6)

                                Text {
                                    text: modelData.handle || "Omarchy builder"
                                    color: fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.status_emoji || "•"
                                    color: accent
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.project_name || modelData.activity || "Making something on Omarchy"
                                color: muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: modelData.common_ground && modelData.common_ground.length > 0
                                width: parent.width
                                text: "Shared: " + (modelData.common_ground || []).join(" · ")
                                color: accent
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: hiButton
                            width: hiText.implicitWidth + Style.space(16)
                            height: Style.space(28)
                            radius: height / 2
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: hiText
                                anchors.centerIn: parent
                                text: root.friendActionLabel(modelData)
                                color: root.friendshipFor(modelData.public_key) && root.friendshipFor(modelData.public_key).status === "friends" ? accent : fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateFriend(modelData)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.world.length > 0 && root.visibleWorld().length === 0
                width: parent.width
                text: "No builders match that search."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Column {
            id: friendsPanel
            visible: root.tab === "friends"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Style.space(12)
            Item { width: 1; height: Style.space(18) }
            Text { text: "Friends"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { text: "Accept chat invites here, then open a private conversation in Messages."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            Text { visible: root.incomingFriendRequests().length > 0; text: "Pending requests"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            Repeater {
                model: root.incomingFriendRequests()
                Rectangle {
                    width: parent.width
                    height: Style.space(56)
                    radius: Style.space(9)
                    color: Qt.rgba(accent.r, accent.g, accent.b, 0.1)
                    Row {
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(9)
                        Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(22); anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - acceptRequestButton.width - Style.space(38)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(2)
                            Text { text: modelData.handle || "A builder"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                            Text { text: "wants to chat"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                        Rectangle {
                            id: acceptRequestButton
                            width: acceptRequestText.implicitWidth + Style.space(16)
                            height: Style.space(28)
                            radius: height / 2
                            color: accent
                            anchors.verticalCenter: parent.verticalCenter
                            Text { id: acceptRequestText; anchors.centerIn: parent; text: "Accept"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.acceptFriendRequest(modelData.id) }
                        }
                    }
                }
            }
            Repeater {
                model: root.friendsList()
                Rectangle {
                    width: parent.width
                    height: Style.space(56)
                    radius: Style.space(9)
                    color: root.selectedFriendKey === modelData.public_key ? Qt.rgba(accent.r, accent.g, accent.b, 0.12) : soft
                    border.width: root.selectedFriendKey === modelData.public_key ? 1 : 0
                    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                    Row {
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(9)
                        Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(22); anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - messageFriendButton.width - Style.space(38)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(2)
                            Text { text: modelData.handle || "Omarchy friend"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                            Text { text: "Private chat available"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                        Rectangle {
                            id: messageFriendButton
                            width: messageFriendText.implicitWidth + Style.space(16)
                            height: Style.space(28)
                            radius: height / 2
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { id: messageFriendText; anchors.centerIn: parent; text: "Message"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.chooseFriend(modelData); root.tab = "messages" } }
                        }
                    }
                }
            }
            Text { visible: root.friendsList().length === 0 && root.incomingFriendRequests().length === 0; width: parent.width; text: "Invite a builder from World. Accepted chats and conversations stay here."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
        }

        Column {
            id: messagesPanel
            visible: root.tab === "messages"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Style.space(12)
            Item { width: 1; height: Style.space(18) }
            Text { text: "Messages"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { text: "Private, encrypted conversations with your Omarchy friends."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            Flow {
                width: parent.width
                spacing: Style.space(6)
                Repeater {
                    model: root.friendsList()
                    Rectangle {
                        width: Math.min(friendChipText.implicitWidth + Style.space(22), parent.width)
                        height: Style.space(30)
                        radius: height / 2
                        color: root.selectedFriendKey === modelData.public_key ? Qt.rgba(accent.r, accent.g, accent.b, 0.2) : soft
                        border.width: root.selectedFriendKey === modelData.public_key ? 1 : 0
                        border.color: accent
                        Text { id: friendChipText; width: parent.width - Style.space(22); anchors.centerIn: parent; text: (modelData.avatar || "👾") + " " + (modelData.handle || "Friend"); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.chooseFriend(modelData) }
                    }
                }
            }
            Text { visible: root.friendsList().length === 0; width: parent.width; text: "Accept a friend request before starting a private chat."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
            Text { visible: root.selectedFriend() !== null; text: root.selectedFriend() ? "Chatting with " + root.selectedFriend().handle : ""; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            Rectangle {
                visible: root.selectedFriend() !== null
                width: parent.width
                height: Math.max(Style.space(72), chatHistory.implicitHeight + Style.space(18))
                radius: Style.space(9)
                color: soft
                Column {
                    id: chatHistory
                    width: parent.width - Style.space(18)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Style.space(9)
                    spacing: Style.space(7)
                    Repeater {
                        model: root.conversationMessages()
                        Column {
                            width: parent.width
                            spacing: Style.space(3)
                            Row {
                                width: parent.width
                                layoutDirection: modelData.incoming ? Qt.LeftToRight : Qt.RightToLeft
                                Rectangle {
                                    width: Math.min(parent.width - Style.space(26), Style.space(330))
                                    height: messageBubble.implicitHeight + Style.space(14)
                                    radius: Style.space(8)
                                    color: modelData.incoming ? Qt.rgba(fg.r, fg.g, fg.b, 0.08) : Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                                    Column {
                                        id: messageBubble
                                        width: parent.width - Style.space(14)
                                        anchors.centerIn: parent
                                        spacing: Style.space(5)
                                        Text { visible: modelData.text !== ""; width: parent.width; text: modelData.text || ""; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                        Repeater {
                                            model: modelData.media || []
                                            Rectangle {
                                                width: parent.width
                                                height: Style.space(28)
                                                radius: height / 2
                                                color: Qt.rgba(accent.r, accent.g, accent.b, 0.14)
                                                Text { anchors.centerIn: parent; text: (modelData.kind === "image" ? "🖼 " : modelData.kind === "video" ? "🎞 " : modelData.kind === "audio" ? "🎧 " : "🔗 ") + "Open shared " + modelData.kind; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openSharedUrl(modelData.url) }
                                            }
                                        }
                                    }
                                }
                            }
                            Text { width: parent.width; text: (modelData.incoming ? "← " : "→ ") + (modelData.handle || "Friend"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: modelData.incoming ? Text.AlignLeft : Text.AlignRight }
                        }
                    }
                    Text { visible: root.conversationMessages().length === 0; width: parent.width; text: "No messages yet. Say hello or share a link."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
                }
            }
            Rectangle {
                visible: root.selectedFriend() !== null
                width: parent.width
                height: Style.space(38)
                radius: Style.space(8)
                color: soft
                TextInput {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    text: root.messageDraft
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    onTextChanged: root.messageDraft = text
                    onAccepted: root.sendMessage()
                }
                Text { visible: root.messageDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: "Write a message…"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; enabled: false }
            }
            Rectangle {
                visible: root.selectedFriend() !== null
                width: parent.width
                height: Style.space(38)
                radius: Style.space(8)
                color: soft
                TextInput {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    text: root.mediaDraft
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    onTextChanged: root.mediaDraft = text
                    onAccepted: root.sendMessage()
                }
                Text { visible: root.mediaDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: "Paste an image, video, audio, or file link (optional)"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; enabled: false; elide: Text.ElideRight; width: parent.width - Style.space(20) }
            }
            Row {
                visible: root.selectedFriend() !== null
                width: parent.width
                spacing: Style.space(8)
                Text { width: parent.width - sendMessageButton.width - Style.space(8); text: "Links are shared inside the encrypted message; Friends never uploads a file without your permission."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    id: sendMessageButton
                    width: sendMessageButtonText.implicitWidth + Style.space(20)
                    height: Style.space(32)
                    radius: height / 2
                    color: accent
                    anchors.verticalCenter: parent.verticalCenter
                    Text { id: sendMessageButtonText; anchors.centerIn: parent; text: "Send"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sendMessage() }
                }
            }
        }

        Column {
            id: showcasePanel
            visible: root.tab === "showcase"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Style.space(12)

            Item { width: 1; height: Style.space(18) }

            Text {
                text: "Showcase"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
            }

            Text {
                text: "Projects, plugins, and custom rice shared in public."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Rectangle {
                width: parent.width
                height: Style.space(42)
                radius: Style.space(9)
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.11)

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(9)

                    Text {
                        text: "✦"
                        color: accent
                        font.pixelSize: Style.space(18)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - setupButton.width - Style.space(30)
                        text: root.profile.project_name ? "Your setup is live." : "Add one project to be discoverable."
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: setupButton
                        width: setupText.implicitWidth + Style.space(16)
                        height: Style.space(26)
                        radius: height / 2
                        color: accent
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: setupText
                            anchors.centerIn: parent
                            text: root.profile.project_name ? "Edit" : "Add setup"
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openProfile()
                        }
                    }
                }
            }

            Repeater {
                model: root.projects()

                Rectangle {
                    width: parent.width
                    height: projectRow.implicitHeight + Style.space(18)
                    radius: Style.space(9)
                    color: soft

                    Row {
                        id: projectRow
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(10)

                        Text {
                            text: modelData.avatar || "👾"
                            font.pixelSize: Style.space(23)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - projectHi.width - Style.space(44)
                            spacing: Style.space(3)
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                spacing: Style.space(5)

                                Text {
                                    text: modelData.project_name || "Omarchy setup"
                                    color: fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "by " + (modelData.handle || "builder")
                                    color: muted
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.project_desc || "A setup worth exploring"
                                color: muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: projectHi
                            width: projectHiText.implicitWidth + Style.space(14)
                            height: Style.space(26)
                            radius: height / 2
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: projectHiText
                                anchors.centerIn: parent
                                text: "Say hi"
                                color: fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.sayHi(modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.projects().length === 0
                width: parent.width
                height: Style.space(150)
                radius: Style.space(12)
                color: soft
                border.width: 1
                border.color: line

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(44)
                    spacing: Style.space(7)

                    Text {
                        width: parent.width
                        text: "Nothing here yet."
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: "Add a project and give someone an easy opener."
                        color: muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: showcaseActionText.implicitWidth + Style.space(22)
                        height: Style.space(30)
                        radius: height / 2
                        color: accent

                        Text {
                            id: showcaseActionText
                            anchors.centerIn: parent
                            text: "Add setup"
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openProfile()
                        }
                    }
                }
            }
        }

        Column {
            id: activityPanel
            visible: false
            width: parent.width
            height: 0
            spacing: Style.space(12)

            Item { width: 1; height: Style.space(18) }

            Text {
                text: "Activity"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
            }

            Text {
                text: "Signals from people you crossed paths with."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Repeater {
                model: root.pulse

                Rectangle {
                    width: parent.width
                    height: activityRow.implicitHeight + Style.space(18)
                    radius: Style.space(9)
                    color: soft

                    Row {
                        id: activityRow
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(9)

                        Text {
                            text: modelData.avatar || "👾"
                            font.pixelSize: Style.space(20)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - activityButton.width - Style.space(38)
                            spacing: Style.space(3)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: (modelData.user || "A builder") + " · " + (modelData.time_ago || "now")
                                color: fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: modelData.text || "Sent a signal"
                                color: muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            id: activityButton
                            visible: modelData.remote && modelData.peer_code
                            width: activityButtonText.implicitWidth + Style.space(14)
                            height: Style.space(26)
                            radius: height / 2
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: activityButtonText
                                anchors.centerIn: parent
                                text: "Reply"
                                color: fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (root.service) root.service.interact(modelData.peer_code, "hello")
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.pulse.length === 0
                width: parent.width
                height: Style.space(150)
                radius: Style.space(12)
                color: soft
                border.width: 1
                border.color: line

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(44)
                    spacing: Style.space(7)

                    Text {
                        width: parent.width
                        text: "Your first hello starts here."
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: "Say hi in World and replies will appear here."
                        color: muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Column {
            id: profilePanel
            visible: root.tab === "profile"
            width: parent.width
            height: visible ? implicitHeight : 0
            spacing: Style.space(10)

            Item { width: 1; height: Style.space(18) }

            Text {
                text: "Profile"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
            }

            Text {
                text: "The small details that help someone say hello."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Text {
                text: "Name"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.space(7)
                color: soft

                TextInput {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    text: root.handleDraft
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    onTextChanged: root.handleDraft = text
                }
            }

            Text {
                text: "Avatar"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Flow {
                width: parent.width
                spacing: Style.space(5)

                Repeater {
                    model: root.service && root.service.availableAvatars && root.service.availableAvatars.length ? root.service.availableAvatars : ["👾", "🦊", "🤖", "🐱", "🚀", "🧙", "🦉", "🐙", "⚡", "☕", "🎮", "🐧"]

                    Rectangle {
                        width: Style.space(29)
                        height: Style.space(29)
                        radius: height / 2
                        color: root.profile.avatar === modelData ? Qt.rgba(accent.r, accent.g, accent.b, 0.22) : soft
                        border.width: root.profile.avatar === modelData ? 1 : 0
                        border.color: accent

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Style.space(16)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.service) root.service.setAvatar(modelData)
                        }
                    }
                }
            }

            Text {
                text: "Status"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Flow {
                width: parent.width
                spacing: Style.space(5)

                Repeater {
                    model: root.service && root.service.availableStatuses && root.service.availableStatuses.length ? root.service.availableStatuses : [
                        { id: "coding", name: "In The Zone", emoji: "🚀" },
                        { id: "vibe", name: "Vibe Coding", emoji: "🎧" },
                        { id: "coffee", name: "Coffee Break", emoji: "☕" },
                        { id: "debug", name: "Debugging Hell", emoji: "🐛" },
                        { id: "night", name: "Late Night Hack", emoji: "🌙" },
                        { id: "rice", name: "Ricing Dotfiles", emoji: "🛠️" },
                        { id: "idle", name: "Away", emoji: "💤" }
                    ]

                    Rectangle {
                        height: Style.space(26)
                        width: statusChip.implicitWidth + Style.space(14)
                        radius: height / 2
                        color: root.profile.status === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.2) : soft
                        border.width: root.profile.status === modelData.id ? 1 : 0
                        border.color: accent

                        Text {
                            id: statusChip
                            anchors.centerIn: parent
                            text: modelData.emoji + " " + modelData.name
                            color: root.profile.status === modelData.id ? accent : muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: root.profile.status === modelData.id
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.service) root.service.setStatus(modelData.id)
                        }
                    }
                }
            }

            Text {
                text: "Interests"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Text {
                text: "Choose up to five."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Flow {
                width: parent.width
                spacing: Style.space(5)

                Repeater {
                    model: root.service && root.service.availableInterests && root.service.availableInterests.length ? root.service.availableInterests : [
                        { id: "linux", name: "Linux", emoji: "🐧" },
                        { id: "open-source", name: "Open source", emoji: "🧩" },
                        { id: "plugins", name: "Plugins", emoji: "🧱" },
                        { id: "rice", name: "Ricing / dotfiles", emoji: "🛠️" },
                        { id: "coding", name: "Coding", emoji: "💻" },
                        { id: "design", name: "Design", emoji: "🎨" },
                        { id: "hardware", name: "Hardware", emoji: "🔧" },
                        { id: "music", name: "Music", emoji: "🎧" },
                        { id: "writing", name: "Writing", emoji: "✍️" },
                        { id: "games", name: "Games", emoji: "🎮" }
                    ]

                    Rectangle {
                        height: Style.space(26)
                        width: interestChip.implicitWidth + Style.space(14)
                        radius: height / 2
                        color: root.interestsDraft.indexOf(modelData.id) >= 0 ? Qt.rgba(accent.r, accent.g, accent.b, 0.2) : soft
                        border.width: root.interestsDraft.indexOf(modelData.id) >= 0 ? 1 : 0
                        border.color: accent

                        Text {
                            id: interestChip
                            anchors.centerIn: parent
                            text: modelData.emoji + " " + modelData.name
                            color: root.interestsDraft.indexOf(modelData.id) >= 0 ? accent : muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: root.interestsDraft.indexOf(modelData.id) >= 0
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleInterest(modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(38)
                radius: height / 2
                color: root.profile.privacy && root.profile.privacy.share_global ? Qt.rgba(0.06, 0.73, 0.51, 0.1) : soft
                border.width: 1
                border.color: root.profile.privacy && root.profile.privacy.share_global ? Qt.rgba(0.06, 0.73, 0.51, 0.28) : line

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(8)

                    Text {
                        text: root.profile.privacy && root.profile.privacy.share_global ? "●" : "○"
                        color: root.profile.privacy && root.profile.privacy.share_global ? "#31c48d" : muted
                        font.pixelSize: Style.space(13)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - privacyButton.width - Style.space(27)
                        text: root.profile.privacy && root.profile.privacy.share_global ? "Visible in World" : "Hidden from World"
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: privacyButton
                        width: privacyText.implicitWidth + Style.space(14)
                        height: Style.space(24)
                        radius: height / 2
                        color: soft
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: privacyText
                            anchors.centerIn: parent
                            text: "Change"
                            color: muted
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.service) root.service.togglePrivacy("share_global")
                        }
                    }
                }
            }

            Text {
                text: "Showcase"
                color: fg
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Text {
                text: "A project name and one sentence is enough."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.space(7)
                color: soft

                TextInput {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    text: root.projectNameDraft
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    onTextChanged: root.projectNameDraft = text
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(54)
                radius: Style.space(7)
                color: soft

                TextEdit {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    text: root.projectDescDraft
                    color: fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: TextEdit.Wrap
                    onTextChanged: root.projectDescDraft = text
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(38)
                radius: height / 2
                color: accent

                Text {
                    anchors.centerIn: parent
                    text: "Save profile"
                    color: bg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.saveProfile()
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(46)
                radius: Style.space(8)
                color: soft

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(8)

                    Column {
                        width: parent.width - updateButton.width - Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        Text { text: "Keep Friends up to date"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { text: "Needed for chat compatibility."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }

                    Rectangle {
                        id: updateButton
                        width: updateButtonText.implicitWidth + Style.space(16)
                        height: Style.space(28)
                        radius: height / 2
                        color: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                        anchors.verticalCenter: parent.verticalCenter
                        Text { id: updateButtonText; anchors.centerIn: parent; text: "Update"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.updatePlugin() }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(82)
                radius: Style.space(8)
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.08)

                Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(6)
                    Row {
                        width: parent.width
                        Text { width: parent.width - inviteCopyButton.width; text: "Invite someone directly"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Rectangle {
                            id: inviteCopyButton
                            width: inviteCopyText.implicitWidth + Style.space(16)
                            height: Style.space(24)
                            radius: height / 2
                            color: accent
                            Text { id: inviteCopyText; anchors.centerIn: parent; text: "Copy invite"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyInviteLink() }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: Style.space(32)
                        radius: height / 2
                        color: soft
                        TextInput {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: connectInviteButton.width + Style.space(8)
                            color: fg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            text: root.inviteDraft
                            onTextChanged: root.inviteDraft = text
                            onAccepted: root.connectInvite()
                        }
                        Text { visible: root.inviteDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: "Paste an invite link"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; enabled: false }
                        Rectangle {
                            id: connectInviteButton
                            anchors.right: parent.right
                            anchors.rightMargin: Style.space(4)
                            anchors.verticalCenter: parent.verticalCenter
                            width: connectInviteText.implicitWidth + Style.space(14)
                            height: Style.space(25)
                            radius: height / 2
                            color: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                            Text { id: connectInviteText; anchors.centerIn: parent; text: "Connect"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.connectInvite() }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: root.ideaOpen ? ideaColumn.implicitHeight + Style.space(18) : Style.space(32)
                radius: Style.space(8)
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.08)

                Column {
                    id: ideaColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(7)

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - ideaToggle.width
                            text: "Suggest a feature"
                            color: fg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        Rectangle {
                            id: ideaToggle
                            width: Style.space(52)
                            height: Style.space(24)
                            radius: height / 2
                            color: soft

                            Text {
                                anchors.centerIn: parent
                                text: root.ideaOpen ? "Close" : "Open"
                                color: muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.ideaOpen = !root.ideaOpen
                            }
                        }
                    }

                    TextEdit {
                        visible: root.ideaOpen
                        width: parent.width
                        height: Style.space(54)
                        text: root.ideaText
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: TextEdit.Wrap
                        onTextChanged: root.ideaText = text
                    }

                    Rectangle {
                        visible: root.ideaOpen
                        width: parent.width
                        height: Style.space(30)
                        radius: height / 2
                        color: accent

                        Text {
                            anchors.centerIn: parent
                            text: "Copy suggestion and open GitHub"
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.submitIdea()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: root.feedbackOpen ? feedbackColumn.implicitHeight + Style.space(18) : Style.space(32)
                radius: Style.space(8)
                color: soft

                Column {
                    id: feedbackColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(7)

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - feedbackToggle.width
                            text: "Send feedback"
                            color: fg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        Rectangle {
                            id: feedbackToggle
                            width: Style.space(52)
                            height: Style.space(24)
                            radius: height / 2
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: root.feedbackOpen ? "Close" : "Open"
                                color: muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.feedbackOpen = !root.feedbackOpen
                            }
                        }
                    }

                    TextEdit {
                        visible: root.feedbackOpen
                        width: parent.width
                        height: Style.space(54)
                        text: root.feedbackText
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: TextEdit.Wrap
                        onTextChanged: root.feedbackText = text
                    }

                    Rectangle {
                        visible: root.feedbackOpen
                        width: parent.width
                        height: Style.space(30)
                        radius: height / 2
                        color: Qt.rgba(accent.r, accent.g, accent.b, 0.75)

                        Text {
                            anchors.centerIn: parent
                            text: "Copy feedback and open GitHub"
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.submitFeedback()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: root.bugOpen ? bugColumn.implicitHeight + Style.space(18) : Style.space(32)
                radius: Style.space(8)
                color: Qt.rgba(0.95, 0.35, 0.25, 0.08)

                Column {
                    id: bugColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(7)

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - bugToggle.width
                            text: "Report a bug"
                            color: fg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        Rectangle {
                            id: bugToggle
                            width: Style.space(52)
                            height: Style.space(24)
                            radius: height / 2
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: root.bugOpen ? "Close" : "Open"
                                color: muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.bugOpen = !root.bugOpen
                            }
                        }
                    }

                    TextEdit {
                        visible: root.bugOpen
                        width: parent.width
                        height: Style.space(54)
                        text: root.bugText
                        color: fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: TextEdit.Wrap
                        onTextChanged: root.bugText = text
                    }

                    Rectangle {
                        visible: root.bugOpen
                        width: parent.width
                        height: Style.space(30)
                        radius: height / 2
                        color: Qt.rgba(0.95, 0.35, 0.25, 0.8)

                        Text {
                            anchors.centerIn: parent
                            text: "Copy bug report and open GitHub"
                            color: bg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.submitBug()
                        }
                    }
                }
            }
        }
        }
    }
}
