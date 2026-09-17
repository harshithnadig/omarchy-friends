import os
import sys
import unittest
import tempfile
import json
from pathlib import Path

class TestOmarchyPaperPlane(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = tempfile.TemporaryDirectory()
        self.orig_state = os.environ.get("XDG_STATE_HOME")
        os.environ["XDG_STATE_HOME"] = self.tmp_dir.name
        
        import importlib.util
        import importlib.machinery
        bin_path = str(Path(__file__).parent.parent / "bin" / "omarchy-friends")
        loader = importlib.machinery.SourceFileLoader("omarchy_friends", bin_path)
        spec = importlib.util.spec_from_loader("omarchy_friends", loader)
        global friends
        friends = importlib.util.module_from_spec(spec)
        loader.exec_module(friends)
        friends.STATE_DIR = Path(self.tmp_dir.name) / "omarchy-friends"

    def tearDown(self):
        self.tmp_dir.cleanup()
        if self.orig_state is not None:
            os.environ["XDG_STATE_HOME"] = self.orig_state
        else:
            os.environ.pop("XDG_STATE_HOME", None)

    def test_anonymous_hangar_id(self):
        hangar_id = friends.get_or_create_hangar_id()
        self.assertTrue(hangar_id.startswith("AERO-"))
        self.assertEqual(len(hangar_id), 9)

    def test_haversine_distance(self):
        # Distance between Tokyo (35.6762, 139.6503) and London (51.5074, -0.1278) ~9,560 km
        dist = friends.haversine_km(35.6762, 139.6503, 51.5074, -0.1278)
        self.assertGreater(dist, 9000)
        self.assertLess(dist, 10000)

    def test_fold_and_seal_setting(self):
        friends.action_set_fold("concorde")
        friends.action_set_seal("midnight")
        state = friends.load_state()
        self.assertEqual(state.get("active_fold"), "concorde")
        self.assertEqual(state.get("active_seal"), "midnight")

    def test_launch_and_cooldown(self):
        state = friends.load_state()
        state["last_launch_time"] = 0
        friends.save_state(state)
        
        self.assertEqual(friends.get_cooldown_remaining(state), 0)

        # Launch flight
        friends.action_launch("crane", "coffee")
        state = friends.load_state()
        self.assertGreater(friends.get_cooldown_remaining(state), 500)
        self.assertEqual(state.get("total_planes_launched"), 1)
        self.assertEqual(state.get("total_planes_caught"), 1)
        self.assertGreater(len(state.get("flight_log", [])), 0)

if __name__ == "__main__":
    unittest.main()
