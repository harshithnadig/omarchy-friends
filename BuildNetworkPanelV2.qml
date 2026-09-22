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

    readonly property color fg: Color.foreground
    readonly property color bg: Color.background
    readonly property color accent: Color.accent
    readonly property color muted: Color.muted
    readonly property color soft: Qt.rgba(fg.r, fg.g, fg.b, 0.055)
    readonly property color line: Qt.rgba(fg.r, fg.g, fg.b, 0.11)
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

    contentWidth: root.fittedContentWidth(Style.space(560))
    contentHeight: root.fittedContentHeight(deck.implicitHeight)

    BuildNetworkService {
        id: build
        onActionResult: function(ok, message) {
            root.notice = message || (ok ? "Done" : "Build Network action failed")
            noticeTimer.restart()
        }
    }

    Timer { id: noticeTimer; interval: 3400; onTriggered: root.notice = "" }

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
        if (url && (url.indexOf("https://") === 0 || url.indexOf("http://") === 0)) Quickshell.execDetached(["xdg-open", url])
    }

    function repoIssues(url) { return url && url.indexOf("https://github.com/") === 0 ? url.replace(/\/$/, "") + "/issues" : "" }
    function repoPulls(url) { return url && url.indexOf("https://github.com/") === 0 ? url.replace(/\/$/, "") + "/pulls" : "" }

    function copyText(text, message) {
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(String(text || "")) + " | wl-copy"])
        root.notice = message || "Copied"
        noticeTimer.restart()
    }

    function connectBuilder(publicKey) {
        if (!publicKey || !root.friendsService) {
            root.notice = "Open Friends to connect with this builder"
            noticeTimer.restart()
            return
        }
        root.friendsService.requestFriend(publicKey)
        root.notice = "Chat invite sent through Friends"
        noticeTimer.restart()
    }

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
        var lines = ["Compare: " + (c.title || "Setup"), c.message || ""]
        if (c.missing_plugins && c.missing_plugins.length) lines.push("Missing plugins: " + c.missing_plugins.join(", "))
        if (c.already_have_plugins && c.already_have_plugins.length) lines.push("Already installed: " + c.already_have_plugins.join(", "))
        var fields = c.fields || []
        for (var i = 0; i < fields.length; i++) {
            var f = fields[i]
            if (f.status === "different") lines.push(f.label + ": " + (f.current || "—") + " → " + (f.wanted || "—"))
        }
        return lines.join("\n")
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
        if (kind === "idea") return "💡 Idea"
        if (kind === "build_room") return "🛠 Build"
        if (kind === "setup_card") return "🖥 Setup"
        if (kind === "solution_card") return "🧠 Solution"
        if (kind === "ship_post") return "🚀 Shipped"
        if (kind === "help_request") return "🆘 Help"
        if (kind === "community_event") return "📍 Event"
        if (kind === "challenge") return "🏆 Challenge"
        return "✦ Community"
    }

    function actionButton(parentItem, label, handler, emphasis) { }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: deck.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: deck
            width: parent.width
            spacing: Style.space(10)

            Row {
                width: parent.width
                height: Style.space(48)
                spacing: Style.space(8)
                Column {
                    width: parent.width - refreshButton.width - Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🛠 Omarchy Build Network"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                    Text { text: "People → ideas → teams → tests → ship → community memory"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
                Rectangle {
                    id: refreshButton
                    width: Style.space(76)
                    height: Style.space(30)
                    radius: height / 2
                    color: build.busy ? soft : Qt.rgba(accent.r, accent.g, accent.b, 0.15)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: build.busy ? "Syncing…" : "↻ Sync"; color: build.busy ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: !build.busy; cursorShape: Qt.PointingHandCursor; onClicked: build.refreshNetwork() }
                }
            }

            Rectangle {
                width: parent.width
                height: summaryRow.implicitHeight + Style.space(16)
                radius: Style.space(10)
                color: soft
                border.width: 1
                border.color: line
                Row {
                    id: summaryRow
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)
                    Repeater {
                        model: [
                            { label: "Builders", value: build.stats.builders || 0 },
                            { label: "Ideas", value: build.stats.ideas || 0 },
                            { label: "Builds", value: build.stats.build_rooms || 0 },
                            { label: "Ships", value: build.stats.ships || 0 },
                            { label: "Solutions", value: build.stats.solutions || 0 }
                        ]
                        Column {
                            width: (summaryRow.width - Style.space(32)) / 5
                            Text { width: parent.width; text: String(modelData.value); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                            Text { width: parent.width; text: modelData.label; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }

            Text {
                visible: root.notice !== ""
                width: parent.width
                text: root.notice
                color: accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                height: Style.space(38)
                Repeater {
                    model: [
                        { id: "discover", label: "Discover" },
                        { id: "build", label: "Build" },
                        { id: "share", label: "Share/Test" },
                        { id: "help", label: "Help" },
                        { id: "community", label: "Community" },
                        { id: "create", label: "+ Create" }
                    ]
                    Rectangle {
                        width: parent.width / 6
                        height: parent.height
                        radius: Style.space(8)
                        color: root.tab === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.14) : "transparent"
                        Text { anchors.centerIn: parent; text: modelData.label; color: root.tab === modelData.id ? accent : muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: root.tab === modelData.id }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = modelData.id }
                    }
                }
            }

            Column {
                visible: root.tab === "discover"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(9)

                Text { text: "Live community work"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "No engagement feed. These are actual ideas, builds, setups, fixes, ships, events and challenges."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Repeater {
                    model: build.discoverFeed.slice ? build.discoverFeed.slice(0, 30) : []
                    Rectangle {
                        width: parent.width
                        height: discoverCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        border.width: 1
                        border.color: line
                        Column {
                            id: discoverCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(5)
                            Row {
                                width: parent.width
                                Text { width: parent.width - discoverActions.width; text: root.kindLabel(modelData.type) + " · " + (modelData.author || "OmarchyBuilder"); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                Row {
                                    id: discoverActions
                                    spacing: Style.space(10)
                                    Text { text: "Save"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.saveObject(modelData.id) } }
                                    Text { text: modelData.mine ? "You" : "Chat"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }
                                }
                            }
                            Text { width: parent.width; text: modelData.title || "Community update"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.summary || modelData.goal || modelData.problem || modelData.solution || modelData.notes || modelData.prompt || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight }
                            Text { visible: !!(modelData.artifact_url || modelData.repo_url || modelData.event_url || modelData.source_url); text: "Open ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.artifact_url || modelData.repo_url || modelData.event_url || modelData.source_url) } }
                        }
                    }
                }

                Text { visible: build.discoverFeed.length === 0; width: parent.width; text: "No public Build Network objects yet. Create the first one."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }

                Text { visible: build.contributors.length > 0; text: "Useful contributors"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.contributors.slice ? build.contributors.slice(0, 10) : []
                    Rectangle {
                        width: parent.width
                        height: Style.space(44)
                        radius: Style.space(8)
                        color: soft
                        Row {
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            Text { width: parent.width - contributorChat.width; text: (modelData.handle || "Builder") + " · 🛠 " + (modelData.builds || 0) + " · 🚀 " + (modelData.ships || 0) + " · 🧪 " + (modelData.tests || 0) + " · 🆘 " + (modelData.helps || 0) + " · 🧠 " + (modelData.solutions || 0); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { id: contributorChat; text: modelData.public_key === build.profile.public_key ? "You" : "Chat"; color: modelData.public_key === build.profile.public_key ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter; MouseArea { anchors.fill: parent; enabled: modelData.public_key !== build.profile.public_key; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "build"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(10)

                Row {
                    width: parent.width
                    Text { width: parent.width - quickIdea.width; text: "💡 Ideas → 🛠 Build Rooms"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                    Text { id: quickIdea; text: "+ idea"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.createKind = "idea"; root.tab = "create" } } }
                }

                Repeater {
                    model: build.ideas
                    Rectangle {
                        width: parent.width
                        height: ideaCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: ideaCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(5)
                            Text { width: parent.width; text: "💡 " + (modelData.title || "Idea") + " · " + (modelData.interest_count || 0) + " interested"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.summary || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "I'm interested"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.markInterested(modelData.id, "") } }
                                Text { text: "Build it"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.buildIdea(modelData.id, "", []) } }
                                Text { text: modelData.mine ? "You" : "Chat author"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }
                            }
                        }
                    }
                }

                Text { text: "Active Build Rooms"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.buildRooms
                    Rectangle {
                        width: parent.width
                        height: roomCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        border.width: 1
                        border.color: line
                        Column {
                            id: roomCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(5)
                            Text { width: parent.width; text: "🛠 " + (modelData.title || "Build") + " · " + (modelData.status || "building") + " · " + (modelData.join_count || 0) + " joined"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.goal || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.roles_needed && modelData.roles_needed.length > 0; width: parent.width; text: "Needs: " + modelData.roles_needed.join(" · "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.tasks && modelData.tasks.length > 0; width: parent.width; text: "Tasks: " + modelData.tasks.join(" · "); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.task_updates && modelData.task_updates.length > 0; width: parent.width; text: "Progress: " + (modelData.done_count || 0) + " done · " + (modelData.blocked_count || 0) + " blocked"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            Row {
                                spacing: Style.space(13)
                                Text { visible: !!modelData.repo_url; text: "Repo ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.repo_url) } }
                                Text { visible: !!root.repoIssues(modelData.repo_url); text: "Issues ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(root.repoIssues(modelData.repo_url)) } }
                                Text { visible: !!root.repoPulls(modelData.repo_url); text: "PRs ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(root.repoPulls(modelData.repo_url)) } }
                                Text { text: "Join"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.joinRoom(modelData.id, "Builder", "") } }
                                Text { text: modelData.mine ? "Mark testing" : "Chat owner"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.mine ? build.updateRoom(modelData.id, "testing", modelData.repo_url || "") : root.connectBuilder(modelData.public_key) } }
                            }
                            Row {
                                visible: modelData.tasks && modelData.tasks.length > 0
                                spacing: Style.space(13)
                                Text { text: "Start first task"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.taskUpdate(modelData.id, modelData.tasks[0], "doing", "") } }
                                Text { text: "Complete first task"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.taskUpdate(modelData.id, modelData.tasks[0], "done", "") } }
                                Text { visible: modelData.mine; text: "Mark shipped"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.updateRoom(modelData.id, "shipped", modelData.repo_url || "") } }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "share"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(10)

                Text { text: "🖥 Setup Cards"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Compare first. Friends never auto-runs somebody else's setup or dotfiles."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Repeater {
                    model: build.setups
                    Rectangle {
                        width: parent.width
                        height: setupCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: setupCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "🖥 " + modelData.title + " · " + (modelData.author || "Builder"); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: "Theme: " + (modelData.theme || "—") + " · Terminal: " + (modelData.terminal || "—") + " · Editor: " + (modelData.editor || "—"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: "Plugins: " + ((modelData.plugins || []).join ? (modelData.plugins || []).join(", ") : ""); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "Compare"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.compareSetup(modelData.id) } }
                                Text { text: "Copy recipe"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyText(root.setupRecipe(modelData), "Setup recipe copied — review before applying") } }
                                Text { visible: !!modelData.repo_url; text: "Dotfiles ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.repo_url) } }
                                Text { text: modelData.mine ? "You" : "Chat"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !!(build.setupComparison && build.setupComparison.setup_id)
                    width: parent.width
                    height: comparisonColumn.implicitHeight + Style.space(18)
                    radius: Style.space(9)
                    color: Qt.rgba(accent.r, accent.g, accent.b, 0.09)
                    border.width: 1
                    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                    Column {
                        id: comparisonColumn
                        anchors.fill: parent
                        anchors.margins: Style.space(9)
                        spacing: Style.space(4)
                        Text { text: "Safe setup comparison"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                        Text { width: parent.width; text: root.comparisonText(); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                    }
                }

                Text { text: "🧪 Test Network"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.tests
                    Rectangle {
                        width: parent.width
                        height: testCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: testCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "🧪 " + (modelData.title || "Test") + " · " + (modelData.pass_count || 0) + "/" + (modelData.result_count || 0) + " passed"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: "Looking for: " + ((modelData.requested_tags || []).join ? modelData.requested_tags.join(" · ") : "any Omarchy system"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "✅ Works"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.submitTestResult(modelData.id, "pass", build.detectedEnvironment.tags || [], "Works on my system") } }
                                Text { text: "⚠ Issue"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.submitTestResult(modelData.id, "issue", build.detectedEnvironment.tags || [], "I found an issue") } }
                                Text { visible: !!modelData.artifact_url; text: "Artifact ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.artifact_url) } }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "help"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(10)

                Text { text: "🆘 Human escalation"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "AI can try first. When it gets stuck, share a bounded problem + what was already tried, then continue privately in Friends chat."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                Text { width: parent.width; text: "Your safe environment labels: " + ((build.detectedEnvironment.tags || []).join ? build.detectedEnvironment.tags.join(" · ") : "not detected"); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Repeater {
                    model: build.helpRequests
                    Rectangle {
                        width: parent.width
                        height: helpCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: helpCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(5)
                            Text { width: parent.width; text: "🆘 " + (modelData.title || "Need help") + " · " + (modelData.status || "open") + " · " + (modelData.offer_count || 0) + " offers"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.problem || ""; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: !!modelData.tried; width: parent.width; text: "Already tried: " + modelData.tried; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: modelData.environment_tags && modelData.environment_tags.length > 0; width: parent.width; text: "Environment: " + modelData.environment_tags.join(" · "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(14)
                                Text { visible: !modelData.mine; text: "Offer help"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.offerHelp(modelData.id, "I can take a look", true) } }
                                Text { visible: !modelData.mine; text: "Chat"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }
                                Text { visible: modelData.mine && modelData.status !== "solved"; text: "Mark solved"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.resolveHelp(modelData.id, "solved") } }
                            }
                        }
                    }
                }

                Text { text: "🧠 Community memory"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.solutions
                    Rectangle {
                        width: parent.width
                        height: solutionCard.implicitHeight + Style.space(18)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: solutionCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(5)
                            Text { width: parent.width; text: "🧠 " + (modelData.title || "Solution") + " · " + (modelData.worked_count || 0) + "/" + (modelData.verification_count || 0) + " verified working"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.solution || ""; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "✅ Worked"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.verifySolution(modelData.id, "worked", "", true) } }
                                Text { text: "◐ Partial"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.verifySolution(modelData.id, "partial", "", true) } }
                                Text { text: "Copy"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyText(modelData.solution || "", "Solution copied") } }
                                Text { visible: !!modelData.source_url; text: "Source ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.source_url) } }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "community"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(10)

                Text { text: "📈 Omarchy Update Pulse"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Only explicit user reports are counted. Matching numbers use the safe environment labels detected on this machine."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                Repeater {
                    model: build.updatePulse
                    Rectangle {
                        width: parent.width
                        height: pulseColumn.implicitHeight + Style.space(16)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: pulseColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            spacing: Style.space(3)
                            Text { width: parent.width; text: "Omarchy " + modelData.version + " · " + modelData.total + " reports"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                            Text { width: parent.width; text: "✅ " + modelData.working + " working · ⚠ " + modelData.minor_issue + " minor · ↩ " + modelData.rolled_back + " rolled back"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            Text { visible: modelData.matching_total > 0; width: parent.width; text: "Similar to you: " + modelData.matching_total + " reports · ✅ " + modelData.matching_working + " · ⚠ " + modelData.matching_minor_issue + " · ↩ " + modelData.matching_rolled_back; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        }
                    }
                }

                Text { text: "📍 Events / meetups"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.events
                    Rectangle {
                        width: parent.width
                        height: eventCard.implicitHeight + Style.space(16)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: eventCard
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "📍 " + (modelData.title || "Event") + " · " + (modelData.when_text || "time TBD"); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: (modelData.location || "Online / location TBD") + " · " + (modelData.going_count || 0) + " going · " + (modelData.interested_count || 0) + " interested"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "Going"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.rsvpEvent(modelData.id, "going", "") } }
                                Text { text: "Interested"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.rsvpEvent(modelData.id, "interested", "") } }
                                Text { visible: !!modelData.event_url; text: "Open ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.event_url) } }
                            }
                        }
                    }
                }

                Text { text: "🏆 Build challenges"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.challenges
                    Rectangle {
                        width: parent.width
                        height: challengeCard.implicitHeight + Style.space(16)
                        radius: Style.space(9)
                        color: soft
                        Column {
                            id: challengeCard
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "🏆 " + (modelData.title || "Challenge") + " · " + (modelData.join_count || 0) + " joined"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.prompt || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row {
                                spacing: Style.space(14)
                                Text { text: "Join"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.joinChallenge(modelData.id, "", "", "") } }
                                Text { text: "Start Build Room"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.createRoom(modelData.title, modelData.prompt, "", modelData.tags || [], [], "") } }
                                Text { visible: !!modelData.rules_url; text: "Rules ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.rules_url) } }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "create"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(9)

                Text { text: "Create something useful"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { width: parent.width; text: "Everything here is public relay-readable metadata. Private conversation belongs in Friends chat."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }

                Flow {
                    width: parent.width
                    spacing: Style.space(6)
                    Repeater {
                        model: [
                            { id: "idea", label: "💡 Idea" }, { id: "room", label: "🛠 Build" }, { id: "setup", label: "🖥 Setup" },
                            { id: "test", label: "🧪 Test" }, { id: "help", label: "🆘 Help" }, { id: "solution", label: "🧠 Solution" },
                            { id: "ship", label: "🚀 Ship" }, { id: "update", label: "📈 Update" }, { id: "event", label: "📍 Event" }, { id: "challenge", label: "🏆 Challenge" }
                        ]
                        Rectangle {
                            width: kindText.implicitWidth + Style.space(16)
                            height: Style.space(30)
                            radius: height / 2
                            color: root.createKind === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.18) : soft
                            Text { id: kindText; anchors.centerIn: parent; text: modelData.label; color: root.createKind === modelData.id ? accent : fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: root.createKind === modelData.id }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.createKind = modelData.id }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(36)
                    radius: Style.space(8)
                    color: soft
                    TextInput { anchors.fill: parent; anchors.margins: Style.space(9); text: root.titleDraft; onTextChanged: root.titleDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    Text { visible: root.titleDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(9); anchors.verticalCenter: parent.verticalCenter; text: root.createKind === "update" ? "Optional title" : "Title"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(92)
                    radius: Style.space(8)
                    color: soft
                    TextArea { anchors.fill: parent; anchors.margins: Style.space(7); text: root.bodyDraft; onTextChanged: root.bodyDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: TextEdit.Wrap }
                    Text { visible: root.bodyDraft === ""; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: Style.space(10); text: root.createKind === "solution" ? "Solution" : root.createKind === "help" ? "Problem" : "Description / notes"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(36)
                    radius: Style.space(8)
                    color: soft
                    TextInput { anchors.fill: parent; anchors.margins: Style.space(9); text: root.urlDraft; onTextChanged: root.urlDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    Text { visible: root.urlDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(9); anchors.verticalCenter: parent.verticalCenter; text: "Optional HTTPS URL (repo/artifact/event/source)"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(36)
                    radius: Style.space(8)
                    color: soft
                    TextInput { anchors.fill: parent; anchors.margins: Style.space(9); text: root.tagsDraft; onTextChanged: root.tagsDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    Text { visible: root.tagsDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(9); anchors.verticalCenter: parent.verticalCenter; text: root.createKind === "event" ? "Location" : "Tags / roles / requested environments, comma-separated"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(36)
                    radius: Style.space(8)
                    color: soft
                    TextInput { anchors.fill: parent; anchors.margins: Style.space(9); text: root.extraDraft; onTextChanged: root.extraDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter }
                    Text { visible: root.extraDraft === ""; anchors.left: parent.left; anchors.leftMargin: Style.space(9); anchors.verticalCenter: parent.verticalCenter; text: root.createKind === "help" ? "What you / AI already tried" : root.createKind === "solution" ? "Problem this solves" : root.createKind === "event" ? "When" : root.createKind === "challenge" ? "Deadline" : root.createKind === "test" ? "Version" : root.createKind === "update" ? "Omarchy version" : "Optional extra"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }

                Row {
                    visible: root.createKind === "help" || root.createKind === "update"
                    width: parent.width
                    spacing: Style.space(8)
                    Rectangle {
                        width: Style.space(20); height: width; radius: Style.space(5); color: root.useDetectedEnvironment ? accent : soft; border.width: 1; border.color: root.useDetectedEnvironment ? accent : line
                        Text { anchors.centerIn: parent; text: root.useDetectedEnvironment ? "✓" : ""; color: bg; font.pixelSize: Style.font.caption; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.useDetectedEnvironment = !root.useDetectedEnvironment }
                    }
                    Text { text: "Include safe environment labels (no hostname, IP, username or file contents)"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                }

                Flow {
                    visible: root.createKind === "update"
                    width: parent.width
                    spacing: Style.space(6)
                    Repeater {
                        model: [ { id: "working", label: "✅ Working" }, { id: "minor_issue", label: "⚠ Minor issue" }, { id: "rolled_back", label: "↩ Rolled back" } ]
                        Rectangle {
                            width: resultText.implicitWidth + Style.space(16)
                            height: Style.space(30)
                            radius: height / 2
                            color: root.updateResult === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.18) : soft
                            Text { id: resultText; anchors.centerIn: parent; text: modelData.label; color: root.updateResult === modelData.id ? accent : fg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.updateResult = modelData.id }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(38)
                    radius: height / 2
                    color: accent
                    Text { anchors.centerIn: parent; text: build.busy ? "Publishing…" : "Publish to Omarchy Build Network"; color: bg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: !build.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.submitCreate() }
                }
            }

            Item { width: 1; height: Style.space(8) }
            Rectangle { width: parent.width; height: 1; color: line }
            Text {
                width: parent.width
                text: "Public Build Network cards are signed, relay-readable metadata. DMs/groups stay in Friends. Shared setups are compare/review only; remote text is never executed."
                color: muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Item { width: 1; height: Style.space(8) }
        }
    }
}
