# Omarchy Friends v4.15.1

## Hotfix

- Chat header `Close` now only closes the selected conversation.
- World safety uses the explicit `Block` label for destructive blocking.
- Added blocked people recovery under Me / Privacy with `Unblock`.
- Added the `unblock-global <pubkey>` CLI action.
- Unblocking preserves all unrelated friendship, message, and profile state.
- Restored old v4.15 blocked profiles by removing only the accidentally blocked key from local state.

This hotfix does not reconstruct local messages that the previous destructive Hide action already deleted.
