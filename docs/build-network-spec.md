# Omarchy Friends — Build Network feature slice

This branch introduces a focused collaboration layer on top of the existing Friends social system.

## Product goals

1. **Build Rooms** — turn a private group into a lightweight Omarchy project room with a title, goal, roles needed, repository URL, and task list.
2. **Ideas → Build** — let users publish a compact idea card and convert it into a Build Room when collaborators join.
3. **Setup Cards** — let users publish an opt-in snapshot of the visible, non-secret parts of an Omarchy setup (theme, plugins, shell, terminal, editor, wallpaper URL, notes).
4. **Test Network** — let plugin/theme authors ask for testers by hardware or environment tags and collect simple pass / issue reports.

## Guardrails

- Reuse Friends identities, relays, block/report controls, and group membership.
- No automatic config installation or arbitrary shell execution.
- Setup sharing is metadata-first and opt-in; never include secrets, tokens, private files, or unreviewed command output.
- Build and test actions should remain useful even with a small network.
- GitHub remains the code source of truth; Friends is the human coordination layer.

## Suggested UX

The existing Circles area gains a **Build** mode rather than adding a completely separate app. It contains four compact sections: Ideas, Build Rooms, Setups, and Testing. Existing Chats / World / Circles / Me behavior remains intact.

This first implementation is intended for real-system testing before protocol stabilization.