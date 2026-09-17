# ✈️ Paper Plane Skyway for Omarchy

**Someone is coding under the same sky.** Fold origami paper planes, catch Earth's real-time atmospheric wind currents, and share quiet serendipity across Linux desktops worldwide.

---

## 🌟 The Concept: The Global Jetstream Skyway

In a world of noisy social media feeds and toxic chat rooms, **Paper Plane Skyway** returns computing to poetic, tactile wonder:

```text
       _                                 
     -=\`\                               
        \ \               🍃 210 km/h Westerly Jetstream
      / /`        - - - ✈️  [🇯🇵 Tokyo ➔ Stockholm]
     / /                                 
    / /`_                                
   / /_//`                               
  / /'--'                                
 `-`                                     
```

- **Fold & Launch:** Choose your origami fold (*Classic Dart*, *Concorde Delta*, *Origami Crane*, *Stratocaster*) and emboss it with your current Travel Seal:
  - 🌿 **Deep Focus** — quiet work in the clouds
  - ☕ **Coffee Break** — warm brew at cruising altitude
  - 🎧 **In the Flow** — headphones on, drifting through the wind
  - 🌙 **Midnight Code** — stargazing over the dark side of the globe
  - ⚡ **Shipping Fast** — supersonic delivery to production
  - 🛠️ **Tinkering** — refining dotfiles and workflows
- **Atmospheric Jetstream Physics:** When launched, your plane catches the real-time 250hPa atmospheric jet stream vectors (calculated from seasonal solar and latitude models), drifting thousands of kilometers across great-circle routes (Tokyo ➔ Amsterdam, Berlin ➔ Seattle, Stockholm ➔ Toronto).
- **On-Screen Screen Flyby:** When a plane lands in your airspace, an origami plane with a dashed jetstream trail quietly glides across the top of your screen on a smooth, hardware-accelerated Wayland layer shell curve. It is **100% click-through** (`mask: Region {}`), ensuring zero interruption to your terminal, editor, or workflow.
- **Passport Stamps & Logbook:** Collect authentic country stamps from every land whose plane crossed into your airspace.

---

## 🚀 Quick Install

Run in an Omarchy Quattro terminal:

```bash
omarchy plugin add https://github.com/harshithnadig/omarchy-friends.git --enable
omarchy bar put community.omarchy-friends --section right
```

Click the plane `✈️` in your bar to open your Flight Deck, fold your plane, and launch into the wind!

### Shortcuts
- **Left-Click:** Open or close the Flight Deck.
- **Middle-Click:** Quick-launch using your active fold and seal without opening the card.

---

## 🛡️ Privacy & Zero-Abuse Guarantee

1. **Zero Text, Zero Abuse:** There is no text field, no chat room, and no message input. It is mathematically impossible to send harassment, hate speech, or spam.
2. **Zero Accounts, Zero Logins:** No emails, passwords, usernames, or telemetry.
3. **Anonymous Local Hangar ID:** Each user receives a locally minted flight token (e.g. `AERO-8F42`) stored in `~/.local/state/omarchy-friends/hangar_id` with `0600` permissions.
4. **10-Minute Cooldown:** Launches are limited to 1 every 10 minutes to preserve intentionality and eliminate notification fatigue.
5. **Standard User Permissions:** Runs within the Quickshell user boundary. No root privileges, no daemons, and zero downloaded binaries.

---

## ⌨️ CLI Flight Operations

Interact with the jetstream directly from terminal or keybindings:

```bash
# View flight deck status, jetstream vector, and recent arrivals
./bin/omarchy-friends status

# Change your fold or travel seal
./bin/omarchy-friends fold concorde
./bin/omarchy-friends seal midnight

# Launch into the jetstream
./bin/omarchy-friends launch concorde midnight

# Copy airmail invitation to clipboard
./bin/omarchy-friends invite
```

---

## 🗑️ Removal

```bash
omarchy plugin disable community.omarchy-friends
omarchy plugin remove community.omarchy-friends
```

To clear local hangar history and reset your flight token:
```bash
rm -rf ~/.local/state/omarchy-friends
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
Copyright (c) 2026 Paper Plane Project Contributors.
