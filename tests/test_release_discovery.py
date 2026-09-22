import json
import os
import shutil
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch

BIN_DIR = Path(__file__).parent.parent / "bin"
friends_module = SourceFileLoader(
    "friends_release_discovery_engine", str(BIN_DIR / "omarchy-friends")
).load_module()


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self, _limit=-1):
        return self.payload


class ReleaseDiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.engine = friends_module.FriendsEngine(state_dir=self.test_dir)

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def manifest(self, version):
        return json.dumps({"id": "community.omarchy-friends", "version": version}).encode("utf-8")

    def test_official_manifest_can_raise_update_banner_state(self):
        response = FakeResponse(self.manifest("4.16.0"))
        with patch.object(friends_module, "now_seconds", return_value=100_000), patch.object(
            friends_module.urllib.request, "urlopen", return_value=response
        ) as opener:
            self.assertTrue(self.engine._refresh_update_status())

        self.assertEqual(self.engine.state["global"]["latest_version"], "4.16.0")
        self.assertTrue(self.engine.state["global"]["update_available"])
        self.assertEqual(self.engine.state["global"]["official_latest_version"], "4.16.0")
        self.assertEqual(opener.call_count, 1)
        request = opener.call_args.args[0]
        self.assertEqual(request.full_url, friends_module.OFFICIAL_MANIFEST_URL)

    def test_successful_release_check_is_cached_across_restart(self):
        with patch.object(friends_module, "now_seconds", return_value=200_000), patch.object(
            friends_module.urllib.request,
            "urlopen",
            return_value=FakeResponse(self.manifest("4.16.1")),
        ):
            self.assertEqual(
                self.engine._official_latest_version(self.engine.state["global"]),
                (4, 16, 1),
            )

        restarted = friends_module.FriendsEngine(state_dir=self.test_dir)
        with patch.object(friends_module, "now_seconds", return_value=200_010), patch.object(
            friends_module.urllib.request, "urlopen"
        ) as opener:
            self.assertEqual(
                restarted._official_latest_version(restarted.state["global"]),
                (4, 16, 1),
            )
            opener.assert_not_called()

    def test_failed_release_check_backs_off_instead_of_hammering(self):
        with patch.object(friends_module, "now_seconds", return_value=300_000), patch.object(
            friends_module.urllib.request, "urlopen", side_effect=OSError("offline")
        ) as opener:
            self.assertIsNone(self.engine._official_latest_version(self.engine.state["global"]))
            self.assertEqual(opener.call_count, 1)

        with patch.object(friends_module, "now_seconds", return_value=300_010), patch.object(
            friends_module.urllib.request, "urlopen"
        ) as opener:
            self.assertIsNone(self.engine._official_latest_version(self.engine.state["global"]))
            opener.assert_not_called()

    def test_release_check_can_be_disabled_without_disabling_peer_gossip(self):
        previous = os.environ.get("OMARCHY_FRIENDS_RELEASE_CHECK")
        os.environ["OMARCHY_FRIENDS_RELEASE_CHECK"] = "0"
        try:
            with patch.object(friends_module.urllib.request, "urlopen") as opener:
                self.assertIsNone(self.engine._official_latest_version(self.engine.state["global"]))
                opener.assert_not_called()
        finally:
            if previous is None:
                os.environ.pop("OMARCHY_FRIENDS_RELEASE_CHECK", None)
            else:
                os.environ["OMARCHY_FRIENDS_RELEASE_CHECK"] = previous

    def test_oversized_or_invalid_manifest_does_not_break_friends(self):
        oversized = FakeResponse(b"{" + (b"x" * (friends_module.OFFICIAL_MANIFEST_MAX_BYTES + 1)))
        with patch.object(friends_module, "now_seconds", return_value=400_000), patch.object(
            friends_module.urllib.request, "urlopen", return_value=oversized
        ):
            self.assertIsNone(self.engine._official_latest_version(self.engine.state["global"]))


if __name__ == "__main__":
    unittest.main()
