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

    function toggleCard() {
        if (cardOpen) close()
        else open()
    }

    function open() {
        buildCardOpen = false
        cardOpen = true
    }

    function close() { cardOpen = false }

    function toggleBuildCard() {
        if (buildCardOpen) closeBuild()
        else openBuild()
    }

    function openBuild() {
        cardOpen = false
        buildCardOpen = true
    }

    function closeBuild() { buildCardOpen = false }

    function closeForPopoutSwitch() {
        close()
        closeBuild()
    }

    function cycleStatus() {
        if (!service) return
        var statuses = ["coding", "coffee", "vibe", "debug", "night", "rice"]
        var cur = service.profile && service.profile.status ? service.profile.status : "coding"
        var idx = statuses.indexOf(cur)
        var next = statuses[(idx + 1) % statuses.length]
        service.setStatus(next)
    }

    WidgetButton {
        id: buttonItem
        anchors.fill: parent
        bar: root.bar
        horizontalMargin: 6
        active: (root.service && root.service.cowork && root.service.cowork.active) || (root.service && root.service.globalFocus && root.service.globalFocus.active)
        activeColor: "#f59e0b"
        text: {
            if (root.service && root.service.cowork && root.service.cowork.active) {
                var s = root.service.cowork.remaining_seconds || 0
                var mins = Math.floor(s / 60)
                var secs = s % 60
                var padSecs = secs < 10 ? "0" + secs : String(secs)
                return "🍅 " + mins + ":" + padSecs
            }
            if (root.service && root.service.globalFocus && root.service.globalFocus.active) {
                var g = root.service.globalFocus.remaining_seconds || 0
                var gm = Math.floor(g / 60)
                var gs = g % 60
                var gpad = gs < 10 ? "0" + gs : String(gs)
                return "🍅 " + gm + ":" + gpad
            }
            var count = root.service && root.service.onlineCount !== undefined ? root.service.onlineCount : 0
            return "👥 " + count
        }
        tooltipText: {
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
            return "Omarchy Friends · " + count + " online\n" + handle + ": " + stName + "\nLeft-click: Messages / World · Middle-click: Build Network · Right-click: Cycle Status"
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
        NumberAnimation { target: buttonItem; property: "scale"; to: 1.35; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: buttonItem; property: "scale"; to: 1.0;  duration: 220; easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: tapAnimation
        NumberAnimation { target: buttonItem; property: "scale"; to: 0.85; duration: 90 }
        NumberAnimation { target: buttonItem; property: "scale"; to: 1.0;  duration: 150; easing.type: Easing.OutBack }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            if (item) {
                item.hostWidget = root
                Qt.callLater(function() { if (item) item.hostWidget = root })
            }
        }
        onStatusChanged: {
            if (status === Loader.Error) console.warn("Omarchy Friends panel failed to load: " + source)
        }
    }

    Loader {
        id: buildPanelLoader
        active: true
        source: Qt.resolvedUrl("BuildNetworkPanelV2.qml")
        visible: false
        onLoaded: {
            if (item) {
                item.hostWidget = root
                Qt.callLater(function() { if (item) item.hostWidget = root })
            }
        }
        onStatusChanged: {
            if (status === Loader.Error) console.warn("Omarchy Friends Build Network panel failed to load: " + source)
        }
    }
}
