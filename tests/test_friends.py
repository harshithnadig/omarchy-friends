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
            self.engine.sync_global()
            self.assertEqual(len(self.engine.pop_events()), 0)
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


if __name__ == "__main__":
    unittest.main()
