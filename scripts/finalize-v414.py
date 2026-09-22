#!/usr/bin/env python3
"""One-shot, anchor-checked finalizer for Omarchy Friends v4.14 RC.

This script only wires already-implemented service actions into the existing V3
panel, exposes Build Network visibly from Friends, and synchronizes the version.
It deliberately refuses to continue if an expected anchor changed.
"""

from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


def insert_before_once(text: str, anchor: str, addition: str, label: str) -> str:
    count = text.count(anchor)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(anchor, addition + anchor, 1)


def finalize_engine_version() -> None:
    path = "bin/omarchy-friends"
    text = read(path)
    if 'PLUGIN_VERSION = "4.14.0"' in text:
        return
    updated, count = re.subn(
        r'^PLUGIN_VERSION\s*=\s*"4\.12\.0"\s*$',
        'PLUGIN_VERSION = "4.14.0"',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise RuntimeError("engine version: expected PLUGIN_VERSION 4.12.0 exactly once")
    write(path, updated)


def finalize_friends_entry() -> None:
    path = "Panel.qml"
    text = read(path)
    marker = "// v4.14-final: visible Build Network entry"
    if marker in text:
        return
    old = '''            Item {
                width: parent.width - titleText.width - settingsButton.width
                height: 1
            }

            Rectangle {
                id: settingsButton
'''
    new = '''            Item {
                width: parent.width - titleText.width - buildNetworkButton.width - settingsButton.width - Style.space(6)
                height: 1
            }

            // v4.14-final: visible Build Network entry
            Rectangle {
                id: buildNetworkButton
                width: buildNetworkButtonText.implicitWidth + Style.space(18)
                height: Style.space(30)
                radius: height / 2
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.22)

                Text {
                    id: buildNetworkButtonText
                    anchors.centerIn: parent
                    text: "🛠 Build"
                    color: accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.hostWidget && typeof root.hostWidget.openBuild === "function")
                            root.hostWidget.openBuild()
                    }
                }
            }

            Item { width: Style.space(6); height: 1 }

            Rectangle {
                id: settingsButton
'''
    text = replace_once(text, old, new, "Friends Build entry")
    write(path, text)


def finalize_build_panel() -> None:
    path = "BuildNetworkPanelV3.qml"
    text = read(path)
    if "// v4.14-final: promise-complete UI wiring" in text:
        return

    # Root state for the contextual final actions.
    old = '''    property bool useDetectedEnvironment: true

    contentWidth:'''
    new = '''    property bool useDetectedEnvironment: true

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

    contentWidth:'''
    text = replace_once(text, old, new, "V3 root state")

    # Copy generated external share text immediately.
    old = '''        onActionResult: function(ok, message) {
            root.notice = message || (ok ? "Done" : "Build Network action failed")
            noticeTimer.restart()
        }
    }
'''
    new = '''        onActionResult: function(ok, message) {
            root.notice = message || (ok ? "Done" : "Build Network action failed")
            noticeTimer.restart()
        }
        onShareTextReady: function(text) {
            root.copyText(text, "Share text copied")
        }
    }
'''
    text = replace_once(text, old, new, "share-text signal")

    # Discover cards: make sharing a first-class action.
    old = '''                                    GlassPill { text: "Save"; onClicked: build.saveObject(modelData.id) }
                                    GlassPill { text: modelData.mine ? "You" : "Chat"; enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
'''
    new = '''                                    GlassPill { text: "Save"; onClicked: build.saveObject(modelData.id) }
                                    GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                    GlassPill { text: modelData.mine ? "You" : "Chat"; enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
'''
    text = replace_once(text, old, new, "Discover share")

    # Build Room delegate gets a stable outer reference for nested GitHub items.
    old = '''                Repeater {
                    model: build.buildRooms
                    GlassSurface {
                        width: parent.width
'''
    new = '''                Repeater {
                    model: build.buildRooms
                    GlassSurface {
                        id: roomCard
                        property var roomItem: modelData
                        width: parent.width
'''
    text = replace_once(text, old, new, "Build Room delegate")

    old = '''                                GlassPill { visible: !!root.repoPulls(modelData.repo_url); text: "PRs"; onClicked: root.openUrl(root.repoPulls(modelData.repo_url)) }
                                GlassPill { text: "Join"; active: true; onClicked: build.joinRoom(modelData.id, "Builder", "") }
'''
    new = '''                                GlassPill { visible: !!root.repoPulls(modelData.repo_url); text: "PRs"; onClicked: root.openUrl(root.repoPulls(modelData.repo_url)) }
                                GlassPill { visible: !!modelData.repo_url; text: "GitHub pulse"; onClicked: build.loadGithubSnapshot(modelData.repo_url) }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { text: "Join"; active: true; onClicked: build.joinRoom(modelData.id, "Builder", "") }
'''
    text = replace_once(text, old, new, "Build Room actions")

    old = '''                                GlassPill { visible: modelData.mine; text: "Ship ↗"; strong: true; onClicked: build.updateRoom(modelData.id, "shipped", modelData.repo_url || "") }
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.tab === "share"
'''
    new = '''                                GlassPill { visible: modelData.mine; text: "Ship ↗"; strong: true; onClicked: build.updateRoom(modelData.id, "shipped", modelData.repo_url || "") }
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
'''
    text = replace_once(text, old, new, "GitHub snapshot UI")

    # Setup cards: expose components and external sharing.
    old = '''                Repeater {
                    model: build.setups
                    GlassSurface {
                        width: parent.width
'''
    new = '''                Repeater {
                    model: build.setups
                    GlassSurface {
                        id: setupCard
                        property var setupItem: modelData
                        width: parent.width
'''
    text = replace_once(text, old, new, "Setup delegate")

    old = '''                                GlassPill { visible: !!modelData.repo_url; text: "Dotfiles ↗"; onClicked: root.openUrl(modelData.repo_url) }
                                GlassPill { text: modelData.mine ? "You" : "Chat"; enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
                            }
                        }
                    }
                }

                GlassSurface {
                    visible: !!(build.setupComparison && build.setupComparison.setup_id)
'''
    new = '''                                GlassPill { visible: !!modelData.repo_url; text: "Dotfiles ↗"; onClicked: root.openUrl(modelData.repo_url) }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: modelData.mine; text: "+ Component"; onClicked: root.componentSetupId = modelData.id }
                                GlassPill { text: modelData.mine ? "You" : "Chat"; enabled: !modelData.mine; onClicked: root.connectBuilder(modelData.public_key) }
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
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.componentNameDraft; onTextChanged: root.componentNameDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter; placeholderText: "Name, e.g. OLED bar" }
                        }
                        GlassSurface {
                            width: parent.width; height: Style.space(42); radius: Style.space(13); fillOpacity: 0.48
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.componentUrlDraft; onTextChanged: root.componentUrlDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter; placeholderText: "HTTPS source link (optional)" }
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
'''
    text = replace_once(text, old, new, "Setup components UI")

    # Help: availability and live helpers before the request list.
    anchor = '''                Repeater {
                    model: build.helpRequests
'''
    addition = '''                GlassSurface {
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
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.availabilitySkillsDraft; onTextChanged: root.availabilitySkillsDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter; placeholderText: "Skills: NVIDIA, QML, Hyprland…" }
                        }
                        GlassSurface {
                            width: parent.width; height: Style.space(42); radius: Style.space(13); fillOpacity: 0.48
                            TextInput { anchors.fill: parent; anchors.margins: Style.space(11); text: root.availabilityNoteDraft; onTextChanged: root.availabilityNoteDraft = text; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; verticalAlignment: TextInput.AlignVCenter; placeholderText: "Optional note" }
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
                            GlassPill { id: helperChat; text: modelData.public_key === build.profile.public_key ? "You" : "Chat"; enabled: modelData.public_key !== build.profile.public_key; onClicked: root.connectBuilder(modelData.public_key) }
                        }
                    }
                }

'''
    text = insert_before_once(text, anchor, addition, "Availability UI")

    # Matching helpers on each help request.
    old = '''                            Text { visible: modelData.environment_tags && modelData.environment_tags.length > 0; width: parent.width; text: modelData.environment_tags.join("   ·   "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
                            Flow {
'''
    new = '''                            Text { visible: modelData.environment_tags && modelData.environment_tags.length > 0; width: parent.width; text: modelData.environment_tags.join("   ·   "); color: accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
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
'''
    text = replace_once(text, old, new, "Helper matches")

    old = '''                                GlassPill { visible: modelData.mine && modelData.status !== "solved"; text: "Solved ✓"; strong: true; onClicked: build.resolveHelp(modelData.id, "solved") }
                            }
                        }
                    }
                }

                Text { text: "Community memory"; color: fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
'''
    new = '''                                GlassPill { visible: modelData.mine && modelData.status !== "solved"; text: "Solved ✓"; strong: true; onClicked: build.resolveHelp(modelData.id, "solved") }
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
'''
    text = replace_once(text, old, new, "Help to solution")

    old = '''                                GlassPill { text: "Copy"; onClicked: root.copyText(modelData.solution || "", "Solution copied") }
                                GlassPill { visible: !!modelData.source_url; text: "Source ↗"; onClicked: root.openUrl(modelData.source_url) }
'''
    new = '''                                GlassPill { text: "Copy"; onClicked: root.copyText(modelData.solution || "", "Solution copied") }
                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: !!modelData.source_url; text: "Source ↗"; onClicked: root.openUrl(modelData.source_url) }
'''
    text = replace_once(text, old, new, "Solution share")

    # Community sharing for real-world events/challenges.
    old = '''                                GlassPill { visible: !!modelData.event_url; text: "Open ↗"; onClicked: root.openUrl(modelData.event_url) }
'''
    new = '''                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: !!modelData.event_url; text: "Open ↗"; onClicked: root.openUrl(modelData.event_url) }
'''
    text = replace_once(text, old, new, "Event share")

    old = '''                                GlassPill { visible: !!modelData.rules_url; text: "Rules ↗"; onClicked: root.openUrl(modelData.rules_url) }
'''
    new = '''                                GlassPill { text: "Share"; onClicked: build.generateShareText(modelData.id) }
                                GlassPill { visible: !!modelData.rules_url; text: "Rules ↗"; onClicked: root.openUrl(modelData.rules_url) }
'''
    text = replace_once(text, old, new, "Challenge share")

    # Small diagnostics/repair surface before the footer.
    anchor = '''            Item { width: 1; height: Style.space(3) }
            Text {
                width: parent.width
                text: "Built for Omarchy'''
    addition = '''            GlassSurface {
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

'''
    text = insert_before_once(text, anchor, addition, "Diagnostics footer")

    write(path, text)


def main() -> None:
    finalize_engine_version()
    finalize_friends_entry()
    finalize_build_panel()
    print("v4.14 finalizer applied successfully")


if __name__ == "__main__":
    main()
