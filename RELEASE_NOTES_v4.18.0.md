# Omarchy Friends v4.18.0 candidate

- Adds direct-chat typing indicators for compatible Friends users who are
  already friends. Groups and older clients are not included.
- Typing state is end-to-end encrypted in an ephemeral NIP-59 gift wrap, is
  rate-limited and replay-filtered, expires quickly, and is kept only in a
  private volatile runtime cache. It is not stored in chat history or
  notifications.
- Typing sharing is enabled by default for new profiles and can be switched off
  in **Me → Privacy**. Existing saved privacy choices are preserved.
- New profiles are discoverable in World by default. Existing users who saved
  the hidden setting stay hidden until they choose to become visible.
- This candidate leaves encrypted chat state, chat history, and message
  journals unchanged.

NIP-59 kind 21059 is specified for ephemeral gift wraps that relays must not
store. Relays can still see the recipient public key and event timing while
routing typing signals. Live relay interoperability and a two-user typing
exchange still need verification before release.
