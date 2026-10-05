# Omarchy Friends v4.18.2 security hotfix candidate

- Private message text, message edits, group payloads, and message searches now
  travel from the UI process to the Friends CLI through stdin instead of
  appearing in `/proc/<pid>/cmdline`. The stdin payload is bounded to 256 KiB;
  legacy CLI argument forms remain available for existing integrations.
- Authenticated non-creators cannot replace a group's metadata. Existing group
  membership cannot change silently, including when an update comes from the
  creator; a recipient consent flow is required before such changes can be
  supported.
- Existing chat history and saved conversation state are not migrated or
  deleted by these changes.

The source release gate passes. Live desktop interaction, public relay
interoperability, installation, and Marketplace publication remain pending.
