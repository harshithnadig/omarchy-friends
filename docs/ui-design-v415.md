# Omarchy Friends v4.15 UI contract

This document freezes the visual direction for the v4.15 release candidate.

## Product feeling

Friends should feel like a native futuristic desktop product rather than a theme-colored utility panel: quiet midnight glass, crisp cool-white typography, violet/blue energy, generous negative space, and strong information hierarchy.

Reference mood: modern macOS / visionOS restraint + Arc-like product chrome, adapted to Omarchy rather than copied literally.

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

`FriendsPanelV2.qml` is the preferred shell. `Panel.qml` remains only as a fallback if the modern shell cannot load.

Top-level navigation:

- Chats
- World
- Circles
- Build
- Me

Build must be visible; middle-click remains a shortcut, not the only discovery route.

### Chats

Desktop-style split layout:

- conversation rail;
- active private/group conversation;
- modern message bubbles;
- clear composer;
- visible Focus / Build-together actions.

### World

Show live people rather than a generic feed:

- builder identity/status;
- project/activity;
- friend/add state;
- Wave / Focus / Build actions;
- relay health and useful aggregate context.

### Circles

Simple public room with readable message grouping and a clear public-information warning. Avoid unnecessary social-media engagement chrome.

### Me

Profile beacon, interests/status, invite sharing, current/update state and direct access to Build Network.

## Build Network

`BuildNetworkPanelV3.qml` uses the same midnight/violet primitives. It should feel like another workspace in Friends, not another plugin.

Six tabs remain:

- Discover
- Build
- Share
- Help
- Community
- Create

Do not reopen V1/V2 panel designs.

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

A future agent may make a small compatibility fix after real Omarchy testing, but should not replace this design language with active-theme colors, giant monochrome forms, dense stacked rectangles or hidden Build navigation without an explicit new design decision.
