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
        )
        for path in forbidden:
            self.assertFalse((ROOT / path).exists(), path)


if __name__ == "__main__":
    unittest.main()
