#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "bin" / "omarchy-friends"
text = ENGINE.read_text(encoding="utf-8")


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    text = text.replace(old, new, 1)


replace_once(
    "import uuid\nfrom pathlib import Path",
    "import uuid\nimport urllib.request\nfrom pathlib import Path",
    "urllib import",
)

replace_once(
    'PLUGIN_VERSION = "4.15.0"\nGLOBAL_CAPABILITIES = (',
    'PLUGIN_VERSION = "4.15.0"\nOFFICIAL_MANIFEST_URL = "https://raw.githubusercontent.com/harshithnadig/omarchy-friends/main/manifest.json"\nOFFICIAL_RELEASE_CHECK_SECONDS = 6 * 60 * 60\nOFFICIAL_RELEASE_RETRY_SECONDS = 30 * 60\nOFFICIAL_MANIFEST_MAX_BYTES = 16 * 1024\nOFFICIAL_RELEASE_TIMEOUT_SECONDS = 4.0\nGLOBAL_CAPABILITIES = (',
    "release constants",
)

replace_once(
    '''            global_state["last_notified_update"] = trim_text(old_global.get("last_notified_update"), 16)\n            global_state["relays"] = {''',
    '''            global_state["last_notified_update"] = trim_text(old_global.get("last_notified_update"), 16)\n            global_state["official_latest_version"] = trim_text(old_global.get("official_latest_version"), 16)\n            global_state["last_release_check"] = safe_int(old_global.get("last_release_check"))\n            global_state["last_release_check_success"] = safe_int(old_global.get("last_release_check_success"))\n            global_state["relays"] = {''',
    "release cache migration",
)

pattern = re.compile(
    r"    def _refresh_update_status\(self\):\n.*?\n        return available\n\n    @staticmethod\n    def _world_event",
    re.DOTALL,
)
match = pattern.search(text)
if not match:
    raise SystemExit("update method block not found")

replacement = '''    def _official_latest_version(self, global_state):
        """Return the latest version advertised by the canonical public manifest.

        This performs a bounded metadata-only HTTPS read. It never downloads or
        executes plugin code. Users can disable the check with
        OMARCHY_FRIENDS_RELEASE_CHECK=0; peer-version gossip remains available.
        Successful checks are cached for six hours and failed attempts back off
        for thirty minutes so the normal four-second status refresh cannot hammer
        GitHub or stall the UI.
        """
        cached_text = trim_text(global_state.get("official_latest_version"), 16)
        cached = parse_plugin_version(cached_text)
        flag = str(os.environ.get("OMARCHY_FRIENDS_RELEASE_CHECK", "1")).strip().lower()
        if flag in {"0", "false", "off", "no"}:
            return cached

        now = now_seconds()
        last_attempt = safe_int(global_state.get("last_release_check"))
        last_success = safe_int(global_state.get("last_release_check_success"))
        if cached and last_success and now - last_success < OFFICIAL_RELEASE_CHECK_SECONDS:
            return cached
        if last_attempt and now - last_attempt < OFFICIAL_RELEASE_RETRY_SECONDS:
            return cached

        global_state["last_release_check"] = now
        try:
            request = urllib.request.Request(
                OFFICIAL_MANIFEST_URL,
                headers={"User-Agent": f"omarchy-friends/{PLUGIN_VERSION}"},
                method="GET",
            )
            with urllib.request.urlopen(request, timeout=OFFICIAL_RELEASE_TIMEOUT_SECONDS) as response:
                payload = response.read(OFFICIAL_MANIFEST_MAX_BYTES + 1)
            if len(payload) > OFFICIAL_MANIFEST_MAX_BYTES:
                raise ValueError("manifest response is too large")
            document = json.loads(payload.decode("utf-8"))
            version_text = trim_text(document.get("version") if isinstance(document, dict) else "", 16)
            parsed = parse_plugin_version(version_text)
            if not parsed:
                raise ValueError("manifest version is invalid")
            global_state["official_latest_version"] = version_text
            global_state["last_release_check_success"] = now
            self.save_state()
            return parsed
        except (OSError, TimeoutError, UnicodeError, ValueError):
            # Update discovery must never make Friends unavailable. Persist only
            # the attempt time for bounded retry and keep any last-known-good
            # version. Peer gossip remains a second independent signal.
            self.save_state()
            return cached

    def _refresh_update_status(self):
        """Compare our version against both official metadata and live peers.

        A newer observed version raises one local event per version so the
        persistent deck banner points at the explicit one-click updater. Code is
        never downloaded or executed by this check.
        """
        global_state = self.state.setdefault("global", {})
        own = parse_plugin_version(PLUGIN_VERSION) or (0, 0, 0)
        latest = own

        official = self._official_latest_version(global_state)
        if official and official > latest:
            latest = official

        for peer in global_state.get("peers", {}).values():
            if not isinstance(peer, dict):
                continue
            parsed = parse_plugin_version(peer.get("plugin_version"))
            if parsed and parsed > latest:
                latest = parsed

        latest_text = f"{latest[0]}.{latest[1]}.{latest[2]}"
        available = latest > own
        global_state["update_available"] = available
        global_state["latest_version"] = latest_text if available else PLUGIN_VERSION
        if available and global_state.get("last_notified_update") != latest_text:
            global_state["last_notified_update"] = latest_text
            self._append_event(
                "update", "↻", "Omarchy Friends", "👾",
                f"Friends {latest_text} is out (you have {PLUGIN_VERSION}). Open the deck and tap Update.",
            )
        return available

    @staticmethod
    def _world_event'''

text = text[: match.start()] + replacement + text[match.end() :]
ENGINE.write_text(text, encoding="utf-8")
print("official release discovery patch applied")
