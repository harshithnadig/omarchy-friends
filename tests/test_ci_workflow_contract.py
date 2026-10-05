"""Keep experimental MLS builds out of the active Friends release workflow."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CiWorkflowContractTests(unittest.TestCase):
    def test_mls_bridge_has_dedicated_path_triggered_and_manual_workflow(self):
        active = (ROOT / ".github/workflows/build-network.yml").read_text(encoding="utf-8")
        experiment = (ROOT / ".github/workflows/mls-experiment.yml").read_text(encoding="utf-8")

        self.assertNotIn("mls-python-bridge-smoke", active)
        self.assertNotIn("mls-session-experiment", active)
        self.assertNotIn("native/mls-session-experiment/**", active)
        self.assertIn("workflow_dispatch:", experiment)
        for path in (
            "native/mls-session-experiment/**",
            "scripts/build-mls-python-bridge.sh",
            "scripts/smoke-mls-python-bridge.py",
        ):
            self.assertIn(path, experiment)
        self.assertIn("cargo test --locked", experiment)
        self.assertIn("../../scripts/build-mls-python-bridge.sh", experiment)


if __name__ == "__main__":
    unittest.main()
