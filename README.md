# Omarchy Friends 👥

**Peer-to-peer developer presence, live activity, LAN discovery, and tactile buddy network for Omarchy.**

See what your developer friends are coding and listening to, celebrate shipped milestones, exchange high-fives and coffee breaks, discover nearby hackers on your local network, and feel the ambient pulse of the hacker community — right from your Hyprland bar.

---

## Highlights

* **👾 Native Developer Presence:** Automatically detects your active editor or workspace (`Neovim`, `Zed`, `VS Code`, `Terminal`, `Blender`, `Obsidian`) via Hyprland IPC, plus current music track via MPRIS DBus.
* **👥 Friends & Buddies List:** Connect with friends via shareable, memorable Friend Codes (e.g. `OMAR-7842-X9K`). See live status dots, current activity, and focus streak timers.
* **📡 Zero-Config LAN & Tailscale Discovery:** Automatically discovers coworkers and friends on the same WiFi, office LAN, or Tailscale mesh via UDP broadcast (port `42424`). No external server required.
* **✋ Tactile Joy & Micro-Interactions:** Send 1-click High-Fives, Coffee Break cheers, and Kudos sparks. Triggers hardware-accelerated bar pulse animations and friendly desktop notifications.
* **🌙 Ambient Companions:** When coding late at night or before your friends install the plugin, toggle realistic global companion developers so you're never hacking alone.
* **🔒 Privacy First & Abuse-Proof:** Zero freeform text entry (no harassment or spam), zero telemetry servers, and granular per-feature privacy toggles for window and music broadcasting.

---

## Bar Widget & Controls

* **Bar Pill:** Displays `👥 <online_count>` with dynamic state indicators.
* **Left-Click:** Opens the Friends Deck & Activity Card.
* **Right-Click:** Quick-cycles your focus status (`🚀 In The Zone` → `☕ Coffee Break` → `🎧 Vibe Coding` → `🐛 Debugging` → `🌙 Late Night` → `🛠️ Ricing`).
* **Middle-Click:** Instant 1-click copy of your Friend Code to clipboard.
* **Incoming High-Five:** Triggers an animated double-bounce swell on your bar icon with an accompanying desktop chime.

---

## Deck Layout

```text
┌─────────────────────────────────────────────────────────┐
│ 👾 OmarchyHacker               [ 🚀 In The Zone ]       │
│    OMAR-F022-42B  [📋 Copy]                             │
│    💻 Neovim (Rust) • 🎧 Tycho - Awake • 🔥 54m focus   │
│    [ 🚀 In Flow ] [ ☕ Coffee ] [ 🎧 Vibe ] [ 🐛 Debug ] │
├─────────────────────────────────────────────────────────┤
│ [👥 Friends (3)]  [📡 LAN (0)]  [➕ Add]  [⚙️ Settings] │
├─────────────────────────────────────────────────────────┤
│ 🦊 Elena • Zurich                     [ ✋ ] [ ☕ ] [ ⚡ ]│
│    Neovim (Rust) • 🎧 Tycho - Awake                     │
│                                                         │
│ 🤖 Kaito • Tokyo                      [ ✋ ] [ ☕ ] [ ⚡ ]│
│    Zed (main.go) • 🎧 Nujabes - Feather                 │
│                                                         │
│ ☕ Marco • Milan                       [ ✋ ] [ ☕ ] [ ⚡ ]│
│    Espresso Bar • 12m break                             │
└─────────────────────────────────────────────────────────┘
```

---

## Installation

```bash
omarchy plugin add https://github.com/harshithnadig/omarchy-friends.git --enable
```

Add to your bar configuration in `~/.config/omarchy/shell.json`:

```json
{
  "right": [
    { "id": "community.omarchy-friends" }
  ]
}
```

---

## Testing & Verification

Run the automated test suite:

```bash
python3 -m unittest tests/test_friends.py
```

Inspect the CLI engine:

```bash
./bin/omarchy-friends status
```

---

## License

MIT License — Omarchy Community Contributors.
