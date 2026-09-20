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
    readonly property var service: hostWidget && hostWidget.service ? hostWidget.service : null
    readonly property var profile: service && service.profile ? service.profile : ({ handle: "OmarchyHacker", avatar: "👾", status_name: "Ready", project_name: "", project_desc: "", project_url: "", privacy: ({ share_global: true }) })
    readonly property var world: service && service.globalPeers ? service.globalPeers : []
    readonly property var pulse: service && service.worldPulse ? service.worldPulse : []
    readonly property var pings: service && service.globalPings ? service.globalPings : []
    readonly property var worldStatus: service && service.globalStatus ? service.globalStatus : ({ visible: true })

    property string tab: "world"
    property int selectedPeer: 0
    property bool ideaOpen: false
    property string ideaText: ""
    property string handleDraft: ""
    property string projectNameDraft: ""
    property string projectDescDraft: ""
    property string projectUrlDraft: ""
    property string notice: ""

    readonly property string issueUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=enhancement&title=Feature%20idea"

    contentWidth: root.fittedContentWidth(Style.space(420))
    contentHeight: root.fittedContentHeight(deck.implicitHeight)

    function tabList() { return ["world", "showcase", "activity", "profile"] }
    function moveTab(delta) {
        var list = tabList()
        var index = list.indexOf(root.tab)
        root.tab = list[(index + delta + list.length) % list.length]
    }
    function projects() {
        var result = []
        for (var i = 0; i < root.world.length; i++) {
            if (root.world[i].project_name || root.world[i].project_desc || root.world[i].project_url) result.push(root.world[i])
        }
        return result
    }
    function showNotice(message) { root.notice = message; noticeTimer.restart() }
    function sayHi(peer) { if (root.service && peer && peer.public_key) root.service.pingGlobal(peer.public_key, "hello") }
    function openProfile() {
        root.tab = "profile"
        root.handleDraft = root.profile.handle || ""
        root.projectNameDraft = root.profile.project_name || ""
        root.projectDescDraft = root.profile.project_desc || ""
        root.projectUrlDraft = root.profile.project_url || ""
    }
    function saveProfile() {
        if (!root.service) return
        if (root.handleDraft.trim() !== "") root.service.setHandle(root.handleDraft)
        root.service.setProject(root.projectNameDraft, root.projectDescDraft, root.projectUrlDraft)
        showNotice("Profile saved")
    }
    function submitIdea() {
        if (root.ideaText.trim() === "") { showNotice("Write an idea first"); return }
        var payload = "Omarchy Friends feature idea:\n\n" + root.ideaText.trim()
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(payload) + " | wl-copy"])
        Quickshell.execDetached(["xdg-open", root.issueUrl])
        root.ideaOpen = false
        showNotice("Copied and opened GitHub")
    }
    function keyPressed(event) {
        if (!root.open) return
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }
        if (event.key === Qt.Key_Left || event.text === "h") { moveTab(-1); event.accepted = true; return }
        if (event.key === Qt.Key_Right || event.text === "l") { moveTab(1); event.accepted = true; return }
        if (event.key === Qt.Key_1) { root.tab = "world"; event.accepted = true; return }
        if (event.key === Qt.Key_2) { root.tab = "showcase"; event.accepted = true; return }
        if (event.key === Qt.Key_3) { root.tab = "activity"; event.accepted = true; return }
        if (event.key === Qt.Key_4) { openProfile(); event.accepted = true; return }
        if (event.text === "r" && root.tab === "world" && root.service) { root.service.refreshGlobal(); event.accepted = true; return }
        if (event.key === Qt.Key_Down || event.text === "j") { root.selectedPeer = Math.min(Math.max(0, root.world.length - 1), root.selectedPeer + 1); event.accepted = true; return }
        if (event.key === Qt.Key_Up || event.text === "k") { root.selectedPeer = Math.max(0, root.selectedPeer - 1); event.accepted = true; return }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.tab === "world" && root.world.length > 0) { sayHi(root.world[root.selectedPeer]); event.accepted = true }
    }

    Timer { id: noticeTimer; interval: 2600; onTriggered: root.notice = "" }

    Item {
        width: 1
        height: 1
        visible: false
        focus: root.open
        Keys.onPressed: function(event) { root.keyPressed(event) }
        Connections {
            target: root
            function onOpenChanged() { if (root.open) Qt.callLater(function() { parent.forceActiveFocus() }) }
        }
        Connections {
            target: root.service
            function onActionResult(ok, message) { root.showNotice(message || (ok ? "Done" : "Something went wrong")) }
            function onEventReceived(event) { root.showNotice(event && event.message ? event.message : "A builder sent a signal") }
        }
    }

    Column {
        id: deck
        width: parent.width
        spacing: Style.space(11)

        Row {
            width: parent.width
            spacing: Style.space(9)
            Rectangle {
                width: Style.space(38); height: Style.space(38); radius: width / 2
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.16); border.width: 1; border.color: accent
                Text { anchors.centerIn: parent; text: root.profile.avatar || "👾"; font.pixelSize: Style.space(20) }
            }
            Column {
                width: parent.width - editButton.width - Style.space(52); spacing: Style.space(2)
                Text { text: root.profile.handle || "OmarchyHacker"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight }
                Text { text: (root.profile.status_emoji || "•") + " " + (root.profile.status_name || "Ready"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Rectangle {
                id: editButton; width: Style.space(42); height: Style.space(27); radius: height / 2; color: Qt.rgba(fg.r, fg.g, fg.b, 0.07)
                Text { anchors.centerIn: parent; text: "Edit"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openProfile() }
            }
        }

        Flow {
            width: parent.width; spacing: Style.space(5)
            Repeater {
                model: [{ id: "world", label: "World" }, { id: "showcase", label: "Showcase" }, { id: "activity", label: "Activity" }, { id: "profile", label: "Profile" }]
                Rectangle {
                    height: Style.space(28); width: tabText.implicitWidth + Style.space(18); radius: height / 2
                    color: root.tab === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.2) : Qt.rgba(fg.r, fg.g, fg.b, 0.045)
                    border.width: root.tab === modelData.id ? 1 : 0; border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                    Text { id: tabText; anchors.centerIn: parent; text: modelData.label; color: root.tab === modelData.id ? accent : muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: root.tab === modelData.id }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (modelData.id === "profile") root.openProfile(); else root.tab = modelData.id } }
                }
            }
        }

        Rectangle {
            visible: root.notice !== ""
            width: parent.width; height: visible ? noticeText.implicitHeight + Style.space(14) : 0; radius: Style.space(6)
            color: Qt.rgba(accent.r, accent.g, accent.b, 0.1)
            Text { id: noticeText; anchors.fill: parent; anchors.margins: Style.space(7); text: root.notice; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap }
        }

        Column {
            visible: root.tab === "world"; width: parent.width; spacing: Style.space(9)
            Row {
                width: parent.width; spacing: Style.space(8)
                Column { width: parent.width - refreshButton.width - Style.space(8); spacing: Style.space(2); Text { text: "World"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }; Text { text: root.worldStatus.visible ? root.world.length + " builders online" : "You are hidden"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption } }
                Rectangle { id: refreshButton; width: refreshText.implicitWidth + Style.space(16); height: Style.space(28); radius: height / 2; color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); Text { id: refreshText; anchors.centerIn: parent; text: "Refresh"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.refreshGlobal() } }
            }

            Rectangle {
                visible: root.pings.length > 0; width: parent.width; height: visible ? pingRow.implicitHeight + Style.space(14) : 0; radius: Style.space(7); color: Qt.rgba(0.96, 0.62, 0.04, 0.1)
                Row { id: pingRow; anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8); Text { text: "👋"; font.pixelSize: Style.space(17) }; Text { width: parent.width - pingAction.width - Style.space(34); text: root.pings[0] && root.pings[0].handle ? root.pings[0].handle + " sent you a wave" : "Someone sent you a wave"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }; Rectangle { id: pingAction; width: pingActionText.implicitWidth + Style.space(14); height: Style.space(25); radius: height / 2; color: accent; Text { id: pingActionText; anchors.centerIn: parent; text: "Wave back"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: if (root.service && root.pings[0]) root.service.pingGlobal(root.pings[0].public_key, "hello") } } }
            }

            Repeater {
                model: root.world
                Rectangle {
                    width: parent.width; height: worldRow.implicitHeight + Style.space(18); radius: Style.space(8)
                    color: index === root.selectedPeer ? Qt.rgba(accent.r, accent.g, accent.b, 0.1) : Qt.rgba(fg.r, fg.g, fg.b, 0.045)
                    border.width: index === root.selectedPeer ? 1 : 0; border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.3)
                    MouseArea { anchors.fill: parent; onClicked: root.selectedPeer = index }
                    Row { id: worldRow; anchors.fill: parent; anchors.margins: Style.space(9); spacing: Style.space(9); Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(22); anchors.verticalCenter: parent.verticalCenter }; Column { width: parent.width - hiButton.width - Style.space(40); spacing: Style.space(3); Row { spacing: Style.space(6); Text { text: modelData.handle || "Omarchy builder"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }; Text { text: modelData.status_emoji || "•"; color: accent; font.pixelSize: Style.font.caption } }; Text { width: parent.width; text: modelData.project_name || modelData.activity || "Building in private"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }; Text { visible: modelData.common_ground && modelData.common_ground.length > 0; width: parent.width; text: "✦ " + (modelData.common_ground || []).join(" · "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight } }; Rectangle { id: hiButton; width: hiText.implicitWidth + Style.space(16); height: Style.space(28); radius: height / 2; color: Qt.rgba(accent.r, accent.g, accent.b, 0.18); anchors.verticalCenter: parent.verticalCenter; Text { id: hiText; anchors.centerIn: parent; text: "Say hi"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sayHi(modelData) } } }
                }
            }

            Rectangle {
                visible: root.world.length === 0; width: parent.width; height: emptyWorld.implicitHeight + Style.space(22); radius: Style.space(9); color: Qt.rgba(accent.r, accent.g, accent.b, 0.07)
                Column { id: emptyWorld; anchors.centerIn: parent; width: parent.width - Style.space(36); spacing: Style.space(5); Text { width: parent.width; text: root.worldStatus.visible ? "You are early." : "You are hidden."; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; horizontalAlignment: Text.AlignHCenter }; Text { width: parent.width; text: root.worldStatus.visible ? "Share your setup and give the next builder a reason to say hello." : "Open Profile when you are ready to appear."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }; Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: emptyWorldAction.implicitWidth + Style.space(20); height: Style.space(28); radius: height / 2; color: accent; Text { id: emptyWorldAction; anchors.centerIn: parent; text: root.worldStatus.visible ? "Share setup" : "Open Profile"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: root.openProfile() } } }
            }
        }

        Column {
            visible: root.tab === "showcase"; width: parent.width; spacing: Style.space(9)
            Text { text: "Showcase"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
            Text { text: "See what people are building and borrow a little inspiration."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            Rectangle { width: parent.width; height: Style.space(44); radius: Style.space(8); color: Qt.rgba(accent.r, accent.g, accent.b, 0.12); Row { anchors.fill: parent; anchors.margins: Style.space(9); spacing: Style.space(8); Text { text: "✦"; color: accent; font.pixelSize: Style.space(18); anchors.verticalCenter: parent.verticalCenter }; Text { width: parent.width - addSetup.width - Style.space(28); text: root.profile.project_name ? "Your setup is live here." : "Add one project so people can discover you."; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }; Rectangle { id: addSetup; width: addSetupText.implicitWidth + Style.space(16); height: Style.space(26); radius: height / 2; color: accent; anchors.verticalCenter: parent.verticalCenter; Text { id: addSetupText; anchors.centerIn: parent; text: root.profile.project_name ? "Edit" : "Add setup"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: root.openProfile() } } } }
            Repeater { model: root.projects(); Rectangle { width: parent.width; height: showcaseRow.implicitHeight + Style.space(18); radius: Style.space(8); color: Qt.rgba(fg.r, fg.g, fg.b, 0.045); Row { id: showcaseRow; anchors.fill: parent; anchors.margins: Style.space(9); spacing: Style.space(9); Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(22); anchors.verticalCenter: parent.verticalCenter }; Column { width: parent.width - showcaseHi.width - Style.space(40); spacing: Style.space(3); Row { spacing: Style.space(5); Text { text: modelData.project_name || "Omarchy setup"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }; Text { text: "by " + (modelData.handle || "builder"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight } }; Text { width: parent.width; text: modelData.project_desc || "A setup worth exploring"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; elide: Text.ElideRight } }; Rectangle { id: showcaseHi; width: showcaseHiText.implicitWidth + Style.space(14); height: Style.space(26); radius: height / 2; color: Qt.rgba(accent.r, accent.g, accent.b, 0.18); anchors.verticalCenter: parent.verticalCenter; Text { id: showcaseHiText; anchors.centerIn: parent; text: "Say hi"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: root.sayHi(modelData) } } } } }
            Text { visible: root.projects().length === 0; width: parent.width; text: "The gallery is empty for now. Add your setup and be the first post."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
        }

        Column {
            visible: root.tab === "activity"; width: parent.width; spacing: Style.space(9)
            Text { text: "Activity"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
            Text { text: "Only signals from real builders appear here."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Repeater { model: root.pulse; Rectangle { width: parent.width; height: activityRow.implicitHeight + Style.space(16); radius: Style.space(8); color: Qt.rgba(fg.r, fg.g, fg.b, 0.045); Row { id: activityRow; anchors.fill: parent; anchors.margins: Style.space(9); spacing: Style.space(8); Text { text: modelData.avatar || "👾"; font.pixelSize: Style.space(19) }; Column { width: parent.width - activityButton.width - Style.space(34); spacing: Style.space(2); Text { text: (modelData.user || "A builder") + " · " + (modelData.time_ago || "now"); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; Text { width: parent.width; text: modelData.text || "Sent a signal"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap } }; Rectangle { id: activityButton; visible: modelData.remote && modelData.peer_code; width: activityButtonText.implicitWidth + Style.space(14); height: Style.space(26); radius: height / 2; color: Qt.rgba(accent.r, accent.g, accent.b, 0.18); anchors.verticalCenter: parent.verticalCenter; Text { id: activityButtonText; anchors.centerIn: parent; text: "Reply"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: if (root.service) root.service.interact(modelData.peer_code, "hello") } } } } }
            Text { visible: root.pulse.length === 0; width: parent.width; text: "No activity yet. Say hi to someone in World to start."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
        }

        Column {
            visible: root.tab === "profile"; width: parent.width; spacing: Style.space(9)
            Text { text: "Profile"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
            Text { text: "Choose what people see when you appear in World."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            Text { text: "Name"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            Rectangle { width: parent.width; height: Style.space(32); radius: Style.space(6); color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); TextInput { anchors.fill: parent; anchors.margins: Style.space(8); text: root.handleDraft || root.profile.handle || "OmarchyHacker"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; onTextChanged: root.handleDraft = text } }
            Text { text: "Status"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            Flow {
                width: parent.width
                spacing: Style.space(5)
                Repeater {
                    model: root.service && root.service.availableStatuses && root.service.availableStatuses.length ? root.service.availableStatuses : [{ id: "coding", name: "In the zone", emoji: "🚀" }, { id: "learning", name: "Learning", emoji: "📚" }, { id: "building", name: "Building", emoji: "🔨" }, { id: "available", name: "Up for a chat", emoji: "💬" }]
                    Rectangle {
                        height: Style.space(25)
                        width: statusChip.implicitWidth + Style.space(14)
                        radius: height / 2
                        color: root.profile.status === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.2) : Qt.rgba(fg.r, fg.g, fg.b, 0.06)
                        border.width: root.profile.status === modelData.id ? 1 : 0
                        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                        Text { id: statusChip; anchors.centerIn: parent; text: modelData.emoji + " " + modelData.name; color: root.profile.status === modelData.id ? accent : muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: root.profile.status === modelData.id }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.setStatus(modelData.id) }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: Style.space(38)
                radius: Style.space(8)
                color: root.profile.privacy && root.profile.privacy.share_global ? Qt.rgba(0.06, 0.73, 0.51, 0.1) : Qt.rgba(fg.r, fg.g, fg.b, 0.06)
                border.width: 1
                border.color: root.profile.privacy && root.profile.privacy.share_global ? Qt.rgba(0.06, 0.73, 0.51, 0.28) : Qt.rgba(fg.r, fg.g, fg.b, 0.1)
                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)
                    Text { text: root.profile.privacy && root.profile.privacy.share_global ? "●" : "○"; color: root.profile.privacy && root.profile.privacy.share_global ? "#10b981" : muted; font.pixelSize: Style.space(14); anchors.verticalCenter: parent.verticalCenter }
                    Text { width: parent.width - visibilityAction.width - Style.space(24); text: root.profile.privacy && root.profile.privacy.share_global ? "Visible in World" : "Hidden from World"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { id: visibilityAction; width: visibilityText.implicitWidth + Style.space(12); height: Style.space(23); radius: height / 2; color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); anchors.verticalCenter: parent.verticalCenter; Text { id: visibilityText; anchors.centerIn: parent; text: "Change"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.togglePrivacy("share_global") } }
                }
            }
            Text { text: "Showcase"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            Text { text: "A project name and one sentence is enough."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Rectangle { width: parent.width; height: Style.space(32); radius: Style.space(6); color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); TextInput { anchors.fill: parent; anchors.margins: Style.space(8); text: root.projectNameDraft || root.profile.project_name || ""; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; onTextChanged: root.projectNameDraft = text } }
            Rectangle { width: parent.width; height: Style.space(54); radius: Style.space(6); color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); TextEdit { anchors.fill: parent; anchors.margins: Style.space(8); text: root.projectDescDraft || root.profile.project_desc || ""; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap; onTextChanged: root.projectDescDraft = text } }
            Text { text: "Optional URL"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Rectangle { width: parent.width; height: Style.space(32); radius: Style.space(6); color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); TextInput { anchors.fill: parent; anchors.margins: Style.space(8); text: root.projectUrlDraft || root.profile.project_url || ""; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; onTextChanged: root.projectUrlDraft = text } }
            Rectangle { width: parent.width; height: Style.space(32); radius: height / 2; color: accent; Text { anchors.centerIn: parent; text: "Save profile"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveProfile() } }
            Rectangle { width: parent.width; height: ideaOpen ? ideaColumn.implicitHeight + Style.space(18) : Style.space(30); radius: Style.space(7); color: Qt.rgba(0.96, 0.62, 0.04, 0.08); Column { id: ideaColumn; anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(6); Row { width: parent.width; Text { width: parent.width - ideaToggle.width; text: "Have an idea?"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; Rectangle { id: ideaToggle; width: Style.space(52); height: Style.space(24); radius: height / 2; color: Qt.rgba(fg.r, fg.g, fg.b, 0.08); Text { anchors.centerIn: parent; text: root.ideaOpen ? "Close" : "Open"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }; MouseArea { anchors.fill: parent; onClicked: root.ideaOpen = !root.ideaOpen } } }; TextEdit { visible: root.ideaOpen; width: parent.width; height: Style.space(54); text: root.ideaText; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap; onTextChanged: root.ideaText = text }; Rectangle { visible: root.ideaOpen; width: parent.width; height: Style.space(28); radius: height / 2; color: accent; Text { anchors.centerIn: parent; text: "Copy and open GitHub"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: root.submitIdea() } } } }
        }
    }
}
