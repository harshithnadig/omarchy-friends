import unittest
import tempfile
import shutil
import json
from pathlib import Path
import sys

# Add bin to sys.path
bin_dir = Path(__file__).parent.parent / "bin"
sys.path.insert(0, str(bin_dir))

from importlib.machinery import SourceFileLoader
friends_module = SourceFileLoader("friends_engine", str(bin_dir / "omarchy-friends")).load_module()


class TestFriendsEngine(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.engine = friends_module.FriendsEngine(state_dir=self.test_dir)

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_initial_state(self):
        status = self.engine.get_full_status()
        self.assertTrue(status["profile"]["code"].startswith("OMAR-"))
        self.assertEqual(status["profile"]["handle"], "OmarchyHacker")
        self.assertGreaterEqual(status["online_count"], 1)

    def test_set_status_and_handle(self):
        self.assertTrue(self.engine.set_status("coffee"))
        status = self.engine.get_full_status()
        self.assertEqual(status["profile"]["status"], "coffee")

        self.assertTrue(self.engine.set_handle("CyberVoxel"))
        status = self.engine.get_full_status()
        self.assertEqual(status["profile"]["handle"], "CyberVoxel")

    def test_add_and_remove_friend(self):
        # Invalid code
        ok, msg = self.engine.add_friend("INVALID")
        self.assertFalse(ok)

        # Valid code
        ok, msg = self.engine.add_friend("OMAR-9999-XYZ", "Alice")
        self.assertTrue(ok)
        friends = [f["code"] for f in self.engine.get_full_status()["friends"]]
        self.assertIn("OMAR-9999-XYZ", friends)

        # Remove friend
        ok, msg = self.engine.remove_friend("OMAR-9999-XYZ")
        self.assertTrue(ok)
        friends_after = [f["code"] for f in self.engine.get_full_status()["friends"]]
        self.assertNotIn("OMAR-9999-XYZ", friends_after)

    def test_interaction_and_events(self):
        ok, msg = self.engine.interact("OMAR-4192-RST", "high-five")
        self.assertTrue(ok)
        events = self.engine.pop_events()
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["action"], "high-five")
        self.assertIn("Elena", events[0]["from_name"])

        # Pop should clear events
        empty = self.engine.pop_events()
        self.assertEqual(len(empty), 0)

    def test_privacy_toggles(self):
        val = self.engine.toggle_privacy("share_window")
        self.assertFalse(val)
        val2 = self.engine.toggle_privacy("share_window")
        self.assertTrue(val2)


if __name__ == "__main__":
    unittest.main()
