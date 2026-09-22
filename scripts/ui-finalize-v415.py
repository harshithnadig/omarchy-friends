#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}: {old!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "FriendsPanelV2.qml",
    '''            Row {\n                width: parent.width\n                height: Style.space(34)\n                leftPadding: Style.space(18)\n                rightPadding: Style.space(18)\n                spacing: Style.space(10)''',
    '''            Row {\n                width: parent.width - Style.space(36)\n                x: Style.space(18)\n                height: Style.space(34)\n                spacing: Style.space(10)''',
)

replace_once(
    "FriendsPanelV2.qml",
    '''                                                    text: typeof modelData === "string" ? modelData : (modelData.label || modelData.id || "Interest")''',
    '''                                                    text: typeof modelData === "string" ? modelData : ((modelData.emoji ? modelData.emoji + " " : "") + (modelData.name || modelData.label || modelData.id || "Interest"))''',
)

replace_once(
    "BuildNetworkPanelV3.qml",
    '''    readonly property color fg: Color.foreground\n    readonly property color bg: Color.background\n    readonly property color accent: Color.accent\n    readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.60)\n    readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.38)\n    readonly property color glassLine: Qt.rgba(fg.r, fg.g, fg.b, 0.10)''',
    '''    // Friends owns a stable cool product palette instead of inheriting every\n    // Omarchy theme hue. This keeps Build Network visually consistent with\n    // FriendsPanelV2 even on red/gold/green desktop themes.\n    readonly property color fg: "#f3f5ff"\n    readonly property color bg: "#070b14"\n    readonly property color accent: "#7c6cff"\n    readonly property color muted: "#98a2ba"\n    readonly property color faint: "#68738d"\n    readonly property color glassLine: Qt.rgba(0.84, 0.87, 1.0, 0.10)''',
)

replace_once(
    "CODEX_REAL_SYSTEM_TEST.md",
    '''qmllint -I "$OMARCHY_PATH/shell" \\\n  BarWidget.qml Panel.qml Service.qml \\\n  BuildNetworkPanelV3.qml BuildNetworkService.qml \\\n  GlassSurface.qml GlassPill.qml''',
    '''qmllint -I "$OMARCHY_PATH/shell" \\\n  BarWidget.qml FriendsPanelV2.qml Panel.qml Service.qml \\\n  BuildNetworkPanelV3.qml BuildNetworkService.qml \\\n  GlassSurface.qml GlassPill.qml GlassButton.qml GlassField.qml \\\n  GlassNavItem.qml GlassAvatar.qml''',
)

replace_once(
    "CODEX_REAL_SYSTEM_TEST.md",
    '''Verify the normal Friends widget first:\n\n- left-click opens Friends;''',
    '''Verify the normal Friends widget first:\n\n- left-click opens the **modern `FriendsPanelV2.qml` shell**, not the legacy fallback;\n- the shell uses the midnight/violet product palette even when the desktop theme is red/gold/green;\n- Chats uses the split conversation layout, message bubbles and modern composer;\n- World, Circles and Me use the same shared glass primitives;\n- left-click opens Friends;''',
)

replace_once(
    "FINAL_RELEASE_STATUS.md",
    '''- Liquid-glass V3 panel: implemented.''',
    '''- Unified liquid-glass UI: `FriendsPanelV2.qml` is the preferred Friends shell and `BuildNetworkPanelV3.qml` is the matching Build workspace; the old `Panel.qml` remains only as automatic load-failure fallback.''',
)

print("v4.15 UI finalizer applied")
