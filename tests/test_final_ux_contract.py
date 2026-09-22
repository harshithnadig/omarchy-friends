from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class FinalUxContractTests(unittest.TestCase):
    def test_build_network_chat_opens_existing_friend_conversation(self):
        bar = read("BarWidget.qml")
        friends = read("FriendsPanelV3.qml")
        build = read("BuildNetworkPanelV3.qml")

        self.assertIn("function openFriendChat(publicKey)", bar)
        self.assertIn("function deliverPendingFriendChat()", bar)
        self.assertIn("openChatForPublicKey", bar)
        self.assertIn("function openChatForPublicKey(publicKey)", friends)
        self.assertIn("function builderActionLabel(publicKey)", build)
        self.assertIn('relation.status === "friends"', build)
        self.assertIn('return "Chat"', build)
        self.assertIn('return "Accept"', build)
        self.assertIn('return "Requested"', build)
        self.assertIn('return "Connect"', build)
        self.assertIn("root.hostWidget.openFriendChat(publicKey)", build)

    def test_build_network_does_not_resend_request_to_existing_friend(self):
        build = read("BuildNetworkPanelV3.qml")
        start = build.index("function connectBuilder(publicKey)")
        end = build.index("function repoIssues", start)
        body = build[start:end]
        friend_branch = body.split('relation.status === "friends"', 1)[1].split("var incoming", 1)[0]
        self.assertIn("openFriendChat(publicKey)", friend_branch)
        self.assertNotIn("requestFriend(publicKey)", friend_branch)
        self.assertIn("requestFriend(publicKey)", body)

    def test_chat_handoff_routes_nonfriends_to_truthful_state(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn('root.requestTab = "received"', friends)
        self.assertIn('root.requestTab = "sent"', friends)
        self.assertIn('root.page = "world"', friends)
        self.assertIn("Accept the request to start chatting", friends)
        self.assertIn("Friend request is still pending", friends)
        self.assertIn("Connect with this builder before starting a private chat", friends)

    def test_chat_close_and_blocked_people_recovery_contract(self):
        friends = read("FriendsPanelV3.qml")
        service = read("Service.qml")
        engine = read("bin/omarchy-friends")
        header = friends[friends.index("id: closeChatButton"):friends.index("id: reportChatButton")]
        self.assertIn('text: "Close"', header)
        self.assertIn("root.closeConversation()", header)
        self.assertNotIn("blockGlobal", header)
        self.assertIn('text: "Block"', friends)
        self.assertIn('text: "Blocked people"', friends)
        self.assertIn('text: "Unblock"', friends)
        self.assertIn("function unblockGlobal(publicKey)", service)
        self.assertIn('"unblock-global"', service)
        self.assertIn("def unblock_global(self, public_key)", engine)
        self.assertIn('command == "unblock-global"', engine)

    def test_private_shared_links_are_clickable_but_http_only(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn("function openSafeUrl(url)", friends)
        self.assertIn('url.indexOf("https://") !== 0', friends)
        self.assertIn('url.indexOf("http://") !== 0', friends)
        self.assertIn('["xdg-open", url]', friends)
        self.assertIn("onClicked: root.openSafeUrl", friends)

    def test_sent_request_actions_reserve_their_own_width(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn("id: sentRequestActions", friends)
        self.assertIn("parent.width - sentRequestActions.width - Style.space(60)", friends)
        self.assertIn('text: "Pending"', friends)
        self.assertIn('text: "Cancel"', friends)

    def test_private_groups_remain_visible_before_first_message(self):
        friends = read("FriendsPanelV3.qml")
        start = friends.index("function conversationGroups()")
        end = friends.index("function selectedFriend()", start)
        body = friends[start:end]
        self.assertIn("root.groupsList()", body)
        self.assertIn("out.push(group)", body)
        self.assertNotIn("groupHasHistory(group.id)", body)
        self.assertNotIn("if (!active) continue", body)

    def test_build_network_is_lazy_loaded(self):
        bar = read("BarWidget.qml")
        start = bar.index("id: buildPanelLoader")
        body = bar[start:]
        self.assertIn("active: root.buildCardOpen", body)
        self.assertIn('source: Qt.resolvedUrl("BuildNetworkPanelV3.qml")', body)
        self.assertNotIn("active: true", body)

    def test_primary_glass_actions_are_keyboard_reachable(self):
        for path in ("GlassButton.qml", "GlassNavItem.qml", "GlassPill.qml"):
            text = read(path)
            self.assertIn("activeFocusOnTab: root.enabled", text, path)
            self.assertIn("Keys.onPressed", text, path)
            self.assertIn("Qt.Key_Return", text, path)
            self.assertIn("Qt.Key_Enter", text, path)
            self.assertIn("Qt.Key_Space", text, path)
            self.assertIn("root.forceActiveFocus()", text, path)

    def test_keyboard_focus_has_visible_feedback(self):
        button = read("GlassButton.qml")
        nav = read("GlassNavItem.qml")
        pill = read("GlassPill.qml")
        self.assertIn("root.activeFocus", button)
        self.assertIn("root.activeFocus", nav)
        self.assertIn("root.activeFocus", pill)
        self.assertIn("border.width: root.activeFocus ? 2 : 1", button)
        self.assertIn("border.width: root.activeFocus ? 2 : 1", pill)

    def test_friends_and_build_panels_take_keyboard_focus_when_summoned(self):
        friends = read("FriendsPanelV3.qml")
        build = read("BuildNetworkPanelV3.qml")
        self.assertIn("KeyboardPanel {", friends)
        self.assertIn("focusTarget: chatsNav", friends)
        self.assertIn("KeyboardPanel {", build)
        self.assertIn("focusTarget: syncButton", build)

    def test_build_tabs_use_keyboard_accessible_shared_control(self):
        build = read("BuildNetworkPanelV3.qml")
        start = build.index('{ id: "discover", label: "Discover" }')
        end = build.index('visible: root.notice !== ""', start)
        tab_bar = build[start:end]
        self.assertIn("GlassPill {", tab_bar)
        self.assertIn("text: modelData.label", tab_bar)
        self.assertIn("onClicked: root.tab = modelData.id", tab_bar)
        self.assertNotIn("TapHandler { onTapped: root.tab = modelData.id }", tab_bar)

    def test_no_one_shot_write_patchers_remain(self):
        forbidden = (
            ".github/workflows/request-management-patcher.yml",
            "scripts/_request_patch.py",
            ".github/workflows/v3-safety-patcher.yml",
            "scripts/_v3_safety_patch.py",
            ".github/workflows/final-ux-patcher.yml",
            "scripts/_final_ux_patch.py",
            ".github/workflows/request-layout-fixer.yml",
            "scripts/_request_layout_fix.py",
            ".github/workflows/group-visibility-fixer.yml",
            "scripts/_group_visibility_fix.py",
            ".github/workflows/final-build-tabs-patch.yml",
            "scripts/_final_build_tabs_patch.py",
            ".github/workflows/fix-multirelay-listener.yml",
            "scripts/_fix_multirelay_listener.py",
        )
        for path in forbidden:
            self.assertFalse((ROOT / path).exists(), path)


if __name__ == "__main__":
    unittest.main()
