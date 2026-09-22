#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "bin" / "omarchy-friends"
MANIFEST = ROOT / "manifest.json"
GATE = ROOT / "scripts" / "release-gate.sh"

def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)

def replace_method(text, name, next_name, new_block):
    start_marker = f"    def {name}("
    end_marker = f"    def {next_name}("
    start = text.find(start_marker)
    if start < 0:
        raise RuntimeError(f"missing method {name}")
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise RuntimeError(f"missing method after {name}: {next_name}")
    return text[:start] + new_block.rstrip() + "\n\n" + text[end:]

def patch_engine():
    text = ENGINE.read_text(encoding="utf-8")

    old_import = '''from omarchy_friends_global import (  # noqa: E402
    WebSocketClient,
    build_event,
    generate_keypair,
    verify_event,
    encrypt_private_text,
    decrypt_private_text,
)
'''
    new_import = '''from omarchy_friends_global import (  # noqa: E402
    WebSocketClient,
    build_event,
    generate_keypair,
    verify_event,
)
from omarchy_friends_private import (  # noqa: E402
    NIP59_GIFT_WRAP_KIND,
    app_envelope_from_rumor,
    create_nip17_rumor,
    decrypt_private_text,
    encrypt_legacy_private_text,
    unwrap_nip17_gift_wrap,
    wrap_nip17_rumor,
)
'''
    text = replace_once(text, old_import, new_import, "private messaging imports")
    text = replace_once(text, 'PLUGIN_VERSION = "4.14.0"', 'PLUGIN_VERSION = "4.15.0"', "plugin version")

    old_caps = 'GLOBAL_CAPABILITIES = ("friend-requests-v1", "encrypted-dm-v1", "group-dm-v1", "media-links-v1", "community-chat-v1")'
    new_caps = '''GLOBAL_CAPABILITIES = (
    "friend-requests-v1",
    "encrypted-dm-v1",
    "group-dm-v1",
    "media-links-v1",
    "community-chat-v1",
    "nip44-v2",
    "nip17-dm-v1",
    "nip59-gift-wrap-v1",
)'''
    text = replace_once(text, old_caps, new_caps, "capabilities")

    old_chat = '''            "can_chat": "encrypted-dm-v1" in capabilities and "friend-requests-v1" in capabilities,
            "common_ground": [],'''
    new_chat = '''            "can_chat": "friend-requests-v1" in capabilities and (
                "nip17-dm-v1" in capabilities or "encrypted-dm-v1" in capabilities
            ),
            "nip17_chat": "nip17-dm-v1" in capabilities and "nip44-v2" in capabilities,
            "common_ground": [],'''
    text = replace_once(text, old_chat, new_chat, "peer chat capabilities")

    new_global_dm = r'''    def _message_from_private_envelope(self, sender, message_id, timestamp, envelope, fallback_text=""):
        identity = self._global_identity()
        own_key = identity["public_key"]
        friendship = self.state.get("global", {}).get("friendships", {}).get(sender, {})
        if sender != own_key and friendship.get("status") != "friends":
            return None
        handle = (
            self.state.get("profile", {}).get("handle", "You")
            if sender == own_key
            else friendship.get("handle", "A friend")
        )
        text = fallback_text
        media = []
        group_id = ""
        group_name = ""
        message_type = "direct"
        group_payload = None

        if isinstance(envelope, dict):
            version = safe_int(envelope.get("v"))
            if version in (1, 3) and envelope.get("type") in (None, "", "direct"):
                message_type = "direct"
                text = envelope.get("text", fallback_text)
                media = normalize_media_items(envelope.get("media"))
            elif version in (2, 3):
                message_type = trim_text(envelope.get("type"), 24)
                group_id = trim_text(envelope.get("group_id"), 40).lower()
                group_payload = envelope.get("group") if isinstance(envelope.get("group"), dict) else None
                if message_type == "group_invite":
                    normalized_group = self._normalize_group(group_id, group_payload or {})
                    if not normalized_group or sender not in normalized_group["members"]:
                        return None
                    group_name = normalized_group["name"]
                    text = f"You were invited to {group_name}"
                elif message_type == "group_message":
                    group = self.state.get("global", {}).get("groups", {}).get(group_id)
                    if not group or sender not in group.get("members", {}):
                        return None
                    group_name = group.get("name", "Group")
                    text = envelope.get("text", fallback_text)
                    media = normalize_media_items(envelope.get("media"))
                else:
                    return None

        text = trim_text(text, 2000)
        if not text and not media and message_type == "direct":
            return None
        return {
            "id": trim_text(message_id, 64).lower(),
            "public_key": sender,
            "handle": trim_text(handle, 24) or ("You" if sender == own_key else "A friend"),
            "group_id": group_id,
            "group_name": group_name,
            "message_type": message_type,
            "group": group_payload,
            "text": text,
            "media": media,
            "timestamp": safe_int(timestamp, now_seconds()),
            "incoming": sender != own_key,
        }

    def _global_dm_from_event(self, event):
        identity = self._global_identity()

        if isinstance(event, dict) and int(event.get("kind", -1)) == NIP59_GIFT_WRAP_KIND:
            try:
                rumor = unwrap_nip17_gift_wrap(identity["secret_key"], event)
            except (KeyError, TypeError, ValueError, UnicodeError, json.JSONDecodeError):
                return None
            sender = trim_text(rumor.get("pubkey"), 64).lower()
            if not is_valid_public_key(sender):
                return None
            envelope = app_envelope_from_rumor(rumor)
            return self._message_from_private_envelope(
                sender,
                rumor.get("id"),
                rumor.get("created_at"),
                envelope,
                rumor.get("content", ""),
            )

        if not verify_event(event) or int(event.get("kind", -1)) != GLOBAL_DM_KIND:
            return None
        if (
            GLOBAL_DM_TAG not in self._event_tag_values(event, "t")
            or identity["public_key"] not in self._event_tag_values(event, "p")
        ):
            return None
        sender = trim_text(event.get("pubkey"), 64).lower()
        friendship = self.state.get("global", {}).get("friendships", {}).get(sender, {})
        if friendship.get("status") != "friends":
            return None
        try:
            payload = json.loads(event.get("content", "{}"))
            decrypted = decrypt_private_text(identity["secret_key"], sender, payload)
        except (KeyError, TypeError, ValueError, UnicodeError, base64.binascii.Error):
            return None
        try:
            envelope = json.loads(decrypted)
        except (TypeError, ValueError):
            envelope = None
        return self._message_from_private_envelope(
            sender,
            event.get("id"),
            event.get("created_at"),
            envelope,
            decrypted,
        )
'''
    text = replace_method(text, "_global_dm_from_event", "_global_community_from_event", new_global_dm)

    helpers = r'''    def _supports_nip17(self, public_key):
        public_key = trim_text(public_key, 64).lower()
        peer = self.state.get("global", {}).get("peers", {}).get(public_key, {})
        capabilities = set(peer.get("capabilities", [])) if isinstance(peer, dict) else set()
        return {"nip44-v2", "nip17-dm-v1"}.issubset(capabilities)

    def _legacy_private_event(self, public_key, envelope, extra_tags=None, alt="Omarchy Friends private message"):
        identity = self._global_identity()
        encrypted = encrypt_legacy_private_text(
            identity["secret_key"],
            public_key,
            json.dumps(envelope, ensure_ascii=False, separators=(",", ":")),
        )
        tags = [["p", public_key], ["t", GLOBAL_DM_TAG]]
        for tag in extra_tags or []:
            if isinstance(tag, (list, tuple)) and tag:
                tags.append([str(value) for value in tag])
        tags.append(["alt", alt])
        return build_event(
            identity["secret_key"],
            GLOBAL_DM_KIND,
            tags,
            json.dumps(encrypted, separators=(",", ":")),
        )

    def _publish_nip17(self, recipient_public_key, rumor):
        identity = self._global_identity()
        event = wrap_nip17_rumor(identity["secret_key"], recipient_public_key, rumor)
        ok, relay_status = self._publish_global_event(event)
        self.state.setdefault("global", {}).setdefault("relays", {}).update(relay_status)
        return ok, event

    def _remember_local_private_rumor(self, rumor_id):
        rumor_id = trim_text(rumor_id, 64).lower()
        if not rumor_id:
            return
        global_state = self.state.setdefault("global", {})
        processed = global_state.setdefault("processed_event_ids", [])
        if rumor_id not in processed:
            processed.append(rumor_id)
            global_state["processed_event_ids"] = processed[-MAX_SEEN_EVENT_IDS:]

'''
    send_pos = text.find("    def send_dm(")
    if send_pos < 0:
        raise RuntimeError("missing send_dm insertion point")
    text = text[:send_pos] + helpers + text[send_pos:]

    new_send_dm = r'''    def send_dm(self, public_key, text, media_url=""):
        public_key = trim_text(public_key, 64).lower()
        text = trim_text(text, 2000)
        media = normalize_media_items(media_url)
        if not text and not media:
            return False, "Write a message or add a media link first"
        if self.state.setdefault("global", {}).setdefault("friendships", {}).get(public_key, {}).get("status") != "friends":
            return False, "DMs are available after you become friends"

        identity = self._global_identity()
        message_id = ""
        try:
            if self._supports_nip17(public_key):
                envelope = {"v": 3, "type": "direct", "text": text, "media": media}
                rumor = create_nip17_rumor(
                    identity["secret_key"],
                    [public_key],
                    text or "Shared media",
                    app_envelope=envelope,
                )
                ok, _ = self._publish_nip17(public_key, rumor)
                if ok:
                    message_id = rumor["id"]
                    self._remember_local_private_rumor(message_id)
                    try:
                        self._publish_nip17(identity["public_key"], rumor)
                    except (TypeError, ValueError):
                        pass
            else:
                event = self._legacy_private_event(
                    public_key,
                    {"v": 1, "text": text, "media": media},
                )
                ok, relay_status = self._publish_global_event(event)
                self.state["global"]["relays"].update(relay_status)
                if ok:
                    message_id = event["id"]
        except (TypeError, ValueError):
            return False, "That friend key is invalid"

        if not message_id:
            self.save_state()
            return False, "Could not send the private message"

        friend = self.state["global"]["friendships"][public_key]
        self.state["global"].setdefault("messages", []).append({
            "id": message_id,
            "public_key": public_key,
            "handle": friend.get("handle", "Friend"),
            "text": text,
            "media": media,
            "timestamp": now_seconds(),
            "incoming": False,
        })
        self.state["global"]["messages"] = self.state["global"]["messages"][-MAX_MESSAGES:]
        self._remember_memory_signal(public_key, "dm", "sent", friend.get("handle", ""), "")
        if not self.state.get("invite_nudge_dismissed"):
            self.state["invite_nudge"] = True
        self.save_state()
        return True, "Private message sent"
'''
    text = replace_method(text, "send_dm", "create_group", new_send_dm)

    new_create_group = r'''    def create_group(self, name, member_keys):
        name = " ".join(trim_text(name, MAX_GROUP_NAME_LENGTH).split())
        if not name:
            return False, "Give the group a name first"
        keys = []
        friendships = self.state.setdefault("global", {}).setdefault("friendships", {})
        for public_key in member_keys or []:
            public_key = trim_text(public_key, 64).lower()
            if not is_valid_public_key(public_key) or public_key in keys:
                continue
            if friendships.get(public_key, {}).get("status") != "friends":
                continue
            keys.append(public_key)
        if len(keys) < 2:
            return False, "Choose at least two friends for a group"
        keys = keys[: MAX_GROUP_MEMBERS - 1]

        identity = self._global_identity()
        own_key = identity["public_key"]
        members = {
            own_key: {
                "public_key": own_key,
                "handle": trim_text(self.state["profile"].get("handle"), 24) or "You",
                "avatar": self.state["profile"].get("avatar")
                if self.state["profile"].get("avatar") in AVAILABLE_AVATARS
                else "👾",
            }
        }
        for public_key in keys:
            friend = friendships[public_key]
            members[public_key] = {
                "public_key": public_key,
                "handle": trim_text(friend.get("handle"), 24) or generate_global_handle(public_key),
                "avatar": friend.get("avatar") if friend.get("avatar") in AVAILABLE_AVATARS else "👾",
            }

        group = {
            "id": uuid.uuid4().hex[:24],
            "name": name,
            "members": members,
            "created_by": own_key,
            "created_at": now_seconds(),
        }
        envelope = {"v": 3, "type": "group_invite", "group_id": group["id"], "group": group}
        nip17_keys = [key for key in keys if self._supports_nip17(key)]
        rumor = None
        if nip17_keys:
            rumor = create_nip17_rumor(
                identity["secret_key"],
                keys,
                f"Invitation to {name}",
                subject=name,
                app_envelope=envelope,
            )

        published = 0
        for public_key in keys:
            try:
                if public_key in nip17_keys:
                    ok, _ = self._publish_nip17(public_key, rumor)
                else:
                    event = self._legacy_private_event(
                        public_key,
                        {"v": 2, "type": "group_invite", "group_id": group["id"], "group": group},
                        [["g", group["id"]]],
                        "Omarchy Friends private group invite",
                    )
                    ok, relay_status = self._publish_global_event(event)
                    self.state["global"]["relays"].update(relay_status)
                published += int(ok)
            except (TypeError, ValueError):
                continue

        if rumor is not None and published:
            self._remember_local_private_rumor(rumor["id"])
            try:
                self._publish_nip17(own_key, rumor)
            except (TypeError, ValueError):
                pass

        if not published:
            self.save_state()
            return False, "Could not reach the group invite relay"

        self.state["global"].setdefault("groups", {})[group["id"]] = group
        self.state["global"]["groups"] = dict(list(self.state["global"]["groups"].items())[-MAX_GROUPS:])
        self.save_state()
        return True, f"Group {name} created"
'''
    text = replace_method(text, "create_group", "send_group_message", new_create_group)

    new_send_group = r'''    def send_group_message(self, group_id, text, media_url=""):
        group_id = trim_text(group_id, 40).lower()
        group = self.state.setdefault("global", {}).setdefault("groups", {}).get(group_id)
        text = trim_text(text, 2000)
        media = normalize_media_items(media_url)
        if not group:
            return False, "That group is no longer available"
        if not text and not media:
            return False, "Write a message or add a media link first"

        identity = self._global_identity()
        recipient_keys = []
        for public_key in group.get("members", {}):
            if public_key == identity["public_key"]:
                continue
            if self.state["global"].get("friendships", {}).get(public_key, {}).get("status") == "friends":
                recipient_keys.append(public_key)

        nip17_keys = [key for key in recipient_keys if self._supports_nip17(key)]
        envelope = {
            "v": 3,
            "type": "group_message",
            "group_id": group_id,
            "text": text,
            "media": media,
        }
        rumor = None
        if nip17_keys:
            rumor = create_nip17_rumor(
                identity["secret_key"],
                recipient_keys,
                text or "Shared media",
                subject=group.get("name", "Group"),
                app_envelope=envelope,
            )

        published = 0
        first_event_id = ""
        for public_key in recipient_keys:
            try:
                if public_key in nip17_keys:
                    ok, _ = self._publish_nip17(public_key, rumor)
                    event_id = rumor["id"] if ok else ""
                else:
                    event = self._legacy_private_event(
                        public_key,
                        {"v": 2, "type": "group_message", "group_id": group_id, "text": text, "media": media},
                        [["g", group_id]],
                        "Omarchy Friends private group message",
                    )
                    ok, relay_status = self._publish_global_event(event)
                    self.state["global"]["relays"].update(relay_status)
                    event_id = event["id"] if ok else ""
                if ok:
                    published += 1
                    first_event_id = first_event_id or event_id
            except (TypeError, ValueError):
                continue

        if rumor is not None and published:
            self._remember_local_private_rumor(rumor["id"])
            first_event_id = rumor["id"]
            try:
                self._publish_nip17(identity["public_key"], rumor)
            except (TypeError, ValueError):
                pass

        if not published:
            self.save_state()
            return False, "Could not reach any group member"

        self.state["global"].setdefault("messages", []).append({
            "id": first_event_id,
            "public_key": identity["public_key"],
            "handle": self.state["profile"].get("handle", "You"),
            "group_id": group_id,
            "group_name": group.get("name", "Group"),
            "message_type": "group_message",
            "text": text,
            "media": media,
            "timestamp": now_seconds(),
            "incoming": False,
        })
        self.state["global"]["messages"] = self.state["global"]["messages"][-MAX_MESSAGES:]
        self.save_state()
        return True, f"Sent to {group.get('name', 'group')}"
'''
    text = replace_method(text, "send_group_message", "send_community_message", new_send_group)

    old_sync_subs = '''        presence_sub = "ofp" + uuid.uuid4().hex[:12]
        ping_sub = "ofg" + uuid.uuid4().hex[:12]
        community_sub = "ofc" + uuid.uuid4().hex[:12]
        result = {"published": False, "presence": [], "pings": [], "messages": [], "community": []}'''
    new_sync_subs = '''        presence_sub = "ofp" + uuid.uuid4().hex[:12]
        ping_sub = "ofg" + uuid.uuid4().hex[:12]
        dm_sub = "ofdm" + uuid.uuid4().hex[:12]
        community_sub = "ofc" + uuid.uuid4().hex[:12]
        result = {"published": False, "presence": [], "pings": [], "messages": [], "community": []}'''
    text = replace_once(text, old_sync_subs, new_sync_subs, "sync dm subscription id")

    sync_ping_req = '''            relay.send_json(
                [
                    "REQ",
                    ping_sub,
                    {
                        "kinds": [GLOBAL_PING_KIND, GLOBAL_DM_KIND],
                        "#t": [GLOBAL_PING_TAG, GLOBAL_DM_TAG],
                        "#p": [self._global_identity()["public_key"]],
                        "since": max(0, since - 10),
                        "limit": GLOBAL_MAX_PINGS,
                    },
                ]
            )
'''
    sync_dm_req = sync_ping_req + '''            relay.send_json(
                [
                    "REQ",
                    dm_sub,
                    {
                        "kinds": [NIP59_GIFT_WRAP_KIND],
                        "#p": [self._global_identity()["public_key"]],
                        "since": max(0, since - 10),
                        "limit": MAX_MESSAGES,
                    },
                ]
            )
'''
    text = replace_once(text, sync_ping_req, sync_dm_req, "sync gift-wrap request")
    text = replace_once(
        text,
        '            while time.monotonic() < deadline and len(eose) < 3:',
        '            while time.monotonic() < deadline and len(eose) < 4:',
        "sync eose count",
    )
    old_route = '''                    elif message[1] == ping_sub:
                        event = message[2]
                        if GLOBAL_DM_TAG in self._event_tag_values(event, "t"):
                            result["messages"].append(event)
                        else:
                            result["pings"].append(event)
                    elif message[1] == community_sub:'''
    new_route = '''                    elif message[1] == ping_sub:
                        event = message[2]
                        if GLOBAL_DM_TAG in self._event_tag_values(event, "t"):
                            result["messages"].append(event)
                        else:
                            result["pings"].append(event)
                    elif message[1] == dm_sub:
                        result["messages"].append(message[2])
                    elif message[1] == community_sub:'''
    text = replace_once(text, old_route, new_route, "sync gift-wrap routing")
    text = replace_once(
        text,
        '''                relay.send_json(["CLOSE", ping_sub])
                relay.send_json(["CLOSE", community_sub])''',
        '''                relay.send_json(["CLOSE", ping_sub])
                relay.send_json(["CLOSE", dm_sub])
                relay.send_json(["CLOSE", community_sub])''',
        "sync close dm subscription",
    )

    old_listen_ids = '''        ping_sub = "ofl" + uuid.uuid4().hex[:12]
        community_sub = "ofcl" + uuid.uuid4().hex[:12]
        presence_sub = "ofpl" + uuid.uuid4().hex[:12]'''
    new_listen_ids = '''        ping_sub = "ofl" + uuid.uuid4().hex[:12]
        dm_sub = "ofdl" + uuid.uuid4().hex[:12]
        community_sub = "ofcl" + uuid.uuid4().hex[:12]
        presence_sub = "ofpl" + uuid.uuid4().hex[:12]'''
    text = replace_once(text, old_listen_ids, new_listen_ids, "listen dm subscription id")

    listen_ping_req = '''            relay.send_json([
                "REQ", ping_sub,
                {
                    "kinds": [GLOBAL_PING_KIND, GLOBAL_DM_KIND],
                    "#t": [GLOBAL_PING_TAG, GLOBAL_DM_TAG],
                    "#p": [identity["public_key"]],
                    "since": max(0, started_at - 60),
                    "limit": GLOBAL_MAX_PINGS,
                },
            ])
'''
    listen_dm_req = listen_ping_req + '''            relay.send_json([
                "REQ", dm_sub,
                {
                    "kinds": [NIP59_GIFT_WRAP_KIND],
                    "#p": [identity["public_key"]],
                    "since": max(0, started_at - 60),
                    "limit": MAX_MESSAGES,
                },
            ])
'''
    text = replace_once(text, listen_ping_req, listen_dm_req, "listen gift-wrap request")
    old_listen_route = '''                    if sub_id == ping_sub:
                        if GLOBAL_DM_TAG in self._event_tag_values(event, "t"):
                            stored = self._ingest_global_dm(event)
                        else:
                            stored = self._ingest_global_ping(event)
                    elif sub_id == community_sub:'''
    new_listen_route = '''                    if sub_id == ping_sub:
                        if GLOBAL_DM_TAG in self._event_tag_values(event, "t"):
                            stored = self._ingest_global_dm(event)
                        else:
                            stored = self._ingest_global_ping(event)
                    elif sub_id == dm_sub:
                        stored = self._ingest_global_dm(event)
                    elif sub_id == community_sub:'''
    text = replace_once(text, old_listen_route, new_listen_route, "listen gift-wrap routing")

    ENGINE.write_text(text, encoding="utf-8")

def patch_manifest():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    data["version"] = "4.15.0"
    data["description"] = (
        "An Omarchy-native social and collaboration layer with NIP-44/NIP-17 private messaging, "
        "live builders, liquid-glass Build Network, setup sharing, testing, human help, community memory, events and challenges."
    )
    MANIFEST.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

def patch_gate():
    text = GATE.read_text(encoding="utf-8")
    old = '''  bin/build_network_app_v4.py \\
  bin/omarchy-friends-open'''
    new = '''  bin/build_network_app_v4.py \\
  bin/omarchy_friends_private.py \\
  bin/omarchy-friends-open'''
    text = replace_once(text, old, new, "release-gate private module compile")
    GATE.write_text(text, encoding="utf-8")

def main():
    patch_engine()
    patch_manifest()
    patch_gate()
    print("private messaging migration patch applied")

if __name__ == "__main__":
    main()
