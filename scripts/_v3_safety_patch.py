from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing patch anchor: {label}")
    return text.replace(old, new, 1)


# Keep request lifecycle operations behind the Service API instead of having
# the panel know how to launch engine commands directly.
service_path = Path("Service.qml")
service = service_path.read_text(encoding="utf-8")
service = replace_once(
    service,
    '''    function acceptFriendRequest(pingId) {
        runAction([root.binPath, "accept-friend", pingId], function(output) { root.reportResult(output, "You are now friends"); root.refresh() })
    }

    function sendDm(publicKey, text, mediaUrl) {
''',
    '''    function acceptFriendRequest(pingId) {
        runAction([root.binPath, "accept-friend", pingId], function(output) { root.reportResult(output, "You are now friends"); root.refresh() })
    }

    function declineFriendRequest(pingId) {
        runAction([root.binPath, "decline-friend", pingId], function(output) { root.reportResult(output, "Friend request declined"); root.refresh() })
    }

    function cancelFriendRequest(publicKey) {
        runAction([root.binPath, "cancel-friend", publicKey], function(output) { root.reportResult(output, "Friend request cancelled"); root.refresh() })
    }

    function sendDm(publicKey, text, mediaUrl) {
''',
    "service request wrappers",
)
service_path.write_text(service, encoding="utf-8")

panel_path = Path("FriendsPanelV3.qml")
panel = panel_path.read_text(encoding="utf-8")

panel = replace_once(
    panel,
    '''    readonly property var updateInfo: service && service.updateInfo ? service.updateInfo : ({ available: false, current: "4.15.0", latest: "4.15.0" })

    property string page: "chats"
''',
    '''    readonly property var updateInfo: service && service.updateInfo ? service.updateInfo : ({ available: false, current: "4.15.0", latest: "4.15.0" })
    readonly property string reportUrl: "https://github.com/harshithnadig/omarchy-friends/issues/new?labels=bug&title=Omarchy%20Friends%20report"

    property string page: "chats"
''',
    "report URL",
)

panel = replace_once(
    panel,
    '''    function declineFriendRequest(pingId) {
        if (!root.service || !pingId) return
        root.service.runAction([root.service.binPath, "decline-friend", pingId], function(output) {
            root.service.reportResult(output, "Friend request declined")
            root.service.refresh()
        })
    }

    function cancelFriendRequest(publicKey) {
        if (!root.service || !publicKey) return
        root.service.runAction([root.service.binPath, "cancel-friend", publicKey], function(output) {
            root.service.reportResult(output, "Friend request cancelled")
            root.service.refresh()
        })
    }

    function toggleGroupMember(publicKey) {
''',
    '''    function declineFriendRequest(pingId) {
        if (root.service && pingId) root.service.declineFriendRequest(pingId)
    }

    function cancelFriendRequest(publicKey) {
        if (root.service && publicKey) root.service.cancelFriendRequest(publicKey)
    }

    function hidePeer(peer) {
        if (!root.service || !peer || !peer.public_key) return
        root.service.blockGlobal(peer.public_key)
        if (root.selectedFriendKey === peer.public_key) root.selectedFriendKey = ""
        root.showNotice((peer.handle || "Builder") + " hidden from Friends")
    }

    function reportPeer(peer) {
        if (!peer || !peer.public_key) return
        var payload = "Omarchy Friends report\\n\\nHandle: " + (peer.handle || "Unknown") + "\\nPublic key: " + peer.public_key + "\\n\\nWhat happened?\\n"
        Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(payload) + " | wl-copy"])
        Quickshell.execDetached(["xdg-open", root.reportUrl])
        root.showNotice("Copied a report template and opened GitHub")
    }

    function toggleGroupMember(publicKey) {
''',
    "request wrappers and safety helpers",
)

# Conversation-level safety is contextual: it appears only for a selected
# one-to-one friend and does not clutter group chats.
panel = replace_once(
    panel,
    '''                                        width: parent.width - focusButton.width - buildTogetherButton.width - Style.space(70)
''',
    '''                                        width: parent.width - focusButton.width - buildTogetherButton.width - hideChatButton.width - reportChatButton.width - Style.space(88)
''',
    "chat header width",
)
panel = replace_once(
    panel,
    '''                                    GlassButton { id: buildTogetherButton; text: "Build"; icon: "⌁"; compact: true; enabled: root.selectedFriend() !== null || root.selectedGroup() !== null; onClicked: root.openBuild("create") }
                                }
''',
    '''                                    GlassButton { id: buildTogetherButton; text: "Build"; icon: "⌁"; compact: true; enabled: root.selectedFriend() !== null || root.selectedGroup() !== null; onClicked: root.openBuild("create") }
                                    GlassButton { id: hideChatButton; text: "Hide"; compact: true; visible: root.selectedFriend() !== null; enabled: visible; onClicked: root.hidePeer(root.selectedFriend()) }
                                    GlassButton { id: reportChatButton; text: "Report"; compact: true; visible: root.selectedFriend() !== null; enabled: visible; onClicked: root.reportPeer(root.selectedFriend()) }
                                }
''',
    "chat safety actions",
)

# World keeps one primary relationship action. The small Safety toggle reveals
# Hide/Report only on demand instead of restoring the old row of micro-actions.
panel = replace_once(
    panel,
    '''                                    GlassSurface {
                                        width: (worldFlow.width - Style.space(8)) / 2
                                        height: Style.space(144)
                                        radius: Style.space(17)
''',
    '''                                    GlassSurface {
                                        property bool safetyOpen: false
                                        width: (worldFlow.width - Style.space(8)) / 2
                                        height: Style.space(safetyOpen ? 180 : 144)
                                        radius: Style.space(17)
''',
    "world card safety state",
)
panel = replace_once(
    panel,
    '''                                                    width: parent.width - personAction.width - Style.space(58)
''',
    '''                                                    width: parent.width - personAction.width - safetyToggle.width - Style.space(66)
''',
    "world card title width",
)
panel = replace_once(
    panel,
    '''                                                GlassButton { id: personAction; text: root.peerActionLabel(modelData); compact: true; primary: root.peerActionLabel(modelData) === "Accept" || root.peerActionLabel(modelData) === "Message"; enabled: root.peerActionLabel(modelData) !== "Requested" && root.peerActionLabel(modelData) !== "Needs update"; onClicked: root.activatePeer(modelData) }
                                            }
''',
    '''                                                GlassButton { id: personAction; text: root.peerActionLabel(modelData); compact: true; primary: root.peerActionLabel(modelData) === "Accept" || root.peerActionLabel(modelData) === "Message"; enabled: root.peerActionLabel(modelData) !== "Requested" && root.peerActionLabel(modelData) !== "Needs update"; onClicked: root.activatePeer(modelData) }
                                                GlassButton { id: safetyToggle; text: "⋯"; compact: true; selected: parent.parent.parent.safetyOpen; onClicked: parent.parent.parent.safetyOpen = !parent.parent.parent.safetyOpen }
                                            }
''',
    "world safety toggle",
)
panel = replace_once(
    panel,
    '''                                                GlassPill { visible: modelData.common_ground && modelData.common_ground.length > 0; text: "common ground"; active: true; accentColor: root.violet }
                                            }
                                        }
''',
    '''                                                GlassPill { visible: modelData.common_ground && modelData.common_ground.length > 0; text: "common ground"; active: true; accentColor: root.violet }
                                            }

                                            Row {
                                                visible: parent.parent.safetyOpen
                                                width: parent.width
                                                spacing: Style.space(6)
                                                GlassButton { text: "Hide builder"; compact: true; onClicked: root.hidePeer(modelData) }
                                                GlassButton { text: "Report"; compact: true; onClicked: root.reportPeer(modelData) }
                                            }
                                        }
''',
    "world safety actions",
)

panel_path.write_text(panel, encoding="utf-8")
