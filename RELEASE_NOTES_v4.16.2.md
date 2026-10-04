# Omarchy Friends v4.16.2

- Correct World status: the UI distinguishes relay checks, stale or failed
  connections, and an empty directory with healthy relays.
- Only a recent relay-confirmed presence publish can mark your profile online;
  sending an event through the background listener alone is not treated as
  confirmation.
- Explain World discovery and visibility accurately. Only other Omarchy Friends
  users with fresh, opted-in presence appear; enabling your own visibility is
  not required to discover them.
- Simplify shared surfaces and controls with solid fills, restrained borders,
  and readable sans-serif labels across Friends and Build Network.
- Preserve existing chat storage and privacy defaults.
- Keep saved chats discoverable from the durable local conversation index even
  when their messages are older than the status summary page.
- Open file and folder choosers after releasing Friends' full-screen overlay,
  then return to the same chat after selection or cancellation.

Validation: release gate, 326 tests, and `qmllint` against installed Omarchy
shell imports passed. Rendered UI and live relay behavior still require a real
desktop check.
