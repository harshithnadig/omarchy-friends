#!/usr/bin/env python3
"""Small follow-up fixes used by the v4.14 one-shot finalizer."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path, old, new, label):
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def fix_solution_title():
    patch(
        "bin/build_network_app_v3.py",
        '        title=data.get("title", help_item.get("title", "Solved Omarchy issue")),\n',
        '        title=(str(data.get("title", "")).strip() or help_item.get("title", "Solved Omarchy issue")),\n',
        "Help to Solution title fallback",
    )


def fix_qml_textinput_placeholders():
    path = ROOT / "BuildNetworkPanelV3.qml"
    text = path.read_text(encoding="utf-8")
    replacements = (
        ('; placeholderText: "Name, e.g. OLED bar"', ''),
        ('; placeholderText: "HTTPS source link (optional)"', ''),
        ('; placeholderText: "Skills: NVIDIA, QML, Hyprland…"', ''),
        ('; placeholderText: "Optional note"', ''),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")


def add_protocol_guard():
    path = ROOT / "bin/build_network_app_v4.py"
    text = path.read_text(encoding="utf-8")
    marker = "# v4.14-final: strict relay event envelope guard"
    if marker in text:
        return
    anchor = "_previous_store_and_publish = core._store_and_publish\n\n"
    if text.count(anchor) != 1:
        raise RuntimeError("protocol guard anchor changed")
    addition = '''_previous_store_and_publish = core._store_and_publish
_previous_event_payload = core._event_payload

# v4.14-final: strict relay event envelope guard
MAX_EVENT_CONTENT_BYTES = 32 * 1024
MAX_FUTURE_SECONDS = 10 * 60


def _event_metadata_precheck(event, now=None):
    if not isinstance(event, dict):
        return False
    now = int(time.time()) if now is None else int(now)
    content = event.get("content", "")
    if not isinstance(content, str) or len(content.encode("utf-8", errors="ignore")) > MAX_EVENT_CONTENT_BYTES:
        return False
    try:
        created_at = int(event.get("created_at", 0) or 0)
    except (TypeError, ValueError, OverflowError):
        return False
    return created_at > 0 and created_at <= now + MAX_FUTURE_SECONDS


def _event_tags_match_payload(event, payload):
    if not isinstance(payload, dict):
        return False
    tags = event.get("tags", []) if isinstance(event, dict) else []
    d_values = [tag[1] for tag in tags if isinstance(tag, list) and len(tag) > 1 and tag[0] == "d"]
    type_values = [tag[1] for tag in tags if isinstance(tag, list) and len(tag) > 1 and tag[0] == "type"]
    return (
        len(d_values) == 1
        and len(type_values) == 1
        and str(d_values[0]) == str(payload.get("id", ""))
        and str(type_values[0]) == str(payload.get("type", ""))
    )


def _release_event_payload(event):
    if not _event_metadata_precheck(event):
        return None
    payload = _previous_event_payload(event)
    if payload is None or not _event_tags_match_payload(event, payload):
        return None
    return payload


core._event_payload = _release_event_payload

'''
    text = text.replace(anchor, addition, 1)
    path.write_text(text, encoding="utf-8")


def add_protocol_tests():
    path = ROOT / "tests/test_release_hardening.py"
    text = path.read_text(encoding="utf-8")
    marker = "    def test_relay_event_envelope_guard(self):\n"
    if marker in text:
        return
    anchor = "    def test_corrupt_state_is_quarantined_and_schema_migrates(self):\n"
    if text.count(anchor) != 1:
        raise RuntimeError("protocol-test anchor changed")
    addition = '''    def test_relay_event_envelope_guard(self):
        now = 2_000_000
        base = {
            "created_at": now,
            "content": "{}",
            "tags": [["d", "idea_123"], ["type", "idea"]],
        }
        self.assertTrue(release._event_metadata_precheck(base, now))
        future = dict(base, created_at=now + release.MAX_FUTURE_SECONDS + 1)
        self.assertFalse(release._event_metadata_precheck(future, now))
        huge = dict(base, content="x" * (release.MAX_EVENT_CONTENT_BYTES + 1))
        self.assertFalse(release._event_metadata_precheck(huge, now))
        self.assertTrue(release._event_tags_match_payload(base, {"id": "idea_123", "type": "idea"}))
        self.assertFalse(release._event_tags_match_payload(base, {"id": "idea_999", "type": "idea"}))
        duplicate_d = dict(base, tags=[["d", "idea_123"], ["d", "idea_123"], ["type", "idea"]])
        self.assertFalse(release._event_tags_match_payload(duplicate_d, {"id": "idea_123", "type": "idea"}))

'''
    path.write_text(text.replace(anchor, addition + anchor, 1), encoding="utf-8")


def main():
    fix_solution_title()
    fix_qml_textinput_placeholders()
    add_protocol_guard()
    add_protocol_tests()
    print("v4.14 post-finalizer applied successfully")


if __name__ == "__main__":
    main()
