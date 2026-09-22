from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ModernFriendsUiContractTests(unittest.TestCase):
    def read(self, path: str) -> str:
        return (ROOT / path).read_text(encoding="utf-8")

    def test_modern_shell_is_primary_with_legacy_fallback(self):
        bar = self.read("BarWidget.qml")
        self.assertIn('FriendsPanelV2.qml', bar)
        self.assertIn('Panel.qml', bar)
        self.assertIn('modernPanelLoader.status === Loader.Error', bar)
        self.assertIn('function openBuildTab', bar)
        self.assertIn('BuildNetworkPanelV3.qml', bar)

    def test_modern_shell_has_first_class_product_navigation(self):
        panel = self.read("FriendsPanelV2.qml")
        for label in ("Chats", "World", "Circles", "Build", "Me"):
            self.assertIn(f'text: "{label}"', panel)
        for shortcut in ("Create build", "Share setup", "Ask for help", "Find people"):
            self.assertIn(f'text: "{shortcut}"', panel)
        self.assertIn('root.openBuild("discover")', panel)
        self.assertIn('root.openBuild("create")', panel)
        self.assertIn('root.openBuild("share")', panel)
        self.assertIn('root.openBuild("help")', panel)

    def test_modern_shell_owns_stable_midnight_palette(self):
        panel = self.read("FriendsPanelV2.qml")
        expected = {
            'canvas': '#070b14',
            'ink': '#f3f5ff',
            'violet': '#7c6cff',
            'cyan': '#58d6ff',
        }
        for name, value in expected.items():
            self.assertIn(f'property color {name}: "{value}"', panel)
        self.assertNotIn('readonly property color canvas: Color.background', panel)

    def test_build_network_uses_same_product_palette(self):
        panel = self.read("BuildNetworkPanelV3.qml")
        self.assertIn('readonly property color fg: "#f3f5ff"', panel)
        self.assertIn('readonly property color bg: "#070b14"', panel)
        self.assertIn('readonly property color accent: "#7c6cff"', panel)

    def test_update_path_is_visible_and_explicit(self):
        panel = self.read("FriendsPanelV2.qml")
        service = self.read("Service.qml")
        self.assertIn('visible: root.updateInfo.available', panel)
        self.assertIn('text: "Update now"', panel)
        self.assertIn('root.service.updatePlugin()', panel)
        self.assertIn('omarchy', service)
        self.assertIn('rescanPlugins', service)
        # v4.15 deliberately uses explicit user action rather than silent background updates.
        self.assertNotIn('Component.onCompleted: root.service.updatePlugin()', panel)

    def test_shared_glass_primitives_exist(self):
        for path in (
            "GlassSurface.qml", "GlassPill.qml", "GlassButton.qml",
            "GlassField.qml", "GlassNavItem.qml", "GlassAvatar.qml",
        ):
            self.assertTrue((ROOT / path).is_file(), path)


if __name__ == "__main__":
    unittest.main()
