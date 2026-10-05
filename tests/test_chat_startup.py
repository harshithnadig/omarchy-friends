"""Exercise the Friends V3 empty-chat state decision."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def qml_function(source, name):
    start = source.index("function " + name + "(")
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


class ChatStartupTests(unittest.TestCase):
    def test_empty_chat_state_distinguishes_loading_failure_and_real_empty_result(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("Node is required to execute QML JavaScript functions")
        source = (ROOT / "FriendsPanelV3.qml").read_text(encoding="utf-8")
        function = qml_function(source, "chatListEmptyState")
        script = """
const assert = require('node:assert/strict');
let root;
const getState = eval('(' + FUNCTION + ')');
root = {serviceStatusRevision: 0, service: {statusError: ''}};
assert.equal(getState(), 'loading');
root.service.statusError = 'Could not load saved conversations';
assert.equal(getState(), 'error');
root.serviceStatusRevision = 1;
assert.equal(getState(), 'empty');
""".replace("FUNCTION", json.dumps(function))
        result = subprocess.run([node, "-e", script], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_status_process_marks_an_empty_or_invalid_first_response_as_retryable(self):
        service = (ROOT / "Service.qml").read_text(encoding="utf-8")
        status_process = service[service.index("id: statusProc"):service.index("id: eventProc")]
        self.assertIn("property string statusError", service)
        self.assertIn("property bool responseReceived", status_process)
        self.assertIn('throw new Error("empty Friends status response")', status_process)
        self.assertIn("statusRevisionAtStart", status_process)
        self.assertIn("root.statusRevision === statusProc.statusRevisionAtStart", status_process)
        self.assertIn("exitCode !== 0 || !statusProc.responseReceived", status_process)
        self.assertIn("root.statusError =", status_process)
        self.assertIn("root.statusRevision += 1", status_process)


if __name__ == "__main__":
    unittest.main()
