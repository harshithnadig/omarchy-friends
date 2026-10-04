# Omarchy Friends v4.17.0

- New profiles are discoverable in World by default while the plugin is online.
  Their stable pseudonymous public key, generated handle, avatar, status and
  inbox-relay list are published to configured public relays.
- Existing saved visibility choices are preserved during upgrade. Users can
  hide their profile at any time in Me → Privacy; private chat contents are
  never included in World presence.
- Detail sharing (active app, music, projects, interests, room and read
  receipts) remains independently controlled and off by default.
- The World empty state now distinguishes hidden profiles from profiles that
  are visible but have no other online users to show.

World entries are temporary presence, not permanent accounts: someone appears
only while Friends is active and relays have fresh presence. Public relays or
recipients may retain published data after visibility is turned off.
