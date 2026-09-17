### Plugin Submission: Omarchy Friends

**Plugin ID:** `community.omarchy-friends`  
**Repository:** `https://github.com/harshithnadig/omarchy-friends`  
**Kinds:** `service`, `bar-widget`  
**License:** `MIT`  

#### Description
Omarchy Friends brings native developer presence, live workspace activity, LAN peer discovery, and tactile buddy interactions to Omarchy Linux.

#### Key Capabilities
1. **Developer Presence:** Automatic active editor detection (`Neovim`, `Zed`, `VS Code`, `Terminal`, `Obsidian`) via Hyprland IPC and current audio track via MPRIS DBus.
2. **Friends & Buddies:** Shareable Friend Codes (`OMAR-XXXX-XXX`), online activity indicators, and focus streak tracking.
3. **LAN Auto-Discovery:** Peer-to-peer discovery across local WiFi, office networks, and Tailscale mesh via lightweight UDP broadcast on port 42424.
4. **Tactile Micro-Interactions:** 1-click High-Fives, Coffee Break cheers, and Kudos sparks with hardware-accelerated bar bounce animations.
5. **Privacy by Design:** Zero external telemetry servers, zero freeform chat, and granular toggles for window and music sharing.

#### Verification
- Passes `omarchy plugin validate` (SchemaVersion 1 compliant).
- Comprehensive unit test suite (`tests/test_friends.py`) passing.
