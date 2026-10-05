"""Execute the actual QML composer functions to check conversation isolation."""
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


class ComposerDraftTests(unittest.TestCase):
    def test_switching_reopening_and_clearing_preserve_the_right_draft(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("Node is required to execute QML JavaScript functions")
        source = (ROOT / "FriendsPanelV3.qml").read_text()
        functions = {name: qml_function(source, name) for name in (
            "composerDraftKey", "saveComposerDraft", "prepareDraftForConversation"
        )}
        fields = {
            "messageDraft": "", "mediaDraft": "", "attachmentDraftPath": "",
            "attachmentDraftIsFolder": False, "replyDraft": None, "editingMessage": None,
        }
        for field in fields:
            self.assertIn("on" + field[0].upper() + field[1:] + "Changed: saveComposerDraft()", source)
        script = """
const assert = require('node:assert/strict');
const shared = {conversationDrafts: {}};
let root;
function panel(account) {
    const p = {profile: {public_key: account}, service: shared,
               draftConversationKey: '', draftAccountKey: '', restoringComposerDraft: false};
    for (const [key, initial] of Object.entries(FIELDS)) {
        let value = initial;
        Object.defineProperty(p, key, {
            get() { return value; },
            set(next) { value = next; if (p.saveComposerDraft) p.saveComposerDraft(); }
        });
    }
    for (const [name, source] of Object.entries(FUNCTIONS)) p[name] = eval('(' + source + ')');
    return p;
}
root = panel('alice');
root.prepareDraftForConversation('friend:bob');
root.messageDraft = 'unfinished for Bob';
root.attachmentDraftPath = '/tmp/folder';
root.attachmentDraftIsFolder = true;
root.replyDraft = {id: 'reply-bob', text: 'quoted message'};
root.prepareDraftForConversation('group:team');
assert.equal(root.messageDraft, '');
assert.equal(root.attachmentDraftPath, '');
assert.equal(root.replyDraft, null);
root.messageDraft = 'unfinished for team';
root.mediaDraft = 'https://example.org';
root.prepareDraftForConversation('friend:bob');
assert.equal(root.messageDraft, 'unfinished for Bob');
assert.equal(root.attachmentDraftPath, '/tmp/folder');
assert.equal(root.attachmentDraftIsFolder, true);
assert.equal(root.replyDraft.id, 'reply-bob');
// Recreating the panel uses the same service and restores its session draft.
root = panel('alice');
root.prepareDraftForConversation('group:team');
assert.equal(root.messageDraft, 'unfinished for team');
assert.equal(root.mediaDraft, 'https://example.org');
// Clearing after send removes only this conversation's draft.
root.messageDraft = '';
root.mediaDraft = '';
assert.equal(shared.conversationDrafts['alice:group:team'], undefined);
root.prepareDraftForConversation('friend:bob');
assert.equal(root.messageDraft, 'unfinished for Bob');
// Account namespaces prevent cross-account draft exposure.
root = panel('carol');
root.prepareDraftForConversation('friend:bob');
assert.equal(root.messageDraft, '');
// Editing is restored as an edit, never silently changed into a new message.
root.editingMessage = {id: 'edit-target', text: 'original'};
root.messageDraft = 'edited text';
root.prepareDraftForConversation('group:team');
root.prepareDraftForConversation('friend:bob');
assert.equal(root.editingMessage.id, 'edit-target');
assert.equal(root.messageDraft, 'edited text');
root.profile = {public_key: 'alice'};
root.prepareDraftForConversation('friend:bob');
assert.equal(root.messageDraft, 'unfinished for Bob');
assert.equal(root.editingMessage, null);
root.profile = {public_key: 'carol'};
root.prepareDraftForConversation('friend:bob');
assert.equal(root.messageDraft, 'edited text');
assert.equal(root.editingMessage.id, 'edit-target');
"""
        script = "const FUNCTIONS = " + json.dumps(functions) + ";\nconst FIELDS = " + json.dumps(fields) + ";\n" + script
        result = subprocess.run([node, "-e", script], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
