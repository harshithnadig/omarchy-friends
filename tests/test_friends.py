import os
import sys
import unittest
import tempfile
import json
from pathlib import Path

# Add bin to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent / "bin"))
import importlib

class TestOmarchyFriends(unittest.TestCase):
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

    def test_anonymous_peer_id(self):
        peer_id = friends.get_or_create_peer_id()
        self.assertEqual(len(peer_id), 32)
        self.assertTrue(all(c in "0123456789abcdef" for c in peer_id))
        
        # Subsequent call returns same peer_id
        peer_id2 = friends.get_or_create_peer_id()
        self.assertEqual(peer_id, peer_id2)

    def test_vibe_setting(self):
        friends.action_set_vibe("coffee")
        state = friends.load_state()
        self.assertEqual(state.get("active_vibe"), "coffee")

        # Unknown vibe falls back safely to focus
        friends.action_set_vibe("non_existent_vibe")
        state = friends.load_state()
        self.assertEqual(state.get("active_vibe"), "focus")

    def test_cooldown_enforcement(self):
        state = friends.load_state()
        state["last_spark_time"] = 0
        friends.save_state(state)
        
        self.assertEqual(friends.get_cooldown_remaining(state), 0)
        self.assertEqual(friends.get_cooldown_progress(state), 1.0)

        # Send spark
        friends.action_spark("midnight")
        state = friends.load_state()
        self.assertGreater(friends.get_cooldown_remaining(state), 500)
        self.assertLessEqual(friends.get_cooldown_remaining(state), 600)

    def test_encounter_generation(self):
        friends.action_spark("shipping")
        state = friends.load_state()
        self.assertGreater(len(state.get("encounters", [])), 0)
        latest = state["encounters"][0]
        self.assertIn("country", latest)
        self.assertIn("flag", latest)
        self.assertIn("vibe", latest)

if __name__ == "__main__":
    unittest.main()
