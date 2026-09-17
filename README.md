# 🔥 Omarchy Friends

**Someone is coding under the same sky.** Ambient peer presence, anonymous vibe sharing, and desktop sparks across the Omarchy universe.

---

## 🌟 The Concept: The Digital Campfire

Omarchy is an intimate, beautiful Linux desktop. But late at night or during deep hacking sprints, it can feel solitary.

**Omarchy Friends** puts an ambient campfire in your top bar. It lets you feel the quiet, warm presence of fellow developers, designers, and Linux enthusiasts worldwide:

- **Ambient Presence:** Glance at your bar to see how many fellow wanderers are around the fire right now (`🔥 42`).
- **Choose Your Vibe:** Set your current atmosphere with one click:
  - 🌿 **Deep Focus** — heads-down deep work
  - ☕ **Coffee & Tea** — sipping a warm cup
  - 🎧 **In the Flow** — headphones on, world tuned out
  - 🌙 **Midnight Code** — hacking into the quiet hours
  - ⚡ **Shipping Fast** — pushing to production
  - 🛠️ **Tinkering** — refining dotfiles and workflows
- **Toss a Spark to the Campfire:** Click once to toss an anonymous spark into the night. Somewhere across the globe, a fellow Omarchy friend's bar glows softly:
  ```text
  🇯🇵 Someone in Japan raised a warm mug ☕ to you!
  ```
- **Constellation of Encounters:** Keep a private, local record of the peers you've crossed orbits with. Over weeks and months, your card fills with stars representing the fellow souls who shared a spark with you.

---

## 🚀 Quick Install

Run in any Omarchy Quattro terminal:

```bash
omarchy plugin add https://github.com/harshithnadig/omarchy-friends.git --enable
omarchy bar put community.omarchy-friends --section right
```

Click the flame `🔥` in your bar to open the campfire card, select your vibe, and toss your first spark!

### Middle-Click Shortcut
- **Left-Click:** Open or close the Campfire card.
- **Middle-Click:** Quick-toss a spark using your active vibe without opening the popup.

---

## 🛡️ Privacy & Security Manifesto

We believe human connection should never require surveillance, personal accounts, or data hoarding.

1. **Zero Accounts, Zero Logins:** No emails, passwords, usernames, or avatars.
2. **Anonymous Local Token:** Your identity is an ephemeral 32-character random hex token minted locally on first launch and stored in `~/.local/state/omarchy-friends/peer_id` (with `0600` permissions). Delete that file, and you become an entirely new stranger.
3. **No Exact Geolocation:** Signals carry only a coarse country flag (or "The Cosmos" if you prefer total anonymity). Never coordinates, IP addresses, cities, or hardware serials.
4. **10-Minute Thoughtful Cooldown:** Sparks are rate-limited to 1 every 10 minutes. This prevents spam, eliminates notification fatigue, and makes each spark meaningful.
5. **Zero Malicious Attack Surface:** The plugin uses user permissions inside the standard Quickshell runtime. No root access, no daemons, no background tracking, no remote code execution.

---

## ⌨️ CLI Interface

You can also interact with your campfire directly from your terminal or Hyprland keybindings:

```bash
# View campfire status and recent encounters in JSON
./bin/omarchy-friends status

# Switch your active vibe
./bin/omarchy-friends vibe coffee
./bin/omarchy-friends vibe midnight

# Toss a spark to the campfire
./bin/omarchy-friends spark

# Copy invitation to clipboard
./bin/omarchy-friends invite
```

---

## 🗑️ Removal

To disable or completely remove the plugin:

```bash
omarchy plugin disable community.omarchy-friends
omarchy plugin remove community.omarchy-friends
```

To clear your local encounter constellation and reset your token:
```bash
rm -rf ~/.local/state/omarchy-friends
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
Copyright (c) 2026 Omarchy Friends Contributors.
