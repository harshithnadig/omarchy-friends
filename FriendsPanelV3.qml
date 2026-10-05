import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "."

KeyboardPanel {
    id: root

    // Omarchy's shared keyboard-panel layer is blurred by default. Give Friends
    // its own namespace so opening chat leaves the rest of the desktop crisp.
    layerNamespace: "omarchy-friends"

    property var hostWidget: null
    anchorItem: hostWidget && hostWidget.button ? hostWidget.button : null
    bar: hostWidget ? hostWidget.bar : null
    owner: hostWidget || root
    open: hostWidget ? hostWidget.cardOpen === true : false
    focusTarget: chatsNav

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

    // Resolve the canonical service from the shell when available. A private
    // fallback is only for panel hosts that don't expose plugin services.
    readonly property var service: hostWidget && hostWidget.service ? hostWidget.service : panelFallbackService
    readonly property var profile: service && service.profile ? service.profile : ({ handle: "Omarchy Builder", avatar: "👾", status_name: "Ready", status_emoji: "🚀", project_name: "", project_desc: "", project_url: "", interests: [], privacy: ({}) })
    readonly property var world: service && service.globalPeers ? service.globalPeers : []
    readonly property var typingPeers: service && service.globalTypingPeers ? service.globalTypingPeers : []
    readonly property var pings: service && service.globalPings ? service.globalPings : []
    readonly property var friendships: service && service.globalFriendships ? service.globalFriendships : ({})
    readonly property var messages: service && service.globalMessages ? service.globalMessages : []
    // Durable per-conversation counts are authoritative for chat existence;
    // latest-message summaries are intentionally compact and can be delayed.
    readonly property var messageCounts: service && service.globalMessageCounts ? service.globalMessageCounts : ({})
    readonly property var unreadCounts: service && service.globalUnreadCounts ? service.globalUnreadCounts : ({})
    readonly property var pinnedConversations: service && service.globalPinnedConversations ? service.globalPinnedConversations : []
    readonly property var mutedConversations: service && service.globalMutedConversations ? service.globalMutedConversations : []
    readonly property var groups: service && service.globalGroups ? service.globalGroups : []
    readonly property var community: service && service.globalCommunity ? service.globalCommunity : []
    property var communityMessageItems: []
    readonly property var memory: service && service.globalMemory ? service.globalMemory : ({})
    property var messageIndexSnapshot: null
    property var messagesByConversation: ({})
    property var latestMessageIndices: ({})
    property var chatFriendRows: []
    property var chatGroupRows: []
    readonly property var worldStatus: service && service.globalStatus ? service.globalStatus : ({ visible: false, online_count: 0, relay_count: 0, relay_total: 0, last_sync: 0, last_publish: 0, last_sync_age: "never", last_error: "" })
    property int statusNowSecond: Math.floor(Date.now() / 1000)
    readonly property int worldRelayCount: Number(root.worldStatus.relay_count || 0)
    readonly property int worldLastSync: Number(root.worldStatus.last_sync || 0)
    readonly property int worldLastPublish: Number(root.worldStatus.last_publish || 0)
    readonly property bool worldRelaysConnected: !root.worldStatus.last_error && root.worldLastSync > 0 && root.statusNowSecond >= root.worldLastSync && root.statusNowSecond - root.worldLastSync <= 180 && root.worldRelayCount > 0
    readonly property string globalConnectionText: {
        var relayError = String(root.worldStatus.last_error || "")
        if (relayError) {
            if (relayError.toLowerCase().indexOf("presence") >= 0) return "Presence not accepted"
            return root.worldRelayCount > 0 ? "Relay check failed" : "Offline"
        }
        if (root.worldLastSync <= 0) return "Checking relays"
        if (root.statusNowSecond < root.worldLastSync || root.statusNowSecond - root.worldLastSync > 180) return root.worldRelayCount > 0 ? "Reconnecting" : "Offline"
        return root.worldRelayCount > 0 ? "Connected to relays" : "No relay connection"
    }
    readonly property color globalConnectionColor: root.worldRelaysConnected ? root.success : (root.globalConnectionText === "Checking relays" ? root.mutedInk : root.warning)
    readonly property var updateInfo: service && service.updateInfo ? service.updateInfo : ({ available: false, current: "4.18.2", latest: "4.18.2" })
    readonly property string reportUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=bug&title=Omarchy%20Friends%20report"
    readonly property string featureIdeaUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=enhancement&title=Feature%20idea"
    readonly property string bugReportUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=bug&title=Omarchy%20Friends%20bug"

    property string page: "chats"
    property string requestTab: "received"
    property string chatQuery: ""
    property string searchTargetMessageId: ""
    property string indexedSearchQuery: ""
    property var indexedSearchMessages: null
    property var indexedSearchResults: null
    property var indexedSearchMatches: ({})
    property string worldQuery: ""
    property string worldFilter: "all"
    property string selectedFriendKey: ""
    property string selectedGroupId: ""
    property string messageDraft: ""
    property string typingRecipientKey: ""
    property bool typingSignalActive: false
    property double lastTypingSignalAt: 0
    property string mediaDraft: ""
    property var replyDraft: null
    property var editingMessage: null
    property var forwardDraft: null
    property int forwardTargetIndex: 0
    property bool forwardingMessage: false
    property bool savingMessageEdit: false
    property string attachmentDraftPath: ""
    property bool attachmentDraftIsFolder: false
    property bool reopenAfterAttachmentDialog: false
    property string privateSafetyCode: ""
    property string privateSafetyPeerHandle: ""
    property bool privateSafetyCodeLoading: false
    property bool syncingPrivateHistory: false
    property string draftConversationKey: ""
    property string draftAccountKey: ""
    property bool restoringComposerDraft: false
    property int pendingSendCount: 0
    property var optimisticMessages: []
    property bool creatingGroup: false
    property string communityDraft: ""
    property bool sendingCommunity: false
    property string notice: ""
    readonly property string uiFontFamily: "sans-serif"
    property bool newChatOpen: false
    property bool groupCreateOpen: false
    property string groupNameDraft: ""
    property var groupMemberKeys: []
    property string handleDraft: ""
    property string projectNameDraft: ""
    property string projectDescDraft: ""
    property string projectUrlDraft: ""
    property string blossomServerDraft: ""
    property var interestsDraft: []
    property bool serviceSignalsConnected: false
    // Keep this as a binding. A value captured when the panel first loads
    // misses status updates if the shell service becomes available afterward.
    readonly property int serviceStatusRevision: root.service ? root.service.statusRevision : 0

    function chatListEmptyState() {
        if (root.serviceStatusRevision > 0) return "empty"
        if (root.service && root.service.statusError) return "error"
        return "loading"
    }

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

    onServiceChanged: {
        connectServiceSignals()
        rebuildMessageSearchIndex()
        Qt.callLater(rebuildConversationRows)
    }

    onFriendshipsChanged: rebuildConversationRows()
    onMemoryChanged: rebuildConversationRows()
    onGroupsChanged: rebuildConversationRows()
    onPinnedConversationsChanged: rebuildConversationRows()
    onMutedConversationsChanged: rebuildConversationRows()
    onSelectedFriendKeyChanged: { rebuildConversationRows(); syncTypingPeer() }
    onSelectedGroupIdChanged: { rebuildConversationRows(); syncTypingPeer() }
    onPageChanged: syncTypingPeer()
    onCommunityChanged: updateCommunityMessageItems()
    onMessageDraftChanged: saveComposerDraft()
    onMediaDraftChanged: saveComposerDraft()
    onAttachmentDraftPathChanged: saveComposerDraft()
    onAttachmentDraftIsFolderChanged: saveComposerDraft()
    onReplyDraftChanged: saveComposerDraft()
    onEditingMessageChanged: saveComposerDraft()
    onMessagesChanged: {
        rebuildMessageIndex()
        rebuildMessageSearchIndex()
        rebuildConversationRows()
    }
    onMessageCountsChanged: {
        rebuildConversationRows()
        Qt.callLater(restoreConversationAfterStatusRefresh)
    }
    onProfileChanged: {
        if (root.draftConversationKey && root.draftAccountKey !== String(root.profile.public_key || ""))
            root.prepareDraftForConversation(root.draftConversationKey)
        rebuildMessageIndex()
        rebuildMessageSearchIndex()
        rebuildConversationRows()
        syncTypingPeer()
    }
    Component.onCompleted: {
        connectServiceSignals()
        rebuildMessageIndex()
        rebuildMessageSearchIndex()
        rebuildConversationRows()
        updateCommunityMessageItems()
    }

    function updateCommunityMessageItems() {
        var items = root.community || []
        var start = Math.max(0, items.length - 80)
        root.communityMessageItems = items.slice ? items.slice(start) : []
    }

    function worldPeer(publicKey) {
        for (var i = 0; i < root.world.length; i++) {
            if (root.world[i] && root.world[i].public_key === publicKey) return root.world[i]
        }
        return null
    }

    function selfPresenceIsLive() {
        return root.worldStatus.visible === true
            && root.worldRelaysConnected
            && root.worldLastPublish > 0
            && root.statusNowSecond >= root.worldLastPublish
            && root.statusNowSecond - root.worldLastPublish <= 150
    }

    function worldEmptyMessage() {
        if (root.world.length > 0)
            return "No people match your search or filters. Clear the search or choose All."
        if (root.globalConnectionText === "Checking relays")
            return "Connecting to your configured relays. World only lists real Friends users who are online, visible and reachable through a shared relay."
        if (root.globalConnectionText === "Presence not accepted")
            return "Your relays are reachable, but none confirmed your public World beacon. Retry or check relay status. New profiles are discoverable by default; existing privacy choices are preserved."
        if (root.globalConnectionText === "Relay check failed" || root.globalConnectionText === "Offline" || root.globalConnectionText === "Reconnecting" || root.globalConnectionText === "No relay connection")
            return "World needs a working relay connection to find people. Check your network and configured relays, then refresh. Your private chats stay available while World is offline."
        if (root.worldStatus.visible === false)
            return "Your profile is hidden from public discovery, but you can still browse World and use private chats. Turn on Visible in World in Me → Privacy, or copy your invite to connect directly."
        if (!root.selfPresenceIsLive())
            return "World visibility is on, but your latest beacon is not confirmed yet. Refresh and check relay status. Only your public profile beacon is shared; messages and chat history are never published here."
        return "Your profile is discoverable and its beacon is live. No other visible Friends users are online on your reachable relays right now. Copy your invite to bring someone in; they will appear when they are online."
    }

    function friendsList() {
        var out = []
        var included = ({})
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
            included[key] = true
        }

        // A saved DM thread is conversation history, even if the social
        // relationship later becomes pending or disappears from the relay.
        // Keep its peer in Chats so a friendship refresh can never make local
        // messages look deleted. This only synthesizes list metadata; it does
        // not change friendship state or message storage.
        var ownKey = root.profile && root.profile.public_key ? String(root.profile.public_key) : ""
        var unlinkedMessages = root.messagesByConversation["unlinked:local"] || []
        var hasUnlinkedMessages = unlinkedMessages.length > 0
        if (hasUnlinkedMessages && ownKey) {
            out.push({
                public_key: ownKey,
                handle: "Recovered messages",
                avatar: "🗃",
                legacy_archive: true,
                saved_history_only: true
            })
            included[ownKey] = true
        }
        if (Number(root.messageCounts["unlinked:local"] || 0) > 0 && ownKey && !included[ownKey]) {
            out.push({
                public_key: ownKey,
                handle: "Recovered messages",
                avatar: "🗃",
                legacy_archive: true,
                saved_history_only: true
            })
            included[ownKey] = true
        }
        for (var conversationKey in root.messagesByConversation) {
            if (conversationKey.indexOf("friend:") !== 0) continue
            var peerKey = conversationKey.slice(7)
            if (!/^[0-9a-f]{64}$/i.test(peerKey)
                || peerKey === ownKey
                || included[peerKey]) continue
            var conversationMessages = root.messagesByConversation[conversationKey]
            if (!Array.isArray(conversationMessages) || conversationMessages.length === 0) continue
            var message = conversationMessages[conversationMessages.length - 1]

            var savedFriend = root.friendships[peerKey] || ({})
            var savedMemory = root.memory[peerKey] || ({})
            var savedItem = Object.assign({}, savedFriend)
            savedItem.public_key = peerKey
            savedItem.handle = savedItem.handle || savedMemory.handle || message.handle || "Saved conversation"
            savedItem.avatar = savedItem.avatar || savedMemory.avatar || message.avatar || "👾"
            savedItem.saved_history_only = true
            out.push(savedItem)
            included[peerKey] = true
        }

        // Recover chat rows directly from the journal index so a partial or
        // late latest-message summary can never make a saved conversation
        // disappear from Chats.
        for (var conversationKey in root.messageCounts) {
            if (conversationKey.indexOf("friend:") !== 0) continue
            var indexedPeerKey = conversationKey.slice(7)
            if (!/^[0-9a-f]{64}$/i.test(indexedPeerKey)
                || indexedPeerKey === ownKey
                || included[indexedPeerKey]
                || Number(root.messageCounts[conversationKey] || 0) <= 0) continue

            var indexedFriend = root.friendships[indexedPeerKey] || ({})
            var indexedMemory = root.memory[indexedPeerKey] || ({})
            var indexedSummary = root.latestMessageForFriend(indexedPeerKey)
            var recoveredFriend = Object.assign({}, indexedFriend)
            recoveredFriend.public_key = indexedPeerKey
            recoveredFriend.handle = recoveredFriend.handle
                || indexedMemory.handle
                || (indexedSummary && indexedSummary.handle)
                || "Saved conversation"
            recoveredFriend.avatar = recoveredFriend.avatar
                || indexedMemory.avatar
                || (indexedSummary && indexedSummary.avatar)
                || "👾"
            recoveredFriend.saved_history_only = recoveredFriend.status !== "friends"
            out.push(recoveredFriend)
            included[indexedPeerKey] = true
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

    // Rebuild only from property change handlers, never during Repeater/Text
    // binding evaluation. The old lazy rebuild mutated dependencies while
    // conversationFriends() was calculating its model and hid saved chats.
    function rebuildMessageIndex() {
        var byConversation = ({})
        var lastIndex = ({})
        var ownKey = String(root.profile && root.profile.public_key || "")
        for (var i = 0; i < root.messages.length; i++) {
            var message = root.messages[i]
            if (!message) continue
            var key = ""
            if (message.group_id) key = "group:" + String(message.group_id)
            else if (message.legacy_unlinked === true
                || (!message.conversation_key && ownKey && String(message.public_key || "") === ownKey)) key = "unlinked:local"
            else key = "friend:" + String(message.conversation_key || message.public_key || "")
            if (key === "friend:") continue
            if (!byConversation[key]) byConversation[key] = []
            byConversation[key].push(message)
            lastIndex[key] = i
        }
        root.messagesByConversation = byConversation
        root.latestMessageIndices = lastIndex
        root.messageIndexSnapshot = root.messages
    }

    function messagesForConversation(kind, identifier) {
        var key = (kind === "group" ? "group:" : (kind === "unlinked" ? "unlinked:" : "friend:")) + String(identifier || "")
        return root.messagesByConversation[key] || []
    }

    function directHasHistory(publicKey) {
        if (root.profile && String(publicKey || "") === String(root.profile.public_key || ""))
            return root.messagesForConversation("unlinked", "local").length > 0
        return root.messagesForConversation("friend", publicKey).length > 0
    }

    function directHasConversationRecord(publicKey) {
        if (root.directHasHistory(publicKey)) return true
        if (Number(root.messageCounts["friend:" + String(publicKey || "")] || 0) > 0) return true
        var item = root.memory[publicKey] || ({})
        return Number(item.dms_sent || 0) > 0 || Number(item.dms_received || 0) > 0
    }

    function hasMorePrivateHistoryPages(publicKey) {
        if (!root.service || !root.directHasConversationRecord(publicKey)) return false
        var relays = root.service.globalPrivateHistoryRelays || []
        var cursors = root.service.globalPrivateHistoryCursors || ({})
        for (var i = 0; i < relays.length; i++) {
            var cursor = cursors[relays[i]]
            if (!cursor || cursor.done !== true) return true
        }
        return false
    }

    function selectedFriendHistoryMissing() {
        var friend = root.selectedFriend()
        return !!(friend && !friend.legacy_archive
            && root.directHasConversationRecord(friend.public_key)
            && !root.directHasHistory(friend.public_key))
    }

    function groupHasHistory(groupId) {
        return root.messagesForConversation("group", groupId).length > 0
    }

    function lastMessageIndexForFriend(publicKey) {
        var index = root.profile && String(publicKey || "") === String(root.profile.public_key || "")
            ? root.latestMessageIndices["unlinked:local"]
            : root.latestMessageIndices["friend:" + String(publicKey || "")]
        return index === undefined ? -1 : index
    }

    function latestMessageForFriend(publicKey) {
        var index = root.lastMessageIndexForFriend(publicKey)
        return index >= 0 && index < root.messages.length ? root.messages[index] : null
    }

    function lastMessageIndexForGroup(groupId) {
        var index = root.latestMessageIndices["group:" + String(groupId || "")]
        return index === undefined ? -1 : index
    }

    function searchableMessageText(message) {
        if (!message || message.deleted) return ""
        var parts = [message.text || ""]
        if (message.reply_to) parts.push(message.reply_to.text || "")
        var media = Array.isArray(message.media) ? message.media : []
        for (var i = 0; i < media.length; i++) if (media[i]) parts.push(media[i].url || media[i].href || "")
        var attachments = Array.isArray(message.attachments) ? message.attachments : []
        for (var j = 0; j < attachments.length; j++) if (attachments[j]) parts.push(attachments[j].name || "")
        return parts.join(" ").toLowerCase()
    }

    // Called only from property/signal handlers. QML bindings in the chat
    // Repeater must never write back into properties while deriving its model.
    function rebuildMessageSearchIndex() {
        var query = root.chatQuery.trim().toLowerCase()
        var messages = root.messages
        var remoteResults = root.service && root.service.globalSearchResults ? root.service.globalSearchResults : []
        if (root.indexedSearchQuery === query && root.indexedSearchMessages === messages && root.indexedSearchResults === remoteResults) return root.indexedSearchMatches
        var matches = ({})
        if (query) {
            for (var r = 0; r < remoteResults.length; r++) {
                var result = remoteResults[r]
                if (!result || !result.id || root.searchableMessageText(result).indexOf(query) < 0) continue
                var resultKey = result.group_id ? "group:" + result.group_id : (result.legacy_unlinked === true ? "unlinked:local" : "friend:" + (result.conversation_key || result.public_key))
                if (!matches[resultKey]) matches[resultKey] = result
            }
            for (var i = root.messages.length - 1; i >= 0; i--) {
                var message = root.messages[i]
                if (!message || !message.id || root.searchableMessageText(message).indexOf(query) < 0) continue
                var key = message.group_id ? "group:" + message.group_id : (message.legacy_unlinked === true ? "unlinked:local" : "friend:" + (message.conversation_key || message.public_key))
                if (!matches[key]) matches[key] = message
            }
        }
        root.indexedSearchQuery = query
        root.indexedSearchMessages = messages
        root.indexedSearchResults = remoteResults
        root.indexedSearchMatches = matches
    }

    function messageSearchIndex() {
        return root.indexedSearchMatches || ({})
    }

    function latestMessageMatchForFriend(publicKey) {
        if (root.profile && String(publicKey || "") === String(root.profile.public_key || ""))
            return root.messageSearchIndex()["unlinked:local"] || null
        return root.messageSearchIndex()["friend:" + publicKey] || null
    }

    function latestMessageMatchForGroup(groupId) {
        return root.messageSearchIndex()["group:" + groupId] || null
    }

    function conversationFriends() {
        // Derive the visible model from the current service snapshot. A
        // cached array can stay empty if the shared service registers or
        // publishes its first status after this panel's change handlers ran.
        return root.buildConversationFriends()
    }

    function buildConversationFriends() {
        var q = root.chatQuery.trim().toLowerCase()
        var out = []
        var included = ({})
        var list = root.friendsList()
        for (var i = 0; i < list.length; i++) {
            var friend = list[i]
            // Persistent DM activity and locally saved messages both keep a
            // thread in Chats, even when relay history is no longer available.
            // Recovered unlinked messages use the owner's key as a local
            // archive, so they have no friend DM memory to satisfy the normal
            // conversation predicate. Keep that archive visible in Chats.
            var active = friend.legacy_archive === true || root.directHasConversationRecord(friend.public_key) || root.selectedFriendKey === friend.public_key
            if (!active) continue
            var hay = ((friend.handle || "") + " " + root.lastMessagePreview(friend.public_key)).toLowerCase()
            if (!q || hay.indexOf(q) >= 0 || root.latestMessageMatchForFriend(friend.public_key)) {
                out.push(friend)
                included[String(friend.public_key)] = true
            }
        }
        // The encrypted journal index is the durable source of truth. Keep
        // those threads visible even if friendship metadata or message
        // summaries are temporarily unavailable during startup/reload.
        var ownKey = String(root.profile && root.profile.public_key || "")
        for (var conversationKey in root.messageCounts) {
            if (conversationKey.indexOf("friend:") !== 0) continue
            var peerKey = conversationKey.slice(7)
            if (!/^[0-9a-f]{64}$/i.test(peerKey) || peerKey === ownKey
                || included[peerKey] || Number(root.messageCounts[conversationKey] || 0) <= 0) continue
            var saved = root.friendships[peerKey] || ({})
            var savedMemory = root.memory[peerKey] || ({})
            var preview = root.latestMessageForFriend(peerKey)
            var recovered = Object.assign({}, saved)
            recovered.public_key = peerKey
            recovered.handle = recovered.handle || savedMemory.handle || (preview && preview.handle) || "Saved conversation"
            recovered.avatar = recovered.avatar || savedMemory.avatar || (preview && preview.avatar) || "👾"
            recovered.saved_history_only = recovered.status !== "friends"
            var recoveredHay = (recovered.handle + " " + root.lastMessagePreview(peerKey)).toLowerCase()
            if (!q || recoveredHay.indexOf(q) >= 0 || root.latestMessageMatchForFriend(peerKey)) out.push(recovered)
            included[peerKey] = true
        }
        out.sort(function(a, b) {
            var aPinned = root.isConversationPinned("friend", a.public_key)
            var bPinned = root.isConversationPinned("friend", b.public_key)
            return aPinned !== bPinned ? (aPinned ? -1 : 1) : root.lastMessageIndexForFriend(b.public_key) - root.lastMessageIndexForFriend(a.public_key)
        })
        return out
    }

    function allConversationFriends() {
        var rows = root.conversationFriends()
        if (!root.chatQuery.trim()) return rows
        var query = root.chatQuery.trim().toLowerCase()
        var included = ({})
        for (var i = 0; i < rows.length; i++) included[String(rows[i].public_key || "")] = true
        // Search results are paged for message display, but the saved local
        // conversation index is complete. Recover old chat rows from it so
        // a recent-message page limit never makes a conversation disappear.
        for (var key in root.messageCounts) {
            if (key.indexOf("friend:") !== 0) continue
            var publicKey = key.slice(7)
            if (!/^[0-9a-f]{64}$/i.test(publicKey) || included[publicKey]
                || Number(root.messageCounts[key] || 0) <= 0) continue
            var friend = root.friendships[publicKey] || ({})
            var saved = root.memory[publicKey] || ({})
            var handle = friend.handle || saved.handle || "Saved conversation"
            var latest = root.latestMessageForFriend(publicKey)
            var preview = latest ? String(latest.text || "") : ""
            if ((handle + " " + preview).toLowerCase().indexOf(query) < 0
                && !root.latestMessageMatchForFriend(publicKey)) continue
            var recovered = Object.assign({}, friend)
            recovered.public_key = publicKey
            recovered.handle = handle
            recovered.avatar = recovered.avatar || saved.avatar || "👾"
            recovered.saved_history_only = recovered.status !== "friends"
            rows.push(recovered)
            included[publicKey] = true
        }
        return rows
    }

    function conversationGroups() {
        return root.buildConversationGroups()
    }

    function buildConversationGroups() {
        var q = root.chatQuery.trim().toLowerCase()
        var out = []
        var included = ({})
        var list = root.groupsList()
        for (var i = 0; i < list.length; i++) {
            var group = list[i]
            // A private group is itself a conversation. Keep joined/created
            // groups visible even before anyone sends the first message.
            if (!q || (group.name || "Private group").toLowerCase().indexOf(q) >= 0 || root.latestMessageMatchForGroup(group.id)) {
                out.push(group)
                included[String(group.id)] = true
            }
        }
        for (var conversationKey in root.messageCounts) {
            if (conversationKey.indexOf("group:") !== 0) continue
            var groupId = conversationKey.slice(6)
            if (!groupId || included[groupId] || Number(root.messageCounts[conversationKey] || 0) <= 0) continue
            var summary = root.latestMessageMatchForGroup(groupId)
            var recoveredGroup = { id: groupId, name: summary && summary.group_name ? summary.group_name : "Saved group", saved_history_only: true }
            if (!q || recoveredGroup.name.toLowerCase().indexOf(q) >= 0 || summary) out.push(recoveredGroup)
        }
        out.sort(function(a, b) {
            var aPinned = root.isConversationPinned("group", a.id)
            var bPinned = root.isConversationPinned("group", b.id)
            return aPinned !== bPinned ? (aPinned ? -1 : 1) : root.lastMessageIndexForGroup(b.id) - root.lastMessageIndexForGroup(a.id)
        })
        return out
    }

    function rebuildConversationRows() {
        root.chatFriendRows = root.buildConversationFriends()
        root.chatGroupRows = root.buildConversationGroups()
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

    function isFriendTyping(publicKey) {
        return !!publicKey && root.typingPeers.indexOf(String(publicKey).toLowerCase()) >= 0
    }

    function syncTypingPeer() {
        var friend = root.selectedFriend()
        var key = root.page === "chats" && friend && !friend.legacy_archive ? String(friend.public_key || "").toLowerCase() : ""
        if (!root.profile.privacy || root.profile.privacy.share_typing !== true) root.stopTypingSignal()
        if (root.typingRecipientKey && root.typingRecipientKey !== key) root.stopTypingSignal()
        if (root.service && root.service.setTypingPeer) root.service.setTypingPeer(key)
    }

    function stopTypingSignal() {
        if (root.typingSignalActive && root.typingRecipientKey && root.service)
            root.service.sendTyping(root.typingRecipientKey, "paused")
        root.typingSignalActive = false
        root.typingRecipientKey = ""
        typingIdleTimer.stop()
    }

    function updateTypingSignal(text) {
        if (!root.service || !root.profile.privacy || root.profile.privacy.share_typing !== true || root.editingMessage) {
            root.stopTypingSignal()
            return
        }
        var friend = root.selectedFriend()
        if (!friend || friend.legacy_archive || root.selectedGroup() || root.page !== "chats") {
            root.stopTypingSignal()
            return
        }
        var key = String(friend.public_key || "").toLowerCase()
        if (!/^[0-9a-f]{64}$/.test(key)) return
        if (root.typingRecipientKey && root.typingRecipientKey !== key) root.stopTypingSignal()
        if (!String(text || "").trim()) {
            root.stopTypingSignal()
            return
        }
        root.typingRecipientKey = key
        var now = Date.now()
        if (!root.typingSignalActive || now - root.lastTypingSignalAt >= 4000) {
            root.service.sendTyping(key, "typing")
            root.lastTypingSignalAt = now
            root.typingSignalActive = true
        }
        typingIdleTimer.restart()
    }

    function conversationMessages() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        if (!friend && !group) return []
        var historyKind = group ? "group" : (friend.legacy_archive ? "unlinked" : "friend")
        var historyId = group ? group.id : (friend.legacy_archive ? "local" : friend.public_key)
        var out = root.messagesForConversation(historyKind, historyId).slice()
        var savedById = ({})
        for (var i = 0; i < out.length; i++) if (out[i].id) savedById[String(out[i].id)] = true
        var pending = root.optimisticMessages.slice()
        var matchedSavedIds = ({})
        for (var p = 0; p < pending.length; p++) {
            var local = pending[p]
            if ((group && local.group_id !== group.id) || (friend && (local.group_id || local.public_key !== friend.public_key))) continue
            var savedMatch = false
            // A send result can arrive before or after its relay echo, and a
            // partial group send is still saved locally for retry. Reconcile
            // every server-backed optimistic bubble by its event ID.
            var sentId = local.serverMessageId ? String(local.serverMessageId) : ""
            if (sentId && savedById[sentId] && !matchedSavedIds[sentId]) {
                matchedSavedIds[sentId] = true
                savedMatch = true
            }
            if (!savedMatch) out.push(local)
        }
        return out
    }

    function loadEarlierMessages() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        if (!root.service || (!friend && !group)) return
        var kind = group ? "group" : (friend.legacy_archive ? "unlinked" : "friend")
        var identifier = group ? group.id : (friend.legacy_archive ? "local" : friend.public_key)
        if (!root.service.canLoadEarlierMessages(kind, identifier)) return
        var oldHeight = messageScroller.contentHeight
        var oldContentY = messageScroller.contentY
        root.service.loadConversationHistory(kind, identifier, root.service.activeHistoryNextOffset, function(ok) {
            if (!ok) {
                root.showNotice("Could not load earlier messages")
                return
            }
            Qt.callLater(function() {
                if (messageScroller) messageScroller.contentY = Math.max(0, oldContentY + messageScroller.contentHeight - oldHeight)
            })
        })
    }

    function hasEarlierMessages() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        return root.service && (friend || group)
            ? root.service.canLoadEarlierMessages(group ? "group" : (friend.legacy_archive ? "unlinked" : "friend"), group ? group.id : (friend.legacy_archive ? "local" : friend.public_key))
            : false
    }

    function reactionSummary(message) {
        var counts = ({})
        var rows = message && Array.isArray(message.reactions) ? message.reactions : []
        for (var i = 0; i < rows.length; i++) {
            var emoji = String(rows[i].emoji || "")
            if (!emoji) continue
            counts[emoji] = (counts[emoji] || 0) + 1
        }
        var result = []
        for (var key in counts) result.push({ emoji: key, count: counts[key] })
        return result
    }

    function myReaction(message) {
        var rows = message && Array.isArray(message.reactions) ? message.reactions : []
        var ownKey = String(root.profile.public_key || "")
        for (var i = 0; i < rows.length; i++) if (rows[i].public_key === ownKey) return String(rows[i].emoji || "")
        return ""
    }

    function unreadCount(kind, identifier) {
        var key = String(kind || "") + ":" + String(identifier || "")
        return Math.max(0, Number(root.unreadCounts[key] || 0))
    }

    function isConversationPinned(kind, identifier) {
        return root.pinnedConversations.indexOf(String(kind) + ":" + String(identifier)) >= 0
    }

    function isConversationMuted(kind, identifier) {
        return root.mutedConversations.indexOf(String(kind) + ":" + String(identifier)) >= 0
    }

    function toggleSelectedConversationPin() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        if (!root.service || (!friend && !group)) return
        var kind = group ? "group" : "friend"
        var identifier = group ? group.id : friend.public_key
        root.service.setConversationPinned(kind, identifier, !root.isConversationPinned(kind, identifier))
    }

    function toggleSelectedConversationMute() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        if (!root.service || (!friend && !group)) return
        var kind = group ? "group" : "friend"
        var identifier = group ? group.id : friend.public_key
        root.service.setConversationMuted(kind, identifier, !root.isConversationMuted(kind, identifier))
    }

    function reactToMessage(message, emoji) {
        if (!message || !root.service) return
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        root.service.reactToMessage(message.id, friend ? friend.public_key : "", group ? group.id : "", emoji)
    }

    function deleteMessage(message) {
        if (!message || message.deleted || message.incoming || (message.sendState && message.sendState !== "Sent") || !root.service) return
        root.service.deleteMessage(message.id)
    }

    function canEditMessage(message) {
        if (!message || message.legacy_unlinked || message.deleted || message.incoming || (message.sendState && message.sendState !== "Sent")) return false
        if (String(message.id || "").indexOf("local_") === 0 || !String(message.text || "").trim()) return false
        if ((message.attachments && message.attachments.length) || (message.media && message.media.length)) return false
        var age = Math.floor(Date.now() / 1000) - Number(message.timestamp || 0)
        return age >= 0 && age <= 15 * 60
    }

    function beginMessageEdit(message) {
        if (!root.canEditMessage(message)) return
        if (root.messageDraft.trim() || root.attachmentDraftPath || root.replyDraft) {
            root.showNotice("Finish or clear your current draft before editing")
            return
        }
        root.editingMessage = { id: String(message.id), text: String(message.text || "") }
        root.savingMessageEdit = false
        root.messageDraft = root.editingMessage.text
        if (messageInput) messageInput.forceActiveFocus()
    }

    function lastMessagePreview(publicKey) {
        if (root.profile && String(publicKey) === String(root.profile.public_key || "")) return "Recovered history · recipient unavailable"
        var match = root.latestMessageMatchForFriend(publicKey)
        if (match) return "Match · " + (match.text || (match.attachments && match.attachments.length ? match.attachments[0].name : "Shared link"))
        var history = root.messagesForConversation("friend", publicKey)
        if (history.length > 0) {
            var m = history[history.length - 1]
            var t = m.text || "Shared a link"
            return (m.incoming ? "" : "You · ") + t
        }
        if (root.directHasConversationRecord(publicKey)) return "Older chat history is missing on this device"
        return "Start a private chat"
    }

    function groupLastMessagePreview(groupId) {
        var match = root.latestMessageMatchForGroup(groupId)
        if (match) return "Match · " + (match.text || (match.attachments && match.attachments.length ? match.attachments[0].name : "Shared link"))
        var history = root.messagesForConversation("group", groupId)
        if (history.length > 0) {
            var m = history[history.length - 1]
            return (m.incoming ? "" : "You · ") + (m.text || "Shared a link")
        }
        return "Start the group conversation"
    }

    function composerDraftKey(key) {
        return String(root.profile.public_key || "") + ":" + key
    }

    function saveComposerDraft() {
        if (root.restoringComposerDraft || !root.draftConversationKey || !root.service) return
        var drafts = Object.assign({}, root.service.conversationDrafts || ({}))
        var key = root.draftAccountKey + ":" + root.draftConversationKey
        if (root.messageDraft || root.mediaDraft || root.attachmentDraftPath || root.replyDraft || root.editingMessage) {
            drafts[key] = {
                text: root.messageDraft, media: root.mediaDraft,
                attachmentPath: root.attachmentDraftPath,
                attachmentIsFolder: root.attachmentDraftIsFolder,
                reply: root.replyDraft, edit: root.editingMessage
            }
        } else delete drafts[key]
        root.service.conversationDrafts = drafts
    }

    function prepareDraftForConversation(key) {
        var accountKey = String(root.profile.public_key || "")
        if (root.draftConversationKey === key && root.draftAccountKey === accountKey) return
        root.saveComposerDraft()
        var drafts = root.service ? root.service.conversationDrafts || ({}) : ({})
        var draft = drafts[root.composerDraftKey(key)] || ({})
        // Property handlers run synchronously: prevent partial restoration
        // from overwriting the saved contents of either conversation.
        root.restoringComposerDraft = true
        root.draftConversationKey = key
        root.draftAccountKey = accountKey
        root.messageDraft = draft.text || ""
        root.mediaDraft = draft.media || ""
        root.attachmentDraftPath = draft.attachmentPath || ""
        root.attachmentDraftIsFolder = draft.attachmentIsFolder === true
        root.replyDraft = draft.reply || null
        root.editingMessage = draft.edit || null
        root.restoringComposerDraft = false
    }

    function startReply(message) {
        if (!message || !message.id || String(message.id).indexOf("local_") === 0) {
            root.showNotice("Wait for this message to finish sending before replying")
            return
        }
        root.replyDraft = {
            id: String(message.id),
            handle: String(message.handle || (message.incoming ? "Friend" : "You")),
            text: String(message.text || "Attachment").slice(0, 240)
        }
        if (messageInput) messageInput.forceActiveFocus()
    }

    function beginForward(message) {
        if (!message || message.deleted || !/^[0-9a-f]{64}$/i.test(String(message.id || ""))) {
            root.showNotice("Choose a saved message to forward")
            return
        }
        root.forwardDraft = { messageId: String(message.id) }
        root.forwardTargetIndex = 0
        root.forwardDialog.open()
    }

    function forwardTargets() {
        var out = []
        var friends = root.friendsList()
        for (var i = 0; i < friends.length; i++) {
            if (friends[i].legacy_archive) continue
            out.push({ kind: "friend", id: friends[i].public_key, label: friends[i].handle || "Friend" })
        }
        var groups = root.groupsList()
        for (var j = 0; j < groups.length; j++) {
            out.push({ kind: "group", id: groups[j].id, label: groups[j].name || "Private group" })
        }
        return out
    }

    function forwardToSelectedTarget() {
        if (!root.forwardDraft || root.forwardingMessage || !root.service) return
        var targets = root.forwardTargets()
        if (root.forwardTargetIndex < 0 || root.forwardTargetIndex >= targets.length) return
        var target = targets[root.forwardTargetIndex]
        root.forwardingMessage = true
        function onForwarded(ok, result) {
            root.forwardingMessage = false
            if (ok || (result && result.message_id)) {
                root.forwardDialog.close()
                root.forwardDraft = null
            }
            var notice = ok ? "Message forwarded"
                : (result && result.message ? result.message : "Forward was not confirmed; check the target chat before retrying")
            root.showNotice(notice)
            if (ok && target.kind === "friend") {
                for (var i = 0; i < root.friendsList().length; i++) {
                    if (root.friendsList()[i].public_key === target.id) { root.chooseFriend(root.friendsList()[i]); break }
                }
            } else if (ok && target.kind === "group") {
                for (var j = 0; j < root.groupsList().length; j++) {
                    if (root.groupsList()[j].id === target.id) { root.chooseGroup(root.groupsList()[j]); break }
                }
            }
        }
        root.service.forwardMessage(root.forwardDraft.messageId, target.kind, target.id, onForwarded)
    }

    function chooseFriend(friend, keepSearchTarget, historyOffset) {
        if (keepSearchTarget !== true) root.searchTargetMessageId = ""
        var isLegacyArchive = friend && friend.legacy_archive === true
        var historyKind = isLegacyArchive ? "unlinked" : "friend"
        var historyId = isLegacyArchive ? "local" : (friend && friend.public_key ? friend.public_key : "")
        root.prepareDraftForConversation(isLegacyArchive ? "unlinked:local" : "friend:" + historyId)
        root.selectedFriendKey = friend && friend.public_key ? friend.public_key : ""
        root.selectedGroupId = ""
        root.page = "chats"
        root.newChatOpen = false
        if (root.service && root.selectedFriendKey && !isLegacyArchive) root.service.markConversationRead("friend", root.selectedFriendKey)
        if (root.service && root.selectedFriendKey) {
            var targetOffset = historyOffset === undefined ? 0 : Math.max(0, Number(historyOffset))
            root.service.loadConversationHistory(historyKind, historyId, targetOffset, function(ok) {
                if (ok && root.searchTargetMessageId) Qt.callLater(root.scrollToSearchTarget)
            })
        }
        var focusKey = root.draftConversationKey
        Qt.callLater(function() {
            if (root.visible && root.page === "chats" && root.draftConversationKey === focusKey && messageInput)
                messageInput.forceActiveFocus()
        })
    }

    function openFriendSearchResult(friend) {
        var match = friend ? root.latestMessageMatchForFriend(friend.public_key) : null
        root.searchTargetMessageId = match ? String(match.id || "") : ""
        var offset = match ? Math.max(0, Number(match.history_offset || 0) - 40) : 0
        root.chooseFriend(friend, true, offset)
    }

    function chooseGroup(group, keepSearchTarget, historyOffset) {
        if (keepSearchTarget !== true) root.searchTargetMessageId = ""
        root.prepareDraftForConversation("group:" + (group && group.id ? group.id : ""))
        root.selectedGroupId = group && group.id ? group.id : ""
        root.selectedFriendKey = ""
        root.page = "chats"
        root.newChatOpen = false
        if (root.service && root.selectedGroupId) root.service.markConversationRead("group", root.selectedGroupId)
        if (root.service && root.selectedGroupId) {
            var targetOffset = historyOffset === undefined ? 0 : Math.max(0, Number(historyOffset))
            root.service.loadConversationHistory("group", root.selectedGroupId, targetOffset, function(ok) {
                if (ok && root.searchTargetMessageId) Qt.callLater(root.scrollToSearchTarget)
            })
        }
        var focusKey = root.draftConversationKey
        Qt.callLater(function() {
            if (root.visible && root.page === "chats" && root.draftConversationKey === focusKey && messageInput)
                messageInput.forceActiveFocus()
        })
    }

    function openGroupSearchResult(group) {
        var match = group ? root.latestMessageMatchForGroup(group.id) : null
        root.searchTargetMessageId = match ? String(match.id || "") : ""
        var offset = match ? Math.max(0, Number(match.history_offset || 0) - 40) : 0
        root.chooseGroup(group, true, offset)
    }

    function scrollToSearchTarget() {
        if (!root.searchTargetMessageId || !messageRepeater) return
        for (var i = 0; i < messageRepeater.count; i++) {
            var item = messageRepeater.itemAt(i)
            if (item && item.modelData && String(item.modelData.id || "") === root.searchTargetMessageId) {
                messageScroller.contentY = Math.max(0, Math.min(item.y, messageScroller.contentHeight - messageScroller.height))
                return
            }
        }
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

    function stageAttachment(url, isFolder) {
        var localPath = String(url || "")
        if (localPath.indexOf("/") !== 0) {
            root.showNotice("Choose a local file or folder")
            return
        }
        if (isFolder) localPath = localPath.replace(/\/+$/, "") || "/"
        root.attachmentDraftPath = localPath
        root.attachmentDraftIsFolder = isFolder === true
        var routeHint = "Up to 16 KiB sends directly; larger files need Me → Large files (up to 100 MiB)."
        root.showNotice((root.attachmentDraftIsFolder ? "Folder ready; ZIP size is checked on send. " : "File ready. ") + routeHint)
    }

    function openAttachmentBrowser(folderMode) {
        attachmentMenu.close()
        root.reopenAfterAttachmentDialog = root.open && root.hostWidget !== null
        if (!root.service || typeof root.service.pickAttachment !== "function") {
            root.finishAttachmentBrowser("", folderMode === true)
            root.showNotice("The desktop file chooser is unavailable")
            return
        }
        // Friends is a full-screen Hyprland overlay layer. A desktop chooser
        // cannot reliably raise above it. Close the owner first, then launch
        // the portal on the next event-loop turn so the overlay has released
        // focus and pointer ownership.
        if (root.reopenAfterAttachmentDialog) root.hostWidget.close()
        Qt.callLater(function() {
            root.service.pickAttachment(folderMode === true, function(result) {
                if (result && result.ok && result.path)
                    root.finishAttachmentBrowser(result.path, folderMode === true)
                else {
                    root.finishAttachmentBrowser("", folderMode === true)
                    if (result && !result.ok)
                        root.showNotice(result.message || "Could not open the desktop file chooser")
                }
            })
        })
    }

    function finishAttachmentBrowser(path, isFolder) {
        if (path) root.stageAttachment(path, isFolder)
        var shouldReopen = root.reopenAfterAttachmentDialog
        root.reopenAfterAttachmentDialog = false
        if (shouldReopen && root.hostWidget) Qt.callLater(function() { root.hostWidget.open() })
    }

    function syncEarlierMessages() {
        var friend = root.selectedFriend()
        if (!friend || friend.legacy_archive || !root.service || root.syncingPrivateHistory) return
        root.syncingPrivateHistory = true
        var friendKey = String(friend.public_key || "")
        root.service.syncPrivateHistory(function(ok) {
            root.syncingPrivateHistory = false
            if (ok && root.selectedFriendKey === friendKey)
                root.service.loadConversationHistory("friend", friendKey, 0)
        })
    }

    function openPrivateSafetyCode(friend) {
        if (!friend || !friend.public_key || !root.service) {
            root.showNotice("Select a friend to verify")
            return
        }
        root.privateSafetyCode = ""
        root.privateSafetyPeerHandle = friend.handle || "Friend"
        root.privateSafetyCodeLoading = true
        privateSafetyDialog.open()
        root.service.getPrivateSafetyCode(friend.public_key, function(result) {
            root.privateSafetyCodeLoading = false
            root.privateSafetyCode = result && result.ok ? String(result.safety_code || "") : ""
        })
    }

    function copyPrivateSafetyCode() {
        if (!root.privateSafetyCode) return
        Quickshell.execDetached(["wl-copy", root.privateSafetyCode.replace(/\s+/g, "")])
        root.showNotice("Safety code copied")
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

    function restoreConversationAfterStatusRefresh() {
        // The panel can open before the shared service has finished reading
        // the saved state. Restore a chat only after a successful status
        // refresh, and only when the user has not already selected one.
        // Avoid chooseFriend()/chooseGroup() here: those mark the thread read.
        if (!root.open || root.page !== "chats" || root.selectedFriend() || root.selectedGroup()) return
        var fs = root.conversationFriends()
        var gs = root.conversationGroups()
        if (fs.length > 0 && gs.length > 0) {
            if (root.lastMessageIndexForFriend(fs[0].public_key) >= root.lastMessageIndexForGroup(gs[0].id)) {
                root.prepareDraftForConversation(fs[0].legacy_archive ? "unlinked:local" : "friend:" + fs[0].public_key)
                root.selectedFriendKey = fs[0].public_key
                root.selectedGroupId = ""
            } else {
                root.prepareDraftForConversation("group:" + gs[0].id)
                root.selectedGroupId = gs[0].id
                root.selectedFriendKey = ""
            }
        } else if (fs.length > 0) {
            root.prepareDraftForConversation(fs[0].legacy_archive ? "unlinked:local" : "friend:" + fs[0].public_key)
            root.selectedFriendKey = fs[0].public_key
            root.selectedGroupId = ""
        } else if (gs.length > 0) {
            root.prepareDraftForConversation("group:" + gs[0].id)
            root.selectedGroupId = gs[0].id
            root.selectedFriendKey = ""
        }
        if (root.service && root.selectedFriendKey) {
            var restored = root.selectedFriend()
            root.service.loadConversationHistory(restored && restored.legacy_archive ? "unlinked" : "friend", restored && restored.legacy_archive ? "local" : root.selectedFriendKey, 0)
        }
        else if (root.service && root.selectedGroupId)
            root.service.loadConversationHistory("group", root.selectedGroupId, 0)
    }

    function sendMessage() {
        var friend = root.selectedFriend()
        var group = root.selectedGroup()
        var text = root.messageDraft.trim()
        var media = root.mediaDraft.trim()
        var attachmentPath = root.attachmentDraftPath
        var attachmentIsFolder = root.attachmentDraftIsFolder
        var reply = root.replyDraft ? Object.assign({}, root.replyDraft) : null
        if (!root.service || (!friend && !group)) { root.showNotice("Choose a conversation first"); return }
        if (friend && friend.legacy_archive) { root.showNotice("These saved messages have no recipient record and are read-only"); return }
        if (root.editingMessage) {
            if (root.savingMessageEdit) return
            if (!text) { root.showNotice("An edited message cannot be empty"); return }
            var editTarget = root.editingMessage
            root.savingMessageEdit = true
            root.service.editMessage(editTarget.id, text, function(ok) {
                root.savingMessageEdit = false
                if (ok && root.editingMessage && root.editingMessage.id === editTarget.id) {
                    root.editingMessage = null
                    root.messageDraft = ""
                }
            })
            return
        }
        if (!text && !media && !attachmentPath) return
        root.stopTypingSignal()
        var conversationKey = root.draftConversationKey
        root.pendingSendCount += 1
        var optimistic = {
            id: "local_" + Date.now() + "_" + Math.random().toString(16).slice(2), public_key: friend ? friend.public_key : root.profile.public_key,
            group_id: group ? group.id : "", group_name: group ? group.name : "",
            handle: root.profile.handle || "You", text: text, media: media ? [{ url: media, kind: "link" }] : [],
            attachments: attachmentPath ? [{ name: attachmentPath.split("/").pop() + (attachmentIsFolder ? ".zip" : ""), is_archive: attachmentIsFolder }] : [], incoming: false,
            reply_to: reply,
            timestamp: Math.floor(Date.now() / 1000), sendState: "Sending…"
        }
        root.optimisticMessages = root.optimisticMessages.concat([optimistic])
        // Let the user keep typing while the relay confirms this message.
        // The optimistic bubble already preserves exactly what was sent.
        if (root.draftConversationKey === conversationKey && root.messageDraft.trim() === text && root.mediaDraft.trim() === media && root.attachmentDraftPath === attachmentPath) {
            root.messageDraft = ""
            root.mediaDraft = ""
            root.attachmentDraftPath = ""
            root.attachmentDraftIsFolder = false
            root.replyDraft = null
        }
        function clearSentDraft(ok) {
            var result = arguments.length > 1 ? arguments[1] : null
            var serverMessageId = result && result.message_id ? String(result.message_id) : ""
            root.pendingSendCount = Math.max(0, root.pendingSendCount - 1)
            var canRestoreDraft = !ok && !serverMessageId && root.draftConversationKey === conversationKey && !root.messageDraft.trim() && !root.mediaDraft.trim() && !root.attachmentDraftPath && !root.replyDraft
            var remaining = []
            for (var i = 0; i < root.optimisticMessages.length; i++) {
                var item = root.optimisticMessages[i]
                if (item.id !== optimistic.id) remaining.push(item)
                else if (serverMessageId) remaining.push(Object.assign({}, item, {
                    id: serverMessageId,
                    serverMessageId: serverMessageId,
                    sendState: ok ? "Sent" : (result.send_state || "Unconfirmed · retry")
                }))
                else if (ok) remaining.push(Object.assign({}, item, { sendState: "Sent" }))
                else if (!canRestoreDraft) { item.sendState = "Not sent · message kept here"; remaining.push(item) }
            }
            root.optimisticMessages = remaining
            if (!ok) {
                // Restore a failed send only if the user has not started a
                // newer draft in the same conversation.
                if (serverMessageId) {
                    root.showNotice("Message is saved with retry available; check the chat before retrying")
                } else if (canRestoreDraft) {
                    root.messageDraft = text
                    root.mediaDraft = media
                    root.attachmentDraftPath = attachmentPath
                    root.attachmentDraftIsFolder = attachmentIsFolder
                    root.replyDraft = reply
                    root.showNotice("Message was not confirmed; your draft was restored")
                } else root.showNotice("Message was not confirmed; check the chat before retrying")
            }
        }
        if (group) root.service.sendGroupMessage(group.id, text, media, clearSentDraft, attachmentPath, attachmentIsFolder, reply)
        else root.service.sendDm(friend.public_key, text, media, clearSentDraft, attachmentPath, attachmentIsFolder, reply)
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
        if (root.creatingGroup) return
        var name = root.groupNameDraft.trim()
        if (!root.service || !name || root.groupMemberKeys.length < 2) {
            root.showNotice("Name the group and choose at least two friends")
            return
        }
        var selectedMembers = root.groupMemberKeys.slice()
        root.creatingGroup = true
        root.service.createGroup(name, selectedMembers, function(ok) {
            root.creatingGroup = false
            if (!ok || root.groupNameDraft.trim() !== name || root.groupMemberKeys.join(",") !== selectedMembers.join(",")) return
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
        return root.updateInfo.current || "4.18.2"
    }

    Item {
        id: supportObjects
        width: 1
        height: 1
        opacity: 0
        enabled: false
        ServiceModern { id: panelFallbackService; uiOnlyFallback: true }
        // KeyboardPanel's default contentItem accepts QQuickItems only.
        // Connections is a QObject, so keep it under a real Item to avoid
        // Loader.Error and the user-visible V2 fallback.
        Connections {
            target: root.service
            ignoreUnknownSignals: true
            function onGlobalSearchResultsChanged() {
                root.rebuildMessageSearchIndex()
                root.rebuildConversationRows()
            }
        }
        Timer { id: noticeTimer; interval: 2800; onTriggered: root.notice = "" }
        Timer { id: typingIdleTimer; interval: 10000; repeat: false; onTriggered: root.stopTypingSignal() }
        Timer {
            id: chatSearchTimer
            interval: 260
            repeat: false
            onTriggered: if (root.service) root.service.searchMessages(root.chatQuery)
        }
        Timer {
            interval: 10000
            repeat: true
            running: root.open
            onTriggered: root.statusNowSecond = Math.floor(Date.now() / 1000)
        }
    }

    onOpenChanged: {
        root.statusNowSecond = Math.floor(Date.now() / 1000)
        if (root.service && typeof root.service.setUiOpen === "function") root.service.setUiOpen(root.open)
        if (root.open) {
            Qt.callLater(root.restoreConversationAfterStatusRefresh)
            Qt.callLater(root.syncTypingPeer)
        } else root.stopTypingSignal()
    }
    onServiceStatusRevisionChanged: {
        Qt.callLater(root.rebuildConversationRows)
        Qt.callLater(root.restoreConversationAfterStatusRefresh)
    }
    onChatQueryChanged: {
        root.rebuildMessageSearchIndex()
        root.rebuildConversationRows()
        if (root.chatQuery.trim()) chatSearchTimer.restart()
        else {
            chatSearchTimer.stop()
            if (root.service) root.service.searchMessages("")
        }
    }

    Rectangle {
        id: panelSurface
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
                        online: root.selfPresenceIsLive()
                        selected: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: Style.space(250)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        PlainText {
                            text: "Omarchy Friends"
                            color: root.ink
                            font.family: root.uiFontFamily
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                        }
                        PlainText {
                            text: root.page === "chats" ? "Private conversations" : root.page === "requests" ? "Connection requests" : root.page === "world" ? "Discover Omarchy people" : root.page === "circles" ? "Community room" : "Your profile & presence"
                            color: root.mutedInk
                            font.family: root.uiFontFamily
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
                    PlainText {
                        width: parent.width - updateNowButton.width - Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "A newer Friends build is available. Update to keep messaging and Build Network compatible."
                        color: "#f7e6a7"
                        font.family: root.uiFontFamily
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

                        PlainText { text: "FRIENDS"; color: root.faintInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.1 }
                        Item { width: 1; height: Style.space(3) }

                        GlassNavItem {
                            id: chatsNav
                            Keys.onEscapePressed: root.close()
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
                        PlainText { text: "QUICK"; color: root.faintInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.0 }
                        Item { width: 1; height: Style.space(2) }
                        GlassNavItem { width: parent.width; text: "New chat"; icon: "+"; onClicked: { root.newChatOpen = true; root.page = "chats" } }
                        GlassNavItem { width: parent.width; text: "Ask help"; icon: "?"; onClicked: root.openBuild("help") }
                        GlassNavItem { width: parent.width; text: "Setup"; icon: "⌘"; onClicked: root.openBuild("share") }

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
                                PlainText { text: root.globalConnectionText; color: root.globalConnectionColor; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                PlainText { width: parent.width; text: (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0) + " relays"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
                            id: conversationListSurface
                            width: Math.max(Style.space(188), Math.min(Style.space(238), parent.width * 0.29))
                            height: parent.height
                            radius: Style.space(18)
                            fillOpacity: 0.67
                            borderOpacity: 0.08

                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(8)

                                Row {
                                    id: chatHeaderRow
                                    width: parent.width
                                    spacing: Style.space(6)
                                    Column {
                                        width: parent.width - newChatButton.width - Style.space(6)
                                        PlainText { width: parent.width; text: "Chats"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
                                        PlainText { width: parent.width; text: "Opened conversations"; color: root.faintInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: newChatButton; text: "New"; icon: "+"; compact: true; primary: true; anchors.verticalCenter: parent.verticalCenter; onClicked: root.newChatOpen = true }
                                }

                                GlassField { width: parent.width; placeholder: "Search chats and messages"; text: root.chatQuery; onTextChanged: { root.chatQuery = text; root.searchTargetMessageId = "" } }

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
                                                activeFocusOnTab: true
                                                Accessible.role: Accessible.Button
                                                Accessible.name: "Open group " + (modelData.name || "Private group") + (root.unreadCount("group", modelData.id) ? ", " + root.unreadCount("group", modelData.id) + " unread messages" : "")
                                                TapHandler { onTapped: root.openGroupSearchResult(modelData) }
                                                Keys.onReturnPressed: root.openGroupSearchResult(modelData)
                                                Keys.onEnterPressed: root.openGroupSearchResult(modelData)
                                                Keys.onSpacePressed: root.openGroupSearchResult(modelData)
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(8)
                                                    spacing: Style.space(8)
                                                    GlassAvatar { size: Style.space(36); emoji: "🫂"; online: false; selected: root.selectedGroupId === modelData.id }
                                                    Column {
                                                        width: parent.width - Style.space(46)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        PlainText { width: parent.width; text: (root.isConversationPinned("group", modelData.id) ? "★ " : "") + (root.isConversationMuted("group", modelData.id) ? "🔕 " : "") + (modelData.name || "Private group"); color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        PlainText { width: parent.width; text: root.groupLastMessagePreview(modelData.id); color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                }
                                                Rectangle {
                                                    visible: root.unreadCount("group", modelData.id) > 0
                                                    width: Style.space(20); height: width; radius: width / 2
                                                    anchors.top: parent.top; anchors.right: parent.right
                                                    anchors.topMargin: Style.space(5); anchors.rightMargin: Style.space(5)
                                                    color: root.success
                                                    PlainText { anchors.centerIn: parent; text: root.unreadCount("group", modelData.id) > 99 ? "99+" : String(root.unreadCount("group", modelData.id)); color: root.canvas; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                                                }
                                                Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: root.cyan; z: 5 }
                                            }
                                        }

                                        Repeater {
                                            model: root.allConversationFriends()
                                            GlassSurface {
                                                width: parent.width
                                                height: Style.space(62)
                                                radius: Style.space(13)
                                                selected: root.selectedFriendKey === modelData.public_key
                                                fillOpacity: selected ? 0.78 : 0.48
                                                activeFocusOnTab: true
                                                Accessible.role: Accessible.Button
                                                Accessible.name: "Open chat with " + (modelData.handle || "friend") + (root.unreadCount("friend", modelData.public_key) ? ", " + root.unreadCount("friend", modelData.public_key) + " unread messages" : "")
                                                TapHandler { onTapped: root.openFriendSearchResult(modelData) }
                                                Keys.onReturnPressed: root.openFriendSearchResult(modelData)
                                                Keys.onEnterPressed: root.openFriendSearchResult(modelData)
                                                Keys.onSpacePressed: root.openFriendSearchResult(modelData)
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: Style.space(8)
                                                    spacing: Style.space(8)
                                                    GlassAvatar { size: Style.space(36); emoji: modelData.avatar || "👾"; online: modelData.online === true; selected: root.selectedFriendKey === modelData.public_key }
                                                    Column {
                                                        width: parent.width - Style.space(46)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        PlainText { width: parent.width; text: (root.isConversationPinned("friend", modelData.public_key) ? "★ " : "") + (root.isConversationMuted("friend", modelData.public_key) ? "🔕 " : "") + (modelData.handle || "Builder"); color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                        PlainText { width: parent.width; text: root.lastMessagePreview(modelData.public_key); color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                    }
                                                }
                                                Rectangle {
                                                    visible: root.unreadCount("friend", modelData.public_key) > 0
                                                    width: Style.space(20); height: width; radius: width / 2
                                                    anchors.top: parent.top; anchors.right: parent.right
                                                    anchors.topMargin: Style.space(5); anchors.rightMargin: Style.space(5)
                                                    color: root.success
                                                    PlainText { anchors.centerIn: parent; text: root.unreadCount("friend", modelData.public_key) > 99 ? "99+" : String(root.unreadCount("friend", modelData.public_key)); color: root.canvas; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                                                }
                                                Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: root.cyan; z: 5 }
                                            }
                                        }

                                        Column {
                                            visible: root.allConversationFriends().length === 0 && root.conversationGroups().length === 0
                                            width: parent.width
                                            spacing: Style.space(8)
                                            topPadding: Style.space(26)
                                            PlainText {
                                                width: parent.width
                                                text: root.chatListEmptyState() === "empty" ? "No chats yet"
                                                    : (root.chatListEmptyState() === "error" ? "Saved chats could not load" : "Loading saved conversations…")
                                                color: root.ink
                                                horizontalAlignment: Text.AlignHCenter
                                                font.family: root.uiFontFamily
                                                font.pixelSize: Style.font.bodySmall
                                                font.bold: true
                                            }
                                            PlainText {
                                                width: parent.width
                                                text: root.chatListEmptyState() === "empty" ? "Pick a friend to start chatting."
                                                    : (root.chatListEmptyState() === "error"
                                                        ? "Check the Friends service, then retry."
                                                        : "Reading your saved chat list…")
                                                color: root.mutedInk
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                                font.family: root.uiFontFamily
                                                font.pixelSize: Style.font.caption
                                            }
                                            GlassButton {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                visible: root.chatListEmptyState() === "error" && !!root.service
                                                text: "Retry"
                                                icon: "↻"
                                                onClicked: if (root.service) root.service.refresh()
                                            }
                                            GlassButton { anchors.horizontalCenter: parent.horizontalCenter; text: "New chat"; icon: "+"; primary: true; onClicked: root.newChatOpen = true }
                                        }
                                    }
                                }
                            }
                        }

                        GlassSurface {
                            // Never force the conversation pane wider than the
                            // space left beside the chat list. The old 320px
                            // minimum pushed the composer beyond the popover on
                            // compact displays.
                            width: Math.max(0, parent.width - conversationListSurface.width - parent.spacing)
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
                                    id: conversationHeader
                                    height: Style.space(48)
                                    spacing: Style.space(6)
                                    GlassAvatar { size: Style.space(40); anchors.verticalCenter: parent.verticalCenter; emoji: root.selectedGroup() ? "🫂" : (root.selectedFriend() ? (root.selectedFriend().avatar || "👾") : "✦"); online: root.selectedGroup() ? true : (root.selectedFriend() && root.selectedFriend().online === true); selected: true }
                                    Column {
                                        width: Math.max(0, parent.width - Style.space(58) - focusButton.width - olderHistoryButton.width - chatMoreButton.width - parent.spacing * 3)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(2)
                                        PlainText { width: parent.width; text: root.selectedGroup() ? (root.selectedGroup().name || "Private group") : (root.selectedFriend() ? (root.selectedFriend().legacy_archive ? "Recovered messages" : (root.selectedFriend().handle || "Builder")) : "Choose a chat"); color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                        PlainText { width: parent.width; text: root.selectedGroup() ? "Private group · encrypted" : (root.selectedFriend() ? (root.selectedFriend().legacy_archive ? "Recipient unavailable · saved on this device" : (root.isFriendTyping(root.selectedFriend().public_key) ? "typing…" : (root.selectedFriend().online ? "Online now" : "Private chat"))) : "Pick a conversation or start a new one"); color: root.selectedFriend() && (root.selectedFriend().online || root.isFriendTyping(root.selectedFriend().public_key)) ? root.success : root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: focusButton; text: "Focus"; icon: "◷"; compact: true; visible: root.selectedFriend() !== null && !root.selectedFriend().legacy_archive; width: visible ? implicitWidth : 0; onClicked: if (root.service && root.selectedFriend()) root.service.inviteGlobalFocus(root.selectedFriend().public_key) }
                                    GlassButton { id: olderHistoryButton; text: root.syncingPrivateHistory ? "Checking…" : "Older"; icon: "↻"; compact: true; visible: root.selectedFriend() !== null && !root.selectedFriend().legacy_archive && root.hasMorePrivateHistoryPages(root.selectedFriend().public_key); width: visible ? implicitWidth : 0; enabled: !root.syncingPrivateHistory; Accessible.name: "Check inbox relays for older private messages"; onClicked: root.syncEarlierMessages() }
                                    GlassButton { id: chatMoreButton; text: "More"; icon: "⋯"; compact: true; visible: (root.selectedFriend() !== null && !root.selectedFriend().legacy_archive) || root.selectedGroup() !== null; width: visible ? implicitWidth : 0; onClicked: chatActionsMenu.open() }
                                }

                                Rectangle { id: conversationDivider; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

                                Flickable {
                                    id: messageScroller
                                    width: parent.width
                                    height: Math.max(0, parent.height - conversationHeader.height - conversationDivider.height - messageComposer.height - parent.spacing * 3)
                                    contentWidth: width
                                    contentHeight: messageColumn.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                    property bool wasNearBottom: true
                                    onContentHeightChanged: {
                                        if (root.searchTargetMessageId) Qt.callLater(root.scrollToSearchTarget)
                                        else if (wasNearBottom) contentY = Math.max(0, contentHeight - height)
                                    }
                                    onContentYChanged: wasNearBottom = contentY >= Math.max(0, contentHeight - height - Style.space(36))

                                    Column {
                                        id: messageColumn
                                        width: parent.width
                                        spacing: Style.space(8)
                                        GlassButton {
                                            visible: root.hasEarlierMessages()
                                            width: parent.width
                                            height: visible ? Style.space(34) : 0
                                            text: root.service && root.service.historyLoading ? "Loading earlier messages…" : "Load earlier messages"
                                            icon: "↑"
                                            compact: true
                                            enabled: !root.service || !root.service.historyLoading
                                            onClicked: root.loadEarlierMessages()
                                        }
                                        Item { width: 1; height: Style.space(6) }

                                        Repeater {
                                            id: messageRepeater
                                            model: root.conversationMessages()
                                            delegate: Item {
                                                id: messageDelegate
                                                required property var modelData
                                                readonly property string messageKey: String(modelData.id || (modelData.timestamp + ":" + modelData.public_key + ":" + modelData.text))
                                                width: messageColumn.width
                                                height: Math.max(bubble.implicitHeight, messageOptionsButton.implicitHeight) + Style.space(4)
                                                objectName: "friend-message-" + messageKey
                                                Rectangle {
                                                    id: bubble
                                                    width: Math.min(parent.width * 0.76, Math.max(Style.space(120), messageBody.implicitWidth + Style.space(22)))
                                                    implicitHeight: messageBody.implicitHeight + Style.space(18)
                                                    anchors.right: modelData.incoming ? undefined : parent.right
                                                    anchors.left: modelData.incoming ? parent.left : undefined
                                                    radius: Style.space(15)
                                                    color: String(modelData.id || "") === root.searchTargetMessageId ? "#1980a0" : (modelData.incoming ? "#121a2c" : "#6258df")
                                                    border.width: 1
                                                    border.color: modelData.incoming ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0.78, 0.75, 1.0, 0.30)
                                                    Column {
                                                        id: messageBody
                                                        width: Math.min(messageScroller.width * 0.70, Math.max(Style.space(44), replyQuote.implicitWidth, messageText.implicitWidth, mediaText.implicitWidth, attachmentText.implicitWidth, sendStateText.implicitWidth, reactionSummaryRow.implicitWidth, attachmentSaveButton.visible ? attachmentSaveButton.implicitWidth : 0, (!modelData.incoming && modelData.read_by && modelData.read_by.length > 0) ? Style.space(56) : 0))
                                                        anchors.centerIn: parent
                                                        spacing: Style.space(5)
                                                        PlainText {
                                                            id: replyQuote
                                                            width: parent.width
                                                            visible: !!modelData.reply_to
                                                            text: visible ? "↪ " + (modelData.reply_to.handle || "Message") + ": " + (modelData.reply_to.text || "Attachment") : ""
                                                            color: modelData.incoming ? root.cyan : "#dedaff"
                                                            font.family: root.uiFontFamily
                                                            font.pixelSize: Style.font.caption
                                                            elide: Text.ElideRight
                                                        }
                                                        PlainText { id: messageText; width: parent.width; text: modelData.text || ""; visible: text !== ""; color: "#f4f5ff"; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                                        PlainText { width: parent.width; visible: !!modelData.edited; text: "Edited"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                                        PlainText { id: sendStateText; width: parent.width; visible: !!modelData.sendState; text: modelData.sendState === "Sent" ? "Sent · relay" : (modelData.sendState === "Failed · retry" ? "Delivery unconfirmed · retry" : (modelData.sendState || "")); color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                                        PlainText { width: parent.width; visible: !!(!modelData.incoming && modelData.read_by && modelData.read_by.length > 0); text: modelData.group_id ? "✓✓ Read by " + modelData.read_by.length : "✓✓ Read"; color: root.cyan; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                                        PlainText {
                                                            id: attachmentText
                                                            width: parent.width
                                                            visible: modelData.attachments && modelData.attachments.length > 0
                                                            text: visible ? "📎 " + modelData.attachments[0].name + " · " + (Number(modelData.attachments[0].size || 0) >= 1048576 ? (Number(modelData.attachments[0].size) / 1048576).toFixed(1) + " MiB" : Math.max(1, Math.round(Number(modelData.attachments[0].size || 0) / 1024)) + " KiB") : ""
                                                            color: modelData.incoming ? root.cyan : "#e8e5ff"
                                                            font.family: root.uiFontFamily
                                                            font.pixelSize: Style.font.caption
                                                            elide: Text.ElideMiddle
                                                        }
                                                        Row {
                                                            id: reactionSummaryRow
                                                            visible: !messageDelegate.modelData.deleted && root.reactionSummary(messageDelegate.modelData).length > 0
                                                            spacing: Style.space(4)
                                                            Repeater {
                                                                model: root.reactionSummary(messageDelegate.modelData)
                                                                delegate: GlassPill {
                                                                    required property var modelData
                                                                    text: modelData.emoji + " " + modelData.count
                                                                    active: root.myReaction(messageDelegate.modelData) === modelData.emoji
                                                                    accentColor: root.violet
                                                                }
                                                            }
                                                        }
                                                        GlassButton {
                                                            id: attachmentSaveButton
                                                            visible: !modelData.deleted && modelData.attachments && modelData.attachments.length > 0 && (!!modelData.attachments[0].data || modelData.attachments[0].transport === "blossom")
                                                            text: "Save to Downloads"
                                                            icon: "↓"
                                                            compact: true
                                                            onClicked: if (root.service) root.service.saveAttachment(modelData.id, 0)
                                                        }
                                                        PlainText {
                                                            id: mediaText
                                                            width: parent.width
                                                            visible: !modelData.deleted && modelData.media && modelData.media.length > 0
                                                            text: visible ? "↗ " + ((modelData.media[0].url || modelData.media[0].href || "Shared link")) : ""
                                                            color: modelData.incoming ? root.cyan : "#e8e5ff"
                                                            font.family: root.uiFontFamily
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
                                                    TapHandler {
                                                    parent: bubble
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    onLongPressed: messageActionMenu.popup()
                                                    onTapped: function(point, button) { if (button === Qt.RightButton) messageActionMenu.popup() }
                                                    }
                                                    GlassButton {
                                                        id: messageOptionsButton
                                                        // Reserve a dedicated gutter beside the bubble. Keeping the
                                                        // action inside the bubble covered real message text.
                                                        anchors.left: modelData.incoming ? bubble.right : undefined
                                                        anchors.right: modelData.incoming ? undefined : bubble.left
                                                        anchors.leftMargin: modelData.incoming ? Style.space(4) : 0
                                                        anchors.rightMargin: modelData.incoming ? 0 : Style.space(4)
                                                        anchors.verticalCenter: bubble.verticalCenter
                                                        text: "⋯"
                                                        accessibleName: "Message options"
                                                        compact: true
                                                        visible: !modelData.legacy_unlinked && !modelData.deleted && String(modelData.id || "").indexOf("local_") !== 0
                                                        z: 3
                                                        onClicked: messageActionMenu.popup()
                                                    }
                                                    Menu {
                                                        id: messageActionMenu
                                                        parent: messageDelegate
                                                        x: bubble.x + bubble.width - width
                                                        y: bubble.y + messageOptionsButton.height
                                                        background: Rectangle {
                                                            implicitWidth: Style.space(190)
                                                            color: root.panel
                                                            radius: Style.space(12)
                                                            border.width: 1
                                                            border.color: Qt.rgba(0.65, 0.68, 1.0, 0.28)
                                                        }
                                                        delegate: MenuItem {
                                                            id: messageMenuItem
                                                            contentItem: PlainText {
                                                                text: messageMenuItem.text
                                                                color: root.ink
                                                                font.family: root.uiFontFamily
                                                                font.pixelSize: Style.font.caption
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            background: Rectangle {
                                                                radius: Style.space(8)
                                                                color: messageMenuItem.highlighted ? Qt.rgba(0.46, 0.43, 0.9, 0.32) : "transparent"
                                                            }
                                                        }
                                                        MenuItem {
                                                            text: "Edit message"
                                                            visible: root.canEditMessage(messageDelegate.modelData)
                                                            onTriggered: root.beginMessageEdit(messageDelegate.modelData)
                                                        }
                                                        MenuItem {
                                                            text: "↩ Reply"
                                                            visible: !modelData.deleted && String(modelData.id || "").indexOf("local_") !== 0
                                                            onTriggered: root.startReply(messageDelegate.modelData)
                                                        }
                                                        MenuItem {
                                                            text: "↻ Retry send"
                                                            visible: modelData.retryable === true
                                                            onTriggered: if (root.service) root.service.retryPrivateMessage(messageDelegate.modelData.id)
                                                        }
                                                        MenuItem {
                                                            text: "↻ Retry pending actions"
                                                            visible: modelData.retryable_actions === true
                                                            onTriggered: if (root.service) root.service.retryMessageAction(messageDelegate.modelData.id)
                                                        }
                                                        MenuItem {
                                                            text: "Forward…"
                                                            visible: !modelData.deleted && (!!String(modelData.text || "").trim() || (modelData.media && modelData.media.length > 0) || (modelData.attachments && modelData.attachments.length > 0)) && String(modelData.id || "").indexOf("local_") !== 0
                                                            onTriggered: root.beginForward(messageDelegate.modelData)
                                                        }
                                                        MenuItem {
                                                            text: "Delete for me"
                                                            onTriggered: if (root.service) root.service.deleteMessageForMe(messageDelegate.modelData.id)
                                                        }
                                                        MenuItem {
                                                            text: "Delete for everyone"
                                                            visible: !modelData.deleted && !modelData.incoming && (!modelData.sendState || modelData.sendState === "Sent") && String(modelData.id || "").indexOf("local_") !== 0
                                                            onTriggered: root.deleteMessage(messageDelegate.modelData)
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
                                            PlainText { width: parent.width; text: root.selectedFriend() && root.selectedFriend().legacy_archive ? "Recovered messages" : (root.selectedFriendHistoryMissing() ? "Earlier messages are missing here" : (root.selectedFriend() || root.selectedGroup() ? "Say hi 👋" : "No conversation selected")); color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            PlainText { width: parent.width; text: root.selectedFriend() && root.selectedFriend().legacy_archive ? "These saved messages have no recipient record, so this archive cannot be replied to." : (root.selectedFriendHistoryMissing() ? "This device has the DM activity record but not the message contents. Check configured inbox relays for retained private messages; use Older to continue through history pages." : (root.selectedFriend() || root.selectedGroup() ? "Messages stay in this conversation." : "Choose a chat or start a new one.")); color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                            GlassButton {
                                                visible: root.selectedFriendHistoryMissing()
                                                enabled: visible && !root.syncingPrivateHistory
                                                text: root.syncingPrivateHistory ? "Checking inbox relays…" : "Check inbox relays for history"
                                                icon: root.syncingPrivateHistory ? "◌" : "↻"
                                                compact: true
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                onClicked: root.syncEarlierMessages()
                                            }
                                        }
                                    }
                                }

                                GlassSurface {
                                    id: messageComposer
                                    width: parent.width
                                    height: (root.replyDraft || root.editingMessage) && root.attachmentDraftPath ? Style.space(174) : ((root.attachmentDraftPath || root.replyDraft || root.editingMessage) ? Style.space(132) : Style.space(70))
                                    radius: Style.space(16)
                                    fillOpacity: 0.78
                                    borderOpacity: 0.10
                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: Style.space(8)
                                        spacing: Style.space(6)
                                        Row {
                                            visible: !!root.replyDraft
                                            width: parent.width
                                            height: visible ? Style.space(22) : 0
                                            PlainText { width: parent.width - cancelReply.width - Style.space(8); text: root.replyDraft ? "Replying to " + root.replyDraft.handle + ": " + root.replyDraft.text : ""; color: root.cyan; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                            GlassButton { id: cancelReply; text: "×"; compact: true; onClicked: root.replyDraft = null }
                                        }
                                        Row {
                                            visible: !!root.editingMessage
                                            width: parent.width
                                            height: visible ? Style.space(22) : 0
                                            PlainText { width: parent.width - cancelEdit.width - Style.space(8); text: root.editingMessage ? "Editing message" : ""; color: root.cyan; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                            GlassButton { id: cancelEdit; text: "×"; compact: true; onClicked: { root.editingMessage = null; root.messageDraft = "" } }
                                        }
                                        Row {
                                            width: parent.width
                                            spacing: Style.space(7)
                                            GlassButton { id: attachmentButton; text: ""; icon: "📎"; accessibleName: "Attach a file, folder, or link"; compact: true; enabled: (root.selectedFriend() !== null && !root.selectedFriend().legacy_archive) || root.selectedGroup() !== null; onClicked: attachmentMenu.open() }
                                            GlassField { id: messageInput; width: Math.max(0, parent.width - sendButton.width - attachmentButton.width - parent.spacing * 2); placeholder: root.selectedFriend() && root.selectedFriend().legacy_archive ? "Recovered archive is read-only" : (root.editingMessage ? "Edit message…" : (root.selectedFriend() || root.selectedGroup() ? "Message…" : "Choose a chat first")); enabled: (root.selectedFriend() !== null && !root.selectedFriend().legacy_archive) || root.selectedGroup() !== null; text: root.messageDraft; onTextChanged: root.messageDraft = text; onEdited: root.updateTypingSignal(text); onAccepted: root.sendMessage() }
                                            GlassButton { id: sendButton; text: root.editingMessage ? (root.savingMessageEdit ? "Saving…" : "Save") : "Send"; icon: root.editingMessage ? "✓" : "➤"; primary: true; enabled: !root.savingMessageEdit && ((root.selectedFriend() !== null && !root.selectedFriend().legacy_archive) || root.selectedGroup() !== null) && (!!root.messageDraft.trim() || (!root.editingMessage && (!!root.mediaDraft.trim() || !!root.attachmentDraftPath))); onClicked: root.sendMessage() }
                                        }
                                        Row {
                                            visible: !!root.attachmentDraftPath
                                            width: parent.width
                                            spacing: Style.space(8)
                                            PlainText { width: parent.width - removeAttachment.width - Style.space(12); anchors.verticalCenter: parent.verticalCenter; text: (root.attachmentDraftIsFolder ? "📁 " : "📎 ") + root.attachmentDraftPath.split("/").pop(); color: root.cyan; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle }
                                            GlassButton { id: removeAttachment; text: "Remove"; compact: true; onClicked: { root.attachmentDraftPath = ""; root.attachmentDraftIsFolder = false } }
                                        }
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
                                PlainText { text: "Requests"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.title; font.bold: true }
                                PlainText { text: "Connections stay separate from your actual conversations."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
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
                                                GlassAvatar { size: Style.space(42); emoji: modelData.avatar || "👋"; online: root.worldPeer(modelData.public_key) !== null }
                                                Column {
                                                    width: parent.width - acceptRequestButton.width - declineRequestButton.width - Style.space(70)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    PlainText { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    PlainText { width: parent.width; text: "Wants to connect and start a private chat"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
                                                    PlainText { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    PlainText { width: parent.width; text: modelData.online ? "Request sent · online now" : "Request sent · waiting for a reply"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
                                        PlainText { width: parent.width; text: root.requestTab === "received" ? "No new requests" : "No pending sent requests"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true }
                                        PlainText { width: parent.width; text: root.requestTab === "received" ? "New connection requests will appear here instead of cluttering Chats." : "People you connect with from World will appear here until they accept."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
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
                                PlainText { text: "World"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.title; font.bold: true }
                                PlainText { text: "Find people worth talking to — not a wall of tiny action buttons."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
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
                                Column { anchors.centerIn: parent; PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.world.length); color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true } PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: "visible now"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption } }
                            }
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(58)
                                radius: Style.space(14)
                                fillOpacity: 0.55
                                Column { anchors.centerIn: parent; PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: String(root.friendsList().length); color: root.violet; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true } PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: "friends"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption } }
                            }
                            GlassSurface {
                                width: (parent.width - Style.space(16)) / 3
                                height: Style.space(58)
                                radius: Style.space(14)
                                fillOpacity: 0.55
                                Column { anchors.centerIn: parent; PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: (root.worldStatus.relay_count || 0) + "/" + (root.worldStatus.relay_total || 0); color: root.cyan; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true } PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: "relays"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption } }
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
                                                    PlainText { width: parent.width; text: modelData.handle || "Omarchy builder"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                                    PlainText { width: parent.width; text: modelData.project_name ? ("Building · " + modelData.project_name) : ((modelData.status_emoji || "●") + " " + (modelData.status_name || modelData.activity || "Online")); color: modelData.project_name ? root.cyan : root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                GlassButton { id: personAction; text: root.peerActionLabel(modelData); compact: true; primary: root.peerActionLabel(modelData) === "Accept" || root.peerActionLabel(modelData) === "Message"; enabled: root.peerActionLabel(modelData) !== "Requested" && root.peerActionLabel(modelData) !== "Needs update"; onClicked: root.activatePeer(modelData) }
                                                GlassButton { id: safetyToggle; text: "⋯"; compact: true; selected: parent.parent.parent.safetyOpen; onClicked: parent.parent.parent.safetyOpen = !parent.parent.parent.safetyOpen }
                                            }

                                            PlainText {
                                                width: parent.width
                                                text: modelData.project_desc ? modelData.project_desc : (modelData.activity ? ("Right now · " + modelData.activity) : "Online in Omarchy")
                                                color: root.mutedInk
                                                font.family: root.uiFontFamily
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
                                    PlainText { width: parent.width; text: root.world.length === 0 ? "No one to show yet" : "No matches"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true }
                                    PlainText { width: parent.width; text: root.worldEmptyMessage(); color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: Style.space(8)
                                        GlassButton { visible: root.world.length === 0 && root.worldStatus.visible === false; text: "Join World"; icon: "◎"; compact: true; primary: true; onClicked: if (root.service) root.service.togglePrivacy("share_global") }
                                        GlassButton { text: "Copy invite"; icon: "↗"; compact: true; primary: root.world.length === 0 && root.worldStatus.visible !== false; onClicked: root.copyInvite() }
                                        GlassButton { text: "Refresh"; icon: "↻"; compact: true; onClicked: if (root.service) root.service.refreshGlobal() }
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
                                GlassAvatar { size: Style.space(44); emoji: "◌"; online: false; selected: true }
                                Column {
                                    width: parent.width - Style.space(176)
                                    anchors.verticalCenter: parent.verticalCenter
                                    PlainText { text: "Omarchy Circle"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true }
                                    PlainText { width: parent.width; text: "Public community chat"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                }
                            GlassPill { anchors.verticalCenter: parent.verticalCenter; text: String(root.world.length) + " online"; active: root.world.length > 0; accentColor: root.world.length > 0 ? root.success : root.mutedInk }
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
                                PlainText { text: "ⓘ"; color: root.cyan; font.pixelSize: Style.font.caption }
                                PlainText { width: parent.width - Style.space(22); text: "Public room · never share private links or personal information."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
                                        model: root.communityMessageItems
                                        Row {
                                            width: parent.width
                                            spacing: Style.space(9)
                                            GlassAvatar { size: Style.space(34); emoji: modelData.avatar || "👾"; online: false }
                                            Column {
                                                width: parent.width - Style.space(45)
                                                spacing: Style.space(4)
                                                PlainText { width: parent.width; text: (modelData.handle || modelData.from_name || "Builder") + (modelData.mine ? " · you" : ""); color: modelData.mine ? "#dcd7ff" : root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                TextMetrics { id: circleTextMetrics; text: modelData.text || modelData.message || ""; font: circleText.font }
                                                Rectangle {
                                                    width: Math.min(parent.width, Math.max(Style.space(150), circleTextMetrics.width + Style.space(20)))
                                                    height: circleText.implicitHeight + Style.space(16)
                                                    radius: Style.space(13)
                                                    color: modelData.mine ? "#322d68" : "#11192a"
                                                    border.width: 1
                                                    border.color: Qt.rgba(1, 1, 1, 0.065)
                                                    PlainText { id: circleText; width: parent.width - Style.space(18); anchors.centerIn: parent; text: circleTextMetrics.text; color: "#dfe3ef"; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        visible: root.communityMessageItems.length === 0
                                        width: parent.width
                                        topPadding: Style.space(60)
                                        spacing: Style.space(7)
                                        PlainText { width: parent.width; text: "The Circle is quiet"; color: root.ink; horizontalAlignment: Text.AlignHCenter; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true }
                                        PlainText { width: parent.width; text: "Start with a useful question, a small discovery, or what you're building today."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
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
                                    GlassAvatar { size: Style.space(64); emoji: root.profile.avatar || "👾"; online: root.selfPresenceIsLive(); selected: true; anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        width: parent.width - Style.space(245)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(3)
                                        PlainText { width: parent.width; text: root.profile.handle || "Omarchy Builder"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
                                        PlainText { width: parent.width; text: (root.profile.status_emoji || "🚀") + " " + (root.profile.status_name || "Ready") + (root.profile.project_name ? " · building " + root.profile.project_name : ""); color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                        PlainText { width: parent.width; text: root.profile.privacy && root.profile.privacy.share_global === true ? "World visibility on · turn off anytime" : "Hidden from World · turn on anytime"; color: root.faintInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
                                        PlainText { text: "About you"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
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
                                            TextArea { textFormat: TextEdit.PlainText;
                                                anchors.fill: parent
                                                anchors.margins: Style.space(5)
                                                text: root.projectDescDraft
                                                onTextChanged: root.projectDescDraft = text
                                                placeholderText: "One sentence about what you're building"
                                                placeholderTextColor: root.faintInk
                                                color: root.ink
                                                background: null
                                                wrapMode: TextArea.Wrap
                                                font.family: root.uiFontFamily
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
                                            PlainText { text: "Presence"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            PlainText { text: "Avatar"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                Repeater {
                                                    model: root.service && root.service.availableAvatars ? root.service.availableAvatars : []
                                                    GlassPill { text: String(modelData); active: root.profile.avatar === modelData; onClicked: if (root.service) root.service.setAvatar(String(modelData)) }
                                                }
                                            }
                                            PlainText { text: "Status"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                Repeater {
                                                    model: root.service && root.service.availableStatuses ? root.service.availableStatuses : []
                                                    GlassPill { text: (modelData.emoji || "•") + " " + (modelData.name || modelData.id || "Status"); active: root.profile.status === modelData.id; onClicked: if (root.service) root.service.setStatus(modelData.id) }
                                                }
                                            }
                                            PlainText { text: "Interests · up to 4"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
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
                                            PlainText { text: "Privacy"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            PlainText { width: parent.width; text: "New profiles are visible to configured public relays by default while online. This shares your pseudonymous public key, handle, avatar, status, and inbox-relay list; relay operators may retain published data. Turn off World visibility any time. Chat contents stay private. Typing hints are encrypted to compatible friends in direct chats, use non-stored relay events, and can be turned off here. Read receipts and extra profile details are off unless enabled."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                            Flow {
                                                width: parent.width
                                                spacing: Style.space(5)
                                                GlassPill { text: root.profile.privacy && root.profile.privacy.share_global === true ? "Visible in World" : "Hidden from World"; active: root.profile.privacy && root.profile.privacy.share_global === true; accentColor: root.success; onClicked: if (root.service) root.service.togglePrivacy("share_global") }
                                                GlassPill { text: "Active app"; active: root.profile.privacy && root.profile.privacy.share_window === true; onClicked: if (root.service) root.service.togglePrivacy("share_window") }
                                                GlassPill { text: "Music"; active: root.profile.privacy && root.profile.privacy.share_music === true; onClicked: if (root.service) root.service.togglePrivacy("share_music") }
                                                GlassPill { text: "Project"; active: root.profile.privacy && root.profile.privacy.share_project === true; onClicked: if (root.service) root.service.togglePrivacy("share_project") }
                                                GlassPill { text: "Interests"; active: root.profile.privacy && root.profile.privacy.share_interests === true; onClicked: if (root.service) root.service.togglePrivacy("share_interests") }
                                                GlassPill { text: "Room"; active: root.profile.privacy && root.profile.privacy.share_room === true; onClicked: if (root.service) root.service.togglePrivacy("share_room") }
                                                GlassPill { text: "Read receipts"; active: root.profile.privacy && root.profile.privacy.share_read_receipts === true; onClicked: if (root.service) root.service.togglePrivacy("share_read_receipts") }
                                                GlassPill { text: "Typing indicators"; active: root.profile.privacy && root.profile.privacy.share_typing === true; onClicked: if (root.service) root.service.togglePrivacy("share_typing") }
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
                                            PlainText { text: "Blocked people"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                            PlainText { width: parent.width; text: "Unblock a person to allow future World presence and messages again."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                            Column {
                                                width: parent.width
                                                spacing: Style.space(6)
                                                Repeater {
                                                    model: root.service && root.service.globalBlockedPubkeys ? root.service.globalBlockedPubkeys : []
                                                    Row {
                                                        width: parent.width
                                                        spacing: Style.space(8)
                                                        PlainText { width: parent.width - unblockButton.width - Style.space(8); text: String(modelData).slice(0, 12) + "…"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                                        GlassButton { id: unblockButton; text: "Unblock"; compact: true; onClicked: if (root.service) root.service.unblockGlobal(String(modelData)) }
                                                    }
                                                }
                                                PlainText { visible: (!root.service || !root.service.globalBlockedPubkeys || root.service.globalBlockedPubkeys.length === 0); text: "No blocked people"; color: root.faintInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
                                            }
                                        }
                                    }
                                }
                            }

                            GlassSurface {
                                width: parent.width
                                height: largeFilesColumn.implicitHeight + Style.space(24)
                                radius: Style.space(18)
                                fillOpacity: 0.60
                                Column {
                                    id: largeFilesColumn
                                    anchors.fill: parent
                                    anchors.margins: Style.space(12)
                                    spacing: Style.space(8)
                                    PlainText { text: "Large files · up to 100 MiB"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                    PlainText { width: parent.width; text: "Choose an HTTPS Blossom server. Files are encrypted on this device before upload; the server stores ciphertext. Server limits and policies still apply."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                                    GlassField { width: parent.width; placeholder: "https://files.example"; text: root.blossomServerDraft || root.worldStatus.blossom_server || ""; onTextChanged: root.blossomServerDraft = text }
                                    GlassButton { width: parent.width; text: "Save file server"; icon: "✓"; compact: true; onClicked: if (root.service) root.service.setBlossomServer(root.blossomServerDraft) }
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
                                        PlainText { text: root.updateInfo.available ? "Update available" : "Friends is current"; color: root.updateInfo.available ? root.warning : root.success; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                                        PlainText { width: parent.width; text: "Installed v" + root.formatVersion() + (root.updateInfo.latest ? " · latest " + root.updateInfo.latest : ""); color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                    }
                                    GlassButton { id: profileUpdateButton; text: root.updateInfo.available ? "Update" : "Check"; icon: "↻"; compact: true; primary: root.updateInfo.available; anchors.verticalCenter: parent.verticalCenter; onClicked: if (root.service) root.service.updatePlugin() }
                                }
                            }

                            GlassSurface {
                                width: parent.width
                                height: supportColumn.implicitHeight + Style.space(20)
                                radius: Style.space(15)
                                fillOpacity: 0.54
                                Column {
                                    id: supportColumn
                                    anchors.fill: parent
                                    anchors.margins: Style.space(10)
                                    spacing: Style.space(7)
                                    PlainText { text: "Feedback"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                                    Flow {
                                        width: parent.width
                                        spacing: Style.space(7)
                                        GlassButton { text: "Suggest a feature"; compact: true; onClicked: root.openSafeUrl(root.featureIdeaUrl) }
                                        GlassButton { text: "Report a bug"; compact: true; onClicked: root.openSafeUrl(root.bugReportUrl) }
                                    }
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
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
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
                                    PlainText { text: "New chat"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true }
                                    PlainText { width: parent.width; text: "Choose a friend or create a private group."; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
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
                                            activeFocusOnTab: true
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Start private chat with " + (modelData.handle || "friend")
                                            TapHandler { onTapped: root.chooseFriend(modelData) }
                                            Keys.onReturnPressed: root.chooseFriend(modelData)
                                            Keys.onEnterPressed: root.chooseFriend(modelData)
                                            Keys.onSpacePressed: root.chooseFriend(modelData)
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(8)
                                                spacing: Style.space(8)
                                                GlassAvatar { size: Style.space(36); emoji: modelData.avatar || "👾"; online: modelData.online === true }
                                                Column {
                                                    width: parent.width - Style.space(90)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    PlainText { width: parent.width; text: modelData.handle || "Builder"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                                    PlainText { width: parent.width; text: modelData.online ? "Online now" : "Friend"; color: modelData.online ? root.success : root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                }
                                                PlainText { anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.cyan; font.pixelSize: Style.font.heading }
                                            }
                                            Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: root.cyan; z: 5 }
                                        }
                                    }
                                    PlainText { visible: root.friendsList().length === 0; width: parent.width; text: "No friends yet. Open World to connect with someone first."; color: root.mutedInk; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; topPadding: Style.space(30) }
                                }
                            }
                        }
                    }

                    GlassSurface {
                        visible: root.groupCreateOpen && root.page === "chats"
                        width: Math.min(contentArea.width - Style.space(30), Style.space(430))
                        height: Math.min(contentArea.height - Style.space(30), Style.space(470))
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
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
                                    PlainText { text: "New private group"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.heading; font.bold: true }
                                    PlainText { text: "Choose at least two friends"; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption }
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
                                            activeFocusOnTab: true
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Toggle group member " + (modelData.handle || "friend")
                                            TapHandler { onTapped: root.toggleGroupMember(modelData.public_key) }
                                            Keys.onReturnPressed: root.toggleGroupMember(modelData.public_key)
                                            Keys.onEnterPressed: root.toggleGroupMember(modelData.public_key)
                                            Keys.onSpacePressed: root.toggleGroupMember(modelData.public_key)
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Style.space(7)
                                                spacing: Style.space(8)
                                                GlassAvatar { size: Style.space(30); emoji: modelData.avatar || "👾"; online: modelData.online === true }
                                                PlainText { width: parent.width - Style.space(66); anchors.verticalCenter: parent.verticalCenter; text: modelData.handle || "Builder"; color: root.ink; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                                PlainText { anchors.verticalCenter: parent.verticalCenter; text: root.groupMemberKeys.indexOf(modelData.public_key) >= 0 ? "✓" : "+"; color: root.groupMemberKeys.indexOf(modelData.public_key) >= 0 ? root.success : root.mutedInk; font.pixelSize: Style.font.bodySmall }
                                            }
                                            Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: root.cyan; z: 5 }
                                        }
                                    }
                                }
                            }
                            GlassButton { width: parent.width; text: "Create encrypted group"; icon: "✦"; primary: true; enabled: !root.creatingGroup; onClicked: root.createGroup() }
                        }
                    }
                }
            }

            Row {
                width: parent.width - Style.space(36)
                x: Style.space(18)
                height: Style.space(30)
                spacing: Style.space(8)
                PlainText { anchors.verticalCenter: parent.verticalCenter; text: "●"; color: root.globalConnectionColor; font.pixelSize: Style.font.caption }
                PlainText { anchors.verticalCenter: parent.verticalCenter; text: root.globalConnectionText; color: root.mutedInk; font.family: root.uiFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                Item { width: Math.max(0, parent.width - Style.space(390) - footerTagline.width); height: 1 }
                PlainText {
                    id: footerTagline
                    width: Math.min(Style.space(290), Math.max(Style.space(150), parent.width - Style.space(390)))
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Private chats · build together"
                    color: root.faintInk
                    font.family: root.uiFontFamily
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
            PlainText {
                id: noticeText
                anchors.fill: parent
                anchors.margins: Style.space(10)
                text: root.notice
                color: root.ink
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font.family: root.uiFontFamily
                font.pixelSize: Style.font.caption
            }
        }

        Menu {
            id: attachmentMenu
            parent: contentArea
            x: Math.max(Style.space(8), Math.min(contentArea.width - width - Style.space(8), attachmentButton.mapToItem(contentArea, 0, 0).x))
            y: Math.max(Style.space(8), Math.min(contentArea.height - height - Style.space(8), attachmentButton.mapToItem(contentArea, 0, attachmentButton.height).y))
            background: Rectangle {
                implicitWidth: Style.space(190)
                color: root.panel
                radius: Style.space(12)
                border.width: 1
                border.color: Qt.rgba(0.65, 0.68, 1.0, 0.28)
            }
            delegate: MenuItem {
                id: attachmentMenuItem
                contentItem: PlainText {
                    text: attachmentMenuItem.text
                    color: root.ink
                    font.family: root.uiFontFamily
                    font.pixelSize: Style.font.caption
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: Style.space(8)
                    color: attachmentMenuItem.highlighted ? Qt.rgba(0.46, 0.43, 0.9, 0.32) : "transparent"
                }
            }
            MenuItem { text: "Choose file…"; onTriggered: root.openAttachmentBrowser(false) }
            MenuItem { text: "Choose folder…"; onTriggered: root.openAttachmentBrowser(true) }
            MenuItem {
                text: "Share a link…"
                onTriggered: {
                    if (messageInput) messageInput.forceActiveFocus()
                    root.showNotice("Paste or type the link in the message box")
                }
            }
        }

        Menu {
            id: chatActionsMenu
            parent: chatMoreButton.parent
            x: chatMoreButton.x
            y: chatMoreButton.y + chatMoreButton.height
            MenuItem { text: root.isConversationPinned(root.selectedGroup() ? "group" : "friend", root.selectedGroup() ? root.selectedGroup().id : (root.selectedFriend() ? root.selectedFriend().public_key : "")) ? "Unpin chat" : "Pin chat"; onTriggered: root.toggleSelectedConversationPin() }
            MenuItem { text: root.isConversationMuted(root.selectedGroup() ? "group" : "friend", root.selectedGroup() ? root.selectedGroup().id : (root.selectedFriend() ? root.selectedFriend().public_key : "")) ? "Unmute chat" : "Mute chat"; onTriggered: root.toggleSelectedConversationMute() }
            MenuItem { text: "Verify security code"; visible: root.selectedFriend() !== null; onTriggered: root.openPrivateSafetyCode(root.selectedFriend()) }
            MenuItem { text: "Close chat"; onTriggered: root.closeConversation() }
            MenuItem { text: "Report"; visible: root.selectedFriend() !== null; onTriggered: root.reportPeer(root.selectedFriend()) }
        }

        Dialog {
            id: forwardDialog
            modal: true
            title: "Forward message"
            width: Math.min(root.width - Style.space(40), Style.space(390))
            standardButtons: Dialog.NoButton
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            contentItem: Column {
                spacing: Style.space(10)
                PlainText {
                    width: parent.width
                    text: "Choose an existing chat. Text, media links and attachments are shared. Reply context and original sender details are omitted."
                    color: root.mutedInk
                    wrapMode: Text.WordWrap
                    font.family: root.uiFontFamily
                    font.pixelSize: Style.font.caption
                }
                ComboBox {
                    id: forwardTargetPicker
                    width: parent.width
                    model: root.forwardTargets()
                    textRole: "label"
                    onCurrentIndexChanged: root.forwardTargetIndex = currentIndex
                    displayText: currentIndex >= 0 && currentIndex < count ? textAt(currentIndex) : "Choose a chat"
                    contentItem: PlainText {
                        leftPadding: Style.space(12)
                        rightPadding: Style.space(12)
                        text: forwardTargetPicker.displayText
                        color: root.ink
                        font.family: root.uiFontFamily
                        font.pixelSize: Style.font.caption
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    delegate: ItemDelegate {
                        width: forwardTargetPicker.width
                        contentItem: PlainText {
                            text: modelData.label
                            color: root.ink
                            font.family: root.uiFontFamily
                            font.pixelSize: Style.font.caption
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    layoutDirection: Qt.RightToLeft
                    GlassButton {
                        text: root.forwardingMessage ? "Forwarding…" : "Forward"
                        icon: "➤"
                        primary: true
                        enabled: !root.forwardingMessage && forwardTargetPicker.count > 0 && forwardTargetPicker.currentIndex >= 0
                        onClicked: root.forwardToSelectedTarget()
                    }
                    GlassButton { text: "Cancel"; onClicked: forwardDialog.close() }
                }
            }
            onOpened: {
                forwardTargetPicker.currentIndex = root.forwardTargets().length ? 0 : -1
                root.forwardTargetIndex = forwardTargetPicker.currentIndex
            }
            onClosed: {
                if (!root.forwardingMessage) root.forwardDraft = null
            }
        }

        Dialog {
            id: privateSafetyDialog
            modal: true
            title: "Verify security code"
            width: Math.min(root.width - Style.space(40), Style.space(430))
            standardButtons: Dialog.NoButton
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            contentItem: Column {
                spacing: Style.space(12)
                PlainText {
                    width: parent.width
                    text: "Compare this code with " + root.privateSafetyPeerHandle + " in person or through a separate trusted channel. Matching codes mean both sides have the same account-key pair. If it differs, stop and re-check who you are talking to."
                    color: root.mutedInk
                    wrapMode: Text.WordWrap
                    font.family: root.uiFontFamily
                    font.pixelSize: Style.font.caption
                }
                PlainText {
                    width: parent.width
                    text: root.privateSafetyCodeLoading ? "Calculating…" : (root.privateSafetyCode || "Could not calculate the code")
                    color: root.ink
                    font.family: "monospace"
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignHCenter
                }
                PlainText {
                    width: parent.width
                    text: "This fingerprint helps detect an identity-key mismatch. It does not provide forward secrecy or independently prove a person's identity."
                    color: root.faintInk
                    wrapMode: Text.WordWrap
                    font.family: root.uiFontFamily
                    font.pixelSize: Style.font.caption
                }
                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    layoutDirection: Qt.RightToLeft
                    GlassButton { text: "Done"; primary: true; onClicked: privateSafetyDialog.close() }
                    GlassButton { text: "Copy code"; enabled: !!root.privateSafetyCode; onClicked: root.copyPrivateSafetyCode() }
                }
            }
        }

        Shortcut {
            sequences: ["Escape"]
            context: Qt.WindowShortcut
            enabled: root.open
                && !attachmentMenu.opened
                && !chatActionsMenu.opened
                && !forwardDialog.visible
                && !privateSafetyDialog.visible
            onActivated: root.close()
        }
    }
}
