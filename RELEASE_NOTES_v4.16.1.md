# Omarchy Friends v4.16.1

This hotfix makes every Friends label render as plain text. Messages, profile
fields, previews, and other peer-provided content can no longer trigger Qt's
automatic rich-text handling or load remote inline images while being viewed.
Editable text areas also use plain-text mode. The hotfix includes an explicit
release-gate regression check for these rendering contracts.

The release does not change chat storage or migrate, clear, or rewrite saved
conversations.
