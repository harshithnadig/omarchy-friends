import shutil
import tempfile
import time
import unittest
import json
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


BIN_DIR = Path(__file__).parent.parent / "bin"
friends_module = SourceFileLoader(
    "friends_engine", str(BIN_DIR / "omarchy-friends")
).load_module()


class TestFriendsEngine(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.engine = friends_module.FriendsEngine(state_dir=self.test_dir)

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    @staticmethod
    def presence_packet(code="OMAR-1111-AAA", handle="LocalBuilder", **extra):
        packet = {
            "protocol": friends_module.PROTOCOL_VERSION,
            "type": "presence",
            "code": code,
            "handle": handle,
            "avatar": "🦊",
            "status": "coding",
            "activity": "Neovim",
            "music": "",
            "focus_mins": 12,
            "project_name": "Tiny Tool",
            "project_desc": "A useful local tool",
            "project_url": "https://github.com/example/tiny-tool",
            "interests": ["linux", "music"],
            "timestamp": int(time.time()),
        }
        packet.update(extra)
        return packet

    def prime_peer(self, engine=None, code="OMAR-1111-AAA", handle="LocalBuilder", **extra):
        engine = engine or self.engine
        self.assertTrue(
            engine.handle_packet(
                self.presence_packet(code=code, handle=handle, **extra),
                ("192.168.1.20", friends_module.BROADCAST_PORT),
            )
        )

    def test_initial_state_is_private_and_empty(self):
        status = self.engine.get_full_status()
        self.assertRegex(status["profile"]["code"], r"^OMAR-[A-Z0-9]{4}-[A-Z0-9]{3}$")
        self.assertEqual(status["online_count"], 0)
        self.assertIsNone(status["matched_peer"])
        self.assertEqual(status["friends"], [])
        self.assertEqual(status["world_pulse"], [])

    def test_unblock_global_only_removes_requested_key_and_presence_returns(self):
        remote = friends_module.FriendsEngine(state_dir=tempfile.mkdtemp())
        try:
            blocked_key = remote.state["global_identity"]["public_key"]
            other_key = "b" * 64
            self.engine.state["global"]["blocked_pubkeys"] = [blocked_key, other_key]
            self.engine.state["global"]["friendships"] = {other_key: {"status": "friends"}}
            self.engine.state["global"]["messages"] = [{"id": "keep-message", "public_key": other_key}]
            before = json.dumps(self.engine.state["global"], sort_keys=True)
            blocked_event = remote._global_presence_event()
            self.engine._ingest_global_presence(blocked_event)
            self.engine._cleanup_global_peers()
            self.assertNotIn(blocked_key, self.engine.state["global"]["peers"])
            self.assertNotIn(blocked_key, self.engine.state["global"]["memory"])

            ok, message = self.engine.unblock_global(blocked_key)

            self.assertTrue(ok, message)
            self.assertEqual(self.engine.state["global"]["blocked_pubkeys"], [other_key])
            self.assertEqual(self.engine.state["global"]["friendships"], {other_key: {"status": "friends"}})
            self.assertEqual(self.engine.state["global"]["messages"], [{"id": "keep-message", "public_key": other_key}])
            after = json.dumps(self.engine.state["global"], sort_keys=True)
            before_without_blocked = json.loads(before)
            after_without_blocked = json.loads(after)
            before_without_blocked["blocked_pubkeys"] = [other_key]
            self.assertEqual(after_without_blocked, before_without_blocked)
            unblocked_event = remote._global_presence_event()
            self.assertTrue(self.engine._ingest_global_presence(unblocked_event))
            self.engine._cleanup_global_peers()
            self.assertIn(blocked_key, self.engine.state["global"]["peers"])
        finally:
            shutil.rmtree(remote.state_dir, ignore_errors=True)

    def test_global_identity_and_presence_are_signed_without_friend_code(self):
        identity = self.engine.state["global_identity"]
        self.assertRegex(identity["public_key"], r"^[0-9a-f]{64}$")
        self.assertRegex(identity["secret_key"], r"^[0-9a-f]{64}$")
        with patch.object(friends_module, "get_active_window", return_value="Neovim"), patch.object(
            friends_module, "get_active_music", return_value=""
        ):
            event = self.engine._global_presence_event()
        self.assertTrue(friends_module.verify_event(event))
        self.assertEqual(event["kind"], friends_module.GLOBAL_PRESENCE_KIND)
        self.assertNotIn("code", json.loads(event["content"]))

    def test_global_presence_advertises_chat_capability_and_plugin_version(self):
        with patch.object(friends_module, "get_active_window", return_value="Neovim"), patch.object(
            friends_module, "get_active_music", return_value=""
        ):
            event = self.engine._global_presence_event()
        content = json.loads(event["content"])
        self.assertEqual(content["plugin_version"], friends_module.PLUGIN_VERSION)
        self.assertIn("friend-requests-v1", content["capabilities"])
        self.assertIn("encrypted-dm-v1", content["capabilities"])

    def test_capable_peer_friend_request_publishes_one_friend_request(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Neovim"):
                peer = self.engine._global_peer_from_event(remote._global_presence_event())
            self.assertTrue(peer["can_chat"])
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            published = []
            with patch.object(
                self.engine,
                "_publish_global_event",
                side_effect=lambda event: published.append(event) or (True, {}),
            ):
                ok, message = self.engine.request_friend(peer["public_key"])
            self.assertTrue(ok, message)
            self.assertEqual(len(published), 1)
            self.assertEqual(json.loads(published[0]["content"])["action"], "friend_request")
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_legacy_peer_friend_request_also_publishes_update_prompt(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            legacy_content = remote._global_presence_content()
            legacy_content.pop("plugin_version", None)
            legacy_content.pop("capabilities", None)
            legacy_event = friends_module.build_event(
                remote.state["global_identity"]["secret_key"],
                friends_module.GLOBAL_PRESENCE_KIND,
                [
                    ["d", friends_module.GLOBAL_PRESENCE_TAG],
                    ["t", "omarchy-friends"],
                    ["alt", "Omarchy Friends online presence"],
                ],
                json.dumps(legacy_content, ensure_ascii=False, separators=(",", ":")),
            )
            peer = self.engine._global_peer_from_event(legacy_event)
            self.assertFalse(peer["can_chat"])
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            published = []
            with patch.object(
                self.engine,
                "_publish_global_event",
                side_effect=lambda event: published.append(event) or (True, {}),
            ):
                ok, message = self.engine.request_friend(peer["public_key"])
            self.assertTrue(ok, message)
            self.assertEqual(len(published), 2)
            actions = [json.loads(event["content"])["action"] for event in published]
            self.assertEqual(actions, ["friend_request", "hello"])
            hello = json.loads(published[1]["content"])
            self.assertIn("omarchy plugin update community.omarchy-friends --yes", hello["prompt"])
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_direct_invite_link_can_start_chat_without_world_cache(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            remote_key = remote.state["global_identity"]["public_key"]
            published = []
            with patch.object(
                self.engine,
                "_publish_global_event",
                side_effect=lambda event: published.append(event) or (True, {}),
            ):
                ok, message = self.engine.request_friend_direct(remote_key)
            self.assertTrue(ok, message)
            self.assertEqual(len(published), 2)
            self.assertEqual(json.loads(published[0]["content"])["action"], "friend_request")
            self.assertEqual(json.loads(published[1]["content"])["action"], "hello")
            self.assertEqual(self.engine.state["global"]["friendships"][remote_key]["status"], "pending")
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_community_message_is_signed_public_and_stored_locally(self):
        published = []
        with patch.object(
            self.engine,
            "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, message = self.engine.send_community_message("Hello Omarchy builders")
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 1)
        event = published[0]
        self.assertEqual(event["kind"], friends_module.GLOBAL_COMMUNITY_KIND)
        self.assertIn(friends_module.GLOBAL_COMMUNITY_TAG, [tag[1] for tag in event["tags"] if tag[0] == "t"])
        self.assertTrue(friends_module.verify_event(event))
        self.assertEqual(self.engine.state["global"]["community"][0]["text"], "Hello Omarchy builders")

    def test_incoming_community_message_raises_popup_event(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            published = []
            with patch.object(
                remote,
                "_publish_global_event",
                side_effect=lambda event: published.append(event) or (True, {}),
            ):
                ok, _ = remote.send_community_message("Hello from a fellow builder")
            self.assertTrue(ok)
            relay_result = {"published": True, "presence": [], "pings": [], "messages": [], "community": published}
            with patch.object(self.engine, "_global_relay_sync", return_value=relay_result):
                ok, _ = self.engine.sync_global()
            self.assertTrue(ok)
            community = self.engine.state["global"]["community"]
            self.assertEqual(len(community), 1)
            self.assertEqual(community[0]["text"], "Hello from a fellow builder")
            events = self.engine.pop_events()
            popup = [event for event in events if event.get("action") == "community"]
            self.assertEqual(len(popup), 1)
            self.assertIn("Hello from a fellow builder", popup[0]["message"])
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_incoming_dm_raises_popup_notification_event(self):
        receiver_dir = tempfile.mkdtemp()
        receiver = friends_module.FriendsEngine(state_dir=receiver_dir)
        try:
            receiver_key = receiver.state["global_identity"]["public_key"]
            sender_key = self.engine.state["global_identity"]["public_key"]
            self.engine.state["global"]["friendships"][receiver_key] = {"status": "friends", "handle": "Receiver", "avatar": "🦊"}
            receiver.state["global"]["friendships"][sender_key] = {"status": "friends", "handle": "Sender", "avatar": "👾"}
            sent = []
            with patch.object(
                self.engine, "_publish_global_event", side_effect=lambda event: sent.append(event) or (True, {})
            ):
                ok, _ = self.engine.send_dm(receiver_key, "hey, check this out", "")
            self.assertTrue(ok)
            relay_result = {"published": True, "presence": [], "pings": [], "messages": sent, "community": []}
            with patch.object(receiver, "_global_relay_sync", return_value=relay_result):
                ok, _ = receiver.sync_global()
            self.assertTrue(ok)
            self.assertEqual(receiver.state["global"]["messages"][0]["text"], "hey, check this out")
            popup = [event for event in receiver.pop_events() if event.get("action") == "dm"]
            self.assertEqual(len(popup), 1)
            self.assertIn("Sender", popup[0]["message"])
        finally:
            shutil.rmtree(receiver_dir, ignore_errors=True)

    def test_private_group_invites_and_messages_are_encrypted_per_member(self):
        first_dir = tempfile.mkdtemp()
        second_dir = tempfile.mkdtemp()
        first = friends_module.FriendsEngine(state_dir=first_dir)
        second = friends_module.FriendsEngine(state_dir=second_dir)
        try:
            first_key = first.state["global_identity"]["public_key"]
            second_key = second.state["global_identity"]["public_key"]
            sender_key = self.engine.state["global_identity"]["public_key"]
            for engine, other_key, other_name in (
                (self.engine, first_key, "First"),
                (self.engine, second_key, "Second"),
            ):
                engine.state["global"]["friendships"][other_key] = {"status": "friends", "handle": other_name, "avatar": "🦊"}
            first.state["global"]["friendships"][sender_key] = {"status": "friends", "handle": "Sender", "avatar": "👾"}
            second.state["global"]["friendships"][sender_key] = {"status": "friends", "handle": "Sender", "avatar": "👾"}
            published = []
            with patch.object(self.engine, "_publish_global_event", side_effect=lambda event: published.append(event) or (True, {})):
                ok, message = self.engine.create_group("Ship Crew", [first_key, second_key])
            self.assertTrue(ok, message)
            self.assertEqual(len(published), 2)
            group_id = next(iter(self.engine.state["global"]["groups"]))
            invite = first._global_dm_from_event(published[0])
            self.assertEqual(invite["message_type"], "group_invite")
            self.assertEqual(invite["group_id"], group_id)
            self.assertTrue(first._ingest_global_dm(published[0]))
            self.assertIn(group_id, first.state["global"]["groups"])
            group_messages = []
            with patch.object(self.engine, "_publish_global_event", side_effect=lambda event: group_messages.append(event) or (True, {})):
                ok, message = self.engine.send_group_message(group_id, "Ship it", "")
            self.assertTrue(ok, message)
            self.assertEqual(len(group_messages), 2)
            message = first._global_dm_from_event(group_messages[0])
            self.assertEqual(message["message_type"], "group_message")
            self.assertEqual(message["group_id"], group_id)
            self.assertEqual(message["text"], "Ship it")
        finally:
            shutil.rmtree(first_dir, ignore_errors=True)
            shutil.rmtree(second_dir, ignore_errors=True)

    def test_global_directory_merges_a_real_signed_installer(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Kitty"):
                event = remote._global_presence_event()
            peer = self.engine._global_peer_from_event(event)
            self.assertIsNotNone(peer)
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            status = self.engine.get_full_status()
            self.assertEqual(len(status["global_peers"]), 1)
            self.assertEqual(status["global_peers"][0]["source"], "global")
            self.assertEqual(status["global_peers"][0]["handle"], remote.state["profile"]["handle"])
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_global_ping_targets_public_key_and_is_signed(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Neovim"):
                peer = self.engine._global_peer_from_event(remote._global_presence_event())
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            published = []
            with patch.object(
                self.engine,
                "_publish_global_event",
                side_effect=lambda event: published.append(event) or (True, {}),
            ):
                ok, message = self.engine.global_ping(peer["public_key"], "hello")
            self.assertTrue(ok, message)
            self.assertEqual(len(published), 1)
            self.assertTrue(friends_module.verify_event(published[0]))
            self.assertIn(peer["public_key"], self.engine._event_tag_values(published[0], "p"))
            self.assertEqual(json.loads(published[0]["content"])["type"], "ping")
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_world_spark_sends_a_bounded_icebreaker_to_a_real_peer(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Neovim"):
                peer = self.engine._global_peer_from_event(remote._global_presence_event())
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            published = []
            with patch.object(
                self.engine,
                "_publish_global_event",
                side_effect=lambda event: published.append(event) or (True, {}),
            ):
                ok, message = self.engine.global_spark()
            self.assertTrue(ok, message)
            self.assertEqual(len(published), 1)
            content = json.loads(published[0]["content"])
            self.assertEqual(content["action"], "spark")
            self.assertTrue(content["prompt"])
            self.assertLessEqual(len(content["prompt"]), 120)
            self.assertTrue(friends_module.verify_event(published[0]))
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_world_focus_invite_and_acceptance_create_a_real_shared_ritual(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Neovim"):
                remote_peer = self.engine._global_peer_from_event(remote._global_presence_event())
                local_peer = remote._global_peer_from_event(self.engine._global_presence_event())
            self.engine.state["global"]["peers"][remote_peer["public_key"]] = remote_peer
            remote.state["global"]["peers"][local_peer["public_key"]] = local_peer

            invite_events = []
            with patch.object(
                self.engine,
                "_publish_global_event",
                side_effect=lambda event: invite_events.append(event) or (True, {}),
            ):
                ok, message = self.engine.global_focus_invite(remote_peer["public_key"])
            self.assertTrue(ok, message)
            self.assertEqual(self.engine.get_full_status()["global_focus"]["status"], "pending")
            invite_content = json.loads(invite_events[0]["content"])
            self.assertEqual(invite_content["action"], "focus")
            self.assertEqual(invite_content["minutes"], 25)

            invite_ping = remote._global_ping_from_event(invite_events[0])
            self.assertIsNotNone(invite_ping)
            remote.state["global"]["pings"].append(invite_ping)
            accept_events = []
            with patch.object(
                remote,
                "_publish_global_event",
                side_effect=lambda event: accept_events.append(event) or (True, {}),
            ):
                ok, message = remote.global_focus_accept(invite_ping["id"])
            self.assertTrue(ok, message)
            self.assertTrue(remote.get_full_status()["global_focus"]["active"])
            self.assertEqual(json.loads(accept_events[0]["content"])["action"], "focus_accept")

            accepted_ping = self.engine._global_ping_from_event(accept_events[0])
            self.assertTrue(self.engine._handle_global_focus_reply(accepted_ping))
            focus = self.engine.get_full_status()["global_focus"]
            self.assertTrue(focus["active"])
            self.assertEqual(focus["buddy_public_key"], remote_peer["public_key"])
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_global_refresh_delivers_incoming_wave_once(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Neovim"):
                presence = remote._global_presence_event()
            ping_content = json.dumps(
                {
                    "app": "omarchy-friends",
                    "v": 1,
                    "type": "ping",
                    "action": "hello",
                    "handle": remote.state["profile"]["handle"],
                    "avatar": remote.state["profile"]["avatar"],
                },
                separators=(",", ":"),
            )
            ping = friends_module.build_event(
                remote.state["global_identity"]["secret_key"],
                friends_module.GLOBAL_PING_KIND,
                [
                    ["p", self.engine.state["global_identity"]["public_key"]],
                    ["t", friends_module.GLOBAL_PING_TAG],
                ],
                ping_content,
            )
            with patch.object(
                self.engine,
                "_global_relay_sync",
                return_value={"published": True, "presence": [presence], "pings": [ping]},
            ), patch.object(friends_module, "get_active_window", return_value="Neovim"):
                ok, message = self.engine.sync_global()
            self.assertTrue(ok, message)
            self.assertEqual(len(self.engine.get_full_status()["global_peers"]), 1)
            self.assertEqual(len(self.engine.get_full_status()["global_pings"]), 1)
            self.assertEqual(len(self.engine.pop_events()), 1)
            with patch.object(
                self.engine,
                "_global_relay_sync",
                return_value={"published": True, "presence": [], "pings": [], "messages": [], "community": []},
            ):
                self.engine.sync_global()
            self.assertEqual(len(self.engine.pop_events()), 0)
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_global_cache_migrates_after_restart(self):
        remote_dir = tempfile.mkdtemp()
        try:
            remote = friends_module.FriendsEngine(state_dir=remote_dir)
            with patch.object(friends_module, "get_active_window", return_value="Kitty"):
                peer = self.engine._global_peer_from_event(remote._global_presence_event())
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            self.engine.state["global"]["relays"] = {
                "wss://nos.lol": {"online": True, "accepted": True, "acknowledged": True}
            }
            self.engine.save_state()
            restarted = friends_module.FriendsEngine(state_dir=self.test_dir)
            self.assertEqual(len(restarted.get_full_status()["global_peers"]), 1)
            self.assertTrue(restarted.state["global"]["relays"]["wss://nos.lol"]["online"])
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_presence_match_and_trusted_friend(self):
        self.engine.set_interests(["linux", "music", "invalid", "linux", "design", "games"])
        self.prime_peer()
        peer = self.engine.match_next()
        self.assertEqual(peer["handle"], "LocalBuilder")
        self.assertTrue(peer["online"])
        self.assertEqual(peer["source"], "lan")
        self.assertIn("🐧 Linux", peer["common_ground"])
        self.assertIn("🎧 Music", peer["common_ground"])

        ok, message = self.engine.add_matched_friend()
        self.assertTrue(ok, message)
        status = self.engine.get_full_status()
        self.assertEqual([friend["code"] for friend in status["friends"]], ["OMAR-1111-AAA"])
        self.assertEqual(status["online_count"], 1)

    def test_match_prefers_shared_interests(self):
        self.engine.set_interests(["linux"])
        self.prime_peer(code="OMAR-1111-AAA", handle="NoOverlap", interests=["design"])
        self.prime_peer(code="OMAR-2222-BBB", handle="LinuxFriend", interests=["linux"])
        peer = self.engine.match_next()
        self.assertEqual(peer["code"], "OMAR-2222-BBB")

    def test_gathering_room_prioritizes_a_meetup_peer(self):
        ok, _ = self.engine.set_room("Friday Hack Night")
        self.assertTrue(ok)
        self.prime_peer(
            code="OMAR-1111-AAA",
            handle="InterestFriend",
            interests=["linux"],
            room="different-room",
        )
        self.prime_peer(
            code="OMAR-2222-BBB",
            handle="RoomFriend",
            interests=[],
            room="friday hack night",
        )
        peer = self.engine.match_next()
        self.assertEqual(peer["code"], "OMAR-2222-BBB")
        self.assertTrue(peer["same_room"])
        self.assertEqual(peer["common_ground"][0], "Room: Friday Hack Night")
        self.assertIn("Friday Hack Night", peer["icebreaker"])

        payload = self.engine.get_public_payload()
        self.assertEqual(payload["room"], "Friday Hack Night")
        self.assertFalse(self.engine.toggle_privacy("share_room"))
        self.assertNotIn("room", self.engine.get_public_payload())

        ok, _ = self.engine.set_room("room/with/slash")
        self.assertFalse(ok)

    def test_friend_code_validation_and_self_protection(self):
        ok, _ = self.engine.add_friend("not-a-code")
        self.assertFalse(ok)
        ok, _ = self.engine.add_friend(self.engine.state["profile"]["code"])
        self.assertFalse(ok)

        ok, _ = self.engine.add_friend("OMAR-2222-BBB", "OfflineFriend")
        self.assertTrue(ok)
        self.assertEqual(self.engine.get_full_status()["online_count"], 0)
        self.assertIsNone(self.engine.match_next())

    def test_untrusted_presence_is_bounded_and_sanitized(self):
        packet = self.presence_packet(
            handle="x" * 200,
            focus_mins="not-a-number",
            project_url="javascript:alert(1)",
            project_desc="y" * 300,
        )
        self.assertTrue(self.engine.handle_packet(packet))
        peer = self.engine.state["lan_peers"][packet["code"]]
        self.assertLessEqual(len(peer["handle"]), 24)
        self.assertEqual(peer["focus_mins"], 0)
        self.assertEqual(peer["project_url"], "")
        self.assertLessEqual(len(peer["project_desc"]), 80)

    def test_project_beacon_and_privacy_payload(self):
        self.engine.set_project(
            "Local Radar",
            "A real project beacon",
            "https://github.com/example/radar",
        )
        with patch.object(friends_module, "get_active_window", return_value="Neovim"), patch.object(
            friends_module, "get_active_music", return_value="A track"
        ):
            payload = self.engine.get_public_payload()
        self.assertEqual(payload["project_name"], "Local Radar")
        self.assertEqual(payload["activity"], "Neovim")
        self.assertEqual(payload["music"], "A track")

        self.engine.set_interests(["linux", "music"])
        self.assertEqual(payload.get("interests"), [])
        payload = self.engine.get_public_payload()
        self.assertEqual(payload["interests"], ["linux", "music"])

        self.assertFalse(self.engine.toggle_privacy("share_window"))
        self.assertFalse(self.engine.toggle_privacy("share_music"))
        self.assertFalse(self.engine.toggle_privacy("share_project"))
        self.assertFalse(self.engine.toggle_privacy("share_interests"))
        with patch.object(friends_module, "get_active_window", return_value="Neovim"), patch.object(
            friends_module, "get_active_music", return_value="A track"
        ):
            private_payload = self.engine.get_public_payload()
        self.assertEqual(private_payload["activity"], "")
        self.assertEqual(private_payload["music"], "")
        self.assertNotIn("project_name", private_payload)
        self.assertNotIn("interests", private_payload)

    def test_setup_showcase_interests_are_publicly_matchable(self):
        self.engine.set_interests(["plugins", "rice"])
        payload = self.engine.get_public_payload()
        self.assertEqual(payload["interests"], ["plugins", "rice"])

        self.prime_peer(code="OMAR-3333-CCC", interests=["plugins"])
        peer = self.engine.state["lan_peers"]["OMAR-3333-CCC"]
        self.assertIn("🧱 Plugins", self.engine._common_ground(peer))

    def test_interaction_round_trip_creates_real_event(self):
        receiver_dir = tempfile.mkdtemp()
        receiver = friends_module.FriendsEngine(state_dir=receiver_dir)
        try:
            receiver_code = receiver.state["profile"]["code"]
            self.prime_peer(self.engine, receiver_code, "Receiver")
            self.prime_peer(receiver, self.engine.state["profile"]["code"], "Sender")
            self.engine.match_next()
            packets = []
            with patch.object(
                self.engine,
                "_send_udp_packet",
                side_effect=lambda packet: packets.append(packet) or True,
            ):
                ok, message = self.engine.interact(receiver_code, "high-five")
            self.assertTrue(ok, message)
            self.assertEqual(len(packets), 1)
            self.assertEqual(packets[0]["type"], "interaction")

            self.assertTrue(receiver.handle_packet(packets[0]))
            events = receiver.pop_events()
            self.assertEqual(len(events), 1)
            self.assertEqual(events[0]["action"], "high-five")
            self.assertEqual(receiver.state["stats"]["high_fives_received"], 1)
            self.assertFalse(receiver.handle_packet(packets[0]))
        finally:
            shutil.rmtree(receiver_dir, ignore_errors=True)

    def test_hello_carries_a_shared_ground_opener(self):
        receiver_dir = tempfile.mkdtemp()
        receiver = friends_module.FriendsEngine(state_dir=receiver_dir)
        try:
            receiver_code = receiver.state["profile"]["code"]
            sender_code = self.engine.state["profile"]["code"]
            self.engine.set_interests(["linux"])
            self.prime_peer(self.engine, receiver_code, "Receiver", interests=["linux"])
            self.prime_peer(receiver, sender_code, "Sender", interests=["linux"])

            packets = []
            with patch.object(
                self.engine,
                "_send_udp_packet",
                side_effect=lambda packet: packets.append(packet) or True,
            ):
                ok, message = self.engine.interact(receiver_code, "hello")

            self.assertTrue(ok, message)
            self.assertEqual(packets[0]["action"], "hello")
            self.assertIn("ricing", packets[0]["prompt"])
            self.assertTrue(receiver.handle_packet(packets[0]))
            event = receiver.pop_events()[0]
            self.assertEqual(event["action"], "hello")
            self.assertIn("ricing", event["message"])
        finally:
            shutil.rmtree(receiver_dir, ignore_errors=True)

    def test_incoming_signals_are_rate_limited_per_peer(self):
        sender_code = "OMAR-3333-CCC"
        self.prime_peer(code=sender_code, handle="NoisyNeighbor")
        for index in range(friends_module.MAX_INCOMING_SIGNALS_PER_MINUTE):
            packet = {
                "protocol": friends_module.PROTOCOL_VERSION,
                "type": "interaction",
                "event_id": f"signal-{index}",
                "from_code": sender_code,
                "to_code": self.engine.state["profile"]["code"],
                "action": "high-five",
            }
            self.assertTrue(self.engine.handle_packet(packet))

        blocked_packet = {
            "protocol": friends_module.PROTOCOL_VERSION,
            "type": "interaction",
            "event_id": "signal-blocked",
            "from_code": sender_code,
            "to_code": self.engine.state["profile"]["code"],
            "action": "high-five",
        }
        self.assertFalse(self.engine.handle_packet(blocked_packet))
        self.assertEqual(
            self.engine.state["stats"]["high_fives_received"],
            friends_module.MAX_INCOMING_SIGNALS_PER_MINUTE,
        )

    def test_rice_requires_a_real_target(self):
        ok, _ = self.engine.share_rice()
        self.assertFalse(ok)
        self.prime_peer()
        self.engine.match_next()
        with patch.object(self.engine, "_send_udp_packet", return_value=True), patch.object(
            friends_module, "get_current_theme", return_value="Aether"
        ), patch.object(
            friends_module, "get_current_wallpaper", return_value="/tmp/wall.png"
        ):
            ok, message = self.engine.share_rice("OMAR-1111-AAA")
        self.assertTrue(ok, message)
        self.assertEqual(self.engine.state["stats"]["rices_shared"], 1)

    def test_cowork_can_be_solo_or_shared(self):
        ok, message = self.engine.start_cowork(25)
        self.assertTrue(ok, message)
        self.assertEqual(self.engine.get_full_status()["cowork"]["mode"], "solo")
        self.engine.cancel_cowork()

        self.prime_peer()
        self.engine.match_next()
        with patch.object(self.engine, "_send_udp_packet", return_value=True):
            ok, message = self.engine.start_cowork(25, "OMAR-1111-AAA")
        self.assertTrue(ok, message)
        cowork = self.engine.get_full_status()["cowork"]
        self.assertEqual(cowork["mode"], "shared")
        self.assertEqual(cowork["buddy_code"], "OMAR-1111-AAA")

    def test_cowork_invite_is_explicit_and_acceptance_is_local(self):
        receiver_dir = tempfile.mkdtemp()
        receiver = friends_module.FriendsEngine(state_dir=receiver_dir)
        try:
            receiver_code = receiver.state["profile"]["code"]
            self.prime_peer(self.engine, receiver_code, "Receiver")
            self.prime_peer(receiver, self.engine.state["profile"]["code"], "Sender")
            self.engine.match_next()
            packets = []
            with patch.object(
                self.engine,
                "_send_udp_packet",
                side_effect=lambda packet: packets.append(packet) or True,
            ):
                ok, message = self.engine.start_cowork(25, receiver_code)
            self.assertTrue(ok, message)
            self.assertEqual(packets[0]["type"], "cowork")
            self.assertTrue(receiver.handle_packet(packets[0]))
            invites = receiver.get_full_status()["cowork_invites"]
            self.assertEqual(len(invites), 1)
            self.assertTrue(receiver.accept_cowork(invites[0]["id"])[0])
            cowork = receiver.get_full_status()["cowork"]
            self.assertTrue(cowork["active"])
            self.assertEqual(cowork["mode"], "shared")
            self.assertEqual(cowork["buddy_name"], "Sender")
        finally:
            shutil.rmtree(receiver_dir, ignore_errors=True)

    def test_local_pulse_and_cheer(self):
        self.prime_peer()
        self.engine.match_next()
        pulse = self.engine.get_full_status()["world_pulse"]
        self.assertGreaterEqual(len(pulse), 1)
        initial_cheers = pulse[0]["cheers"]
        ok, message = self.engine.cheer_feed_item(pulse[0]["id"])
        self.assertTrue(ok, message)
        self.assertEqual(
            self.engine.get_full_status()["world_pulse"][0]["cheers"],
            initial_cheers + 1,
        )

    def test_legacy_demo_state_is_migrated_out(self):
        state_file = Path(self.test_dir) / "friends_state.json"
        state_file.write_text(
            '{"profile":{"code":"OMAR-0000-000","handle":"Me"},'
            '"friends":[{"code":"OMAR-4192-RST","handle":"Elena"}],'
            '"world_pulse":[{"id":"p-1","user":"Elena"}]}',
            encoding="utf-8",
        )
        engine = friends_module.FriendsEngine(state_dir=self.test_dir)
        self.assertEqual(engine.state["friends"], [])
        self.assertEqual(engine.state["world_pulse"], [])
        self.assertRegex(engine.state["profile"]["code"], r"^OMAR-[A-Z0-9]{4}-[A-Z0-9]{3}$")

    def test_private_dm_round_trip_requires_mutual_friendship(self):
        receiver_dir = tempfile.mkdtemp()
        receiver = friends_module.FriendsEngine(state_dir=receiver_dir)
        try:
            receiver_key = receiver.state["global_identity"]["public_key"]
            sender_key = self.engine.state["global_identity"]["public_key"]
            self.engine.state["global"]["friendships"][receiver_key] = {"status": "friends", "handle": "Receiver"}
            receiver.state["global"]["friendships"][sender_key] = {"status": "friends", "handle": "Sender"}
            events = []
            with patch.object(self.engine, "_publish_global_event", side_effect=lambda event: events.append(event) or (True, {})):
                ok, message = self.engine.send_dm(receiver_key, "hello privately", "https://cdn.example.test/omarchy.png")
            self.assertTrue(ok, message)
            received = receiver._global_dm_from_event(events[0])
            self.assertEqual(received["text"], "hello privately")
            self.assertEqual(received["media"], [{"url": "https://cdn.example.test/omarchy.png", "kind": "image"}])
            receiver.state["global"]["friendships"].pop(sender_key)
            self.assertFalse(receiver._global_dm_from_event(events[0]))
        finally:
            shutil.rmtree(receiver_dir, ignore_errors=True)

    def test_global_friendships_and_messages_survive_state_migration(self):
        state_file = Path(self.test_dir) / "friends_state.json"
        peer_key = friends_module.generate_keypair()["public_key"]
        state_file.write_text(
            json.dumps(
                {
                    "global_identity": self.engine.state["global_identity"],
                    "global": {
                        "friendships": {peer_key: {"status": "friends", "handle": "Saved friend", "avatar": "🦊"}},
                        "messages": [{
                            "id": "a" * 64,
                            "public_key": peer_key,
                            "handle": "Saved friend",
                            "text": "kept after upgrade",
                            "media": [{"url": "https://cdn.example.test/clip.mp4"}],
                            "timestamp": int(time.time()),
                            "incoming": True,
                        }],
                    },
                }
            ),
            encoding="utf-8",
        )
        migrated = friends_module.FriendsEngine(state_dir=self.test_dir)
        self.assertEqual(migrated.state["global"]["friendships"][peer_key]["status"], "friends")
        self.assertEqual(migrated.state["global"]["messages"][0]["media"][0]["kind"], "video")

    def test_duplicate_community_events_are_collapsed_during_migration(self):
        state_file = Path(self.test_dir) / "friends_state.json"
        peer_key = friends_module.generate_keypair()["public_key"]
        duplicate_id = "f" * 64
        base = {
            "id": duplicate_id,
            "public_key": peer_key,
            "handle": "Builder",
            "avatar": "🦊",
            "text": "one event, one bubble",
            "timestamp": int(time.time()),
        }
        state_file.write_text(
            json.dumps({"global_identity": self.engine.state["global_identity"], "global": {"community": [
                {**base, "incoming": True},
                {**base, "incoming": False},
            ]}}),
            encoding="utf-8",
        )
        migrated = friends_module.FriendsEngine(state_dir=self.test_dir)
        community = migrated.state["global"]["community"]
        self.assertEqual(len(community), 1)
        self.assertFalse(community[0]["incoming"])

    def test_conversation_memory_records_waves_and_enriches_peers(self):
        remote_dir = tempfile.mkdtemp()
        remote = friends_module.FriendsEngine(state_dir=remote_dir)
        try:
            with patch.object(friends_module, "get_active_window", return_value="Neovim"):
                peer = self.engine._global_peer_from_event(remote._global_presence_event())
            self.engine.state["global"]["peers"][peer["public_key"]] = peer
            self.engine._touch_memory(peer["public_key"], peer["handle"], peer["avatar"], encounter=True)
            with patch.object(
                self.engine, "_publish_global_event", return_value=(True, {})
            ):
                ok, _ = self.engine.global_ping(peer["public_key"], "hello")
            self.assertTrue(ok)
            memory = self.engine.state["global"]["memory"][peer["public_key"]]
            self.assertEqual(memory["waves_sent"], 1)
            self.assertEqual(memory["encounters"], 1)
            # Incoming wave is remembered without a network round-trip.
            incoming = dict(peer, action="hello", id="b" * 64, timestamp=int(time.time()))
            normalized = self.engine._normalize_global_ping(incoming)
            self.engine._remember_memory_signal(
                peer["public_key"], normalized["action"], "received",
                normalized["handle"], normalized["avatar"],
            )
            self.assertEqual(self.engine.state["global"]["memory"][peer["public_key"]]["waves_received"], 1)
            enriched = self.engine._global_peers()[0]
            self.assertTrue(enriched["memory"]["familiar"])
            self.assertIn("exchange", enriched["memory"]["summary"])
            status = self.engine.get_full_status()
            self.assertIn(peer["public_key"], status["global_memory"])
        finally:
            shutil.rmtree(remote_dir, ignore_errors=True)

    def test_conversation_memory_migrates_and_block_clears_it(self):
        peer_key = friends_module.generate_keypair()["public_key"]
        state_file = Path(self.test_dir) / "friends_state.json"
        state_file.write_text(
            json.dumps({
                "global_identity": self.engine.state["global_identity"],
                "global": {
                    "memory": {peer_key: {
                        "handle": "Old Friend", "avatar": "🦊",
                        "first_seen": 100, "last_seen": 200, "encounters": 3,
                        "waves_sent": 2, "waves_received": 1,
                    }},
                },
            }),
            encoding="utf-8",
        )
        migrated = friends_module.FriendsEngine(state_dir=self.test_dir)
        entry = migrated.state["global"]["memory"][peer_key]
        self.assertEqual(entry["handle"], "Old Friend")
        self.assertEqual(entry["encounters"], 3)
        self.assertEqual(entry["waves_sent"], 2)
        ok, _ = migrated.block_global(peer_key)
        self.assertTrue(ok)
        self.assertNotIn(peer_key, migrated.state["global"].get("memory", {}))

    def test_update_detector_flags_newer_world_version_once(self):
        self.assertEqual(friends_module.parse_plugin_version("4.6.0"), (4, 6, 0))
        self.assertEqual(friends_module.parse_plugin_version("4.6"), (4, 6, 0))
        self.assertIsNone(friends_module.parse_plugin_version("latest"))
        self.assertIsNone(friends_module.parse_plugin_version("4.6.0.1"))
        peer_key = friends_module.generate_keypair()["public_key"]
        self.engine.state["global"]["peers"][peer_key] = {"public_key": peer_key, "plugin_version": "99.0.0", "last_seen": int(time.time())}
        self.assertTrue(self.engine._refresh_update_status())
        status = self.engine.get_full_status()
        self.assertTrue(status["update"]["available"])
        self.assertEqual(status["update"]["latest"], "99.0.0")
        self.assertEqual(status["update"]["current"], friends_module.PLUGIN_VERSION)
        notified = len(self.engine.pop_events())
        self.assertEqual(notified, 1)
        # Same version twice must not spam another popup.
        self.assertTrue(self.engine._refresh_update_status())
        self.assertEqual(len(self.engine.pop_events()), 0)
        # Nobody newer anymore — the banner clears.
        self.engine.state["global"]["peers"] = {}
        self.assertFalse(self.engine._refresh_update_status())
        self.assertFalse(self.engine.get_full_status()["update"]["available"])

    def test_first_dm_raises_invite_nudge_until_dismissed(self):
        receiver_dir = tempfile.mkdtemp()
        receiver = friends_module.FriendsEngine(state_dir=receiver_dir)
        try:
            receiver_key = receiver.state["global_identity"]["public_key"]
            self.engine.state["global"]["friendships"][receiver_key] = {"status": "friends", "handle": "Receiver", "avatar": "🦊"}
            self.assertFalse(self.engine.get_full_status()["invite_nudge"])
            with patch.object(self.engine, "_publish_global_event", return_value=(True, {})):
                ok, _ = self.engine.send_dm(receiver_key, "first hello", "")
            self.assertTrue(ok)
            self.assertTrue(self.engine.get_full_status()["invite_nudge"])
            self.assertTrue(self.engine.dismiss_nudge())
            self.assertFalse(self.engine.get_full_status()["invite_nudge"])
            # A restart keeps the dismissal.
            restarted = friends_module.FriendsEngine(state_dir=self.test_dir)
            self.assertFalse(restarted.get_full_status()["invite_nudge"])
        finally:
            shutil.rmtree(receiver_dir, ignore_errors=True)

    def test_world_event_is_always_a_friday_shape(self):
        event = friends_module.FriendsEngine._world_event()
        self.assertEqual(event["title"], "Ship-It Friday")
        self.assertIsInstance(event["live"], bool)
        self.assertTrue(event["label"])
        self.assertIn("Friday", self.engine.get_full_status()["world_event"]["label"])

    def test_focus_streak_counts_consecutive_days(self):
        peer_key = friends_module.generate_keypair()["public_key"]
        day_one = 100 * 86400 + 3600
        day_two = 101 * 86400 + 3600
        with patch.object(friends_module, "now_seconds", return_value=day_one):
            self.engine._remember_memory_signal(peer_key, "focus_accept", "sent", "Pal", "🦊")
        entry = self.engine.state["global"]["memory"][peer_key]
        self.assertEqual(entry["focus_streak"], 1)
        with patch.object(friends_module, "now_seconds", return_value=day_one + 7200):
            self.engine._remember_memory_signal(peer_key, "focus_accept", "sent", "Pal", "🦊")
        self.assertEqual(self.engine.state["global"]["memory"][peer_key]["focus_streak"], 1)
        with patch.object(friends_module, "now_seconds", return_value=day_two):
            self.engine._remember_memory_signal(peer_key, "focus_accept", "sent", "Pal", "🦊")
        self.assertEqual(self.engine.state["global"]["memory"][peer_key]["focus_streak"], 2)

    def test_blocked_peer_cannot_dm_or_appear_in_circles(self):
        peer_key = friends_module.generate_keypair()["public_key"]
        self.engine.state["global"]["friendships"][peer_key] = {"status": "friends", "handle": "Spammer", "avatar": "🦊"}
        self.engine.state["global"]["messages"].append({"id": "c" * 64, "public_key": peer_key, "handle": "Spammer", "text": "old", "media": [], "timestamp": int(time.time()), "incoming": True})
        ok, _ = self.engine.block_global(peer_key)
        self.assertTrue(ok)
        self.assertNotIn(peer_key, self.engine.state["global"]["friendships"])
        self.assertEqual(self.engine.state["global"]["messages"], [])
        # A late-arriving DM or Circles note from them is dropped silently.
        fake_dm = {"id": "d" * 64, "public_key": peer_key, "handle": "Spammer", "text": "hi", "media": [], "timestamp": int(time.time()), "incoming": True}
        with patch.object(self.engine, "_global_dm_from_event", return_value=fake_dm):
            self.assertFalse(self.engine._ingest_global_dm({"id": "raw"}))
        self.assertEqual(self.engine.state["global"]["messages"], [])
        fake_room = {"id": "e" * 64, "public_key": peer_key, "handle": "Spammer", "avatar": "🦊", "text": "spam", "timestamp": int(time.time()), "incoming": True}
        with patch.object(self.engine, "_global_community_from_event", return_value=fake_room):
            self.assertFalse(self.engine._ingest_global_community({"id": "raw"}))
        self.assertEqual(self.engine.state["global"]["community"], [])

    def test_own_community_post_is_not_duplicated_on_refetch(self):
        published = []
        with patch.object(
            self.engine, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, _ = self.engine.send_community_message("my own note")
        self.assertTrue(ok)
        self.assertEqual(len(self.engine.state["global"]["community"]), 1)
        relay_result = {"published": True, "presence": [], "pings": [], "messages": [], "community": published}
        with patch.object(self.engine, "_global_relay_sync", return_value=relay_result):
            ok, _ = self.engine.sync_global()
        self.assertTrue(ok)
        texts = [item["text"] for item in self.engine.state["global"]["community"]]
        self.assertEqual(texts.count("my own note"), 1)

    def test_automatic_signals_rotate_instead_of_hammering_top_peer(self):
        key_a = friends_module.generate_keypair()["public_key"]
        key_b = friends_module.generate_keypair()["public_key"]
        peers = [{"public_key": key_a, "handle": "A"}, {"public_key": key_b, "handle": "B"}]
        self.engine.state["global"]["sent_pings"] = [{"public_key": key_a, "timestamp": int(time.time())}]
        self.assertEqual(self.engine._least_recently_pinged(peers)["public_key"], key_b)

    def test_dm_and_community_flood_is_rate_limited(self):
        peer_key = friends_module.generate_keypair()["public_key"]
        self.engine.state["global"]["friendships"][peer_key] = {"status": "friends", "handle": "Chatter", "avatar": "🦊"}
        stored = 0
        for index in range(20):
            fake = {"id": f"ab{index:062d}", "public_key": peer_key, "handle": "Chatter",
                    "avatar": "🦊", "text": f"msg {index}", "timestamp": int(time.time()), "incoming": True}
            with patch.object(self.engine, "_global_community_from_event", return_value=fake):
                if self.engine._ingest_global_community({"id": "raw"}):
                    stored += 1
        self.assertLessEqual(stored, 12)
        self.assertLessEqual(len(self.engine.state["global"]["community"]), 12)

    def test_popup_event_ids_keep_full_relay_id(self):
        event = self.engine._append_event("hello", "👋", "Pal", "🦊", "hi", "a" * 64)
        self.assertEqual(event["id"], "a" * 64)
        self.assertEqual(len(self.engine.pop_events()), 1)

    def test_state_survives_concurrent_processes(self):
        other = friends_module.FriendsEngine(state_dir=self.test_dir)
        other.state["profile"]["handle"] = "OtherWriter"
        other.save_state()
        self.engine.state["profile"]["handle"] = "MainWriter"
        self.engine.save_state()
        reloaded = friends_module.FriendsEngine(state_dir=self.test_dir)
        self.assertEqual(reloaded.state["profile"]["handle"], "MainWriter")

    def test_concurrent_state_writes_merge_disjoint_changes_and_messages(self):
        other = friends_module.FriendsEngine(state_dir=self.test_dir)
        key = friends_module.generate_keypair()["public_key"]
        self.engine.state["profile"]["handle"] = "MainWriter"
        self.engine.state["global"]["messages"].append({"id": "message-a", "public_key": key, "text": "A", "timestamp": 100})
        self.engine.save_state()

        other.state["global"]["messages"].append({"id": "message-b", "public_key": key, "text": "B", "timestamp": 200})
        other.save_state()
        reloaded = friends_module.FriendsEngine(state_dir=self.test_dir)
        self.assertEqual(reloaded.state["profile"]["handle"], "MainWriter")
        self.assertEqual(
            {item["id"] for item in reloaded.state["global"]["messages"]},
            {"message-a", "message-b"},
        )
        self.assertEqual(
            [item["id"] for item in reloaded.state["global"]["messages"]],
            ["message-a", "message-b"],
        )

    def test_stale_save_preserves_friendship_added_by_another_process(self):
        other = friends_module.FriendsEngine(state_dir=self.test_dir)
        public_key = friends_module.generate_keypair()["public_key"]
        other.state["global"]["friendships"][public_key] = {"status": "friends", "handle": "Pal", "avatar": "🦊"}
        other.save_state()
        self.engine.state["profile"]["handle"] = "Local edit"
        self.engine.save_state()
        reloaded = friends_module.FriendsEngine(state_dir=self.test_dir)
        self.assertEqual(reloaded.state["global"]["friendships"][public_key]["status"], "friends")
        self.assertEqual(reloaded.state["profile"]["handle"], "Local edit")

    def test_stale_process_cannot_restore_messages_for_newly_blocked_peer(self):
        other = friends_module.FriendsEngine(state_dir=self.test_dir)
        blocked_key = friends_module.generate_keypair()["public_key"]
        self.engine.block_global(blocked_key)
        other.state["global"]["messages"].append({"id": "stale-message", "public_key": blocked_key, "text": "private"})
        other.save_state()
        reloaded = friends_module.FriendsEngine(state_dir=self.test_dir)
        self.assertIn(blocked_key, reloaded.state["global"]["blocked_pubkeys"])
        self.assertFalse(any(item.get("public_key") == blocked_key for item in reloaded.state["global"]["messages"]))

    def test_corrupt_state_is_quarantined_before_defaults_are_written(self):
        state_file = self.engine.state_file
        invalid = '{"profile": '
        state_file.write_text(invalid, encoding="utf-8")
        recovered = friends_module.FriendsEngine(state_dir=self.test_dir)
        quarantined = list(Path(self.test_dir).glob("friends_state.corrupt-*.json"))
        self.assertEqual(len(quarantined), 1)
        self.assertEqual(quarantined[0].read_text(encoding="utf-8"), invalid)
        self.assertTrue(friends_module.is_valid_public_key(recovered.state["global_identity"]["public_key"]))
        self.assertEqual(json.loads(state_file.read_text(encoding="utf-8"))["global_identity"], recovered.state["global_identity"])

    def test_focus_accept_survives_stale_lobby_cache(self):
        ping = {
            "id": "f" * 64, "public_key": friends_module.generate_keypair()["public_key"],
            "handle": "FocusPal", "avatar": "🦊", "action": "focus",
            "session_id": "s" * 32, "minutes": 25, "timestamp": int(time.time()),
        }
        self.engine.state["global"]["pings"] = [dict(ping)]
        with patch.object(self.engine, "_publish_global_event", return_value=(True, {})):
            ok, message = self.engine.global_focus_accept(ping["id"])
        self.assertTrue(ok, message)
        self.assertEqual(self.engine.state["global_focus"]["buddy_name"], "FocusPal")

    def test_conversation_memory_is_bounded(self):
        for _ in range(friends_module.MAX_MEMORY_PEERS + 5):
            key = friends_module.generate_keypair()["public_key"]
            self.engine._touch_memory(key, "Builder", "👾", encounter=True)
        self.assertLessEqual(len(self.engine.state["global"]["memory"]), friends_module.MAX_MEMORY_PEERS)


if __name__ == "__main__":
    unittest.main()
