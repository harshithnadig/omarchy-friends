import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "community.omarchy-friends"

    property var service: null
    property bool cardOpen: false
    property bool buildCardOpen: false
    property string pendingBuildTab: "discover"
    property string pendingFriendChatKey: ""
    property bool modernUiFailed: false
    readonly property Item button: buttonItem
    readonly property bool opened: cardOpen || buildCardOpen
    readonly property bool popoutSwitchClosing: false

    function resolveService() {
        if (!service && bar && bar.shell && typeof bar.shell.serviceFor === "function") {
            service = bar.shell.serviceFor(moduleName)
            if (service) {
                service.eventReceived.connect(function(ev) {
                    Qt.callLater(function() {
                        if (pulseAnimation) pulseAnimation.restart()
                    })
                })
                service.friendInteracted.connect(function(action, target) {
                    Qt.callLater(function() {
                        if (tapAnimation) tapAnimation.restart()
                    })
                })
            }
        }
        return service
    }

    onBarChanged: resolveService()
    Component.onCompleted: resolveService()

    Timer {
        interval: 400
        repeat: true
        running: !root.service
        onTriggered: root.resolveService()
    }

    implicitWidth: buttonItem.implicitWidth
    implicitHeight: barSize

    function toggleCard() { if (cardOpen) close(); else open() }
    function open() { buildCardOpen = false; cardOpen = true }
    function close() {
        cardOpen = false
        buildCardOpen = false
    }

    function toggleBuildCard() {
        if (buildCardOpen) closeBuild()
        else openBuildTab(root.pendingBuildTab || "discover")
    }

    function openBuild() { openBuildTab("discover") }

    function openBuildTab(tabName) {
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
    function closeForPopoutSwitch() { close(); closeBuild() }

    function cycleStatus() {
        if (!service) return
        var statuses = ["coding", "coffee", "vibe", "debug", "night", "rice"]
        var cur = service.profile && service.profile.status ? service.profile.status : "coding"
        var idx = statuses.indexOf(cur)
        service.setStatus(statuses[(idx + 1) % statuses.length])
    }

    function notifyUiFallback(message) {
        if (root.modernUiFailed) return
        root.modernUiFailed = true
        Quickshell.execDetached([
            "omarchy-notification-send",
            "--app-name", "Omarchy Friends",
            "-u", "critical",
            "Friends UI fallback active",
            message || "The newest Friends shell could not load. A compatibility panel was loaded instead; run the real-system QML release check."
        ])
    }

    WidgetButton {
        id: buttonItem
        anchors.fill: parent
        bar: root.bar
        horizontalMargin: 6
        active: (root.service && root.service.cowork && root.service.cowork.active) || (root.service && root.service.globalFocus && root.service.globalFocus.active)
        activeColor: "#7c6cff"
        text: {
            if (root.service && root.service.cowork && root.service.cowork.active) {
                var s = root.service.cowork.remaining_seconds || 0
                var mins = Math.floor(s / 60)
                var secs = s % 60
                return "🍅 " + mins + ":" + (secs < 10 ? "0" + secs : String(secs))
            }
            if (root.service && root.service.globalFocus && root.service.globalFocus.active) {
                var g = root.service.globalFocus.remaining_seconds || 0
                var gm = Math.floor(g / 60)
                var gs = g % 60
                return "🍅 " + gm + ":" + (gs < 10 ? "0" + gs : String(gs))
            }
            var count = root.service && root.service.onlineCount !== undefined ? root.service.onlineCount : 0
            return "👥 " + count
        }
        tooltipText: {
            if (root.modernUiFailed)
                return "Omarchy Friends · compatibility UI active\nRun the v4.15 real-system QML check"
            if (root.service && root.service.cowork && root.service.cowork.active) {
                var s = root.service.cowork.remaining_seconds || 0
                var bName = root.service.cowork.buddy_name || "yourself"
                var title = root.service.cowork.mode === "solo" ? "🍅 Quiet focus" : "🍅 Co-Working with " + bName
                return title + " (" + Math.ceil(s / 60) + "m left)\nLeft: Friends · Middle: Build Network"
            }
            if (root.service && root.service.globalFocus && root.service.globalFocus.active) {
                var g = root.service.globalFocus.remaining_seconds || 0
                var gb = root.service.globalFocus.buddy_name || "a builder"
                return "🍅 World focus with " + gb + " (" + Math.ceil(g / 60) + "m left)\nLeft: Friends · Middle: Build Network"
            }
            var count = root.service && root.service.onlineCount !== undefined ? root.service.onlineCount : 0
            var handle = root.service && root.service.profile ? root.service.profile.handle : "Me"
            var stName = root.service && root.service.profile ? root.service.profile.status_name : "Ready"
            return "Omarchy Friends · " + count + " online\n" + handle + ": " + stName + "\nLeft-click: Friends · Middle-click: Build Network · Right-click: Cycle status"
        }
        onPressed: function(button) {
            if (button === Qt.LeftButton) root.toggleCard()
            else if (button === Qt.RightButton) root.cycleStatus()
            else if (button === Qt.MiddleButton) root.toggleBuildCard()
        }
    }

    SequentialAnimation {
        id: pulseAnimation
        loops: 2
        NumberAnimation { target: buttonItem; property: "scale"; to: 1.25; duration: 130; easing.type: Easing.OutCubic }
        NumberAnimation { target: buttonItem; property: "scale"; to: 1.0; duration: 210; easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: tapAnimation
        NumberAnimation { target: buttonItem; property: "scale"; to: 0.88; duration: 90 }
        NumberAnimation { target: buttonItem; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.OutBack }
    }

    // V3 is the primary product shell. V2 remains a compatibility fallback,
    // and Panel.qml is the final legacy safety net so a UI regression cannot
    // brick Friends on a real Omarchy installation.
    Loader {
        id: modernPanelLoader
        active: true
        source: Qt.resolvedUrl("FriendsPanelV3.qml")
        visible: false
        onLoaded: if (item) {
            root.modernUiFailed = false
            item.hostWidget = root
            Qt.callLater(function() {
                if (item) item.hostWidget = root
                root.deliverPendingFriendChat()
            })
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("Omarchy Friends V3 panel failed; enabling V2 compatibility fallback: " + source)
                root.notifyUiFallback("The V3 Friends shell could not load. The V2 compatibility UI was loaded instead; run the real-system QML release check.")
            }
        }
    }

    Loader {
        id: compatibilityPanelLoader
        active: modernPanelLoader.status === Loader.Error
        source: Qt.resolvedUrl("FriendsPanelV2.qml")
        visible: false
        onLoaded: if (item) {
            item.hostWidget = root
            Qt.callLater(function() { if (item) item.hostWidget = root })
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omarchy Friends V2 compatibility panel also failed: " + source)
    }

    Loader {
        id: fallbackPanelLoader
        active: modernPanelLoader.status === Loader.Error && compatibilityPanelLoader.status === Loader.Error
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: if (item) {
            item.hostWidget = root
            Qt.callLater(function() { if (item) item.hostWidget = root })
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omarchy Friends legacy fallback also failed: " + source)
    }

    // Build Network does network/status work of its own. Keep it completely
    // unloaded until the user opens Build so the normal Friends experience
    // does not pay for background Python processes and relay refreshes.
    Loader {
        id: buildPanelLoader
        active: root.buildCardOpen
        source: Qt.resolvedUrl("BuildNetworkPanelV3.qml")
        visible: false
        onLoaded: if (item) {
            item.hostWidget = root
            if (item.tab !== undefined) item.tab = root.pendingBuildTab
            Qt.callLater(function() {
                if (item) {
                    item.hostWidget = root
                    if (item.tab !== undefined) item.tab = root.pendingBuildTab
                }
            })
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omarchy Friends Build Network panel failed to load: " + source)
    }
}
