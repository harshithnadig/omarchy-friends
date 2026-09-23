from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def qml_functions(text):
    return set(re.findall(r"\bfunction\s+([A-Za-z_]\w*)\s*\(", text))


class RuntimeContractTests(unittest.TestCase):
    def test_friends_v3_service_calls_exist(self):
        panel = read("FriendsPanelV3.qml")
        service = read("Service.qml")
        available = qml_functions(service)
        called = set(re.findall(r"\broot\.service\.([A-Za-z_]\w*)\s*\(", panel))
        missing = sorted(called - available)
        self.assertEqual(missing, [], "FriendsPanelV3 calls missing Service methods: " + ", ".join(missing))

    def test_initial_privacy_indicators_match_private_engine_defaults(self):
        service = read("Service.qml")
        engine = read("bin/omarchy-friends")
        defaults = re.search(r"PRIVACY_DEFAULTS\s*=\s*\{([^}]+)\}", engine)
        self.assertIsNotNone(defaults)
        for key in ("share_window", "share_music", "share_lan", "share_project", "share_theme", "share_interests", "share_room", "share_global"):
            expected = re.search(rf'"{key}"\s*:\s*(True|False)', defaults.group(1))
            actual = re.search(rf'{key}\s*:\s*(true|false)', service)
            self.assertIsNotNone(expected, key)
            self.assertIsNotNone(actual, key)
            self.assertEqual(actual.group(1).lower(), expected.group(1).lower(), key)

    def test_build_panel_friends_handoffs_exist(self):
        panel = read("BuildNetworkPanelV3.qml")
        service = read("Service.qml")
        available = qml_functions(service)
        called = set(re.findall(r"\broot\.friendsService\.([A-Za-z_]\w*)\s*\(", panel))
        missing = sorted(called - available)
        self.assertEqual(missing, [], "Build Network calls missing Friends service methods: " + ", ".join(missing))

    def test_build_chat_handoff_is_supported_by_every_friends_fallback(self):
        widget = read("BarWidget.qml")
        self.assertIn("panel = compatibilityPanelLoader.item", widget)
        self.assertIn("panel = fallbackPanelLoader.item", widget)
        self.assertIn("panel.openChatForPublicKey(key)", widget)
        self.assertIn("return panel.openChatForPublicKey(key) === true", widget)
        for path in ("FriendsPanelV3.qml", "FriendsPanelV2.qml", "Panel.qml"):
            self.assertIn("function openChatForPublicKey(publicKey)", read(path), path)
        build = read("BuildNetworkPanelV3.qml")
        self.assertIn("var opened = root.hostWidget.openFriendChat(publicKey)", build)
        self.assertIn('"Friend not found in Chats; check Requests or World"', build)

    def test_build_panel_actions_exist_in_build_service(self):
        panel = read("BuildNetworkPanelV3.qml")
        service = read("BuildNetworkService.qml")
        available = qml_functions(service)
        called = set(re.findall(r"\bbuild\.([A-Za-z_]\w*)\s*\(", panel))
        missing = sorted(called - available)
        self.assertEqual(missing, [], "BuildNetworkPanelV3 calls missing BuildNetworkService methods: " + ", ".join(missing))

    def test_friends_service_cli_commands_exist_in_engine(self):
        service = read("Service.qml")
        engine = read("bin/omarchy-friends")
        commands = set(re.findall(r'\[root\.binPath,\s*"([^"]+)"', service))
        # A few actions construct args over multiple lines but still begin with
        # [root.binPath, "command"], so the same expression covers them.
        missing = sorted(command for command in commands if f'"{command}"' not in engine)
        self.assertEqual(missing, [], "Service.qml references Friends CLI commands absent from the engine: " + ", ".join(missing))

    def test_build_service_commands_exist_in_active_runtime_stack(self):
        service = read("BuildNetworkService.qml")
        runtime = "\n".join(
            read(path)
            for path in (
                "bin/build_network_app_v4.py",
                "bin/build_network_app_v3.py",
                "bin/build_network_app_v2.py",
                "bin/build_network_runtime.py",
            )
        )
        commands = set(re.findall(r'\brun\("([^"]+)"', service))
        missing = sorted(command for command in commands if f'"{command}"' not in runtime)
        self.assertEqual(missing, [], "BuildNetworkService commands absent from active runtime stack: " + ", ".join(missing))

    def test_manifest_entrypoints_point_to_existing_files(self):
        manifest = read("manifest.json")
        for entry in ("ServiceModern.qml", "BarWidget.qml"):
            self.assertIn(f'"{entry}"', manifest)
            self.assertTrue((ROOT / entry).is_file(), entry)


if __name__ == "__main__":
    unittest.main()
