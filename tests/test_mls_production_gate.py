"""Keep the unfinished MLS experiment out of the production chat path."""

import unittest
from pathlib import Path


ROOT = Path(__file__).parent.parent


class MlsProductionGateTests(unittest.TestCase):
    def test_production_launcher_does_not_load_or_advertise_experimental_mls(self):
        launcher = (ROOT / "bin" / "omarchy-friends").read_text(encoding="utf-8")

        # MDK remains an isolated experiment until its history-loss regression,
        # migration, and Friends interoperability gates have all passed.
        for marker in ("omarchy_friends_mls", "marmot_uniffi", "mls-session-v1"):
            with self.subTest(marker=marker):
                self.assertNotIn(marker, launcher)

    def test_security_migration_docs_record_the_current_upstream_blocker(self):
        migration = (ROOT / "docs" / "private-messaging-security-migration.md").read_text(
            encoding="utf-8"
        )

        self.assertIn("Latest upstream reassessment: MDK 0.12.0", migration)
        self.assertIn("issues/2086", migration)
        self.assertIn("pull/2153", migration)
        self.assertIn("Do **not** upgrade the experimental bridge", migration)


if __name__ == "__main__":
    unittest.main()
