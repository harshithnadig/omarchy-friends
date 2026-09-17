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
        status: "coding",
        status_name: "In The Zone",
        status_emoji: "🚀",
        status_desc: "Writing code in deep focus",
        activity: "Ready",
        music: "",
        focus_mins: 0,
        privacy: { share_window: true, share_music: true, share_lan: true, ambient_peers: true }
    })
    property var friends: []
    property var lanPeers: []
    property int onlineCount: 0
    property var stats: ({ high_fives_sent: 0, high_fives_received: 0, coffee_breaks_shared: 0 })
    property var availableStatuses: []
    property var availableAvatars: []
    property string lastNotice: ""

    signal eventReceived(var event)
    signal friendInteracted(string action, string targetCode)

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

    function setStatus(statusId) {
        runAction([root.binPath, "set-status", statusId], function() { root.refresh() })
    }

    function setHandle(newHandle) {
        if (!newHandle || newHandle.trim() === "") return
        runAction([root.binPath, "set-handle", newHandle.trim()], function() { root.refresh() })
    }

    function setAvatar(newAvatar) {
        runAction([root.binPath, "set-avatar", newAvatar], function() { root.refresh() })
    }

    function togglePrivacy(key) {
        runAction([root.binPath, "toggle-privacy", key], function() { root.refresh() })
    }

    function addFriend(code, handle) {
        var args = [root.binPath, "add-friend", code]
        if (handle) args.push(handle)
        runAction(args, function() { root.refresh() })
    }

    function removeFriend(code) {
        runAction([root.binPath, "remove-friend", code], function() { root.refresh() })
    }

    function interact(targetCode, action) {
        root.friendInteracted(action, targetCode)
        runAction([root.binPath, "interact", targetCode, action || "high-five"], function() {
            root.refresh()
            root.pollEvents()
        })
    }

    function copyFriendCode() {
        copyProc.command = ["wl-copy", root.profile.code || ""]
        copyProc.running = true
    }

    function runAction(cmdArgs, callback) {
        var proc = actionComponent.createObject(root, { command: cmdArgs, callback: callback })
        proc.running = true
    }

    Component {
        id: actionComponent
        Process {
            property var callback: null
            onExited: function(exitCode) {
                if (callback) callback()
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
                    if (data.friends) root.friends = data.friends
                    if (data.lan_peers) root.lanPeers = data.lan_peers
                    root.onlineCount = data.online_count !== undefined ? data.online_count : 0
                    if (data.stats) root.stats = data.stats
                    if (data.available_statuses) root.availableStatuses = data.available_statuses
                    if (data.available_avatars) root.availableAvatars = data.available_avatars
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

    // Status refresh timer (every 6 seconds)
    Timer {
        interval: 6000
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
