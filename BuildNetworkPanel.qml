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

    contentWidth: root.fittedContentWidth(Style.space(540))
    contentHeight: root.fittedContentHeight(deck.implicitHeight)

    BuildNetworkService {
        id: build
        onActionResult: function(ok, message) {
            root.notice = message || (ok ? "Done" : "Build Network action failed")
            noticeTimer.restart()
        }
    }

    Timer {
        id: noticeTimer
        interval: 3200
        onTriggered: root.notice = ""
    }

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

    function copyText(text, message) {
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(String(text || "")) + " | wl-copy"])
        root.notice = message || "Copied"
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

    function connectBuilder(publicKey) {
        if (!publicKey || !root.friendsService) {
            root.notice = "Open the main Friends deck to connect with this builder"
            noticeTimer.restart()
            return
        }
        root.friendsService.requestFriend(publicKey)
        root.notice = "Chat invite sent through Friends"
        noticeTimer.restart()
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
        else if (root.createKind === "help") build.createHelp(title, body, extra, tags)
        else if (root.createKind === "solution") build.createSolution(title, extra, body, tags, url)
        else if (root.createKind === "ship") build.ship(title, body, url, tags, "")
        else if (root.createKind === "update") build.reportUpdate(extra || title, root.updateResult, tags, body)
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
                height: Style.space(44)
                spacing: Style.space(8)
                Column {
                    width: parent.width - refreshButton.width - Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🛠 Omarchy Build Network"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                    Text { text: "Build together · share setups · test · help · ship"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
                Rectangle {
                    id: refreshButton
                    width: Style.space(74)
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
                            { label: "Tests", value: build.stats.tests || 0 }
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
                Text { width: parent.width; text: "Not an infinite social feed — recent things people are actually building, sharing, solving or organizing."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                Repeater {
                    model: build.discoverFeed.slice ? build.discoverFeed.slice(0, 24) : []
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
                            spacing: Style.space(4)
                            Row {
                                width: parent.width
                                Text { width: parent.width - connectDiscover.width; text: root.kindLabel(modelData.type) + " · " + (modelData.author || "OmarchyBuilder"); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                                Text { id: connectDiscover; text: modelData.mine ? "You" : "Chat"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }
                            }
                            Text { width: parent.width; text: modelData.title || "Community update"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.summary || modelData.goal || modelData.problem || modelData.solution || modelData.notes || modelData.prompt || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight }
                            Text { visible: !!(modelData.artifact_url || modelData.repo_url || modelData.event_url || modelData.source_url); text: "Open link ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.artifact_url || modelData.repo_url || modelData.event_url || modelData.source_url) } }
                        }
                    }
                }
                Text { visible: build.discoverFeed.length === 0; width: parent.width; text: "No public Build Network objects yet. Create the first idea or build room — this empty state is exactly what early testers should verify."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }

                Text { visible: build.contributors.length > 0; text: "Useful contributors"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Repeater {
                    model: build.contributors.slice ? build.contributors.slice(0, 8) : []
                    Rectangle {
                        width: parent.width
                        height: Style.space(42)
                        radius: Style.space(8)
                        color: soft
                        Row {
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            Text { width: parent.width - contributorChat.width; text: (modelData.handle || "Builder") + " · 🛠 " + (modelData.builds || 0) + " · 🚀 " + (modelData.ships || 0) + " · 🧪 " + (modelData.tests || 0) + " · 🧠 " + (modelData.solutions || 0); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
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
                            Text { width: parent.width; text: (modelData.tags || []).join ? (modelData.tags || []).join(" · ") : ""; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                            Row { spacing: Style.space(14); Text { text: "I'm interested"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.markInterested(modelData.id, "") } }; Text { text: "Build it"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.buildIdea(modelData.id, "", modelData.tags || []) } }; Text { text: modelData.mine ? "You" : "Chat author"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } } }
                        }
                    }
                }

                Text { text: "Build Rooms"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
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
                            Text { width: parent.width; text: "🛠 " + (modelData.title || "Build Room") + " · " + ((modelData.join_count || 0) + 1) + " builders"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.goal || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: "Needs: " + ((modelData.roles_needed || []).join ? (modelData.roles_needed || []).join(" · ") : "open collaboration"); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row { spacing: Style.space(14); Text { text: "Join build"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.joinRoom(modelData.id, "Builder", "Happy to collaborate") } }; Text { visible: !!modelData.repo_url; text: "GitHub ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.repo_url) } }; Text { text: modelData.mine ? "You own this" : "Chat owner"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } } }
                        }
                    }
                }

                Text { visible: build.challenges.length > 0; text: "🏆 Challenges"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
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
                            Text { width: parent.width; text: "🏆 " + modelData.title + (modelData.deadline_text ? " · " + modelData.deadline_text : ""); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.prompt || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row { spacing: Style.space(14); Text { text: "Start a build"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.createRoom(modelData.title, modelData.prompt || "", "", modelData.tags || [], [], "") } }; Text { visible: !!modelData.rules_url; text: "Rules ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.rules_url) } } }
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
                Text { width: parent.width; text: "Copyable recipes only. Friends does not auto-run someone else's configuration."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
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
                            Row { spacing: Style.space(14); Text { text: "Copy recipe"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyText(root.setupRecipe(modelData), "Setup recipe copied — review before applying") } }; Text { visible: !!modelData.repo_url; text: "Dotfiles ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.repo_url) } }; Text { text: modelData.mine ? "You" : "Chat"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } } }
                        }
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
                        border.width: 1
                        border.color: line
                        Column {
                            id: testCard
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "🧪 " + modelData.title + (modelData.version ? " · " + modelData.version : ""); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: "Wanted: " + ((modelData.requested_tags || []).join ? (modelData.requested_tags || []).join(" · ") : "any Omarchy machine"); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: (modelData.pass_count || 0) + " passes · " + Math.max(0, (modelData.result_count || 0) - (modelData.pass_count || 0)) + " issues"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                            Row { spacing: Style.space(14); Text { text: "✅ Works"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.submitTestResult(modelData.id, "pass", (build.detectedSetup.components || []).concat(build.detectedSetup.theme ? [build.detectedSetup.theme] : []), "Works on my machine") } }; Text { text: "⚠️ Issue"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: build.submitTestResult(modelData.id, "issue", build.detectedSetup.components || [], "Found an issue — message me for details") } }; Text { visible: !!modelData.artifact_url; text: "Artifact ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.artifact_url) } } }
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
                Text { width: parent.width; text: "Use this after your agent gets stuck. Share only the environment/problem details you choose."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
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
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "🆘 " + modelData.title + " · " + (modelData.author || "Builder"); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.problem || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: !!modelData.tried; width: parent.width; text: "Already tried: " + modelData.tried; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row { spacing: Style.space(14); Text { text: modelData.mine ? "Your request" : "I can help → chat"; color: modelData.mine ? muted : accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; MouseArea { anchors.fill: parent; enabled: !modelData.mine; cursorShape: Qt.PointingHandCursor; onClicked: root.connectBuilder(modelData.public_key) } }; Text { text: "Copy context"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyText((modelData.title || "") + "\n" + (modelData.problem || "") + "\nTried: " + (modelData.tried || "") + "\nEnvironment: " + ((modelData.environment_tags || []).join ? (modelData.environment_tags || []).join(", ") : ""), "Help context copied") } } }
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
                            spacing: Style.space(4)
                            Text { width: parent.width; text: "🧠 " + modelData.title + " · " + (modelData.author || "Builder"); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { visible: !!modelData.problem; width: parent.width; text: "Problem: " + modelData.problem; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: "Solution: " + (modelData.solution || ""); color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Row { spacing: Style.space(14); Text { text: "Copy solution"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyText((modelData.solution || ""), "Solution copied") } }; Text { visible: !!modelData.source_url; text: "Source ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.source_url) } } }
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
                Text { width: parent.width; text: "Only explicit user reports are counted — no hidden telemetry."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                Repeater {
                    model: build.updatePulse
                    Rectangle {
                        width: parent.width
                        height: Style.space(50)
                        radius: Style.space(9)
                        color: soft
                        Row {
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(10)
                            Text { width: parent.width * 0.3; text: "Omarchy " + modelData.version; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                            Text { width: parent.width * 0.6; text: "✅ " + modelData.working + "   ⚠️ " + modelData.minor_issue + "   ↩ " + modelData.rolled_back + "   · " + modelData.total + " reports"; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        }
                    }
                }

                Text { text: "📍 Events & meetups"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
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
                            Text { width: parent.width; text: "📍 " + modelData.title; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: (modelData.when_text || "Time TBD") + (modelData.location ? " · " + modelData.location : ""); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { width: parent.width; text: modelData.notes || ""; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Text { visible: !!modelData.event_url; text: "Event link ↗"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(modelData.event_url) } }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "create"
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.space(9)
                Text { text: "Create for the Omarchy community"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
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
                            width: createKindText.implicitWidth + Style.space(18)
                            height: Style.space(30)
                            radius: height / 2
                            color: root.createKind === modelData.id ? accent : soft
                            border.width: root.createKind === modelData.id ? 0 : 1
                            border.color: line
                            Text { id: createKindText; anchors.centerIn: parent; text: modelData.label; color: root.createKind === modelData.id ? bg : fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: root.createKind === modelData.id }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.createKind = modelData.id }
                        }
                    }
                }

                TextField {
                    visible: root.createKind !== "update"
                    width: parent.width
                    placeholderText: root.createKind === "setup" ? "Setup name" : "Title"
                    text: root.titleDraft
                    onTextChanged: root.titleDraft = text
                }
                TextArea {
                    width: parent.width
                    height: Style.space(92)
                    placeholderText: root.createKind === "idea" ? "What should exist?" : root.createKind === "room" ? "What are you building?" : root.createKind === "help" ? "Describe the problem" : root.createKind === "solution" ? "Explain the solution" : root.createKind === "ship" ? "What did you ship?" : root.createKind === "challenge" ? "Challenge prompt" : "Notes / description"
                    text: root.bodyDraft
                    wrapMode: TextEdit.Wrap
                    onTextChanged: root.bodyDraft = text
                }
                TextField {
                    visible: root.createKind !== "idea" && root.createKind !== "help" && root.createKind !== "update"
                    width: parent.width
                    placeholderText: root.createKind === "room" || root.createKind === "setup" ? "GitHub/repo URL (optional)" : root.createKind === "event" ? "Event URL (optional)" : root.createKind === "challenge" ? "Rules URL (optional)" : root.createKind === "solution" ? "Source URL (optional)" : "Artifact URL (optional)"
                    text: root.urlDraft
                    onTextChanged: root.urlDraft = text
                }
                TextField {
                    width: parent.width
                    placeholderText: root.createKind === "room" ? "Roles needed, comma separated" : root.createKind === "event" ? "Location / online" : root.createKind === "update" || root.createKind === "help" || root.createKind === "solution" || root.createKind === "test" ? "Environment/tags, comma separated" : "Tags, comma separated"
                    text: root.tagsDraft
                    onTextChanged: root.tagsDraft = text
                }
                TextField {
                    visible: root.createKind === "test" || root.createKind === "help" || root.createKind === "solution" || root.createKind === "update" || root.createKind === "event" || root.createKind === "challenge"
                    width: parent.width
                    placeholderText: root.createKind === "test" || root.createKind === "update" ? "Version" : root.createKind === "help" ? "What your AI/you already tried" : root.createKind === "solution" ? "Problem this solves" : root.createKind === "event" ? "When" : "Deadline"
                    text: root.extraDraft
                    onTextChanged: root.extraDraft = text
                }

                Row {
                    visible: root.createKind === "update"
                    width: parent.width
                    spacing: Style.space(6)
                    Repeater {
                        model: [{ id: "working", label: "✅ Working" }, { id: "minor_issue", label: "⚠️ Minor issue" }, { id: "rolled_back", label: "↩ Rolled back" }]
                        Rectangle {
                            width: (parent.width - Style.space(12)) / 3
                            height: Style.space(32)
                            radius: Style.space(8)
                            color: root.updateResult === modelData.id ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : soft
                            Text { anchors.centerIn: parent; text: modelData.label; color: root.updateResult === modelData.id ? accent : muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: root.updateResult === modelData.id }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.updateResult = modelData.id }
                        }
                    }
                }

                Rectangle {
                    visible: root.createKind === "setup"
                    width: parent.width
                    height: detectedColumn.implicitHeight + Style.space(16)
                    radius: Style.space(9)
                    color: soft
                    Column {
                        id: detectedColumn
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(3)
                        Text { text: "Safe local preview"; color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { width: parent.width; text: "Theme: " + (build.detectedSetup.theme || "unknown") + " · " + (build.detectedSetup.components || []).join(" · "); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                        Text { width: parent.width; text: "Plugins detected: " + ((build.detectedSetup.plugins || []).join ? (build.detectedSetup.plugins || []).join(", ") : "none"); color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
                        Text { width: parent.width; text: "No private files or config contents are uploaded."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Style.space(38)
                    radius: Style.space(9)
                    color: build.busy ? soft : accent
                    Text { anchors.centerIn: parent; text: build.busy ? "Publishing…" : "Publish to Build Network"; color: build.busy ? muted : bg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: !build.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.submitCreate() }
                }
                Text { width: parent.width; text: "Public Build Network cards are signed and relay-readable. Do not put secrets, private repo URLs, tokens, addresses, or sensitive personal information here."; color: muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            }

            Item { width: 1; height: Style.space(14) }
        }
    }
}
