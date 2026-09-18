import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    readonly property color accentColor: Color.accent
    readonly property color mutedColor: Color.muted
    readonly property color urgentColor: Color.urgent

    readonly property var service: hostWidget && hostWidget.service ? hostWidget.service : null
    readonly property var profile: service && service.profile ? service.profile : ({
        handle: "OmarchyHacker",
        avatar: "👾",
        code: "OMAR-0000-000",
        status: "coding",
        status_name: "In The Zone",
        status_emoji: "🚀",
        status_desc: "Writing code in deep focus",
        activity: "Desktop",
        music: "",
        theme: "",
        wallpaper: "",
        focus_mins: 0,
        project_name: "",
        project_desc: "",
        project_url: "",
        interests: [],
        room: "",
        privacy: { share_window: true, share_music: true, share_lan: true, share_project: true, share_theme: false, share_interests: true, share_room: true }
    })

    readonly property var matchedPeer: service && service.matchedPeer ? service.matchedPeer : null
    readonly property var friendsList: service && service.friends ? service.friends : []
    readonly property var lanList: service && service.lanPeers ? service.lanPeers : []
    readonly property var worldPulse: service && service.worldPulse ? service.worldPulse : []
    readonly property var cowork: service && service.cowork ? service.cowork : ({ active: false, mode: "", remaining_seconds: 0, buddy_name: "", buddy_avatar: "", total_seconds: 0 })
    readonly property var coworkInvites: service && service.coworkInvites ? service.coworkInvites : []
    readonly property var availableInterests: service && service.availableInterests ? service.availableInterests : []
    readonly property var stats: service && service.stats ? service.stats : ({ hackers_met: 0, friends_made: 0, cowork_completed: 0, high_fives_sent: 0, high_fives_received: 0, rices_shared: 0 })

    property string currentTab: "match"
    property bool avatarPickerOpen: false
    property string copyFeedback: ""
    property string projectInputName: ""
    property string projectInputDesc: ""
    property string projectInputUrl: ""
    property string projectSaveNotice: ""
    property string friendInputCode: ""
    property string friendInputHandle: ""
    property string addFriendStatus: ""
    property bool addFriendSuccess: false
    property string actionNotice: ""
    property bool actionNoticeGood: true
    property string roomInput: ""

    contentWidth: root.fittedContentWidth(Style.space(450))
    contentHeight: root.fittedContentHeight(mainColumn.implicitHeight)

    Column {
        id: mainColumn
        width: parent.width
        spacing: Style.space(12)

        // PopupCard's contentItem accepts visual items only. Keep signal
        // wiring in an invisible QQuickItem so it does not get mistaken for
        // popup content during construction.
        Item {
            width: 0
            height: 0
            visible: false

            Connections {
                target: root.service
                function onFriendCodeResult(ok, message) {
                    root.addFriendStatus = message || "Friend Code was not saved"
                    root.addFriendSuccess = ok
                    friendStatusTimer.restart()
                }
                function onActionResult(ok, message) {
                    root.actionNotice = message || "Done"
                    root.actionNoticeGood = ok
                    actionNoticeTimer.restart()
                }
                function onEventReceived(event) {
                    root.actionNotice = event && event.message ? event.message : "A nearby builder sent a signal"
                    root.actionNoticeGood = true
                    actionNoticeTimer.restart()
                }
            }
        }

        // -------------------------------------------------------------
        // ACTIVE CO-WORKING BANNER (If session is running)
        // -------------------------------------------------------------
        Rectangle {
            width: parent.width
            height: Style.space(44)
            radius: Math.max(6, Style.cornerRadius)
            visible: root.cowork && root.cowork.active
            color: Qt.rgba(0.96, 0.62, 0.04, 0.15)
            border.width: 1
            border.color: "#f59e0b"

            Row {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(10)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🍅"
                    font.pixelSize: Style.space(20)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(130)
                    spacing: Style.space(1)

                    Text {
                        text: root.cowork.mode === "solo" ? "Quiet focus" : "Co-Working with " + (root.cowork.buddy_name || "a nearby builder") + " " + (root.cowork.buddy_avatar || "")
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                    }

                    Text {
                        readonly property int remSecs: root.cowork.remaining_seconds || 0
                        readonly property int mins: Math.floor(remSecs / 60)
                        readonly property int secs: remSecs % 60
                        text: mins + "m " + (secs < 10 ? "0" + secs : secs) + "s remaining"
                        color: "#f59e0b"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(24)
                    width: stopCwText.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

                    Text {
                        id: stopCwText
                        anchors.centerIn: parent
                        text: "Stop Session"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) root.service.cancelCowork()
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // INCOMING CO-WORK INVITES (EXPLICIT, LOCAL, BOUNDED)
        // -------------------------------------------------------------
        Rectangle {
            width: parent.width
            height: root.coworkInvites.length > 0 ? inviteColumn.implicitHeight + Style.space(16) : 0
            radius: Math.max(6, Style.cornerRadius)
            visible: root.coworkInvites.length > 0
            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)

            Column {
                id: inviteColumn
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                Text {
                    text: "🍅 Co-work invites"
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }

                Repeater {
                    model: root.coworkInvites

                    Row {
                        width: inviteColumn.width
                        spacing: Style.space(8)

                        Text {
                            width: parent.width - Style.space(148)
                            text: (modelData.from_avatar || "👾") + " " + (modelData.from_name || "A nearby builder") + " · " + (modelData.duration_mins || 25) + "m"
                            color: root.mutedColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: Style.space(62)
                            height: Style.space(24)
                            radius: Style.space(4)
                            color: root.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: "Join"
                                color: root.bg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.acceptCowork(modelData.id)
                            }
                        }

                        Rectangle {
                            width: Style.space(62)
                            height: Style.space(24)
                            radius: Style.space(4)
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "Dismiss"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.dismissCowork(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: root.actionNotice !== "" ? actionNoticeText.implicitHeight + Style.space(14) : 0
            visible: root.actionNotice !== ""
            radius: Math.max(6, Style.cornerRadius)
            color: root.actionNoticeGood ? Qt.rgba(0.06, 0.73, 0.51, 0.12) : Qt.rgba(0.96, 0.32, 0.28, 0.12)
            border.width: 1
            border.color: root.actionNoticeGood ? Qt.rgba(0.06, 0.73, 0.51, 0.34) : Qt.rgba(0.96, 0.32, 0.28, 0.34)

            Text {
                id: actionNoticeText
                anchors.fill: parent
                anchors.margins: Style.space(7)
                text: (root.actionNoticeGood ? "✓ " : "⚠ ") + root.actionNotice
                color: root.actionNoticeGood ? "#10b981" : root.urgentColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }

        // -------------------------------------------------------------
        // HEADER / MY STATUS ROW
        // -------------------------------------------------------------
        Rectangle {
            width: parent.width
            height: profileHeaderCol.implicitHeight + Style.space(16)
            radius: Math.max(6, Style.cornerRadius)
            color: Qt.rgba(fg.r, fg.g, fg.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.1)

            Column {
                id: profileHeaderCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Row {
                    width: parent.width
                    spacing: Style.space(10)

                    // Avatar button
                    Rectangle {
                        width: Style.space(42)
                        height: Style.space(42)
                        radius: width / 2
                        color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
                        border.width: 1.5
                        border.color: accentColor

                        Text {
                            anchors.centerIn: parent
                            text: root.profile.avatar || "👾"
                            font.pixelSize: Style.space(22)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.avatarPickerOpen = !root.avatarPickerOpen
                        }
                    }

                    Column {
                        width: parent.width - Style.space(54)
                        spacing: Style.space(3)

                        Row {
                            spacing: Style.space(6)
                            Text {
                                text: root.profile.handle || "OmarchyHacker"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.subtitle
                                font.bold: true
                            }

                            Rectangle {
                                height: Style.space(18)
                                width: myStatusPill.implicitWidth + Style.space(10)
                                radius: height / 2
                                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)

                                Text {
                                    id: myStatusPill
                                    anchors.centerIn: parent
                                    text: (root.profile.status_emoji || "🚀") + " " + (root.profile.status_name || "In The Zone")
                                    color: root.accentColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }
                            }
                        }

                        Row {
                            spacing: Style.space(8)

                            Text {
                                text: root.profile.code || "OMAR-0000-000"
                                color: root.mutedColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                            }

                            Rectangle {
                                height: Style.space(18)
                                width: copyBtnLabel.implicitWidth + Style.space(10)
                                radius: Style.space(4)
                                color: copyBtnMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.18) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    id: copyBtnLabel
                                    anchors.centerIn: parent
                                    text: root.copyFeedback !== "" ? root.copyFeedback : "📋 Copy Code"
                                    color: root.copyFeedback !== "" ? root.accentColor : root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }

                                MouseArea {
                                    id: copyBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.service) root.service.copyFriendCode()
                                        root.copyFeedback = "Copied! ✓"
                                        copyResetTimer.restart()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.profile.room !== ""
                            text: root.profile.room ? "🪩 " + root.profile.room : ""
                            color: root.accentColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }
                }

                // Avatar Picker Grid
                Flow {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: root.avatarPickerOpen

                    Repeater {
                        model: ["👾", "🦊", "🤖", "🐱", "🚀", "🧙", "🦉", "🐙", "⚡", "☕", "🎮", "🐧"]
                        Rectangle {
                            width: Style.space(28)
                            height: Style.space(28)
                            radius: Style.space(6)
                            color: avGridMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.2) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Style.space(16)
                            }

                            MouseArea {
                                id: avGridMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.service) root.service.setAvatar(modelData)
                                    root.avatarPickerOpen = false
                                }
                            }
                        }
                    }
                }

                // Live status chips
                Flow {
                    width: parent.width
                    spacing: Style.space(5)

                    Repeater {
                        model: [
                            { id: "coding", emoji: "🚀", name: "In Flow" },
                            { id: "coffee", emoji: "☕", name: "Coffee" },
                            { id: "vibe",   emoji: "🎧", name: "Vibe" },
                            { id: "debug",  emoji: "🐛", name: "Debug" },
                            { id: "night",  emoji: "🌙", name: "Late Night" },
                            { id: "rice",   emoji: "🛠️", name: "Ricing" }
                        ]

                        Rectangle {
                            height: Style.space(22)
                            width: chipLabel.implicitWidth + Style.space(12)
                            radius: height / 2
                            readonly property bool isCur: root.profile.status === modelData.id
                            color: isCur ? root.accentColor : (stChipMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.14) : Qt.rgba(fg.r, fg.g, fg.b, 0.06))
                            border.width: 1
                            border.color: isCur ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.1)

                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData.emoji + " " + modelData.name
                                color: isCur ? root.bg : root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: isCur
                            }

                            MouseArea {
                                id: stChipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.setStatus(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // TABS NAVIGATION (4 TABS)
        // -------------------------------------------------------------
        Row {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
                model: [
                    { id: "match",    label: "📡 Local Radar" },
                    { id: "friends",  label: "👥 Friends (" + root.friendsList.length + ")" },
                    { id: "pulse",    label: "✦ Local Pulse" },
                    { id: "beacon",   label: "🚀 My Beacon" }
                ]

                Rectangle {
                    height: Style.space(26)
                    width: tabBtnLabel.implicitWidth + Style.space(14)
                    radius: Style.space(6)
                    readonly property bool isSelectedTab: root.currentTab === modelData.id
                    color: isSelectedTab ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : (tabBtnMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.1) : "transparent")

                    Text {
                        id: tabBtnLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: isSelectedTab ? root.accentColor : root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: isSelectedTab
                    }

                    MouseArea {
                        id: tabBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = modelData.id
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // TAB 1: LOCAL RADAR (CONNECT TO OPT-IN PEERS)
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.currentTab === "match"

            // Header Banner
            Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.space(6)
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)

                Row {
                    anchors.centerIn: parent
                    spacing: Style.space(8)
                    Text { text: "📡"; font.pixelSize: Style.space(15) }
                    Text {
                        text: "Omarchy Local Radar • opt-in peers on this network"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                }
            }

            // Matched Peer Card
            Rectangle {
                width: parent.width
                height: root.matchedPeer ? matchedCardCol.implicitHeight + Style.space(18) : 0
                visible: root.matchedPeer !== null
                radius: Math.max(6, Style.cornerRadius)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.04)
                border.width: 1.5
                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)

                Column {
                    id: matchedCardCol
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(8)

                    // Peer Identity Row
                    Row {
                        width: parent.width
                        spacing: Style.space(10)

                        Item {
                            width: Style.space(42)
                            height: Style.space(42)

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                                border.width: 1.5
                                border.color: root.accentColor

                                Text {
                                    anchors.centerIn: parent
                                    text: root.matchedPeer ? root.matchedPeer.avatar : "👾"
                                    font.pixelSize: Style.space(22)
                                }
                            }

                            // Green online dot
                            Rectangle {
                                width: Style.space(11)
                                height: Style.space(11)
                                radius: 6
                                color: "#10b981"
                                border.width: 2
                                border.color: root.bg
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                            }
                        }

                        Column {
                            width: parent.width - Style.space(130)
                            spacing: Style.space(2)

                            Row {
                                spacing: Style.space(6)
                                Text {
                                    text: root.matchedPeer ? root.matchedPeer.handle : ""
                                    color: root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.subtitle
                                    font.bold: true
                                }
                                Text {
                                    text: root.matchedPeer ? "· local network" : ""
                                    color: root.mutedColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            Text {
                                text: root.matchedPeer ? (root.matchedPeer.status_emoji || "•") + " " + (root.matchedPeer.status_text || "Active") + " • " + (root.matchedPeer.focus_mins || 0) + "m" : ""
                                color: root.accentColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            Text {
                                visible: root.matchedPeer && root.matchedPeer.same_room && root.matchedPeer.room
                                text: root.matchedPeer && root.matchedPeer.room ? "🪩 " + root.matchedPeer.room : ""
                                color: root.accentColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                        }

                        // Next Peer button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Style.space(26)
                            width: nextPeerLabel.implicitWidth + Style.space(14)
                            radius: Style.space(6)
                            color: nextMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.2) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                id: nextPeerLabel
                                anchors.centerIn: parent
                                text: "⏭️ Next Peer"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.matchNext()
                            }
                        }
                    }

                    // Workspace & Music
                    Row {
                        width: parent.width
                        spacing: Style.space(12)

                        Row {
                            spacing: Style.space(4)
                            Text { text: "💻"; font.pixelSize: Style.font.caption }
                            Text {
                                text: root.matchedPeer && root.matchedPeer.activity ? root.matchedPeer.activity : "Private activity"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }
                        }

                        Row {
                            spacing: Style.space(4)
                            visible: root.matchedPeer && root.matchedPeer.music !== ""
                            Text { text: "🎧"; font.pixelSize: Style.font.caption }
                            Text {
                                text: root.matchedPeer ? root.matchedPeer.music : ""
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        height: visible ? implicitHeight : 0
                        spacing: Style.space(5)
                        visible: root.matchedPeer && root.matchedPeer.common_ground && root.matchedPeer.common_ground.length > 0

                        Text {
                            height: Style.space(22)
                            text: "✨ Shared ground"
                            color: root.mutedColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            verticalAlignment: Text.AlignVCenter
                        }

                        Repeater {
                            model: root.matchedPeer ? root.matchedPeer.common_ground : []

                            Rectangle {
                                height: Style.space(22)
                                width: sharedGroundLabel.implicitWidth + Style.space(12)
                                radius: height / 2
                                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)

                                Text {
                                    id: sharedGroundLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.accentColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: root.matchedPeer ? promptCol.implicitHeight + Style.space(14) : 0
                        visible: root.matchedPeer !== null
                        radius: Style.space(6)
                        color: Qt.rgba(0.96, 0.62, 0.04, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(0.96, 0.62, 0.04, 0.22)

                        Column {
                            id: promptCol
                            anchors.fill: parent
                            anchors.margins: Style.space(7)
                            spacing: Style.space(2)

                            Text {
                                text: "💬 Easy opener"
                                color: "#f59e0b"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.matchedPeer ? (root.matchedPeer.icebreaker || "What are you building today?") : ""
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Project Beacon Box
                    Rectangle {
                        width: parent.width
                        height: projCol.implicitHeight + Style.space(14)
                        radius: Style.space(6)
                        color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                        Column {
                            id: projCol
                            anchors.fill: parent
                            anchors.margins: Style.space(7)
                            spacing: Style.space(3)

                            Row {
                                spacing: Style.space(6)
                                Text { text: "🔨"; font.pixelSize: Style.font.caption }
                                Text {
                                    text: "Beacon: " + (root.matchedPeer && root.matchedPeer.project_name ? root.matchedPeer.project_name : "No project shared")
                                    color: root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.matchedPeer && root.matchedPeer.project_desc ? root.matchedPeer.project_desc : "This peer has not shared a project beacon."
                                color: root.mutedColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                visible: root.matchedPeer && root.matchedPeer.project_url !== ""
                                text: "🔗 " + (root.matchedPeer ? root.matchedPeer.project_url : "")
                                color: root.accentColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.underline: true
                            }
                        }
                    }

                    // Tactical Action Deck
                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        // Add to Friends
                        Rectangle {
                            height: Style.space(28)
                            width: addFriendPillText.implicitWidth + Style.space(14)
                            radius: Style.space(6)
                            color: root.accentColor

                            Text {
                                id: addFriendPillText
                                anchors.centerIn: parent
                                text: "🤝 Add Friend"
                                color: root.bg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.addMatchedFriend()
                            }
                        }

                        // Share Rice
                        Rectangle {
                            height: Style.space(28)
                            width: shareRiceLabel.implicitWidth + Style.space(14)
                            radius: Style.space(6)
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                id: shareRiceLabel
                                anchors.centerIn: parent
                                text: "🎨 Share Rice"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service && root.matchedPeer) root.service.shareRice(root.matchedPeer.code)
                            }
                        }

                        // Start 25m Co-Work Pomodoro
                        Rectangle {
                            height: Style.space(28)
                            width: coworkPillLabel.implicitWidth + Style.space(14)
                            radius: Style.space(6)
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.2)
                            border.width: 1
                            border.color: "#f59e0b"

                            Text {
                                id: coworkPillLabel
                                anchors.centerIn: parent
                                text: "🍅 Co-Work (25m)"
                                color: "#f59e0b"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service && root.matchedPeer) root.service.startCowork(25, root.matchedPeer.code)
                            }
                        }

                        // Say hello with a bounded opener
                        Rectangle {
                            height: Style.space(28)
                            width: helloPillLabel.implicitWidth + Style.space(14)
                            radius: Style.space(6)
                            color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                id: helloPillLabel
                                anchors.centerIn: parent
                                text: "👋 Hello"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.service && root.matchedPeer) {
                                        root.service.interact(root.matchedPeer.code, "hello")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(82)
                visible: root.matchedPeer === null
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.04)
                border.width: 1
                border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.1)

                Column {
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                        width: Style.space(390)
                        text: "No trusted peer on the local radar"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: Style.space(390)
                        text: "Enable LAN sharing on both machines, or add a Friend Code."
                        color: root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // TAB 2: FRIENDS & BUDDIES LIST
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "friends"

            Text {
                text: "Trusted friends"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            Text {
                text: "Save a real peer by Friend Code. Offline friends stay private until they reappear on LAN."
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Style.space(6)

                Rectangle {
                    width: Style.space(150)
                    height: Style.space(32)
                    radius: Style.space(5)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                    TextInput {
                        id: friendCodeEditor
                        anchors.fill: parent
                        anchors.margins: Style.space(7)
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        text: root.friendInputCode
                        onTextChanged: root.friendInputCode = text
                        selectByMouse: true
                    }

                    Text {
                        visible: friendCodeEditor.text === ""
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(7)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OMAR-1234-ABC"
                        color: root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }

                Rectangle {
                    width: parent.width - Style.space(150) - Style.space(6) - addFriendButton.width - Style.space(6)
                    height: Style.space(32)
                    radius: Style.space(5)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                    TextInput {
                        id: friendHandleEditor
                        anchors.fill: parent
                        anchors.margins: Style.space(7)
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        text: root.friendInputHandle
                        onTextChanged: root.friendInputHandle = text
                        selectByMouse: true
                    }

                    Text {
                        visible: friendHandleEditor.text === ""
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(7)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Name (optional)"
                        color: root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }

                Rectangle {
                    id: addFriendButton
                    width: Style.space(54)
                    height: Style.space(32)
                    radius: Style.space(5)
                    color: root.accentColor

                    Text {
                        anchors.centerIn: parent
                        text: "Add"
                        color: root.bg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) {
                                if (!root.friendInputCode || root.friendInputCode.trim() === "") {
                                    root.addFriendStatus = "Enter a Friend Code first"
                                    root.addFriendSuccess = false
                                    friendStatusTimer.restart()
                                    return
                                }
                                root.service.addFriend(root.friendInputCode, root.friendInputHandle)
                                root.friendInputCode = ""
                                root.friendInputHandle = ""
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.addFriendStatus !== ""
                text: root.addFriendStatus
                color: root.addFriendSuccess ? "#10b981" : root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Repeater {
                model: root.friendsList

                Rectangle {
                    width: parent.width
                    height: fRow.implicitHeight + Style.space(14)
                    radius: Style.space(6)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                    Row {
                        id: fRow
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(10)

                        Item {
                            width: Style.space(36)
                            height: Style.space(36)

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.avatar || "👾"
                                    font.pixelSize: Style.space(18)
                                }
                            }

                            Rectangle {
                                width: Style.space(10)
                                height: Style.space(10)
                                radius: 5
                                color: modelData.online ? (modelData.status === "coffee" ? "#f59e0b" : "#10b981") : root.mutedColor
                                border.width: 1.5
                                border.color: root.bg
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                            }
                        }

                        Column {
                            width: parent.width - Style.space(180)
                            spacing: Style.space(2)

                            Row {
                                spacing: Style.space(6)
                                Text {
                                    text: modelData.handle || "Friend"
                                    color: root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                }
                                Text {
                                    text: (modelData.status_emoji || "•") + " • " + (modelData.online ? "online" : "offline")
                                    color: root.mutedColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            Text {
                                width: parent.width
                                text: (modelData.activity || "Private activity") + (modelData.music ? " • 🎧 " + modelData.music : "")
                                color: root.mutedColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)

                            // High Five
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                opacity: modelData.online ? 1 : 0.45
                                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✋"
                                    font.pixelSize: Style.space(13)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.online
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.interact(modelData.code, "high-five")
                                }
                            }

                            // Start Co-Work
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                opacity: modelData.online ? 1 : 0.45
                                color: Qt.rgba(0.96, 0.62, 0.04, 0.2)

                                Text {
                                    anchors.centerIn: parent
                                    text: "🍅"
                                    font.pixelSize: Style.space(13)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.online
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.startCowork(25, modelData.code)
                                }
                            }

                            // Coffee
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                opacity: modelData.online ? 1 : 0.45
                                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "☕"
                                    font.pixelSize: Style.space(13)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.online
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.interact(modelData.code, "coffee")
                                }
                            }

                            // Remove
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: root.mutedColor
                                    font.pixelSize: Style.space(11)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.removeFriend(modelData.code)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.friendsList.length === 0
                text: "No trusted friends yet. Match a nearby peer or save a Friend Code."
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }

        // -------------------------------------------------------------
        // TAB 3: LOCAL PULSE (REAL SIGNALS FROM THIS SESSION)
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "pulse"

            Text {
                text: "Local Pulse · signals, not a feed"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            Repeater {
                model: root.worldPulse

                Rectangle {
                    width: parent.width
                    height: pulseRow.implicitHeight + Style.space(14)
                    radius: Style.space(6)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                    Row {
                        id: pulseRow
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(8)

                        Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(18) }

                        Column {
                            width: parent.width - (modelData.remote && modelData.peer_code ? Style.space(175) : Style.space(90))
                            spacing: Style.space(2)

                            Row {
                                spacing: Style.space(6)
                                Text {
                                    text: modelData.user + " " + (modelData.flag || "")
                                    color: root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: true
                                }
                                Text {
                                    text: "• " + modelData.time_ago
                                    color: root.mutedColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.text
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Reply to a real incoming signal without opening a chat box.
                        Rectangle {
                            visible: modelData.remote && modelData.peer_code
                            width: visible ? pulseReplyLabel.implicitWidth + Style.space(10) : 0
                            height: Style.space(24)
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Style.space(4)
                            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                            Text {
                                id: pulseReplyLabel
                                anchors.centerIn: parent
                                text: "👋 Hello"
                                color: root.accentColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.visible
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.interact(modelData.peer_code, "hello")
                            }
                        }

                        // Cheer button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Style.space(24)
                            width: cheerLabel.implicitWidth + Style.space(10)
                            radius: Style.space(4)
                            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                            Text {
                                id: cheerLabel
                                anchors.centerIn: parent
                                text: "👏 " + (modelData.cheers || 0)
                                color: root.accentColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.cheerFeed(modelData.id)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.worldPulse.length === 0
                text: "No signals yet. High-five a nearby builder or start a focus session."
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
            }
        }

        // -------------------------------------------------------------
        // TAB 4: MY BEACON & PROFILE SETTINGS
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "beacon"

            Text {
                text: "My Beacon · shared only with your chosen fields"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                TextInput {
                    id: projNameBox
                    anchors.fill: parent
                    anchors.margins: Style.space(7)
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: root.profile.project_name || ""
                    onTextChanged: root.projectInputName = text
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                TextInput {
                    id: projDescBox
                    anchors.fill: parent
                    anchors.margins: Style.space(7)
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: root.profile.project_desc || ""
                    onTextChanged: root.projectInputDesc = text
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                TextInput {
                    id: projUrlBox
                    anchors.fill: parent
                    anchors.margins: Style.space(7)
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: root.profile.project_url || ""
                    onTextChanged: root.projectInputUrl = text
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(28)
                radius: Style.space(6)
                color: root.accentColor

                Text {
                    anchors.centerIn: parent
                    text: "Save Beacon"
                    color: root.bg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.service) {
                            root.service.setProject(projNameBox.text, projDescBox.text, projUrlBox.text)
                            root.projectSaveNotice = "Beacon updated!"
                            beaconResetTimer.restart()
                        }
                    }
                }
            }

            Text {
                visible: root.projectSaveNotice !== ""
                text: root.projectSaveNotice
                color: "#10b981"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Text {
                text: "🪩 Gathering room (optional)"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
            }

            Text {
                text: "Use a shared nickname at a meetup or hack night. It is never inferred from your location."
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                TextInput {
                    id: roomBox
                    anchors.fill: parent
                    anchors.margins: Style.space(7)
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: root.profile.room || ""
                    onTextChanged: root.roomInput = text
                }

                Text {
                    id: roomHint
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(7)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: roomBox.text === "" && !roomBox.activeFocus
                    text: "e.g. friday-hack-night"
                    color: root.mutedColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(28)
                radius: Style.space(6)
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.34)

                Text {
                    anchors.centerIn: parent
                    text: roomBox.text === "" ? "Leave gathering room" : "Join / update gathering room"
                    color: root.accentColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.service) root.service.setRoom(roomBox.text)
                }
            }

            Text {
                text: "Find people on your wavelength"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
            }

            Text {
                text: "Pick up to four interests. They create a small shared-ground moment on a match."
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: Style.space(5)

                Repeater {
                    model: root.availableInterests

                    Rectangle {
                        height: Style.space(24)
                        width: interestChipLabel.implicitWidth + Style.space(14)
                        radius: height / 2
                        readonly property bool selected: (root.profile.interests || []).indexOf(modelData.id) >= 0
                        color: selected ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : Qt.rgba(fg.r, fg.g, fg.b, 0.07)
                        border.width: 1
                        border.color: selected ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.12)

                        Text {
                            id: interestChipLabel
                            anchors.centerIn: parent
                            text: (parent.selected ? "● " : "○ ") + modelData.emoji + " " + modelData.name
                            color: parent.selected ? root.accentColor : root.mutedColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: parent.selected
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.service) return
                                var selected = (root.profile.interests || []).slice()
                                var index = selected.indexOf(modelData.id)
                                if (index >= 0) {
                                    selected.splice(index, 1)
                                } else if (selected.length < 4) {
                                    selected.push(modelData.id)
                                } else {
                                    root.projectSaveNotice = "Choose up to four interests"
                                    beaconResetTimer.restart()
                                    return
                                }
                                root.service.setInterests(selected)
                            }
                        }
                    }
                }
            }

            Text {
                text: "Privacy controls"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
            }

            Flow {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                    model: [
                        { id: "share_lan", label: "LAN radar" },
                        { id: "share_project", label: "Project" },
                        { id: "share_window", label: "App" },
                        { id: "share_music", label: "Music" },
                        { id: "share_theme", label: "Theme" },
                        { id: "share_interests", label: "Interests" },
                        { id: "share_room", label: "Room" }
                    ]

                    Rectangle {
                        height: Style.space(24)
                        width: privacyChipLabel.implicitWidth + Style.space(14)
                        radius: height / 2
                        readonly property bool enabledForPeer: root.profile.privacy && root.profile.privacy[modelData.id]
                        color: enabledForPeer ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : Qt.rgba(fg.r, fg.g, fg.b, 0.07)
                        border.width: 1
                        border.color: enabledForPeer ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.12)

                        Text {
                            id: privacyChipLabel
                            anchors.centerIn: parent
                            text: (parent.enabledForPeer ? "● " : "○ ") + modelData.label
                            color: parent.enabledForPeer ? root.accentColor : root.mutedColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.service) root.service.togglePrivacy(modelData.id)
                        }
                    }
                }
            }

            // Lifetime Stats
            Rectangle {
                width: parent.width
                height: Style.space(48)
                radius: Style.space(6)
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)

                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    spacing: Style.space(14)

                    Text {
                        text: "📡 " + (root.stats.hackers_met || 0) + " Peers Seen"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                    Text {
                        text: "👥 " + (root.stats.friends_made || 0) + " Friends"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                    Text {
                        text: "🍅 " + (root.stats.cowork_completed || 0) + " Co-Works"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }

        Timer {
            id: friendStatusTimer
            interval: 2500
            repeat: false
            onTriggered: root.addFriendStatus = ""
        }

        Timer {
            id: copyResetTimer
            interval: 2500
            repeat: false
            onTriggered: root.copyFeedback = ""
        }

        Timer {
            id: beaconResetTimer
            interval: 2500
            repeat: false
            onTriggered: root.projectSaveNotice = ""
        }

        Timer {
            id: actionNoticeTimer
            interval: 3500
            repeat: false
            onTriggered: root.actionNotice = ""
        }
    }
}
