from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ModernFriendsUiContractTests(unittest.TestCase):
    def read(self, path: str) -> str:
        return (ROOT / path).read_text(encoding="utf-8")

    def test_v3_shell_is_primary_with_v2_and_legacy_fallbacks(self):
        bar = self.read("BarWidget.qml")
        self.assertIn('FriendsPanelV3.qml', bar)
        self.assertIn('FriendsPanelV2.qml', bar)
        self.assertIn('Panel.qml', bar)
        self.assertIn('modernPanelLoader.status === Loader.Error', bar)
        self.assertIn('compatibilityPanelLoader.status === Loader.Error', bar)
        self.assertIn('function openBuildTab', bar)
        self.assertIn('BuildNetworkPanelV3.qml', bar)

    def test_v3_shell_has_first_class_product_navigation(self):
        panel = self.read("FriendsPanelV3.qml")
        for label in ("Chats", "Requests", "World", "Circles", "Build", "Me"):
            self.assertIn(f'text: "{label}"', panel)
        for shortcut in ("New chat", "Ask help", "Setup"):
            self.assertIn(f'text: "{shortcut}"', panel)
        self.assertIn('root.openBuild("discover")', panel)
        self.assertIn('root.openBuild("share")', panel)
        self.assertIn('root.openBuild("help")', panel)

    def test_chat_header_and_empty_state_keep_copy_compact(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn('text: "Opened conversations"', panel)
        self.assertIn('text: "Pick a friend to start chatting."', panel)
        self.assertIn('visible: root.selectedFriend() !== null; onClicked:', panel)
        self.assertIn('visible: root.selectedFriend() !== null || root.selectedGroup() !== null; onClicked:', panel)
        self.assertIn('width: parent.width - (focusButton.visible ? focusButton.width : 0)', panel)

    def test_requests_are_not_mixed_into_chat_list_and_are_manageable(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        chats = panel.split("// CHATS:", 1)[1].split("// REQUESTS", 1)[0]
        requests = panel.split("// REQUESTS", 1)[1].split("// WORLD", 1)[0]
        self.assertNotIn("incomingFriendRequests()", chats)
        self.assertIn("incomingFriendRequests()", requests)
        self.assertIn("sentFriendRequests()", requests)
        self.assertIn('requestTab === "received"', requests)
        self.assertIn('requestTab === "sent"', requests)
        self.assertIn('text: "Accept"', requests)
        self.assertIn('text: "Decline"', requests)
        self.assertIn('text: "Cancel"', requests)
        self.assertIn('function declineFriendRequest', panel)
        self.assertIn('function cancelFriendRequest', panel)
        self.assertIn('root.service.declineFriendRequest(pingId)', panel)
        self.assertIn('root.service.cancelFriendRequest(publicKey)', panel)
        self.assertIn('function declineFriendRequest(pingId)', service)
        self.assertIn('function cancelFriendRequest(publicKey)', service)
        self.assertIn('"decline-friend"', service)
        self.assertIn('"cancel-friend"', service)
        self.assertNotIn('[root.service.binPath, "decline-friend"', panel)
        self.assertNotIn('[root.service.binPath, "cancel-friend"', panel)

    def test_chats_only_show_opened_conversations_and_have_separate_picker(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn("function conversationFriends()", panel)
        self.assertIn("root.directHasHistory(friend.public_key) || root.selectedFriendKey === friend.public_key", panel)
        self.assertIn("Full friend list lives here instead of cluttering Chats", panel)
        self.assertIn('text: "New chat"', panel)
        self.assertIn('text: "Create private group"', panel)

    def test_people_safety_actions_survive_the_v3_cleanup(self):
        panel = self.read("FriendsPanelV3.qml")
        legacy_panel = self.read("Panel.qml")
        service = self.read("Service.qml")
        world = panel.split("// WORLD", 1)[1].split("// CIRCLES", 1)[0]
        chats = panel.split("// CHATS:", 1)[1].split("// REQUESTS", 1)[0]
        self.assertIn("function blockPeer(peer)", panel)
        self.assertIn("function reportPeer(peer)", panel)
        self.assertIn("root.service.blockGlobal(peer.public_key)", panel)
        self.assertIn("root.reportUrl", panel)
        self.assertIn('text: "Block"', world)
        self.assertIn('text: "Report"', world)
        self.assertIn('text: "Close"', chats)
        self.assertIn('text: "Report"', chats)
        self.assertIn('text: "⋯"', world)
        self.assertIn("function blockGlobal(publicKey)", service)

        legacy_block_action = legacy_panel.split("root.service.blockGlobal(modelData.public_key)", 1)[0][-500:]
        self.assertIn('text: "Block"', legacy_block_action)
        self.assertNotIn('text: "Hide"', legacy_panel)

    def test_unblock_triggers_world_refresh_and_chat_drafts_do_not_cross_recipients(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        unblock = service.split("function unblockGlobal(publicKey)", 1)[1].split("function dismissNudge", 1)[0]
        self.assertIn("if (result.ok === true) root.refreshGlobal()", unblock)
        self.assertIn("function prepareDraftForConversation(key)", panel)
        self.assertIn('root.prepareDraftForConversation("friend:"', panel)
        self.assertIn('root.prepareDraftForConversation("group:"', panel)
        self.assertIn('root.draftConversationKey !== key', panel)
        self.assertIn('root.messageDraft = ""', panel)

    def test_failed_private_sends_and_group_creation_preserve_user_input(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        send = panel.split("function sendMessage()", 1)[1].split("function sendCommunity()", 1)[0]
        create_group = panel.split("function createGroup()", 1)[1].split("function openProfile()", 1)[0]
        self.assertIn("function clearSentDraft(ok)", send)
        self.assertIn("if (root.sendingMessage) return", send)
        self.assertIn("root.sendingMessage = false", send)
        draft_callback = send.split("function clearSentDraft(ok)", 1)[1].split("if (group) root.service.sendGroupMessage", 1)[0]
        self.assertIn("if (!ok || root.draftConversationKey !== conversationKey) return", draft_callback)
        self.assertLess(draft_callback.index("draftConversationKey !== conversationKey"), draft_callback.index('root.messageDraft = ""'))
        self.assertIn("root.service.sendGroupMessage(group.id, text, media, clearSentDraft)", send)
        self.assertIn("root.service.sendDm(friend.public_key, text, media, clearSentDraft)", send)
        self.assertIn("root.service.createGroup(name, selectedMembers, function(ok)", create_group)
        self.assertIn("if (root.creatingGroup) return", create_group)
        self.assertIn("root.creatingGroup = false", create_group)
        self.assertIn("if (!ok || root.groupNameDraft.trim() !== name", create_group)
        for method, fallback in (("sendDm", "Private message sent"), ("sendGroupMessage", "Group message could not be sent"), ("createGroup", "Group could not be created")):
            block = service.split(f"function {method}(", 1)[1].split("\n    function ", 1)[0]
            self.assertIn(f'root.reportResult(output, "{fallback}")', block)
            self.assertIn("if (callback) callback(result.ok === true, result)", block)

    def test_world_cards_keep_one_clear_primary_connection_action(self):
        panel = self.read("FriendsPanelV3.qml")
        world = panel.split("// WORLD", 1)[1].split("// CIRCLES", 1)[0]
        self.assertIn('return "Message"', panel)
        self.assertIn('return "Connect"', panel)
        self.assertNotIn('text: "Wave"', world)
        self.assertNotIn('text: "Focus"', world)
        self.assertNotIn('text: "Build"', world)
        self.assertIn('id: personAction', world)
        for filter_name in ("All", "New", "Building", "Friends"):
            self.assertIn(f'text: "{filter_name}"', world)

    def test_circles_is_room_style_chat_and_profile_exposes_privacy(self):
        panel = self.read("FriendsPanelV3.qml")
        circles = panel.split("// CIRCLES", 1)[1].split("// PROFILE", 1)[0]
        profile = panel.split("// PROFILE / SETTINGS", 1)[1].split("// New-chat picker", 1)[0]
        self.assertIn('text: "Omarchy Circle"', circles)
        self.assertIn('placeholder: "Message the Circle…"', circles)
        self.assertIn('text: "Privacy"', profile)
        self.assertNotIn("This is what other Omarchy users see when you choose to share it.", profile)
        self.assertIn('text: "Pseudonymous profile · sharing is opt-in."', profile)
        self.assertIn('readonly property string globalConnectionText:', panel)
        self.assertIn('"Presence not accepted"', panel)
        self.assertNotIn('"Reconnecting"', panel)
        for privacy_key in ("share_global", "share_window", "share_music", "share_project", "share_interests", "share_room"):
            self.assertIn(f'root.service.togglePrivacy("{privacy_key}")', profile)

    def test_modern_shell_owns_stable_midnight_palette(self):
        panel = self.read("FriendsPanelV3.qml")
        expected = {
            'canvas': '#070b14',
            'ink': '#f3f5ff',
            'violet': '#7c6cff',
            'cyan': '#58d6ff',
        }
        for name, value in expected.items():
            self.assertIn(f'property color {name}: "{value}"', panel)
        self.assertNotIn('readonly property color canvas: Color.background', panel)

    def test_build_network_uses_same_product_palette(self):
        panel = self.read("BuildNetworkPanelV3.qml")
        self.assertIn('readonly property color fg: "#f3f5ff"', panel)
        self.assertIn('readonly property color bg: "#070b14"', panel)
        self.assertIn('readonly property color accent: "#7c6cff"', panel)

    def test_update_path_is_visible_explicit_and_never_background_write(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        modern_service = self.read("ServiceModern.qml")
        self.assertIn('visible: root.updateInfo.available', panel)
        self.assertIn('root.service.updatePlugin()', panel)
        self.assertIn('omarchy', service)
        self.assertIn('rescanPlugins', service)
        self.assertNotIn('Component.onCompleted: root.service.updatePlugin()', panel)
        self.assertNotIn('autoUpdate', modern_service)
        self.assertNotIn('Timer {', modern_service)
        self.assertFalse((ROOT / "bin" / "omarchy-friends-auto-update").exists())

    def test_one_shot_write_capable_migration_helpers_are_removed(self):
        for path in (
            ROOT / ".github" / "workflows" / "request-management-patcher.yml",
            ROOT / "scripts" / "_request_patch.py",
            ROOT / ".github" / "workflows" / "v3-safety-patcher.yml",
            ROOT / "scripts" / "_v3_safety_patch.py",
        ):
            self.assertFalse(path.exists(), str(path))

    def test_shared_glass_primitives_exist(self):
        for path in (
            "GlassSurface.qml", "GlassPill.qml", "GlassButton.qml",
            "GlassField.qml", "GlassNavItem.qml", "GlassAvatar.qml",
        ):
            self.assertTrue((ROOT / path).is_file(), path)

    def test_chat_and_group_rows_are_keyboard_reachable(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertEqual(panel.count("Accessible.role: Accessible.Button"), 4)
        self.assertEqual(panel.count("Keys.onReturnPressed:"), 4)
        self.assertEqual(panel.count("Keys.onSpacePressed:"), 4)
        self.assertEqual(panel.count("activeFocusOnTab: true"), 4)

    def test_fallback_conversation_selection_remains_keyboard_reachable(self):
        for path, minimum_actions in (("FriendsPanelV2.qml", 3), ("Panel.qml", 4)):
            panel = self.read(path)
            self.assertGreaterEqual(panel.count("Keys.onReturnPressed:"), minimum_actions, path)
            self.assertGreaterEqual(panel.count("Keys.onSpacePressed:"), minimum_actions, path)
            self.assertGreaterEqual(panel.count("Accessible.role: Accessible.Button"), minimum_actions, path)

    def test_profile_has_explicit_feature_and_bug_feedback_paths(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn('text: "Suggest a feature"', panel)
        self.assertIn('text: "Report a bug"', panel)
        self.assertIn('labels=enhancement&title=Feature%20idea', panel)
        self.assertIn('labels=bug&title=Omarchy%20Friends%20bug', panel)


if __name__ == "__main__":
    unittest.main()
