import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
    id: root

    // Omarchy's hosted-service loader injects these shared host objects when
    // it creates a service component. Friends currently uses neither, but
    // declaring the contract avoids failed-initial-properties warnings and
    // keeps the plugin compatible with the host service API.
    property var shell: null
    property var manifest: null

    readonly property string binPath: {
        var local = Qt.resolvedUrl("bin/omarchy-friends").toString().replace(/^file:\/\//, "")
        return local
    }

    property var profile: ({
        handle: "OmarchyHacker",
        avatar: "👾",
        code: "OMAR-0000-000",
        public_key: "",
        global_visible: false,
        status: "coding",
        status_name: "In The Zone",
        status_emoji: "🚀",
        status_desc: "Writing code in deep focus",
        activity: "Ready",
        music: "",
        theme: "",
        wallpaper: "",
        focus_mins: 0,
        project_name: "",
        project_desc: "",
        project_url: "",
        interests: [],
        room: "",
        privacy: { share_window: false, share_music: false, share_lan: false, share_project: false, share_theme: false, share_interests: false, share_room: false, share_global: false }
    })
    property var matchedPeer: null
    property var friends: []
    property var lanPeers: []
    property var globalPeers: []
    property var globalPings: []
    property var globalFriendships: ({})
    property var globalMessages: []
    property var globalMessageSummaries: []
    property var globalMessageCounts: ({})
    property var activeHistoryMessages: []
    property string activeHistoryKey: ""
    property int activeHistoryTotal: 0
    property int activeHistoryNextOffset: 0
    property bool activeHistoryHasEarlier: false
    property bool historyLoading: false
    property int historyRequestSerial: 0
    property int historyRequestOffset: -1
    property int activeHistoryRequestOffset: -1
    property var globalSearchResults: []
    property string globalSearchQuery: ""
    property int searchRequestSerial: 0
    property var activeSearchProcess: null
    property var globalUnreadCounts: ({})
    property var globalPinnedConversations: []
    property var globalMutedConversations: []
    property var globalGroups: []
    property var globalCommunity: []
    property var globalMemory: ({})
    property var globalPrivateHistoryCursors: ({})
    property var globalPrivateHistoryRelays: []
    property var globalBlockedPubkeys: []
    property var updateInfo: ({ available: false, current: "", latest: "" })
    property bool inviteNudge: false
    property var worldEvent: ({ title: "Ship-It Friday", live: false, label: "" })
    property var globalStatus: ({ visible: false, online_count: 0, relay_count: 0, relay_total: 0, last_sync_age: "never", last_error: "" })
    property string worldPrompt: "What tiny thing are you making better today?"
    property var globalFocus: ({ status: "idle", active: false, pending: false, buddy_name: "", buddy_avatar: "", remaining_seconds: 0, total_seconds: 0 })
    property var worldPulse: []
    property var cowork: ({ active: false, mode: "", remaining_seconds: 0, buddy_code: "", buddy_name: "", buddy_avatar: "", total_seconds: 0 })
    property var coworkInvites: []
    property int onlineCount: 0
    property var stats: ({ hackers_met: 0, friends_made: 0, cowork_completed: 0, high_fives_sent: 0, high_fives_received: 0, rices_shared: 0 })
    property var availableStatuses: []
    property var availableAvatars: []
    property var availableInterests: []
    property string lastNotice: ""
    property bool retryingPendingMessages: false
    property bool uiOpen: false
    property int statusRevision: 0

    signal eventReceived(var event)
    signal friendInteracted(string action, string targetCode)
    signal coworkCompleted(string buddyName)
    signal friendCodeResult(bool ok, string message)
    signal actionResult(bool ok, string message)

    function refresh() {
        if (!statusProc.running) {
            statusProc.running = true
        }
    }

    function rebuildGlobalMessageCache() {
        var byId = ({})
        var messages = []
        function merge(rows, replace) {
            for (var i = 0; i < rows.length; i++) {
                var message = rows[i]
                if (!message || !message.id) continue
                var key = String(message.id)
                if (byId[key] === undefined) {
                    byId[key] = messages.length
                    messages.push(message)
                } else if (replace) {
                    messages[byId[key]] = message
                }
            }
        }
        merge(root.globalMessageSummaries, false)
        merge(root.activeHistoryMessages, true)
        messages.sort(function(a, b) {
            var delta = Number(a.timestamp || 0) - Number(b.timestamp || 0)
            if (delta !== 0) return delta
            delta = Number(a.received_at_ms || 0) - Number(b.received_at_ms || 0)
            if (delta !== 0) return delta
            return String(a.id || "") < String(b.id || "") ? -1 : (String(a.id || "") > String(b.id || "") ? 1 : 0)
        })
        root.globalMessages = messages
        if (root.activeHistoryRequestOffset === 0 && root.activeHistoryMessages.length > 0) {
            var savedCount = Number(root.globalMessageCounts[root.activeHistoryKey] || 0)
            root.activeHistoryHasEarlier = savedCount > root.activeHistoryMessages.length
        }
    }

    function loadConversationHistory(kind, identifier, offset, callback) {
        var conversationType = kind === "group" ? "group" : (kind === "unlinked" ? "unlinked" : "friend")
        var conversationId = String(identifier || "")
        if (!conversationId) return false
        var key = conversationType + ":" + conversationId
        if (root.activeHistoryKey !== key) {
            root.historyRequestSerial++
            root.historyLoading = false
            root.activeHistoryKey = key
            root.activeHistoryMessages = []
            root.activeHistoryTotal = 0
            root.activeHistoryNextOffset = 0
            root.activeHistoryHasEarlier = false
            root.activeHistoryRequestOffset = -1
            root.rebuildGlobalMessageCache()
        }
        var requestOffset = Math.max(0, Number(offset || 0))
        if (root.historyLoading && root.historyRequestOffset === requestOffset) return false
        if (root.historyLoading) {
            root.historyRequestSerial++
            root.historyLoading = false
        }
        var serial = ++root.historyRequestSerial
        root.historyRequestOffset = requestOffset
        root.historyLoading = true
        runAction([root.binPath, "conversation-history", conversationType, conversationId, String(requestOffset), "80"], function(output) {
            if (serial !== root.historyRequestSerial) return
            root.historyLoading = false
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            if (result.ok !== true || !Array.isArray(result.messages)) {
                root.actionResult(false, result.message || "Could not load this chat's history")
                if (callback) callback(false, result)
                return
            }
            var byId = ({})
            for (var i = 0; i < root.activeHistoryMessages.length; i++) {
                var saved = root.activeHistoryMessages[i]
                if (saved && saved.id) byId[String(saved.id)] = saved
            }
            for (var j = 0; j < result.messages.length; j++) {
                var incoming = result.messages[j]
                if (incoming && incoming.id) byId[String(incoming.id)] = incoming
            }
            var combined = []
            for (var id in byId) combined.push(byId[id])
            combined.sort(function(a, b) {
                var delta = Number(a.timestamp || 0) - Number(b.timestamp || 0)
                if (delta !== 0) return delta
                delta = Number(a.received_at_ms || 0) - Number(b.received_at_ms || 0)
                return delta !== 0 ? delta : (String(a.id || "") < String(b.id || "") ? -1 : (String(a.id || "") > String(b.id || "") ? 1 : 0))
            })
            root.activeHistoryMessages = combined
            root.activeHistoryTotal = Number(result.total || 0)
            root.activeHistoryNextOffset = Math.max(root.activeHistoryNextOffset, requestOffset + result.messages.length)
            root.activeHistoryRequestOffset = requestOffset
            root.activeHistoryHasEarlier = result.has_earlier === true
            root.rebuildGlobalMessageCache()
            if (callback) callback(true, result)
        })
        return true
    }

    function canLoadEarlierMessages(kind, identifier) {
        var key = (kind === "group" ? "group:" : (kind === "unlinked" ? "unlinked:" : "friend:")) + String(identifier || "")
        return root.activeHistoryKey === key && root.activeHistoryHasEarlier
    }

    function searchMessages(query, callback) {
        var search = String(query || "").trim()
        var serial = ++root.searchRequestSerial
        root.globalSearchQuery = search
        var previousSearchProcess = root.activeSearchProcess
        root.activeSearchProcess = null
        if (previousSearchProcess && previousSearchProcess.running)
            previousSearchProcess.running = false
        if (!search) {
            root.globalSearchResults = []
            if (callback) callback(true, [])
            return
        }
        var searchProcess = runAction([root.binPath, "search-messages", search], function(output) {
            if (serial !== root.searchRequestSerial) return
            root.activeSearchProcess = null
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            if (result.ok !== true || !Array.isArray(result.messages)) {
                root.globalSearchResults = []
                if (callback) callback(false, [])
                return
            }
            root.globalSearchResults = result.messages
            if (callback) callback(true, result.messages)
        })
        // runAction returns the child process so the next debounced search can
        // stop this full encrypted-journal scan instead of stacking workers.
        root.activeSearchProcess = searchProcess
    }

    function setUiOpen(open) {
        var next = open === true
        if (root.uiOpen === next) return
        root.uiOpen = next
        if (next) root.refresh()
    }

    function pollEvents() {
        if (!eventProc.running) {
            eventProc.running = true
        }
    }

    function matchNext() {
        runAction([root.binPath, "match-next"], function(output) {
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            var message = result.peer && result.peer.handle ? "Matched with " + result.peer.handle : "No nearby peer yet"
            root.lastNotice = message
            root.actionResult(result.ok === true, message)
            root.refresh()
        })
    }

    function addMatchedFriend() {
        runAction([root.binPath, "add-matched"], function(output) {
            root.reportResult(output, "Friend saved")
            root.refresh()
        })
    }

    function shareRice(targetCode) {
        var args = [root.binPath, "share-rice"]
        if (targetCode) args.push(targetCode)
        runAction(args, function(output) {
            root.reportResult(output, "Setup signal sent")
            root.refresh()
            root.pollEvents()
        })
    }

    function startCowork(mins, targetCode) {
        var m = mins ? String(mins) : "25"
        var args = [root.binPath, "start-cowork", m]
        if (targetCode) args.push(targetCode)
        runAction(args, function(output) {
            root.reportResult(output, "Focus session started")
            root.refresh()
        })
    }

    function acceptCowork(inviteId) {
        runAction([root.binPath, "accept-cowork", inviteId], function(output) {
            root.reportResult(output, "Joined the co-work session")
            root.refresh()
        })
    }

    function dismissCowork(inviteId) {
        runAction([root.binPath, "dismiss-cowork", inviteId], function(output) {
            root.reportResult(output, "Invite dismissed")
            root.refresh()
        })
    }

    function cancelCowork() {
        runAction([root.binPath, "cancel-cowork"], function(output) {
            root.reportResult(output, "Focus session ended")
            root.refresh()
        })
    }

    function cheerFeed(itemId) {
        runAction([root.binPath, "cheer-feed", itemId], function(output) {
            root.reportResult(output, "Cheer sent")
            root.refresh()
        })
    }

    function setProject(name, desc, url) {
        runAction([root.binPath, "set-project", name, desc || "", url || ""], function(output) {
            root.reportResult(output, "Beacon updated")
            root.refresh()
        })
    }

    function setProfile(handle, projectName, projectDesc, projectUrl) {
        runAction([root.binPath, "set-profile", handle || "", projectName || "", projectDesc || "", projectUrl || ""], function(output) {
            root.reportResult(output, "Profile saved")
            root.refresh()
        })
    }

    function setInterests(interests) {
        var args = [root.binPath, "set-interests"]
        var selected = interests || []
        for (var i = 0; i < selected.length; i++) args.push(selected[i])
        runAction(args, function() { root.refresh() })
    }

    function setRoom(room) {
        runAction([root.binPath, "set-room", room || ""], function(output) {
            root.reportResult(output, "Gathering room updated")
            root.refresh()
        })
    }

    function setStatus(statusId) {
        runAction([root.binPath, "set-status", statusId], function(output) {
            root.reportResult(output, "Status updated")
            root.refresh()
        })
    }

    function setHandle(newHandle) {
        if (!newHandle || newHandle.trim() === "") return
        runAction([root.binPath, "set-handle", newHandle.trim()], function(output) {
            root.reportResult(output, "Name updated")
            root.refresh()
        })
    }

    function setAvatar(newAvatar) {
        runAction([root.binPath, "set-avatar", newAvatar], function(output) {
            root.reportResult(output, "Avatar updated")
            root.refresh()
        })
    }

    function togglePrivacy(key) {
        runAction([root.binPath, "toggle-privacy", key], function(output) {
            root.reportResult(output, "Privacy setting updated")
            root.refresh()
        })
    }

    function addFriend(code, handle) {
        if (!code || code.trim() === "") {
            root.friendCodeResult(false, "Enter a Friend Code first")
            return
        }
        var args = [root.binPath, "add-friend", code]
        if (handle) args.push(handle)
        runAction(args, function(output) {
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            root.friendCodeResult(result.ok === true, result.message || "Friend Code was not saved")
            root.lastNotice = result.message || "Friend Code was not saved"
            root.actionResult(result.ok === true, root.lastNotice)
            root.refresh()
        })
    }

    function removeFriend(code) {
        runAction([root.binPath, "remove-friend", code], function(output) {
            root.reportResult(output, "Friend removed")
            root.refresh()
        })
    }

    function interact(targetCode, action) {
        root.friendInteracted(action, targetCode)
        runAction([root.binPath, "interact", targetCode, action || "high-five"], function(output) {
            root.reportResult(output, "Signal sent")
            root.refresh()
            root.pollEvents()
        })
    }

    function refreshGlobal() {
        runAction([root.binPath, "global-refresh"], function(output) {
            root.reportResult(output, "World refreshed")
            root.refresh()
            root.pollEvents()
        })
    }

    function syncPrivateHistory(callback) {
        runAction([root.binPath, "sync-private-history"], function(output) {
            var result = root.reportResult(output, "Could not check private inbox history")
            if (callback) callback(result.ok === true, result)
            root.refresh()
        })
    }

    function sparkWorld() {
        runAction([root.binPath, "global-spark"], function(output) {
            root.reportResult(output, "Connection spark sent")
            root.refresh()
            root.pollEvents()
        })
    }

    function inviteGlobalFocus(publicKey) {
        var args = [root.binPath, "global-focus"]
        if (publicKey) args.push(publicKey)
        runAction(args, function(output) {
            root.reportResult(output, "Focus invite sent")
            root.refresh()
            root.pollEvents()
        })
    }

    function acceptGlobalFocus(pingId) {
        runAction([root.binPath, "accept-global-focus", pingId], function(output) {
            root.reportResult(output, "You joined the focus ritual")
            root.refresh()
            root.pollEvents()
        })
    }

    function cancelGlobalFocus() {
        runAction([root.binPath, "cancel-global-focus"], function(output) {
            root.reportResult(output, "World focus ended")
            root.refresh()
        })
    }

    function pingGlobal(publicKey, action) {
        root.friendInteracted(action || "hello", publicKey)
        runAction([root.binPath, "global-ping", publicKey, action || "hello"], function(output) {
            root.reportResult(output, "Wave sent")
            root.refresh()
        })
    }

    function requestFriend(publicKey) {
        runAction([root.binPath, "request-friend", publicKey], function(output) { root.reportResult(output, "Friend request sent"); root.refresh() })
    }

    function requestFriendDirect(publicKey) {
        runAction([root.binPath, "request-friend-direct", publicKey], function(output) { root.reportResult(output, "Chat invite sent"); root.refresh() })
    }

    function acceptFriendRequest(pingId) {
        runAction([root.binPath, "accept-friend", pingId], function(output) { root.reportResult(output, "You are now friends"); root.refresh() })
    }

    function declineFriendRequest(pingId) {
        runAction([root.binPath, "decline-friend", pingId], function(output) { root.reportResult(output, "Friend request declined"); root.refresh() })
    }

    function cancelFriendRequest(publicKey) {
        runAction([root.binPath, "cancel-friend", publicKey], function(output) { root.reportResult(output, "Friend request cancelled"); root.refresh() })
    }

    function sendDm(publicKey, text, mediaUrl, callback, attachmentPath, attachmentIsFolder, replyTo) {
        var payload = JSON.stringify({ text: text || "", media_url: mediaUrl || "", attachment_path: attachmentPath || "", attachment_is_folder: attachmentIsFolder === true, reply_to: replyTo || null })
        runAction([root.binPath, "send-dm", publicKey, payload], function(output) {
            var result = root.reportResult(output, "Private message sent")
            if (callback) callback(result.ok === true, result)
            root.refresh()
        })
    }

    function getPrivateSafetyCode(publicKey, callback) {
        runAction([root.binPath, "safety-code", publicKey || ""], function(output) {
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            if (!result.ok) root.actionResult(false, result.message || "Could not derive the safety code")
            if (callback) callback(result)
        })
    }

    function createGroup(name, members, callback) {
        var payload = JSON.stringify({ name: name || "", members: members || [] })
        runAction([root.binPath, "create-group", payload], function(output) {
            var result = root.reportResult(output, "Group could not be created")
            root.refresh()
            if (callback) callback(result.ok === true, result)
        })
    }

    function sendGroupMessage(groupId, text, mediaUrl, callback, attachmentPath, attachmentIsFolder, replyTo) {
        var payload = JSON.stringify({ text: text || "", media_url: mediaUrl || "", attachment_path: attachmentPath || "", attachment_is_folder: attachmentIsFolder === true, reply_to: replyTo || null })
        runAction([root.binPath, "send-group", groupId, payload], function(output) {
            var result = root.reportResult(output, "Group message could not be sent")
            if (callback) callback(result.ok === true, result)
            root.refresh()
        })
    }

    function saveAttachment(messageId, index) {
        runAction([root.binPath, "save-attachment", messageId || "", String(index || 0)], function(output) {
            root.reportResult(output, "Attachment saved to Downloads")
        })
    }

    function pickAttachment(folderMode, callback) {
        // The portal chooser is a separate desktop window, so it can appear
        // above Friends' full-screen Wayland overlay and provide native file
        // and directory selection without embedding a second file browser.
        runAction([root.binPath, "pick-attachment", folderMode ? "folder" : "file"], function(output) {
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) {
                result = { ok: false, message: "The desktop file chooser returned an invalid result" }
            }
            if (!result.ok) root.actionResult(false, result.message || "Could not open the file chooser")
            if (callback) callback(result)
        })
    }

    function reactToMessage(messageId, publicKey, groupId, emoji) {
        runAction([root.binPath, "react-message", messageId || "", publicKey || "", groupId || "", emoji || ""], function(output) {
            root.reportResult(output, "Reaction sent")
            root.refresh()
        })
    }

    function deleteMessage(messageId) {
        runAction([root.binPath, "delete-message", messageId || ""], function(output) {
            root.reportResult(output, "Message deletion sent")
            root.refresh()
        })
    }

    function deleteMessageForMe(messageId) {
        runAction([root.binPath, "delete-message-for-me", messageId || ""], function(output) {
            root.reportResult(output, "Message removed from this device")
            root.refresh()
        })
    }

    function retryPrivateMessage(messageId) {
        runAction([root.binPath, "retry-message", messageId || ""], function(output) {
            root.reportResult(output, "Message delivery confirmed")
            root.refresh()
        })
    }

    function retryPendingMessages() {
        if (root.retryingPendingMessages) return
        var nowSeconds = Math.floor(Date.now() / 1000)
        var hasDueMessage = false
        var hasDueReadReceipt = false
        for (var i = 0; i < root.globalMessages.length; i++) {
            var message = root.globalMessages[i]
            if (!message) continue
            var retryAt = Number(message.retry_at || 0)
            var interrupted = message.sendState === "Sending…"
                && nowSeconds - Number(message.timestamp || 0) >= 30
            if (message.retryable === true && Number(message.retry_attempts || 0) < 4
                    && ((retryAt > 0 && retryAt <= nowSeconds) || interrupted)) {
                hasDueMessage = true
            }
            var receiptRetryAt = Number(message.read_receipt_retry_at || 0)
            if (root.profile.privacy && root.profile.privacy.share_read_receipts === true
                    && message.incoming === true && message.read_receipt_eligible === true
                    && Number(message.read_receipt_retry_attempts || 0) < 4
                    && receiptRetryAt > 0 && receiptRetryAt <= nowSeconds)
                hasDueReadReceipt = true
            if (hasDueMessage && hasDueReadReceipt) break
        }
        if (!hasDueMessage && !hasDueReadReceipt) return
        root.retryingPendingMessages = true
        runAction([root.binPath, "retry-pending-messages"], function(output) {
            root.retryingPendingMessages = false
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            if (Number(result.attempted || 0) > 0 || Number(result.read_receipts_attempted || 0) > 0) root.refresh()
        })
    }

    function retryMessageAction(messageId) {
        runAction([root.binPath, "retry-message-action", messageId || ""], function(output) {
            root.reportResult(output, "Message action could not be retried")
            root.refresh()
        })
    }

    function editMessage(messageId, text, callback) {
        runAction([root.binPath, "edit-message", messageId || "", text || ""], function(output) {
            var result = root.reportResult(output, "Message could not be edited")
            if (callback) callback(result.ok === true, result)
            root.refresh()
        })
    }

    function setConversationPinned(kind, identifier, pinned) {
        runAction([root.binPath, "pin-conversation", kind || "", identifier || "", pinned === true ? "true" : "false"], function(output) {
            root.reportResult(output, pinned ? "Conversation pinned" : "Conversation unpinned")
            root.refresh()
        })
    }

    function setConversationMuted(kind, identifier, muted) {
        runAction([root.binPath, "mute-conversation", kind || "", identifier || "", muted === true ? "true" : "false"], function(output) {
            root.reportResult(output, muted ? "Conversation muted" : "Conversation unmuted")
            root.refresh()
        })
    }

    function markConversationRead(kind, identifier) {
        runAction([root.binPath, "mark-read", kind || "", identifier || ""], function(output) {
            var result = {}
            try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
            if (result.ok === true) root.refresh()
        })
    }

    function setBlossomServer(server, callback) {
        runAction([root.binPath, "set-blossom-server", server || ""], function(output) {
            var result = root.reportResult(output, "Large file server saved")
            root.refresh()
            if (callback) callback(result.ok === true, result)
        })
    }

    function sendCommunity(text, callback) {
        runAction([root.binPath, "send-community", text || ""], function(output) {
            var result = root.reportResult(output, "Community message sent")
            root.refresh()
            if (callback) callback(result.ok === true, result)
        })
    }

    function updatePlugin() {
        var installedBefore = root.updateInfo.current || ""
        var expectedVersion = root.updateInfo.latest || ""
        runAction(["omarchy", "plugin", "update", "community.omarchy-friends", "--yes"], function(output, exitCode) {
            if (exitCode !== 0) {
                root.lastNotice = "Friends update failed"
                root.actionResult(false, "Friends update failed")
                return
            }
            var manifestPath = Qt.resolvedUrl("manifest.json").toString().replace(/^file:\/\//, "")
            runAction(["python3", "-c", "import json,sys; print(json.load(open(sys.argv[1], encoding='utf-8'))['version'])", manifestPath], function(versionOutput, verifyExitCode) {
                var installedAfter = verifyExitCode === 0 ? String(versionOutput || "").trim() : ""
                if (!installedAfter || (expectedVersion && installedAfter !== expectedVersion) || (!expectedVersion && installedAfter === installedBefore)) {
                    var staleMessage = "Update did not reach the latest version. Installed v" + (installedAfter || installedBefore || "unknown") + (expectedVersion ? "; latest is v" + expectedVersion : "") + ". The plugin depot may still serve an older release."
                    root.lastNotice = staleMessage
                    root.actionResult(false, staleMessage)
                    return
                }
                if (installedAfter === installedBefore) {
                    var currentMessage = "Friends is already current (v" + installedAfter + ")"
                    root.lastNotice = currentMessage
                    root.actionResult(true, currentMessage)
                    return
                }
                var successMessage = "Friends updated to v" + installedAfter
                root.lastNotice = successMessage
                root.actionResult(true, successMessage)
                Util.execArgv(["omarchy-shell", "shell", "rescanPlugins"])
                daemonProc.running = false
                listenProc.running = false
                root.refresh()
                daemonRestartTimer.restart()
                listenRestartTimer.restart()
            })
        })
    }

    function blockGlobal(publicKey) {
        runAction([root.binPath, "block-global", publicKey], function(output) {
            root.reportResult(output, "Builder blocked")
            root.refresh()
        })
    }

    function unblockGlobal(publicKey) {
        runAction([root.binPath, "unblock-global", publicKey], function(output) {
            var result = root.reportResult(output, "Builder unblocked")
            if (result.ok === true) root.refreshGlobal()
        })
    }

    function dismissNudge() {
        runAction([root.binPath, "dismiss-nudge"], function() { root.refresh() })
    }

    function copyFriendCode() {
        copyProc.command = ["wl-copy", root.profile.code || ""]
        copyProc.running = true
    }

    function runAction(cmdArgs, callback) {
        var proc = actionComponent.createObject(root, { command: cmdArgs, callback: callback })
        if (!proc) {
            var unavailable = JSON.stringify({ ok: false, message: "Friends could not start this action" })
            root.reportResult(unavailable, "Friends could not start this action")
            if (callback) callback(unavailable)
            return null
        }
        proc.running = true
        return proc
    }

    function reportResult(output, fallback) {
        var result = {}
        try { result = JSON.parse(output || "{}") } catch (e) { result = {} }
        var ok = result.ok === true
        var message = result.message || fallback
        root.lastNotice = message
        root.actionResult(ok, message)
        return result
    }

    Component {
        id: actionComponent
        Process {
            id: actionProcess
            property var callback: null
            property string resultText: ""
            property string errorText: ""
            stdout: StdioCollector {
                onStreamFinished: actionProcess.resultText = this.text
            }
            stderr: StdioCollector {
                onStreamFinished: actionProcess.errorText = this.text
            }
            onExited: function(exitCode) {
                var output = resultText
                if (!output || output.trim() === "") {
                    output = JSON.stringify({
                        ok: false,
                        message: errorText.trim() || "Friends action returned no result (exit " + exitCode + ")"
                    })
                }
                if (callback) callback(output, exitCode)
                destroy()
            }
        }
    }

    Process {
        id: copyProc
        onExited: function(exitCode) {
            if (exitCode === 0) {
                Util.execArgv([
                    "omarchy-notification-send",
                    "--app-name", "Omarchy Friends",
                    "-u", "low",
                    "Friend Code Copied! 📋",
                    root.profile.code + " is ready to share with buddies."
                ])
            }
        }
    }

    Process {
        id: statusProc
        command: [root.binPath, "status-ui"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return
                try {
                    var data = JSON.parse(this.text)
                    if (data.profile) root.profile = data.profile
                    if (data.matched_peer !== undefined) root.matchedPeer = data.matched_peer
                    if (data.friends) root.friends = data.friends
                    if (data.lan_peers) root.lanPeers = data.lan_peers
                    if (data.global_peers) root.globalPeers = data.global_peers
                    if (data.global_pings) root.globalPings = data.global_pings
                    if (data.global_friendships) root.globalFriendships = data.global_friendships
                    if (data.global_messages) {
                        root.globalMessageSummaries = data.global_messages
                        if (data.global_message_counts) root.globalMessageCounts = data.global_message_counts
                        root.rebuildGlobalMessageCache()
                    }
                    if (data.global_unread_counts) root.globalUnreadCounts = data.global_unread_counts
                    if (data.global_pinned_conversations) root.globalPinnedConversations = data.global_pinned_conversations
                    if (data.global_muted_conversations) root.globalMutedConversations = data.global_muted_conversations
                    if (data.global_groups) root.globalGroups = data.global_groups
                    if (data.global_community) root.globalCommunity = data.global_community
                    if (data.global_memory) root.globalMemory = data.global_memory
                    if (data.global_private_history_cursors) root.globalPrivateHistoryCursors = data.global_private_history_cursors
                    if (data.global_private_history_relays) root.globalPrivateHistoryRelays = data.global_private_history_relays
                    if (data.global_blocked_pubkeys) root.globalBlockedPubkeys = data.global_blocked_pubkeys
                    if (data.update) root.updateInfo = data.update
                    if (data.invite_nudge !== undefined) root.inviteNudge = data.invite_nudge
                    if (data.world_event) root.worldEvent = data.world_event
                    if (data.global_status) root.globalStatus = data.global_status
                    if (data.world_prompt) root.worldPrompt = data.world_prompt
                    if (data.global_focus) root.globalFocus = data.global_focus
                    if (data.world_pulse) root.worldPulse = data.world_pulse
                    if (data.cowork) root.cowork = data.cowork
                    if (data.cowork_invites) root.coworkInvites = data.cowork_invites
                    root.onlineCount = data.online_count !== undefined ? data.online_count : 0
                    if (data.stats) root.stats = data.stats
                    if (data.available_statuses) root.availableStatuses = data.available_statuses
                    if (data.available_avatars) root.availableAvatars = data.available_avatars
                    if (data.available_interests) root.availableInterests = data.available_interests
                    root.statusRevision += 1
                } catch (e) {
                    console.log("FriendsService status parse error:", e)
                }
            }
        }
    }

    Process {
        id: eventProc
        command: [root.binPath, "poll-events"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return
                try {
                    var data = JSON.parse(this.text)
                    if (data.events && data.events.length > 0) {
                        for (var i = 0; i < data.events.length; i++) {
                            var ev = data.events[i]
                            root.lastNotice = ev.message || ""
                            root.eventReceived(ev)
                            Util.execArgv([
                                "omarchy-notification-send",
                                "--app-name", "Omarchy Friends",
                                "-u", "normal",
                                (ev.icon || "👥") + " " + (ev.from_name || "Friend"),
                                ev.message || "Interacted with you!"
                            ])
                        }
                    }
                } catch (e) {
                    console.log("FriendsService event parse error:", e)
                }
            }
        }
    }

    // Persistent LAN broadcast and listener daemon
    Process {
        id: daemonProc
        command: [root.binPath, "daemon"]
        running: true
        onExited: daemonRestartTimer.restart()
    }

    Timer {
        id: daemonRestartTimer
        interval: 3000
        repeat: false
        onTriggered: daemonProc.running = true
    }

    // Persistent relay listener: DMs, waves, and community notes arrive instantly
    Process {
        id: listenProc
        command: [root.binPath, "listen-global"]
        running: true
        onExited: listenRestartTimer.restart()
    }

    Timer {
        id: listenRestartTimer
        interval: 15000
        repeat: false
        onTriggered: listenProc.running = true
    }

    // Status refresh timer (every 8 seconds)
    Timer {
        id: statusRefreshTimer
        interval: 8000
        running: root.uiOpen
        repeat: true
        onTriggered: root.refresh()
    }

    // Retry one previously saved private message at a time. The engine uses
    // its persisted exponential backoff and republishes the same event IDs.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.retryPendingMessages()
    }

    // Event poll timer (every 5 seconds)
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.pollEvents()
    }

    Component.onCompleted: {
        if (root.uiOpen) root.refresh()
        root.pollEvents()
    }
}
