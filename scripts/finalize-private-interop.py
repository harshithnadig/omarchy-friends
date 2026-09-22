#!/usr/bin/env python3
"""One-shot final private-message interoperability hardening for v4.15.

Applies repository-side fixes that can be validated in CI:
- publish/consume NIP-17 kind-10050 DM inbox relay lists;
- route gift wraps only to a recipient's verified configured inbox relays;
- make the modern-protocol anti-downgrade marker survive state migration;
- require an incoming kind-14 rumor to actually address this receiver;
- describe the 65,535-byte ceiling as a Friends resource cap, not the NIP-44 protocol maximum.

The patch deliberately accepts only relay URLs already configured in GLOBAL_RELAYS.
That avoids turning an untrusted remote relay-list event into arbitrary network egress.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new, label):
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_private_module():
    replace_once(
        "bin/omarchy_friends_private.py",
        'raise ValueError("private message size is outside NIP-44 v2 limits")',
        'raise ValueError("private message size is outside the Friends NIP-44 resource limit")',
        "NIP-44 encrypt resource-limit wording",
    )
    replace_once(
        "bin/omarchy_friends_private.py",
        'raise ValueError("private message size is outside NIP-44 v2 limits")',
        'raise ValueError("private message size is outside the Friends NIP-44 resource limit")',
        "NIP-44 decrypt resource-limit wording",
    )


def patch_engine_constants_and_state():
    replace_once(
        "bin/omarchy-friends",
        '''    "nip59-gift-wrap-v1",\n)\n''',
        '''    "nip59-gift-wrap-v1",\n    "nip17-inbox-relays-v1",\n)\n''',
        "modern inbox relay capability",
    )
    replace_once(
        "bin/omarchy-friends",
        '''GLOBAL_DM_KIND = 4\nGLOBAL_COMMUNITY_KIND = 1\n''',
        '''GLOBAL_DM_KIND = 4\nNIP17_DM_RELAY_LIST_KIND = 10050\nNIP17_MAX_DM_RELAYS = 3\nNIP17_DM_RELAY_REFRESH_SECONDS = 12 * 60 * 60\nNIP17_DM_RELAY_CACHE_SECONDS = 7 * 24 * 60 * 60\nGLOBAL_COMMUNITY_KIND = 1\n''',
        "NIP-17 inbox constants",
    )
    replace_once(
        "bin/omarchy-friends",
        ''')\nSTATE_DIR = (\n''',
        ''')\nNIP17_DM_RELAYS = tuple(GLOBAL_RELAYS[:NIP17_MAX_DM_RELAYS])\nSTATE_DIR = (\n''',
        "configured NIP-17 inbox relays",
    )
    replace_once(
        "bin/omarchy-friends",
        '''                "last_publish": 0,\n                "last_error": "",\n''',
        '''                "last_publish": 0,\n                "dm_relay_list_last_publish": 0,\n                "last_error": "",\n''',
        "default inbox relay publish timestamp",
    )
    replace_once(
        "bin/omarchy-friends",
        '''            global_state["last_publish"] = safe_int(old_global.get("last_publish"))\n            global_state["last_error"] = trim_text(old_global.get("last_error"), 180)\n''',
        '''            global_state["last_publish"] = safe_int(old_global.get("last_publish"))\n            global_state["dm_relay_list_last_publish"] = safe_int(old_global.get("dm_relay_list_last_publish"))\n            global_state["last_error"] = trim_text(old_global.get("last_error"), 180)\n''',
        "migrate inbox relay publish timestamp",
    )
    replace_once(
        "bin/omarchy-friends",
        '''                item = {\n                    "status": status,\n                    "request_id": trim_text(friendship.get("request_id"), 40),\n                    "handle": trim_text(friendship.get("handle"), 24) or "A builder",\n                    "avatar": friendship.get("avatar") if friendship.get("avatar") in AVAILABLE_AVATARS else "👾",\n                }\n                friendships[public_key] = item\n''',
        '''                item = {\n                    "status": status,\n                    "request_id": trim_text(friendship.get("request_id"), 40),\n                    "handle": trim_text(friendship.get("handle"), 24) or "A builder",\n                    "avatar": friendship.get("avatar") if friendship.get("avatar") in AVAILABLE_AVATARS else "👾",\n                }\n                if friendship.get("private_protocol") == "nip17-v1":\n                    item["private_protocol"] = "nip17-v1"\n                    item["private_protocol_seen_at"] = safe_int(friendship.get("private_protocol_seen_at"))\n                relay_urls = [\n                    relay_url\n                    for relay_url in friendship.get("nip17_dm_relays", [])\n                    if isinstance(relay_url, str) and relay_url in GLOBAL_RELAYS\n                ][:NIP17_MAX_DM_RELAYS]\n                if relay_urls:\n                    item["nip17_dm_relays"] = relay_urls\n                    item["nip17_dm_relays_seen_at"] = safe_int(friendship.get("nip17_dm_relays_seen_at"))\n                    item["nip17_dm_relays_event_at"] = safe_int(friendship.get("nip17_dm_relays_event_at"))\n                friendships[public_key] = item\n''',
        "persist modern protocol and inbox relay cache",
    )


def patch_presence_and_modern_capability():
    replace_once(
        "bin/omarchy-friends",
        '''            "capabilities": list(GLOBAL_CAPABILITIES),\n            "type": "presence",\n''',
        '''            "capabilities": list(GLOBAL_CAPABILITIES),\n            "dm_relays": list(NIP17_DM_RELAYS),\n            "type": "presence",\n''',
        "presence inbox relay hint",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        return {\n            "public_key": public_key,\n''',
        '''        dm_relays = [\n            relay_url\n            for relay_url in peer.get("dm_relays", [])\n            if isinstance(relay_url, str) and relay_url in GLOBAL_RELAYS\n        ][:NIP17_MAX_DM_RELAYS]\n        return {\n            "public_key": public_key,\n''',
        "normalize signed inbox relay hint",
    )
    replace_once(
        "bin/omarchy-friends",
        '''            "capabilities": capabilities,\n            "can_chat": "friend-requests-v1" in capabilities and (\n''',
        '''            "capabilities": capabilities,\n            "dm_relays": dm_relays,\n            "can_chat": "friend-requests-v1" in capabilities and (\n''',
        "store signed inbox relay hint",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        modern = {"nip44-v2", "nip17-dm-v1"}.issubset(capabilities)\n''',
        '''        modern = {"nip44-v2", "nip17-dm-v1", "nip17-inbox-relays-v1"}.issubset(capabilities)\n''',
        "require complete modern transport capability",
    )


def patch_nip17_inbox_methods():
    anchor = '''    def _legacy_private_event(self, public_key, envelope, extra_tags=None, alt="Omarchy Friends private message"):\n'''
    methods = '''    @staticmethod\n    def _normalize_nip17_dm_relays(relay_urls):\n        result = []\n        for relay_url in relay_urls or []:\n            if not isinstance(relay_url, str):\n                continue\n            relay_url = relay_url.strip().rstrip("/")\n            # Remote kind-10050 data never gets to create arbitrary network\n            # destinations. Friends only follows relays the user already\n            # configured locally through GLOBAL_RELAYS.\n            if relay_url in GLOBAL_RELAYS and relay_url not in result:\n                result.append(relay_url)\n            if len(result) >= NIP17_MAX_DM_RELAYS:\n                break\n        return result\n\n    def _dm_relay_list_event(self):\n        identity = self._global_identity()\n        relays = self._normalize_nip17_dm_relays(NIP17_DM_RELAYS)\n        if not relays:\n            raise ValueError("no configured NIP-17 inbox relays")\n        return build_event(\n            identity["secret_key"],\n            NIP17_DM_RELAY_LIST_KIND,\n            [["relay", relay_url] for relay_url in relays],\n            "",\n        )\n\n    def _dm_relays_from_event(self, event, expected_public_key):\n        expected_public_key = trim_text(expected_public_key, 64).lower()\n        if (\n            not is_valid_public_key(expected_public_key)\n            or not verify_event(event)\n            or int(event.get("kind", -1)) != NIP17_DM_RELAY_LIST_KIND\n            or trim_text(event.get("pubkey"), 64).lower() != expected_public_key\n        ):\n            return []\n        return self._normalize_nip17_dm_relays(self._event_tag_values(event, "relay"))\n\n    def _remember_nip17_dm_relay_event(self, public_key, event):\n        public_key = trim_text(public_key, 64).lower()\n        friendship = self.state.setdefault("global", {}).setdefault("friendships", {}).get(public_key)\n        if not isinstance(friendship, dict) or friendship.get("status") != "friends":\n            return []\n        relays = self._dm_relays_from_event(event, public_key)\n        if not relays:\n            return []\n        event_at = safe_int(event.get("created_at"))\n        if event_at < safe_int(friendship.get("nip17_dm_relays_event_at")):\n            return self._normalize_nip17_dm_relays(friendship.get("nip17_dm_relays", []))\n        friendship["nip17_dm_relays"] = relays\n        friendship["nip17_dm_relays_seen_at"] = now_seconds()\n        friendship["nip17_dm_relays_event_at"] = event_at\n        return relays\n\n    def _fetch_nip17_dm_relays(self, public_key):\n        public_key = trim_text(public_key, 64).lower()\n        if public_key == self._global_identity()["public_key"]:\n            return self._normalize_nip17_dm_relays(NIP17_DM_RELAYS)\n        friendship = self.state.setdefault("global", {}).setdefault("friendships", {}).get(public_key, {})\n        cached = self._normalize_nip17_dm_relays(friendship.get("nip17_dm_relays", [])) if isinstance(friendship, dict) else []\n        cache_age = now_seconds() - safe_int(friendship.get("nip17_dm_relays_seen_at")) if isinstance(friendship, dict) else NIP17_DM_RELAY_CACHE_SECONDS + 1\n        if cached and cache_age <= NIP17_DM_RELAY_CACHE_SECONDS:\n            return cached\n        if not is_valid_public_key(public_key):\n            return []\n\n        for relay_url in GLOBAL_RELAYS:\n            sub_id = "ofdr" + uuid.uuid4().hex[:12]\n            try:\n                with WebSocketClient(relay_url, timeout=2.0) as relay:\n                    relay.send_json([\n                        "REQ", sub_id,\n                        {"kinds": [NIP17_DM_RELAY_LIST_KIND], "authors": [public_key], "limit": 4},\n                    ])\n                    candidates = []\n                    deadline = time.monotonic() + 1.5\n                    while time.monotonic() < deadline:\n                        try:\n                            message = relay.recv_json(max(0.05, deadline - time.monotonic()))\n                        except EOFError:\n                            break\n                        if not isinstance(message, list) or not message:\n                            continue\n                        if message[0] == "EVENT" and len(message) >= 3 and message[1] == sub_id:\n                            event = message[2]\n                            if self._dm_relays_from_event(event, public_key):\n                                candidates.append(event)\n                        elif message[0] in ("EOSE", "CLOSED") and len(message) >= 2 and message[1] == sub_id:\n                            break\n                    try:\n                        relay.send_json(["CLOSE", sub_id])\n                    except OSError:\n                        pass\n                if candidates:\n                    newest = max(candidates, key=lambda item: safe_int(item.get("created_at")))\n                    relays = self._remember_nip17_dm_relay_event(public_key, newest)\n                    if relays:\n                        return relays\n            except (OSError, ValueError, ssl.SSLError, EOFError):\n                continue\n        return []\n\n'''
    replace_once("bin/omarchy-friends", anchor, methods + anchor, "NIP-17 inbox methods")


def patch_private_publish_routing():
    replace_once(
        "bin/omarchy-friends",
        '''    def _publish_nip17(self, recipient_public_key, rumor):\n        identity = self._global_identity()\n        event = wrap_nip17_rumor(identity["secret_key"], recipient_public_key, rumor)\n        ok, relay_status = self._publish_global_event(event)\n        self.state.setdefault("global", {}).setdefault("relays", {}).update(relay_status)\n        return ok, event\n''',
        '''    def _publish_nip17(self, recipient_public_key, rumor):\n        identity = self._global_identity()\n        event = wrap_nip17_rumor(identity["secret_key"], recipient_public_key, rumor)\n        relay_urls = self._fetch_nip17_dm_relays(recipient_public_key)\n        if not relay_urls:\n            return False, event\n        ok, relay_status = self._publish_event_to_relays(event, relay_urls)\n        self.state.setdefault("global", {}).setdefault("relays", {}).update(relay_status)\n        return ok, event\n''',
        "route gift wraps to recipient inbox relays",
    )
    replace_once(
        "bin/omarchy-friends",
        '''    def _publish_global_event(self, event):\n        published = 0\n        relay_status = {}\n        for relay_url in GLOBAL_RELAYS:\n''',
        '''    def _publish_event_to_relays(self, event, relay_urls):\n        published = 0\n        relay_status = {}\n        for relay_url in self._normalize_nip17_dm_relays(relay_urls) if int(event.get("kind", -1)) == NIP59_GIFT_WRAP_KIND else list(dict.fromkeys(relay_urls or [])):\n''',
        "generic bounded relay publisher",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        return published > 0, relay_status\n\n    def _ingest_global_dm(self, event):\n''',
        '''        return published > 0, relay_status\n\n    def _publish_global_event(self, event):\n        return self._publish_event_to_relays(event, GLOBAL_RELAYS)\n\n    def _ingest_global_dm(self, event):\n''',
        "global publisher wrapper",
    )


def patch_receiver_membership_validation():
    replace_once(
        "bin/omarchy-friends",
        '''            sender = trim_text(rumor.get("pubkey"), 64).lower()\n            if not is_valid_public_key(sender):\n                return None\n            envelope = app_envelope_from_rumor(rumor)\n''',
        '''            sender = trim_text(rumor.get("pubkey"), 64).lower()\n            if not is_valid_public_key(sender):\n                return None\n            own_key = identity["public_key"]\n            rumor_receivers = self._event_tag_values(rumor, "p")\n            if sender != own_key and own_key not in rumor_receivers:\n                return None\n            envelope = app_envelope_from_rumor(rumor)\n''',
        "inner rumor receiver membership",
    )


def patch_periodic_inbox_publication_and_listener():
    replace_once(
        "bin/omarchy-friends",
        '''    def _global_relay_sync(self, relay_url, presence_event, since):\n        """Publish presence and collect current presence plus addressed pings."""\n''',
        '''    def _global_relay_sync(self, relay_url, presence_event, since, dm_relay_event=None):\n        """Publish presence/inbox metadata and collect current addressed events."""\n''',
        "relay sync inbox event argument",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        result = {"published": False, "presence": [], "pings": [], "messages": [], "community": []}\n        ok_seen = False\n        with WebSocketClient(relay_url, timeout=3.5) as relay:\n            relay.send_json(["EVENT", presence_event])\n''',
        '''        result = {"published": False, "dm_relay_published": False, "presence": [], "pings": [], "messages": [], "community": []}\n        ok_seen = False\n        dm_ok_seen = False\n        with WebSocketClient(relay_url, timeout=3.5) as relay:\n            relay.send_json(["EVENT", presence_event])\n            if dm_relay_event is not None:\n                relay.send_json(["EVENT", dm_relay_event])\n''',
        "publish inbox metadata during relay sync",
    )
    replace_once(
        "bin/omarchy-friends",
        '''                if message[0] == "OK" and len(message) >= 3 and message[1] == presence_event["id"]:\n                    ok_seen = True\n                    result["published"] = bool(message[2])\n                elif message[0] == "EVENT" and len(message) >= 3:\n''',
        '''                if message[0] == "OK" and len(message) >= 3 and message[1] == presence_event["id"]:\n                    ok_seen = True\n                    result["published"] = bool(message[2])\n                elif dm_relay_event is not None and message[0] == "OK" and len(message) >= 3 and message[1] == dm_relay_event["id"]:\n                    dm_ok_seen = True\n                    result["dm_relay_published"] = bool(message[2])\n                elif message[0] == "EVENT" and len(message) >= 3:\n''',
        "track inbox metadata relay ack",
    )
    replace_once(
        "bin/omarchy-friends",
        '''            if not ok_seen:\n                # Some relays flush EOSE before their OK acknowledgement. The\n                # EVENT was written successfully, so don't show a false\n                # "offline" state to the user in that normal race.\n                result["published"] = True\n''',
        '''            if not ok_seen:\n                # Some relays flush EOSE before their OK acknowledgement. The\n                # EVENT was written successfully, so don't show a false\n                # "offline" state to the user in that normal race.\n                result["published"] = True\n            if dm_relay_event is not None and not dm_ok_seen:\n                result["dm_relay_published"] = True\n''',
        "inbox metadata no-ack fallback",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        presence_event = self._global_presence_event()\n        sync_since = max(0, safe_int(global_state.get("last_sync")) - 10)\n''',
        '''        presence_event = self._global_presence_event()\n        dm_relay_event = None\n        if (\n            NIP17_DM_RELAYS\n            and now_seconds() - safe_int(global_state.get("dm_relay_list_last_publish")) >= NIP17_DM_RELAY_REFRESH_SECONDS\n        ):\n            dm_relay_event = self._dm_relay_list_event()\n        sync_since = max(0, safe_int(global_state.get("last_sync")) - 10)\n''',
        "prepare periodic inbox metadata",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        published = False\n        errors = []\n        for relay_url in GLOBAL_RELAYS:\n            try:\n                result = self._global_relay_sync(relay_url, presence_event, sync_since)\n                successes += 1\n                published = published or bool(result.get("published"))\n''',
        '''        published = False\n        dm_relay_published = False\n        errors = []\n        for relay_url in GLOBAL_RELAYS:\n            try:\n                result = self._global_relay_sync(relay_url, presence_event, sync_since, dm_relay_event)\n                successes += 1\n                published = published or bool(result.get("published"))\n                dm_relay_published = dm_relay_published or bool(result.get("dm_relay_published"))\n''',
        "sync inbox metadata result",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        if successes:\n            global_state["last_sync"] = now_seconds()\n            global_state["last_publish"] = now_seconds() if published else global_state.get("last_publish", 0)\n''',
        '''        if successes:\n            global_state["last_sync"] = now_seconds()\n            global_state["last_publish"] = now_seconds() if published else global_state.get("last_publish", 0)\n            if dm_relay_event is not None and dm_relay_published:\n                global_state["dm_relay_list_last_publish"] = now_seconds()\n''',
        "remember inbox metadata publication",
    )
    replace_once(
        "bin/omarchy-friends",
        '''            if not GLOBAL_RELAYS:\n                time.sleep(30)\n                continue\n            relay_url = GLOBAL_RELAYS[relay_index % len(GLOBAL_RELAYS)]\n''',
        '''            listen_relays = NIP17_DM_RELAYS or GLOBAL_RELAYS\n            if not listen_relays:\n                time.sleep(30)\n                continue\n            relay_url = listen_relays[relay_index % len(listen_relays)]\n''',
        "listen on inbox relays",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        presence_event = self._global_presence_event()\n        ping_sub = "ofl" + uuid.uuid4().hex[:12]\n''',
        '''        presence_event = self._global_presence_event()\n        dm_relay_event = None\n        if (\n            NIP17_DM_RELAYS\n            and now_seconds() - safe_int(global_state.get("dm_relay_list_last_publish")) >= NIP17_DM_RELAY_REFRESH_SECONDS\n        ):\n            dm_relay_event = self._dm_relay_list_event()\n        ping_sub = "ofl" + uuid.uuid4().hex[:12]\n''',
        "listener prepares inbox metadata",
    )
    replace_once(
        "bin/omarchy-friends",
        '''        with WebSocketClient(relay_url, timeout=5.0) as relay:\n            relay.send_json(["EVENT", presence_event])\n            relay.send_json([\n''',
        '''        with WebSocketClient(relay_url, timeout=5.0) as relay:\n            relay.send_json(["EVENT", presence_event])\n            if dm_relay_event is not None:\n                relay.send_json(["EVENT", dm_relay_event])\n            relay.send_json([\n''',
        "listener publishes inbox metadata",
    )
    replace_once(
        "bin/omarchy-friends",
        '''            global_state["last_sync"] = now_seconds()\n            global_state["last_publish"] = now_seconds()\n            global_state["last_error"] = ""\n''',
        '''            global_state["last_sync"] = now_seconds()\n            global_state["last_publish"] = now_seconds()\n            if dm_relay_event is not None:\n                global_state["dm_relay_list_last_publish"] = now_seconds()\n            global_state["last_error"] = ""\n''',
        "listener remembers inbox metadata publication",
    )


def patch_tests():
    replace_once(
        "tests/test_private_messaging.py",
        '''    def test_nip44_v2_exact_size_boundaries(self):\n''',
        '''    def test_nip44_v2_friends_resource_cap(self):\n''',
        "resource cap test name",
    )
    replace_once(
        "tests/test_private_messaging_engine.py",
        '''    def advertise_modern(self, viewer, peer):\n        normalized = viewer._global_peer_from_event(peer._global_presence_event())\n        self.assertIsNotNone(normalized)\n        viewer.state["global"]["peers"][normalized["public_key"]] = normalized\n        self.assertTrue(viewer._supports_nip17(normalized["public_key"]))\n''',
        '''    def advertise_modern(self, viewer, peer):\n        normalized = viewer._global_peer_from_event(peer._global_presence_event())\n        self.assertIsNotNone(normalized)\n        viewer.state["global"]["peers"][normalized["public_key"]] = normalized\n        self.assertTrue(viewer._supports_nip17(normalized["public_key"]))\n        relay_event = peer._dm_relay_list_event()\n        self.assertEqual(\n            viewer._remember_nip17_dm_relay_event(normalized["public_key"], relay_event),\n            list(friends.NIP17_DM_RELAYS),\n        )\n''',
        "seed verified inbox metadata in engine tests",
    )
    replace_once(
        "tests/test_private_messaging_engine.py",
        '''        with patch.object(\n            self.alice, "_publish_global_event",\n            side_effect=lambda event: published.append(event) or (True, {}),\n        ):\n            ok, message = self.alice.send_dm(self.key(self.bob), "secret hello", "")\n''',
        '''        routed = []\n        with patch.object(\n            self.alice, "_publish_event_to_relays",\n            side_effect=lambda event, relays: routed.append((event, tuple(relays))) or (published.append(event) or (True, {})),\n        ):\n            ok, message = self.alice.send_dm(self.key(self.bob), "secret hello", "")\n        self.assertTrue(all(relays == friends.NIP17_DM_RELAYS for _, relays in routed))\n''',
        "modern direct message relay routing test",
    )
    replace_once(
        "tests/test_private_messaging_engine.py",
        '''        self.alice.state["global"]["peers"].pop(self.key(self.bob), None)\n        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))\n\n    def test_old_peer_still_uses_legacy_transport_during_upgrade_window(self):\n''',
        '''        self.alice.state["global"]["peers"].pop(self.key(self.bob), None)\n        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))\n        self.alice.save_state()\n        restarted = friends.FriendsEngine(state_dir=self.paths[0])\n        restored = restarted.state["global"]["friendships"][self.key(self.bob)]\n        self.assertEqual(restored.get("private_protocol"), "nip17-v1")\n        self.assertEqual(restored.get("nip17_dm_relays"), list(friends.NIP17_DM_RELAYS))\n        self.assertTrue(restarted._supports_nip17(self.key(self.bob)))\n\n    def test_signed_kind_10050_inbox_list_is_bounded_to_configured_relays(self):\n        self.make_friends(self.alice, self.bob)\n        event = self.bob._dm_relay_list_event()\n        self.assertTrue(friends.verify_event(event))\n        self.assertEqual(event["kind"], friends.NIP17_DM_RELAY_LIST_KIND)\n        self.assertEqual(\n            self.alice._dm_relays_from_event(event, self.key(self.bob)),\n            list(friends.NIP17_DM_RELAYS),\n        )\n        hostile = friends.build_event(\n            self.bob.state["global_identity"]["secret_key"],\n            friends.NIP17_DM_RELAY_LIST_KIND,\n            [["relay", "wss://127.0.0.1.example.invalid"], ["relay", "ws://127.0.0.1:7777"]],\n            "",\n        )\n        self.assertEqual(self.alice._dm_relays_from_event(hostile, self.key(self.bob)), [])\n\n    def test_incoming_rumor_must_address_receiver(self):\n        self.make_friends(self.alice, self.bob)\n        self.make_friends(self.alice, self.carol)\n        rumor = friends.create_nip17_rumor(\n            self.alice.state["global_identity"]["secret_key"],\n            [self.key(self.carol)],\n            "not for bob",\n            app_envelope={"v": 3, "type": "direct", "text": "not for bob", "media": []},\n        )\n        gift_for_bob = friends.wrap_nip17_rumor(\n            self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor\n        )\n        self.assertIsNone(self.bob._global_dm_from_event(gift_for_bob))\n\n    def test_old_peer_still_uses_legacy_transport_during_upgrade_window(self):\n''',
        "restart persistence and inbox validation tests",
    )
    replace_once(
        "tests/test_private_messaging_engine.py",
        '''        with patch.object(\n            self.alice, "_publish_global_event",\n            side_effect=lambda event: published.append(event) or (True, {}),\n        ):\n            ok, message = self.alice.create_group(\n''',
        '''        with patch.object(\n            self.alice, "_publish_event_to_relays",\n            side_effect=lambda event, relays: published.append(event) or (True, {}),\n        ):\n            ok, message = self.alice.create_group(\n''',
        "modern group inbox publisher mock",
    )
    replace_once(
        "tests/test_e2e_journey.py",
        '''            with patch.object(sender, "_publish_global_event",\n                              side_effect=lambda e: out.append(e) or (True, {})):\n                ok, _ = sender.send_dm(skey, text, "")\n''',
        '''            with patch.object(sender, "_publish_event_to_relays",\n                              side_effect=lambda e, relays: out.append(e) or (True, {})):\n                # Simulate the receiver's verified kind-10050 relay metadata.\n                sender.state["global"]["friendships"][skey]["nip17_dm_relays"] = list(friends_module.NIP17_DM_RELAYS)\n                sender.state["global"]["friendships"][skey]["nip17_dm_relays_seen_at"] = int(time.time())\n                ok, _ = sender.send_dm(skey, text, "")\n''',
        "E2E modern DM relay mock",
    )


def main():
    patch_private_module()
    patch_engine_constants_and_state()
    patch_presence_and_modern_capability()
    patch_nip17_inbox_methods()
    patch_private_publish_routing()
    patch_receiver_membership_validation()
    patch_periodic_inbox_publication_and_listener()
    patch_tests()
    print("final NIP-17 inbox interoperability hardening applied")


if __name__ == "__main__":
    main()
