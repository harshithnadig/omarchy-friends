from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PinnedLiveInstallTests(unittest.TestCase):
    def test_live_installer_requires_and_checks_out_an_exact_commit(self):
        installer = (ROOT / "scripts/use-v415-rc-live.sh").read_text()
        self.assertIn('COMMIT="${1:-}"', installer)
        self.assertIn('[[ "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]]', installer)
        self.assertIn('git -C "$PLUGIN_DIR" fetch --no-tags origin "$COMMIT"', installer)
        self.assertIn('git -C "$PLUGIN_DIR" switch --detach "$COMMIT"', installer)
        self.assertIn('"$PLUGIN_DIR" "$COMMIT"', installer)
        self.assertNotIn('pull --ff-only origin', installer)
        self.assertNotIn('BRANCH=', installer)

    def test_live_verifier_checks_the_requested_commit(self):
        verifier = (ROOT / "scripts/verify-live-v415.sh").read_text()
        self.assertIn('EXPECTED_COMMIT="${2:-}"', verifier)
        self.assertIn('actual="$(git -C "$PLUGIN_DIR" rev-parse HEAD)"', verifier)
        self.assertIn('does not match expected', verifier)


if __name__ == "__main__":
    unittest.main()
