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
        focus_mins: 0,
        privacy: { share_window: true, share_music: true, share_lan: true, ambient_peers: true }
    })

    readonly property var friendsList: service && service.friends ? service.friends : []
    readonly property var lanList: service && service.lanPeers ? service.lanPeers : []
    readonly property var stats: service && service.stats ? service.stats : ({ high_fives_sent: 0, high_fives_received: 0, coffee_breaks_shared: 0 })

    property string currentTab: "friends"
    property bool avatarPickerOpen: false
    property string friendInputCode: ""
    property string friendInputHandle: ""
    property string addFriendStatus: ""
    property bool addFriendSuccess: false
    property string copyFeedback: ""

    contentWidth: root.fittedContentWidth(Style.space(430))
    contentHeight: root.fittedContentHeight(mainColumn.implicitHeight)

    Column {
        id: mainColumn
        width: parent.width
        spacing: Style.space(12)

        // -------------------------------------------------------------
        // HEADER / MY PROFILE CARD
        // -------------------------------------------------------------
        Rectangle {
            width: parent.width
            height: profileCol.implicitHeight + Style.space(20)
            radius: Math.max(6, Style.cornerRadius)
            color: Qt.rgba(fg.r, fg.g, fg.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

            Column {
                id: profileCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Row {
                    width: parent.width
                    spacing: Style.space(10)

                    // Avatar button
                    Rectangle {
                        width: Style.space(44)
                        height: Style.space(44)
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

                    // Handle, Friend Code, Status
                    Column {
                        width: parent.width - Style.space(56)
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

                            // Live status pill
                            Rectangle {
                                height: Style.space(18)
                                width: statusTextItem.implicitWidth + Style.space(12)
                                radius: height / 2
                                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                                Text {
                                    id: statusTextItem
                                    anchors.centerIn: parent
                                    text: (root.profile.status_emoji || "🚀") + " " + (root.profile.status_name || "In The Zone")
                                    color: root.accentColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }
                            }
                        }

                        // Friend Code + Copy
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
                                width: copyLabel.implicitWidth + Style.space(12)
                                radius: Style.space(4)
                                color: copyMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.18) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    id: copyLabel
                                    anchors.centerIn: parent
                                    text: root.copyFeedback !== "" ? root.copyFeedback : "📋 Copy Code"
                                    color: root.copyFeedback !== "" ? root.accentColor : root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }

                                MouseArea {
                                    id: copyMouse
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
                    }
                }

                // Avatar Picker Grid (toggleable)
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
                            color: avMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.2) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Style.space(16)
                            }

                            MouseArea {
                                id: avMouse
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

                // Live Activity & Focus Ticker
                Row {
                    width: parent.width
                    spacing: Style.space(12)

                    Row {
                        spacing: Style.space(4)
                        Text { text: "💻"; font.pixelSize: Style.font.caption }
                        Text {
                            text: root.profile.activity || "Desktop"
                            color: root.fg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        spacing: Style.space(4)
                        visible: root.profile.music !== ""
                        Text { text: "🎧"; font.pixelSize: Style.font.caption }
                        Text {
                            text: root.profile.music || ""
                            color: root.fg
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        spacing: Style.space(4)
                        Text { text: "🔥"; font.pixelSize: Style.font.caption }
                        Text {
                            text: (root.profile.focus_mins || 0) + "m focus"
                            color: root.mutedColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }
                }

                // Status Quick Switcher Chips
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
                            width: chipText.implicitWidth + Style.space(12)
                            radius: height / 2
                            readonly property bool isSelected: root.profile.status === modelData.id
                            color: isSelected ? root.accentColor : (chipMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.15) : Qt.rgba(fg.r, fg.g, fg.b, 0.06))
                            border.width: 1
                            border.color: isSelected ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.12)

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: modelData.emoji + " " + modelData.name
                                color: isSelected ? root.bg : root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: isSelected
                            }

                            MouseArea {
                                id: chipMouse
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
        // TABS NAVIGATION
        // -------------------------------------------------------------
        Row {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
                model: [
                    { id: "friends",  label: "👥 Friends (" + root.friendsList.length + ")" },
                    { id: "lan",      label: "📡 LAN (" + root.lanList.length + ")" },
                    { id: "add",      label: "➕ Add Friend" },
                    { id: "settings", label: "⚙️ Settings" }
                ]

                Rectangle {
                    height: Style.space(26)
                    width: tabLabel.implicitWidth + Style.space(16)
                    radius: Style.space(6)
                    readonly property bool isTabActive: root.currentTab === modelData.id
                    color: isTabActive ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : (tabMouse.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.1) : "transparent")

                    Text {
                        id: tabLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: isTabActive ? root.accentColor : root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: isTabActive
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = modelData.id
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // TAB 1: FRIENDS LIST
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "friends"

            Repeater {
                model: root.friendsList

                Rectangle {
                    width: parent.width
                    height: friendRow.implicitHeight + Style.space(16)
                    radius: Style.space(6)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                    Row {
                        id: friendRow
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(10)

                        // Avatar & online dot
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

                            // Green online dot
                            Rectangle {
                                width: Style.space(10)
                                height: Style.space(10)
                                radius: 5
                                color: modelData.status === "coffee" ? "#f59e0b" : "#10b981"
                                border.width: 1.5
                                border.color: root.bg
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                            }
                        }

                        // Info column
                        Column {
                            width: parent.width - Style.space(170)
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
                                    text: modelData.status_emoji || "🚀"
                                    font.pixelSize: Style.font.caption
                                }
                                Text {
                                    text: modelData.location ? "• " + modelData.location : ""
                                    color: root.mutedColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            // Activity & music
                            Text {
                                width: parent.width
                                text: (modelData.activity || "Hacking") + (modelData.music ? " • 🎧 " + modelData.music : "")
                                color: root.mutedColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                        }

                        // Tactile Action buttons
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)

                            // High Five ✋
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                color: hfMouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✋"
                                    font.pixelSize: Style.space(14)
                                }

                                MouseArea {
                                    id: hfMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.interact(modelData.code, "high-five")
                                }
                            }

                            // Coffee Cheer ☕
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                color: cofMouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "☕"
                                    font.pixelSize: Style.space(14)
                                }

                                MouseArea {
                                    id: cofMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.interact(modelData.code, "coffee")
                                }
                            }

                            // Kudos ⚡
                            Rectangle {
                                width: Style.space(28)
                                height: Style.space(28)
                                radius: Style.space(6)
                                color: kdMouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) : Qt.rgba(fg.r, fg.g, fg.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "⚡"
                                    font.pixelSize: Style.space(14)
                                }

                                MouseArea {
                                    id: kdMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.service) root.service.interact(modelData.code, "kudos")
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.friendsList.length === 0
                text: "No buddies yet. Click 'Add Friend' to connect with developers!"
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }

        // -------------------------------------------------------------
        // TAB 2: NEARBY ON LAN
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "lan"

            Rectangle {
                width: parent.width
                height: Style.space(38)
                radius: Style.space(6)
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)

                Row {
                    anchors.centerIn: parent
                    spacing: Style.space(8)
                    Text { text: "📡"; font.pixelSize: Style.space(16) }
                    Text {
                        text: "Auto-discovering Omarchy developers on your local network / WiFi"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }

            Repeater {
                model: root.lanList

                Rectangle {
                    width: parent.width
                    height: Style.space(48)
                    radius: Style.space(6)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.05)

                    Row {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(8)

                        Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(18) }

                        Column {
                            width: parent.width - Style.space(120)
                            spacing: Style.space(2)
                            Text {
                                text: (modelData.handle || "Peer") + " [LAN]"
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                            }
                            Text {
                                text: modelData.activity || "Omarchy Linux"
                                color: root.mutedColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: Style.space(24)
                            width: addLanText.implicitWidth + Style.space(12)
                            radius: Style.space(4)
                            color: root.accentColor

                            Text {
                                id: addLanText
                                anchors.centerIn: parent
                                text: "+ Add"
                                color: root.bg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.addFriend(modelData.code, modelData.handle)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.lanList.length === 0
                text: "No other Omarchy machines currently broadcasting on LAN.\nListening on UDP port 42424..."
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }

        // -------------------------------------------------------------
        // TAB 3: ADD FRIEND
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.currentTab === "add"

            Text {
                text: "Add Buddy via Friend Code"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)
                border.width: 1
                border.color: codeInput.activeFocus ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.15)

                TextInput {
                    id: codeInput
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.friendInputCode = text

                    Text {
                        anchors.fill: parent
                        text: "Enter code: OMAR-XXXX-XXX"
                        color: root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        visible: !codeInput.text && !codeInput.activeFocus
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.space(6)
                color: Qt.rgba(fg.r, fg.g, fg.b, 0.08)
                border.width: 1
                border.color: handleInput.activeFocus ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.15)

                TextInput {
                    id: handleInput
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.friendInputHandle = text

                    Text {
                        anchors.fill: parent
                        text: "Optional nickname (e.g. Alex)"
                        color: root.mutedColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        visible: !handleInput.text && !handleInput.activeFocus
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Style.space(32)
                radius: Style.space(6)
                color: addMouse.containsMouse ? Qt.lighter(accentColor, 1.1) : root.accentColor

                Text {
                    anchors.centerIn: parent
                    text: "Add Buddy"
                    color: root.bg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.friendInputCode || root.friendInputCode.trim() === "") {
                            root.addFriendStatus = "Please enter a valid Friend Code"
                            root.addFriendSuccess = false
                            return
                        }
                        if (root.service) {
                            root.service.addFriend(root.friendInputCode.trim(), root.friendInputHandle.trim())
                            root.addFriendStatus = "Friend code registered!"
                            root.addFriendSuccess = true
                            codeInput.text = ""
                            handleInput.text = ""
                        }
                    }
                }
            }

            Text {
                visible: root.addFriendStatus !== ""
                text: root.addFriendStatus
                color: root.addFriendSuccess ? "#10b981" : root.urgentColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }

        // -------------------------------------------------------------
        // TAB 4: SETTINGS & PRIVACY
        // -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "settings"

            Text {
                text: "Privacy & Community Preferences"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            // Toggles
            Repeater {
                model: [
                    { key: "share_window",   label: "Broadcast Active Window", desc: "Shares current editor (Neovim/VSCode/etc.)" },
                    { key: "share_music",    label: "Broadcast Current Track", desc: "Shares song title playing via MPRIS" },
                    { key: "share_lan",      label: "Local LAN Auto-Discovery", desc: "Allows peers on local WiFi/network to see you" },
                    { key: "ambient_peers",  label: "Global Ambient Hackers",  desc: "Keep companion peers active when working alone" }
                ]

                Rectangle {
                    width: parent.width
                    height: Style.space(42)
                    radius: Style.space(6)
                    color: Qt.rgba(fg.r, fg.g, fg.b, 0.05)

                    Row {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)

                        Column {
                            width: parent.width - Style.space(60)
                            spacing: Style.space(2)
                            Text {
                                text: modelData.label
                                color: root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                            }
                            Text {
                                text: modelData.desc
                                color: root.mutedColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        // Toggle button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Style.space(40)
                            height: Style.space(20)
                            radius: height / 2
                            readonly property bool isChecked: root.profile.privacy && root.profile.privacy[modelData.key] !== false
                            color: isChecked ? root.accentColor : Qt.rgba(fg.r, fg.g, fg.b, 0.2)

                            Rectangle {
                                width: Style.space(16)
                                height: Style.space(16)
                                radius: 8
                                color: root.bg
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.isChecked ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.service) root.service.togglePrivacy(modelData.key)
                            }
                        }
                    }
                }
            }

            // Stats summary card
            Rectangle {
                width: parent.width
                height: Style.space(34)
                radius: Style.space(6)
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)

                Row {
                    anchors.centerIn: parent
                    spacing: Style.space(16)
                    Text {
                        text: "✋ " + (root.stats.high_fives_sent || 0) + " High Fives Sent"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                    Text {
                        text: "☕ " + (root.stats.coffee_breaks_shared || 0) + " Coffee Breaks"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }

        Timer {
            id: copyResetTimer
            interval: 2500
            repeat: false
            onTriggered: root.copyFeedback = ""
        }
    }
}
