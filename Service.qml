import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
    id: root

    readonly property string binPath: {
        var local = Qt.resolvedUrl("bin/omarchy-friends").toString().replace(/^file:\/\//, "")
        return local
    }

    property var profile: ({
        handle: "OmarchyHacker",
        avatar: "👾",
        code: "OMAR-0000-000",
        public_key: "",
        global_visible: true,
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
        privacy: { share_window: true, share_music: true, share_lan: true, share_project: true, share_theme: false, share_interests: true, share_room: true, share_global: true }
    })
    property var matchedPeer: null
    property var friends: []
    property var lanPeers: []
    property var globalPeers: []
    property var globalPings: []
    property var globalFriendships: ({})
    property var globalMessages: []
    property var globalGroups: []
    property var globalCommunity: []
    property var globalMemory: ({})
    property var updateInfo: ({ available: false, current: "", latest: "" })
    property bool inviteNudge: false
    property var worldEvent: ({ title: "Ship-It Friday", live: false, label: "" })
    property var globalStatus: ({ visible: true, online_count: 0, relay_count: 0, relay_total: 0, last_sync_age: "never", last_error: "" })
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

    function sendDm(publicKey, text, mediaUrl) {
        var payload = JSON.stringify({ text: text || "", media_url: mediaUrl || "" })
        runAction([root.binPath, "send-dm", publicKey, payload], function(output) { root.reportResult(output, "Private message sent"); root.refresh() })
    }

    function createGroup(name, members) {
        var payload = JSON.stringify({ name: name || "", members: members || [] })
        runAction([root.binPath, "create-group", payload], function(output) { root.reportResult(output, "Group could not be created"); root.refresh() })
    }

    function sendGroupMessage(groupId, text, mediaUrl) {
        var payload = JSON.stringify({ text: text || "", media_url: mediaUrl || "" })
        runAction([root.binPath, "send-group", groupId, payload], function(output) { root.reportResult(output, "Group message could not be sent"); root.refresh() })
    }

    function sendCommunity(text) {
        runAction([root.binPath, "send-community", text || ""], function(output) { root.reportResult(output, "Community message sent"); root.refresh() })
    }

    function updatePlugin() {
        runAction(["omarchy", "plugin", "update", "community.omarchy-friends", "--yes"], function(output, exitCode) {
            if (exitCode !== 0) {
                root.lastNotice = "Friends update failed"
                root.actionResult(false, "Friends update failed")
                return
            }
            root.lastNotice = "Friends update checked"
            root.actionResult(true, "Friends update checked")
            Util.execArgv(["omarchy-shell", "shell", "rescanPlugins"])
            // Reload background workers so they run the new code, not the old one.
            daemonProc.running = false
            listenProc.running = false
            root.refresh()
            daemonRestartTimer.restart()
            listenRestartTimer.restart()
        })
    }

    function blockGlobal(publicKey) {
        runAction([root.binPath, "block-global", publicKey], function(output) {
            root.reportResult(output, "Builder hidden")
            root.refresh()
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
            return
        }
        proc.running = true
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
                if (exitCode !== 0 && (!output || output.trim() === "")) {
                    output = JSON.stringify({
                        ok: false,
                        message: errorText.trim() || "Friends action failed (exit " + exitCode + ")"
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
        command: [root.binPath, "status"]
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
                    if (data.global_messages) root.globalMessages = data.global_messages
                    if (data.global_groups) root.globalGroups = data.global_groups
                    if (data.global_community) root.globalCommunity = data.global_community
                    if (data.global_memory) root.globalMemory = data.global_memory
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

    // Status refresh timer (every 4 seconds)
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Event poll timer (every 2.5 seconds)
    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.pollEvents()
    }

    Component.onCompleted: {
        root.refresh()
        root.pollEvents()
    }
}
