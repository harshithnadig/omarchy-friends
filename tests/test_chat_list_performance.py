"""Keep large recovered chat lists linear by using the existing summary index."""
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


class ChatListPerformanceTests(unittest.TestCase):
    def test_large_partial_chat_index_uses_bounded_summary_reads(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("Node is required to execute QML JavaScript functions")
        source = (ROOT / "FriendsPanelV3.qml").read_text(encoding="utf-8")
        functions = {
            name: qml_function(source, name)
            for name in ("friendsList", "lastMessageIndexForFriend", "latestMessageForFriend")
        }
        script = """
const assert = require('node:assert/strict');
const FUNCTIONS = JSON.parse(FUNCTIONS_JSON);
let reads = 0;
const ownKey = 'f'.repeat(64);
const counts = {};
const summaries = [];
const latest = {};
const byConversation = {};
for (let i = 0; i < 500; i++) {
    const key = i.toString(16).padStart(64, '0');
    counts['friend:' + key] = 1;
    if (i < 250) {
        latest['friend:' + key] = summaries.length;
        const summary = {conversation_key: key, public_key: key, handle: 'Saved ' + i};
        byConversation['friend:' + key] = [summary];
        summaries.push(summary);
    }
}
const messages = new Proxy(summaries, {
    get(target, property, receiver) {
        if (/^(0|[1-9][0-9]*)$/.test(String(property))) reads++;
        return Reflect.get(target, property, receiver);
    }
});
const root = {
    friendships: {}, profile: {public_key: ownKey}, memory: {},
    messageCounts: counts, messages, messagesByConversation: byConversation,
    latestMessageIndices: latest,
    worldPeer: () => null
};
for (const [name, functionSource] of Object.entries(FUNCTIONS))
    root[name] = eval('(' + functionSource + ')');
const rows = root.friendsList();
assert.equal(rows.length, 500, 'every durable conversation remains listed');
assert.ok(reads < 5000, `expected indexed lookup, observed ${reads} array reads`);
""".replace("FUNCTIONS_JSON", json.dumps(json.dumps(functions)))
        result = subprocess.run([node, "-e", script], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
