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
    open: hostWidget ? hostWidget.buildCardOpen === true : false
    triggerMode: "click"

    // Friends owns a stable cool product palette instead of inheriting every
    // Omarchy theme hue. This keeps Build Network visually consistent with
    // FriendsPanelV2 even on red/gold/green desktop themes.
    readonly property color fg: "#f3f5ff"
    readonly property color bg: "#070b14"
    readonly property color accent: "#7c6cff"
    readonly property color muted: "#98a2ba"
    readonly property color faint: "#68738d"
    readonly property color glassLine: Qt.rgba(0.84, 0.87, 1.0, 0.10)
    readonly property var friendsService: hostWidget && hostWidget.service ? hostWidget.service : null

    property string tab: "discover"
    property string createKind: "idea"
    property string titleDraft: ""
    property string bodyDraft: ""
    property string urlDraft: ""
    property string tagsDraft: ""
    property string extraDraft: ""
    property string updateResult: "working"
    property string notice: ""
    property bool useDetectedEnvironment: true

    // v4.14-final: promise-complete UI wiring
    property string componentSetupId: ""
    property string componentTypeDraft: "plugin"
    property string componentNameDraft: ""
    property string componentUrlDraft: ""
    property string availabilityMode: "can_help"
    property string availabilitySkillsDraft: ""
    property string availabilityNoteDraft: ""
    property int availabilityMinutes: 30
    property string solutionHelpId: ""
    property string solutionDraft: ""

    contentWidth: root.fittedContentWidth(Style.space(620))
    contentHeight: root.fittedContentHeight(contentColumn.implicitHeight)

    BuildNetworkService {
        id: build
        onActionResult: function(ok, message) {
            root.notice = message || (ok ? "Done" : "Build Network action failed")
            noticeTimer.restart()
        }
        onShareTextReady: function(text) {
            root.copyText(text, "Share text copied")
        }
    }

    Timer { id: noticeTimer; interval: 3300; onTriggered: root.notice = "" }

    function csv(value) {
        var parts = String(value || "").split(",")
        var out = []
        for (var i = 0; i < parts.length; i++) {
            var item = parts[i].trim()
            if (item && out.indexOf(item) < 0) out.push(item)
        }
        return out
    }

    function openUrl(url) {
        if (url && (url.indexOf("https://") === 0 || url.indexOf("http://") === 0))
            Quickshell.execDetached(["xdg-open", url])
    }

    function copyText(text, message) {
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(String(text || "")) + " | wl-copy"])
        root.notice = message || "Copied"
        noticeTimer.restart()
    }

    function incomingFriendRequest(publicKey) {
        var pings = root.friendsService && root.friendsService.globalPings ? root.friendsService.globalPings : []
        for (var i = 0; i < pings.length; i++) {
            if (pings[i] && pings[i].action === "friend_request" && pings[i].public_key === publicKey) return pings[i]
        }
        return null
    }

    function builderActionLabel(publicKey) {
        if (!publicKey || !root.friendsService) return "Connect"
        var friendships = root.friendsService.globalFriendships || ({})
        var relation = friendships[publicKey]
        if (relation && relation.status === "friends") return "Chat"
        if (root.incomingFriendRequest(publicKey)) return "Accept"
        if (relation && relation.status === "pending") return "Requested"
        return "Connect"
    }

    function connectBuilder(publicKey) {
        if (!publicKey || !root.friendsService) {
            root.notice = "Open Friends to connect with this builder"
            noticeTimer.restart()
            return
        }
        var friendships = root.friendsService.globalFriendships || ({})
        var relation = friendships[publicKey]
        if (relation && relation.status === "friends") {
            if (root.hostWidget && typeof root.hostWidget.openFriendChat === "function") {
                root.hostWidget.openFriendChat(publicKey)
                root.notice = "Opening private chat"
            } else {
                root.notice = "Open Friends → Chats to continue the conversation"
            }
            noticeTimer.restart()
            return
        }
        var incoming = root.incomingFriendRequest(publicKey)
        if (incoming) {
            root.friendsService.acceptFriendRequest(incoming.id)
            root.notice = "Friend request accepted — Chat will be ready after sync"
            noticeTimer.restart()
            return
        }
        if (relation && relation.status === "pending") {
            root.notice = "Friend request already pending"
            noticeTimer.restart()
            return
        }
        root.friendsService.requestFriend(publicKey)
        root.notice = "Friend request sent through Friends"
        noticeTimer.restart()
    }

    function repoIssues(url) { return url && url.indexOf("https://github.com/") === 0 ? url.replace(/\/$/, "") + "/issues" : "" }
    function repoPulls(url) { return url && url.indexOf("https://github.com/") === 0 ? url.replace(/\/$/, "") + "/pulls" : "" }

    function setupRecipe(item) {
        return [
            "Omarchy Setup Card: " + (item.title || "Setup"),
            "By: " + (item.author || "OmarchyBuilder"),
            "Theme: " + (item.theme || "—"),
            "Plugins: " + ((item.plugins || []).join ? (item.plugins || []).join(", ") : ""),
            "Components: " + ((item.components || []).join ? (item.components || []).join(", ") : ""),
            "Shell: " + (item.shell || "—"),
            "Terminal: " + (item.terminal || "—"),
            "Editor: " + (item.editor || "—"),
            "Repo: " + (item.repo_url || "—"),
            "Notes: " + (item.notes || "")
        ].join("\n")
    }

    function comparisonText() {
        var c = build.setupComparison || ({})
        if (!c.setup_id) return ""
        var lines = []
        if (c.missing_plugins && c.missing_plugins.length)
            lines.push("Missing · " + c.missing_plugins.join(", "))
        if (c.already_have_plugins && c.already_have_plugins.length)
            lines.push("Already have · " + c.already_have_plugins.join(", "))
        var fields = c.fields || []
        for (var i = 0; i < fields.length; i++) {
            var f = fields[i]
            if (f.status === "different") lines.push(f.label + " · " + (f.current || "—") + " → " + (f.wanted || "—"))
        }
        return lines.length ? lines.join("\n") : "Your local setup already matches the shared metadata."
    }

    function clearDrafts() {
        root.titleDraft = ""
        root.bodyDraft = ""
        root.urlDraft = ""
        root.tagsDraft = ""
        root.extraDraft = ""
    }

    function submitCreate() {
        var title = root.titleDraft.trim()
        var body = root.bodyDraft.trim()
        var url = root.urlDraft.trim()
        var tags = root.csv(root.tagsDraft)
        var extra = root.extraDraft.trim()
        if (root.createKind !== "update" && !title) {
            root.notice = "Give it a title first"
            noticeTimer.restart()
            return
        }
        if (root.createKind === "idea") build.createIdea(title, body, tags)
        else if (root.createKind === "room") build.createRoom(title, body, url, tags, [], "")
        else if (root.createKind === "setup") build.createSetup(title || "My Omarchy setup", url, "", body, true)
        else if (root.createKind === "test") build.createTest(title, url, extra, tags, body, "")
        else if (root.createKind === "help") build.createHelp(title, body, extra, tags, root.useDetectedEnvironment)
        else if (root.createKind === "solution") build.createSolution(title, extra, body, tags, url)
        else if (root.createKind === "ship") build.ship(title, body, url, tags, "")
        else if (root.createKind === "update") build.reportUpdate(extra || title, root.updateResult, tags, body, root.useDetectedEnvironment)
        else if (root.createKind === "event") build.createEvent(title, extra, root.tagsDraft.trim(), url, body)
        else if (root.createKind === "challenge") build.createChallenge(title, body, extra, url, tags)
        root.clearDrafts()
    }

    function kindLabel(kind) {
        if (kind === "idea") return "Idea"
        if (kind === "build_room") return "Build"
        if (kind === "setup_card") return "Setup"
        if (kind === "solution_card") return "Solution"
        if (kind === "ship_post") return "Shipped"
        if (kind === "help_request") return "Help"
        if (kind === "community_event") return "Event"
        if (kind === "challenge") return "Challenge"
        return "Community"
    }

    function kindIcon(kind) {
        if (kind === "idea") return "💡"
        if (kind === "build_room") return "🛠"
        if (kind === "setup_card") return "◫"
        if (kind === "solution_card") return "✦"
        if (kind === "ship_post") return "↗"
        if (kind === "help_request") return "?"
        if (kind === "community_event") return "⌖"
        if (kind === "challenge") return "◇"
        return "•"
    }

    function fieldHint() {
        if (root.createKind === "solution") return "The fix, clearly explained"
        if (root.createKind === "help") return "What is actually broken?"
        if (root.createKind === "challenge") return "What should builders make?"
        return "Describe it in a few useful lines"
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Style.space(14)

            Item {
                width: parent.width
                height: Style.space(150)

                Rectangle {
                    width: Style.space(190)
                    height: width
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.rightMargin: -Style.space(55)
                    anchors.top: parent.top
                    anchors.topMargin: -Style.space(75)
                    color: Qt.rgba(accent.r, accent.g, accent.b, 0.10)
                }

                Rectangle {
                    width: Style.space(120)
                    height: width
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(80)
                    anchors.top: parent.top
                    anchors.topMargin: -Style.space(62)
                    color: Qt.rgba(0.35, 0.55, 1.0, 0.055)
                }

                GlassSurface {
                    anchors.fill: parent
                    radius: Style.space(22)
                    fillOpacity: 0.78
                    borderOpacity: 0.12
                    elevated: true
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(18)
                    spacing: Style.space(7)

                    Row {
                        width: parent.width
                        spacing: Style.space(10)

                        Rectangle {
                            width: Style.space(40)
                            height: width
                            radius: Style.space(13)
                            color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                            border.width: 1
                            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.26)
                            Text { anchors.centerIn: parent; text: "∞"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                        }

                        Column {
                            width: parent.width - syncButton.width - Style.space(60)
                            spacing: 1
                            Text { text: "Build Network"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                            Text { text: "The live workshop for Omarchy"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }

                        GlassPill {
                            id: syncButton
                            text: build.busy ? "Syncing…" : "↻ Sync"
                            active: !build.busy
                            enabled: !build.busy
                            onClicked: build.refreshNetwork()
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Find builders. Turn ideas into real projects. Share setups safely. Test on actual machines. Preserve what the community learns."
                        color: Qt.rgba(fg.r, fg.g, fg.b, 0.82)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Style.space(16)
                        Text { text: (build.stats.builders || 0) + " builders"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { text: (build.stats.build_rooms || 0) + " builds"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { text: (build.stats.ships || 0) + " shipped"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { text: (build.stats.solutions || 0) + " solutions"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }
            }

            GlassSurface {
                width: parent.width
                height: Style.space(48)
                radius: Style.space(16)
                fillOpacity: 0.60

                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(5)
                    spacing: Style.space(4)
                    Repeater {
                        model: [
                            { id: "discover", label: "Discover" },
                            { id: "build", label: "Build" },
                            { id: "share", label: "Share" },
                            { id: "help", label: "Help" },
                            { id: "community", label: "Community" },
                            { id: "create", label: "Create" }
                        ]
                        Rectangle {
                            width: (parent.width - Style.space(20)) / 6
                            height: parent.height
                            radius: Style.space(12)
                            color: root.tab === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : "transparent"
                            border.width: root.tab === modelData.id ? 1 : 0
                            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.24)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.tab === modelData.id ? accent : muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: root.tab === modelData.id
                            }
                            HoverHandler { id: tabHover }
                            TapHandler { onTapped: root.tab = modelData.id }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.notice !== ""
                width: parent.width
                height: noticeText.implicitHeight + Style.space(16)
                radius: Style.space(12)
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.11)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.20)
                Text {
                    id: noticeText
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    text: root.notice
                    color: accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Column {
                visible: root.tab === "discover"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                Row {
                    width: parent.width
                    Column {
                        width: parent.width
                        spacing: 2
                        Text { text: "What people are making"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { text: "Recent work, not an engagement feed."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                Repeater {
                    model: build.discoverFeed.slice ? build.discoverFeed.slice(0, 24) : []
                    GlassSurface {
                        width: parent.width
                        height: discoverContent.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.64
                        elevated: true

                        Column {
                            id: discoverContent
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(7)

                            Row {
                                width: parent.width
                                spacing: Style.space(8)
                                Rectangle {
                                    width: Style.space(28)
                                    height: width
                                    radius: Style.space(9)
                                    color: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
                                    Text { anchors.centerIn: parent; text: root.kindIcon(modelData.type); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                }
                                Column {
                                    width: parent.width - discoverActions.width - Style.space(44)
                                    Text { width: parent.width; text: modelData.title || "Community update"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                                    Text { width: parent.width; text: root.kindLabel(modelData.type) + " · " + (modelData.author || "OmarchyBuilder"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                                }
                                Row {
                                    id: discoverActions
                                    spacing: Style.space(6)
                                    GlassPill { text: "Save"; onClicked: build.saveObject(modelData.id) }
                                    GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                    GlassPill { text: modelData.mine ? "You" : root.builderActionLabel(modelData.public_key); enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.summary || modelData.goal || modelData.problem || modelData.solution || modelData.notes || modelData.prompt || ""
                                color: Qt.rgba(fg.r, fg.g, fg.b, 0.75)
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            GlassPill {
                                visible: !!(modelData.artifact_url || modelData.repo_url || modelData.event_url || modelData.source_url)
                                text: "Open link ↗"
                                active: true
                                onClicked: root.openUrl(modelData.artifact_url || modelData.repo_url || modelData.event_url || modelData.source_url)
                            }
                        }
                    }
                }

                GlassSurface {
                    visible: build.discoverFeed.length === 0
                    width: parent.width
                    height: Style.space(110)
                    radius: Style.space(18)
                    fillOpacity: 0.48
                    Column {
                        anchors.centerIn: parent
                        spacing: Style.space(5)
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✦"; color: accent; font.pixelSize: Style.font.title }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Quiet in here — for now"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Share the first idea, build or setup."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                Text { visible: build.contributors.length > 0; text: "Builders worth knowing"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.contributors.slice ? build.contributors.slice(0, 8) : []
                    GlassSurface {
                        width: parent.width
                        height: Style.space(56)
                        radius: Style.space(16)
                        fillOpacity: 0.52
                        Row {
                            anchors.fill: parent
                            anchors.margins: Style.space(10)
                            spacing: Style.space(10)
                            Rectangle {
                                width: Style.space(34); height: width; radius: width / 2
                                color: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
                                Text { anchors.centerIn: parent; text: "◉"; color: accent; font.pixelSize: Style.font.bodySmall }
                            }
                            Column {
                                width: parent.width - contributorButton.width - Style.space(56)
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData.handle || "Builder"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                Text { text: "🛠 " + (modelData.builds || 0) + "   ↗ " + (modelData.ships || 0) + "   🧪 " + (modelData.tests || 0) + "   ✦ " + (modelData.solutions || 0); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            GlassPill { id: contributorButton; text: modelData.public_key === build.profile.public_key ? "You" : root.builderActionLabel(modelData.public_key); enabled: modelData.public_key !== build.profile.public_key; onClicked: root.connectBuilder(modelData.public_key) }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "build"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                Row {
                    width: parent.width
                    Column {
                        width: parent.width - newIdeaButton.width
                        Text { text: "Ideas become teams"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { text: "Signal interest, open a room, find the people you need."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                    GlassPill { id: newIdeaButton; text: "+ Idea"; strong: true; onClicked: { root.createKind = "idea"; root.tab = "create" } }
                }

                Repeater {
                    model: build.ideas
                    GlassSurface {
                        width: parent.width
                        height: ideaColumn.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.58
                        Column {
                            id: ideaColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(7)
                            Row {
                                width: parent.width
                                Text { width: parent.width - interestCount.width; text: modelData.title || "Idea"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                                Text { id: interestCount; text: (modelData.interest_count || 0) + " interested"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            Text { width: parent.width; text: modelData.summary || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(7)
                                GlassPill { text: "I'm interested"; active: true; onClicked: build.markInterested(modelData.id, "") }
                                GlassPill { text: "Start build"; strong: true; onClicked: build.buildIdea(modelData.id, "", []) }
                                GlassPill { text: modelData.mine ? "Your idea" : "Chat"; enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
                            }
                        }
                    }
                }

                Text { text: "Build rooms"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.buildRooms
                    GlassSurface {
                        id: roomCard
                        property var roomItem: modelData
                        width: parent.width
                        height: roomColumn.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.68
                        elevated: true
                        Column {
                            id: roomColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(8)
                            Row {
                                width: parent.width
                                Column {
                                    width: parent.width - roomState.width
                                    Text { width: parent.width; text: modelData.title || "Build"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                                    Text { text: (modelData.join_count || 0) + " builders · " + (modelData.done_count || 0) + " done · " + (modelData.blocked_count || 0) + " blocked"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                }
                                GlassPill { id: roomState; text: modelData.status || "building"; active: true }
                            }
                            Text { width: parent.width; text: modelData.goal || ""; color: Qt.rgba(fg.r, fg.g, fg.b, 0.74); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.roles_needed && modelData.roles_needed.length > 0; width: parent.width; text: "Looking for · " + modelData.roles_needed.join(" · "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.tasks && modelData.tasks.length > 0; width: parent.width; text: "Next · " + modelData.tasks.join("  ·  "); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { visible: !!modelData.repo_url; text: "Repo ↗"; onClicked: root.openUrl(modelData.repo_url) }
                                GlassPill { visible: !!root.repoIssues(modelData.repo_url); text: "Issues"; onClicked: root.openUrl(root.repoIssues(modelData.repo_url)) }
                                GlassPill { visible: !!root.repoPulls(modelData.repo_url); text: "PRs"; onClicked: root.openUrl(root.repoPulls(modelData.repo_url)) }
                                GlassPill { visible: !!modelData.repo_url; text: "GitHub pulse"; onClicked: build.loadGithubSnapshot(modelData.repo_url) }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { text: "Join"; active: true; onClicked: build.joinRoom(modelData.id, "Builder", "") }
                                GlassPill { text: modelData.mine ? "Testing" : root.builderActionLabel(modelData.public_key); onClicked: modelData.mine ? build.updateRoom(modelData.id, "testing", modelData.repo_url || "") : root.connectBuilder(modelData.public_key) }
                                GlassPill { visible: modelData.tasks && modelData.tasks.length > 0; text: "Start task"; onClicked: build.taskUpdate(modelData.id, modelData.tasks[0], "doing", "") }
                                GlassPill { visible: modelData.tasks && modelData.tasks.length > 0; text: "Done ✓"; onClicked: build.taskUpdate(modelData.id, modelData.tasks[0], "done", "") }
                                GlassPill { visible: modelData.mine; text: "Ship ↗"; strong: true; onClicked: build.updateRoom(modelData.id, "shipped", modelData.repo_url || "") }
                            }

                            Column {
                                visible: !!roomCard.roomItem.repo_url && build.githubSnapshot && build.githubSnapshot.repo_url === roomCard.roomItem.repo_url && build.githubSnapshot.items && build.githubSnapshot.items.length > 0
                                width: parent.width
                                spacing: Style.space(5)
                                Text { text: "Public GitHub pulse"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                Repeater {
                                    model: build.githubSnapshot && build.githubSnapshot.items ? build.githubSnapshot.items.slice(0, 6) : []
                                    Row {
                                        width: parent.width
                                        spacing: Style.space(7)
                                        Text {
                                            width: parent.width - githubPublish.width - Style.space(8)
                                            text: (modelData.reference ? modelData.reference + " · " : "") + (modelData.title || "GitHub activity")
                                            color: muted
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            elide: Text.ElideRight
                                        }
                                        GlassPill {
                                            id: githubPublish
                                            text: "Publish"
                                            onClicked: build.publishProjectActivity(modelData.activity_type, modelData.title, modelData.url, roomCard.roomItem.id, roomCard.roomItem.repo_url, modelData.state, modelData.reference)
                                        }
                                    }
                                }
                            }

                            Column {
                                visible: roomCard.roomItem.project_activity && roomCard.roomItem.project_activity.length > 0
                                width: parent.width
                                spacing: Style.space(3)
                                Text { text: "Shared project activity"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                Repeater {
                                    model: roomCard.roomItem.project_activity ? roomCard.roomItem.project_activity.slice(0, 5) : []
                                    Text {
                                        width: parent.width
                                        text: (modelData.reference ? modelData.reference + " · " : "") + (modelData.title || "Project activity")
                                        color: Qt.rgba(fg.r, fg.g, fg.b, 0.68)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "share"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                Text { text: "Share the good parts"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Setups are metadata and review plans — never remote install scripts."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Repeater {
                    model: build.setups
                    GlassSurface {
                        id: setupCard
                        property var setupItem: modelData
                        width: parent.width
                        height: setupColumn.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.62
                        Column {
                            id: setupColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(7)
                            Row {
                                width: parent.width
                                Column {
                                    width: parent.width
                                    Text { text: modelData.title || "Setup"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                    Text { text: (modelData.author || "Builder") + " · " + (modelData.theme || "No theme name"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                }
                            }
                            Text { width: parent.width; text: "Plugins · " + ((modelData.plugins || []).join ? modelData.plugins.join(" · ") : "None shared"); color: Qt.rgba(fg.r, fg.g, fg.b, 0.72); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { text: "Compare with mine"; strong: true; onClicked: build.compareSetup(modelData.id) }
                                GlassPill { text: "Copy recipe"; onClicked: root.copyText(root.setupRecipe(modelData), "Setup recipe copied") }
                                GlassPill { visible: !!modelData.repo_url; text: "Dotfiles ↗"; onClicked: root.openUrl(modelData.repo_url) }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: modelData.mine; text: "+ Component"; onClicked: root.componentSetupId = modelData.id }
                                GlassPill { text: modelData.mine ? "You" : root.builderActionLabel(modelData.public_key); enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
                            }
                            Repeater {
                                model: setupCard.setupItem.shared_components || []
                                Row {
                                    width: parent.width
                                    spacing: Style.space(7)
                                    Text {
                                        width: parent.width - componentOpen.width - Style.space(8)
                                        text: (modelData.component_type || "component") + " · " + (modelData.name || "Shared component")
                                        color: muted
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        elide: Text.ElideRight
                                    }
                                    GlassPill { id: componentOpen; visible: !!modelData.source_url; text: "Open ↗"; onClicked: root.openUrl(modelData.source_url) }
                                }
                            }
                        }
                    }
                }

                GlassSurface {
                    visible: root.componentSetupId !== ""
                    width: parent.width
                    height: componentComposer.implicitHeight + Style.space(24)
                    radius: Style.space(18)
                    fillOpacity: 0.66
                    selected: true
                    Column {
                        id: componentComposer
                        anchors.fill: parent
                        anchors.margins: Style.space(12)
                        spacing: Style.space(7)
                        Text { text: "Share one piece of this setup"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                        Flow {
                            width: parent.width
                            spacing: Style.space(6)
                            Repeater {
                                model: ["plugin", "theme", "bar", "wallpaper", "font", "keybindings"]
                                GlassPill { text: modelData; active: root.componentTypeDraft === modelData; onClicked: root.componentTypeDraft = modelData }
                            }
                        }
                        GlassSurface {
                            width: parent.width; height: Style.space(42); radius: Style.space(13); fillOpacity: 0.48
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.componentNameDraft; onTextChanged: root.componentNameDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                        }
                        GlassSurface {
                            width: parent.width; height: Style.space(42); radius: Style.space(13); fillOpacity: 0.48
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.componentUrlDraft; onTextChanged: root.componentUrlDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                        }
                        Flow {
                            width: parent.width
                            spacing: Style.space(7)
                            GlassPill {
                                text: "Share component"
                                strong: true
                                onClicked: {
                                    var name = root.componentNameDraft.trim()
                                    if (!name) { root.notice = "Give the component a name"; noticeTimer.restart(); return }
                                    build.shareComponent(root.componentTypeDraft, name, root.componentUrlDraft.trim(), root.componentSetupId, [], "")
                                    root.componentSetupId = ""; root.componentNameDraft = ""; root.componentUrlDraft = ""
                                }
                            }
                            GlassPill { text: "Cancel"; onClicked: { root.componentSetupId = ""; root.componentNameDraft = ""; root.componentUrlDraft = "" } }
                        }
                        Text { text: "Metadata/link only — Friends never installs it automatically."; color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                GlassSurface {
                    visible: !!(build.setupComparison && build.setupComparison.setup_id)
                    width: parent.width
                    height: compareColumn.implicitHeight + Style.space(24)
                    radius: Style.space(18)
                    fillOpacity: 0.72
                    selected: true
                    Column {
                        id: compareColumn
                        anchors.fill: parent
                        anchors.margins: Style.space(12)
                        spacing: Style.space(6)
                        Text { text: "Safe comparison"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                        Text { width: parent.width; text: root.comparisonText(); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        Text { text: "Nothing has been installed or changed."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                Text { text: "Test on real Omarchy machines"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.tests
                    GlassSurface {
                        width: parent.width
                        height: testColumn.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.55
                        Column {
                            id: testColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(7)
                            Row {
                                width: parent.width
                                Column {
                                    width: parent.width - testScore.width
                                    Text { text: modelData.title || "Test request"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                    Text { text: "Needs · " + ((modelData.requested_tags || []).join ? modelData.requested_tags.join(" · ") : "any Omarchy system"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                }
                                Text { id: testScore; text: (modelData.pass_count || 0) + "/" + (modelData.result_count || 0); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                            }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { text: "Works ✓"; strong: true; onClicked: build.submitTestResult(modelData.id, "pass", build.detectedEnvironment.tags || [], "Works on my system") }
                                GlassPill { text: "Found issue"; onClicked: build.submitTestResult(modelData.id, "issue", build.detectedEnvironment.tags || [], "I found an issue") }
                                GlassPill { visible: !!modelData.artifact_url; text: "Artifact ↗"; onClicked: root.openUrl(modelData.artifact_url) }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "help"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                Text { text: "When AI gets stuck, ask a human"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Share only the useful context. Private follow-up stays in Friends chat."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                GlassSurface {
                    width: parent.width
                    height: envColumn.implicitHeight + Style.space(20)
                    radius: Style.space(16)
                    fillOpacity: 0.50
                    Column {
                        id: envColumn
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(4)
                        Text { text: "Safe local context"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { width: parent.width; text: ((build.detectedEnvironment.tags || []).join ? build.detectedEnvironment.tags.join("   ·   ") : "No environment labels detected"); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        Text { text: "No hostname · IP · username · file contents"; color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                GlassSurface {
                    width: parent.width
                    height: availabilityColumn.implicitHeight + Style.space(22)
                    radius: Style.space(18)
                    fillOpacity: 0.60
                    Column {
                        id: availabilityColumn
                        anchors.fill: parent
                        anchors.margins: Style.space(11)
                        spacing: Style.space(7)
                        Text { text: "Be available to another builder"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                        Flow {
                            width: parent.width
                            spacing: Style.space(6)
                            Repeater {
                                model: [ { id: "can_help", label: "Can help" }, { id: "pair", label: "Pair" }, { id: "building", label: "Build with me" } ]
                                GlassPill { text: modelData.label; active: root.availabilityMode === modelData.id; onClicked: root.availabilityMode = modelData.id }
                            }
                        }
                        GlassSurface {
                            width: parent.width; height: Style.space(42); radius: Style.space(13); fillOpacity: 0.48
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.availabilitySkillsDraft; onTextChanged: root.availabilitySkillsDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                        }
                        GlassSurface {
                            width: parent.width; height: Style.space(42); radius: Style.space(13); fillOpacity: 0.48
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.availabilityNoteDraft; onTextChanged: root.availabilityNoteDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                        }
                        Flow {
                            width: parent.width
                            spacing: Style.space(6)
                            Repeater {
                                model: [30, 60, 120]
                                GlassPill { text: modelData + "m"; active: root.availabilityMinutes === modelData; onClicked: root.availabilityMinutes = modelData }
                            }
                            GlassPill { text: "Go live"; strong: true; onClicked: build.setAvailability(root.availabilityMode, root.csv(root.availabilitySkillsDraft), root.availabilityNoteDraft, root.availabilityMinutes, "active") }
                            GlassPill { text: "Stop"; onClicked: build.setAvailability(root.availabilityMode, root.csv(root.availabilitySkillsDraft), root.availabilityNoteDraft, root.availabilityMinutes, "closed") }
                        }
                        Text { text: "Availability expires automatically."; color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                Text { visible: build.helpers.length > 0; text: "Builders available now"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.helpers.slice ? build.helpers.slice(0, 8) : []
                    GlassSurface {
                        width: parent.width
                        height: Style.space(58)
                        radius: Style.space(16)
                        fillOpacity: 0.52
                        Row {
                            anchors.fill: parent
                            anchors.margins: Style.space(10)
                            spacing: Style.space(8)
                            Column {
                                width: parent.width - helperChat.width - Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData.author || "Builder"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                Text { width: parent.width; text: (modelData.mode || "can_help") + (modelData.skills && modelData.skills.length ? " · " + modelData.skills.join(" · ") : ""); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            }
                            GlassPill { id: helperChat; text: modelData.public_key === build.profile.public_key ? "You" : root.builderActionLabel(modelData.public_key); enabled: modelData.public_key !== build.profile.public_key; onClicked: root.connectBuilder(modelData.public_key) }
                        }
                    }
                }

                Repeater {
                    model: build.helpRequests
                    GlassSurface {
                        width: parent.width
                        height: helpColumn.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.62
                        Column {
                            id: helpColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(7)
                            Row {
                                width: parent.width
                                Text { width: parent.width - offerBadge.width; text: modelData.title || "Need help"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                                GlassPill { id: offerBadge; text: (modelData.offer_count || 0) + " offers"; active: true }
                            }
                            Text { width: parent.width; text: modelData.problem || ""; color: Qt.rgba(fg.r, fg.g, fg.b, 0.80); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: !!modelData.tried; width: parent.width; text: "Already tried · " + modelData.tried; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.environment_tags && modelData.environment_tags.length > 0; width: parent.width; text: modelData.environment_tags.join("   ·   "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Flow {
                                visible: modelData.helper_matches && modelData.helper_matches.length > 0
                                width: parent.width
                                spacing: Style.space(6)
                                Repeater {
                                    model: modelData.helper_matches ? modelData.helper_matches.slice(0, 4) : []
                                    GlassPill { text: "Ask " + (modelData.handle || "builder"); active: true; onClicked: root.connectBuilder(modelData.public_key) }
                                }
                            }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { visible: !modelData.mine; text: "I can help"; strong: true; onClicked: build.offerHelp(modelData.id, "I can take a look", true) }
                                GlassPill { visible: !modelData.mine; text: root.builderActionLabel(modelData.public_key); onClicked: root.connectBuilder(modelData.public_key) }
                                GlassPill { visible: modelData.mine && modelData.status !== "solved"; text: "Solved ✓"; strong: true; onClicked: build.resolveHelp(modelData.id, "solved") }
                                GlassPill { visible: modelData.mine && modelData.status === "solved"; text: "Write solution"; strong: true; onClicked: root.solutionHelpId = modelData.id }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                            }
                        }
                    }
                }

                GlassSurface {
                    visible: root.solutionHelpId !== ""
                    width: parent.width
                    height: helpSolutionColumn.implicitHeight + Style.space(22)
                    radius: Style.space(18)
                    fillOpacity: 0.66
                    selected: true
                    Column {
                        id: helpSolutionColumn
                        anchors.fill: parent
                        anchors.margins: Style.space(11)
                        spacing: Style.space(7)
                        Text { text: "Turn this fix into community memory"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                        GlassSurface {
                            width: parent.width; height: Style.space(92); radius: Style.space(13); fillOpacity: 0.48
                            TextArea { anchors.fill: parent; anchors.margins: Style.space(8); text: root.solutionDraft; onTextChanged: root.solutionDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap; background: Item {} ; placeholderText: "What fixed it?" }
                        }
                        Flow {
                            spacing: Style.space(7)
                            GlassPill {
                                text: "Publish solution"
                                strong: true
                                onClicked: {
                                    var fix = root.solutionDraft.trim()
                                    if (!fix) { root.notice = "Write the fix first"; noticeTimer.restart(); return }
                                    build.solutionFromHelp(root.solutionHelpId, fix, "", "")
                                    root.solutionHelpId = ""; root.solutionDraft = ""
                                }
                            }
                            GlassPill { text: "Cancel"; onClicked: { root.solutionHelpId = ""; root.solutionDraft = "" } }
                        }
                        Text { text: "Only publish what you are comfortable making public."; color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                Text { text: "Community memory"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.solutions
                    GlassSurface {
                        width: parent.width
                        height: solutionColumn.implicitHeight + Style.space(24)
                        radius: Style.space(18)
                        fillOpacity: 0.58
                        Column {
                            id: solutionColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(7)
                            Row {
                                width: parent.width
                                Text { width: parent.width - verifyBadge.width; text: modelData.title || "Solution"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                GlassPill { id: verifyBadge; text: (modelData.worked_count || 0) + "/" + (modelData.verification_count || 0) + " worked"; active: true }
                            }
                            Text { width: parent.width; text: modelData.solution || ""; color: Qt.rgba(fg.r, fg.g, fg.b, 0.82); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { text: "Worked ✓"; strong: true; onClicked: build.verifySolution(modelData.id, "worked", "", true) }
                                GlassPill { text: "Partly"; onClicked: build.verifySolution(modelData.id, "partial", "", true) }
                                GlassPill { text: "Copy"; onClicked: root.copyText(modelData.solution || "", "Solution copied") }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: !!modelData.source_url; text: "Source ↗"; onClicked: root.openUrl(modelData.source_url) }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "community"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                Text { text: "Community pulse"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Voluntary reports, meetups and challenges — no hidden telemetry."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Repeater {
                    model: build.updatePulse
                    GlassSurface {
                        width: parent.width
                        height: pulseColumn.implicitHeight + Style.space(22)
                        radius: Style.space(18)
                        fillOpacity: 0.62
                        Column {
                            id: pulseColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(11)
                            spacing: Style.space(6)
                            Row {
                                width: parent.width
                                Text { width: parent.width - pulseTotal.width; text: "Omarchy " + modelData.version; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                Text { id: pulseTotal; text: modelData.total + " reports"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "✓ " + modelData.working + " working"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                                Text { text: "⚠ " + modelData.minor_issue + " minor"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                Text { text: "↩ " + modelData.rolled_back + " rollback"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            Text { visible: modelData.matching_total > 0; width: parent.width; text: "Similar to your machine · " + modelData.matching_total + " reports · " + modelData.matching_working + " working"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        }
                    }
                }

                Text { text: "Events"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.events
                    GlassSurface {
                        width: parent.width
                        height: eventColumn.implicitHeight + Style.space(22)
                        radius: Style.space(18)
                        fillOpacity: 0.54
                        Column {
                            id: eventColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(11)
                            spacing: Style.space(6)
                            Text { text: modelData.title || "Event"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                            Text { width: parent.width; text: (modelData.when_text || "Time TBD") + "   ·   " + (modelData.location || "Location TBD"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { text: (modelData.going_count || 0) + " going   ·   " + (modelData.interested_count || 0) + " interested"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { text: "Going"; strong: true; onClicked: build.rsvpEvent(modelData.id, "going", "") }
                                GlassPill { text: "Interested"; onClicked: build.rsvpEvent(modelData.id, "interested", "") }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: !!modelData.event_url; text: "Open ↗"; onClicked: root.openUrl(modelData.event_url) }
                            }
                        }
                    }
                }

                Text { text: "Challenges"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.challenges
                    GlassSurface {
                        width: parent.width
                        height: challengeColumn.implicitHeight + Style.space(22)
                        radius: Style.space(18)
                        fillOpacity: 0.54
                        Column {
                            id: challengeColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(11)
                            spacing: Style.space(6)
                            Row {
                                width: parent.width
                                Text { width: parent.width - challengeCount.width; text: modelData.title || "Challenge"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                Text { id: challengeCount; text: (modelData.join_count || 0) + " joined"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            }
                            Text { width: parent.width; text: modelData.prompt || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Flow {
                                width: parent.width
                                spacing: Style.space(7)
                                GlassPill { text: "Join"; strong: true; onClicked: build.joinChallenge(modelData.id, "", "", "") }
                                GlassPill { text: "Start a team"; onClicked: build.createRoom(modelData.title, modelData.prompt, "", modelData.tags || [], [], "") }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: !!modelData.rules_url; text: "Rules ↗"; onClicked: root.openUrl(modelData.rules_url) }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "create"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(12)

                Text { text: "Put something into the world"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Public metadata only. Private conversation stays private in Friends."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Flow {
                    width: parent.width
                    spacing: Style.space(6)
                    Repeater {
                        model: [
                            { id: "idea", label: "Idea" }, { id: "room", label: "Build" }, { id: "setup", label: "Setup" },
                            { id: "test", label: "Test" }, { id: "help", label: "Help" }, { id: "solution", label: "Solution" },
                            { id: "ship", label: "Ship" }, { id: "update", label: "Update" }, { id: "event", label: "Event" }, { id: "challenge", label: "Challenge" }
                        ]
                        GlassPill { text: modelData.label; active: root.createKind === modelData.id; onClicked: root.createKind = modelData.id }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Text { text: root.createKind === "update" ? "Title (optional)" : "Title"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GlassSurface {
                        width: parent.width; height: Style.space(44); radius: Style.space(14); fillOpacity: 0.50
                        TextInput { anchors.fill: parent; anchors.margins: Style.space(12); text: root.titleDraft; onTextChanged: root.titleDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: TextInput.AlignVCenter }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Text { text: root.fieldHint(); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GlassSurface {
                        width: parent.width; height: Style.space(106); radius: Style.space(14); fillOpacity: 0.50
                        TextArea { anchors.fill: parent; anchors.margins: Style.space(8); text: root.bodyDraft; onTextChanged: root.bodyDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap; background: Item {} }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Text { text: "Link"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GlassSurface {
                        width: parent.width; height: Style.space(44); radius: Style.space(14); fillOpacity: 0.50
                        TextInput { anchors.fill: parent; anchors.margins: Style.space(12); text: root.urlDraft; onTextChanged: root.urlDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    }
                    Text { text: "Optional HTTPS repo, artifact, event or source URL"; color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Text { text: root.createKind === "event" ? "Location" : "Tags / roles / environments"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GlassSurface {
                        width: parent.width; height: Style.space(44); radius: Style.space(14); fillOpacity: 0.50
                        TextInput { anchors.fill: parent; anchors.margins: Style.space(12); text: root.tagsDraft; onTextChanged: root.tagsDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Text {
                        text: root.createKind === "help" ? "What you / AI already tried" : root.createKind === "solution" ? "Problem this solves" : root.createKind === "event" ? "When" : root.createKind === "challenge" ? "Deadline" : root.createKind === "test" ? "Version" : root.createKind === "update" ? "Omarchy version" : "Extra"
                        color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
                    }
                    GlassSurface {
                        width: parent.width; height: Style.space(44); radius: Style.space(14); fillOpacity: 0.50
                        TextInput { anchors.fill: parent; anchors.margins: Style.space(12); text: root.extraDraft; onTextChanged: root.extraDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    }
                }

                Row {
                    visible: root.createKind === "help" || root.createKind === "update"
                    width: parent.width
                    spacing: Style.space(9)
                    GlassPill { text: root.useDetectedEnvironment ? "✓ Safe environment included" : "Include environment"; active: root.useDetectedEnvironment; onClicked: root.useDetectedEnvironment = !root.useDetectedEnvironment }
                    Text { text: "No identifying machine data"; color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                }

                Flow {
                    visible: root.createKind === "update"
                    width: parent.width
                    spacing: Style.space(7)
                    Repeater {
                        model: [ { id: "working", label: "Working" }, { id: "minor_issue", label: "Minor issue" }, { id: "rolled_back", label: "Rolled back" } ]
                        GlassPill { text: modelData.label; active: root.updateResult === modelData.id; onClicked: root.updateResult = modelData.id }
                    }
                }

                GlassSurface {
                    width: parent.width
                    height: Style.space(58)
                    radius: Style.space(18)
                    fillOpacity: 0.66
                    selected: true
                    Row {
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(10)
                        Column {
                            width: parent.width - publishButton.width - Style.space(10)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Public Build Network"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                            Text { text: "Signed metadata · relay readable"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                        GlassPill { id: publishButton; text: build.busy ? "Publishing…" : "Publish ↗"; strong: true; enabled: !build.busy; onClicked: root.submitCreate() }
                    }
                }
            }

            GlassSurface {
                width: parent.width
                height: Style.space(56)
                radius: Style.space(17)
                fillOpacity: 0.46
                Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(9)
                    spacing: Style.space(7)
                    Column {
                        width: parent.width - repairInvite.width - releaseHealth.width - Style.space(16)
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Release diagnostics"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { text: "Queued: " + (build.releaseInfo.pending_publish || 0) + " · blocked filtered: " + (build.releaseInfo.blocked_filtered || 0); color: faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                    GlassPill { id: repairInvite; text: "Repair invites"; onClicked: build.registerInviteLinks() }
                    GlassPill { id: releaseHealth; text: "Health"; onClicked: build.health() }
                }
            }

            Item { width: 1; height: Style.space(3) }
            Text {
                width: parent.width
                text: "Built for Omarchy · public cards are signed metadata · private chat stays private · shared setup data is compare/review only"
                color: faint
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Item { width: 1; height: Style.space(8) }
        }
    }
}
