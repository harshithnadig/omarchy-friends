# Omarchy Friends v4.15 UI contract

This document freezes the visual and information-architecture direction for the v4.15 release candidate.

## Product feeling

Friends should feel like a native futuristic desktop product rather than a theme-colored utility panel: quiet midnight glass, crisp cool-white typography, violet/blue energy, generous negative space, and strong information hierarchy.

Reference mood: modern macOS / visionOS restraint + Arc-like product chrome, adapted to Omarchy rather than copied literally.

The product should behave like a real messaging/community app, not expose transport concepts or dump every possible action into every card.

## Palette

Friends owns a stable product palette across Omarchy themes:

- canvas: `#070b14`
- primary glass: `#0a0f1d`
- elevated glass: `#11192d`
- primary text: `#f3f5ff`
- secondary text: `#98a2ba`
- faint text: `#68738d`
- violet: `#7c6cff`
- blue: `#5b8cff`
- cyan: `#58d6ff`
- success: `#34d399`
- warning: `#fbbf24`
- danger: `#fb7185`

The active Omarchy theme may affect the surrounding desktop, but it should not turn Friends burgundy, gold, green, etc.

## Container model

Do not wrap every line in a card. Use a small number of strong glass regions:

1. product shell / background;
2. sidebar or segmented navigation;
3. content workspace;
4. contextual cards only for actual entities such as a conversation, builder, setup, build room or help request.

Nested card-on-card-on-card layouts are discouraged.

## Reusable primitives

Use these before inventing one-off rectangles:

- `GlassSurface.qml`
- `GlassPill.qml`
- `GlassButton.qml`
- `GlassField.qml`
- `GlassNavItem.qml`
- `GlassAvatar.qml`

All interactive controls need hover/pressed/selected/disabled treatment. Primary actions use violet; destructive or warning states use semantic colors.

## Friends shell

`FriendsPanelV3.qml` is the preferred shell. `FriendsPanelV2.qml` is the compatibility fallback. `Panel.qml` remains the final safety fallback if both modern shells cannot load.

Top-level navigation:

- Chats
- Requests
- World
- Circles
- Build
- Me

Build must be visible; middle-click remains a shortcut, not the only discovery route.

### Chats

Desktop-style split layout:

- conversation rail containing only opened/history conversations;
- active private/group conversation;
- modern message bubbles;
- one primary message composer;
- optional HTTPS link field revealed on demand;
- visible Focus / Build-together actions in the selected conversation header.

**Do not put incoming requests or every friend into the conversation rail.** A person with no opened conversation belongs in the New chat picker until the user chooses them.

The full friends list lives behind **New chat**. Private-group creation belongs there too.

### Requests

Connection management is separate from messaging:

- Received requests;
- Sent/pending requests;
- incoming request badge;
- Accept on received requests;
- no request cards mixed into Chats.

### World

World is for discovering real Omarchy people and useful context, not a grid of repeated micro-actions.

Show:

- builder identity/status;
- project/activity;
- common ground where available;
- search;
- `All / New / Building / Friends` filters;
- one clear relationship action per person: Connect / Accept / Requested / Needs update / Message;
- relay health and truthful online counts.

Do **not** repeat Wave / Focus / Build buttons on every person card. Focus and Build-together are contextual actions after a conversation exists.

### Circles

Circles is one coherent public room:

- compact room identity/header;
- concise public-information warning;
- readable avatar/name/message stream;
- normal chat bubbles/grouping rather than giant dashboard cards;
- sticky bottom composer;
- truthful quiet/empty state.

Avoid generic social-media engagement chrome.

### Me

Me is a clean profile/settings workspace, separated into:

- profile hero + Copy Invite;
- **About you**: handle/project fields;
- **Presence**: avatar, status and interests;
- **Privacy**: explicit public-beacon sharing controls;
- compact update/version status.

The user must be able to control World visibility, active-app sharing, music, project, interests and room sharing without hunting through another screen.

## Build Network

`BuildNetworkPanelV3.qml` uses the same midnight/violet primitives. It should feel like another workspace in Friends, not another plugin.

Six tabs remain:

- Discover
- Build
- Share
- Help
- Community
- Create

Do not reopen V1/V2 Build Network panel designs.

## Update UX

Keeping people current is part of compatibility, not decoration.

- update availability is persistent and visually prominent;
- the current version is visible in the shell;
- one click calls the existing safe plugin update path, rescans plugins and restarts background workers;
- older peers can be shown as needing an update;
- do not silently auto-update in the background for v4.15: explicit user action is safer for a community plugin and avoids bricking installs on a bad upstream release.

## Motion

Use short 90–220 ms scale/color transitions. Motion should confirm hover, press, selection or incoming activity. No looping decorative animation.

## Release rule

A future agent may make a small compatibility fix after real Omarchy testing, but should not collapse Requests back into Chats, repopulate Chats with every friend, restore repeated World action buttons, replace the room-style Circles layout, remove explicit privacy controls, replace the design language with active-theme colors, or hide Build navigation without an explicit new design decision.
