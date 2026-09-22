import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

from build_network import BuildRoom, Idea, SetupCard, TestRequest, TestResult, parse_payload


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
            wallpaper_url="https://example.com/wallpaper.jpg",
        ).to_payload()
        self.assertEqual(payload["type"], "setup_card")
        self.assertNotIn("commands", payload)
        self.assertNotIn("files", payload)

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

    def test_unknown_payload_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_payload({"type": "run_shell", "command": "rm -rf /"})


if __name__ == "__main__":
    unittest.main()
