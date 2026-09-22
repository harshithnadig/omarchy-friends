# Omarchy Friends 👥

**Omarchy World: find real people who are building on Omarchy right now.**

Friends is a small human layer in the bar. A fresh install creates a memorable
pseudonymous identity, appears in the Friends tab while it is running, and can
receive a friendly wave without anyone having to copy a code. The experience
is global and federated, with the original LAN radar and co-work tools still
available when people are nearby.

New here? Read **[How to use Friends](docs/howto.md)** — the 60-second tour,
or press **?** inside the deck.

## The experience

* **🌍 Omarchy World:** See recently active, real plugin installations across
  the internet. Presence expires after 150 seconds, so the list is a live
  lobby, not a fake social feed.
* **✦ Showcase:** Browse the projects, plugins, and custom-rice setup beacons
  that builders choose to share, then say hello when something catches your
  eye. Add your own from Profile so your setup can become someone else’s
  starting point.
* **👋 One-click connection:** Wave, offer coffee, or send kudos from any
  world profile. Incoming waves appear in the deck and as a desktop
  notification. No Friend Code is required.
* **🤝 Chat invites:** Invite a builder from World, accept chat invites
  explicitly, and keep accepted people in the Friends tab. The action is named
  **Invite to chat** so it is clear that accepting unlocks messaging.
  You can also open Profile, copy your personal `omarchy-friends://invite/...`
  link, and send it anywhere. The recipient pastes it into **Connect** to send
  a request even when you are not currently visible in their World list.
* **💬 Community room:** Post short public messages in the Community tab so
  builders can meet in one shared room before becoming private friends. Public
  room messages are signed and relay-readable; never share private information.
* **🔒 Private DMs:** Accepted friends can send short encrypted one-to-one
  messages from the dedicated Messages tab. Messages are stored locally after
  delivery; relays carry only signed ciphertext. Paste an image, video, audio,
  or file URL to share media without uploading a file to a third party.
  Requests, blocks, and visibility remain under the recipient's control.
* **✨ World Spark:** Get a daily bounded opener and send it to the best live
  match, so meeting someone starts with an actual question instead of a
  blank chat box.
* **🍅 Focus ritual:** Invite a real builder to pair for 25 minutes. The
  invite expires, the other person explicitly joins, and both sides get a
  shared local countdown without opening another social app.
* **🛠 Hack Circles:** Join a lightweight shared room such as Ship It, Open
  Source, Rice Club, or Night Owls. It uses the existing opt-in room signal,
  so people can find a temporary tribe without creating a chat server.
* **💬 Chats:** WhatsApp-easy by design — open Friends and your conversations
  are right there with the latest line, unread counts, and one-tap entry.
  Tap any chat to read and reply; invites waiting for you sit at the top.
* **⌨️ Friends Deck:** Press `h/l` to move between tabs, `j/k` to select a
  person, `Enter` to say hello, and `r` to refresh the World. The tab
  shortcuts are `1` Chats, `2` World, `3` Circles, and `4` Me.
* **⚡ Instant delivery:** A live relay listener keeps one subscription open,
  so DMs, waves, and Circle notes arrive in about a second with a desktop
  popup — no refresh needed. The periodic World sync remains as backup.
* **✨ Shared ground:** Optional interests, status, project beacon, room, app,
  and music fields help people discover an honest conversation starter.
* **↻ Fast updates:** Every install advertises its version, so the moment a
  newer Friends appears in your World you get a banner and one popup —
  one tap updates. Silent auto-update is a non-goal: updating code always
  stays your explicit choice.
* **↺ Conversation memory:** Returning builders feel familiar with a tiny
  local-only note — exchanges, last signal, and friends-since — kept on
  your machine, never published, and cleared when you block someone.
* **🍅 Co-work:** Keep the explicit 25-minute focus sessions and invites for
  people on the local radar or saved as private shortcuts.
* **🛡️ Human controls:** Hide from the world, block a profile, rate-limit
  signals, or keep using only the local radar. Friend Codes remain an
  optional private shortcut for people who already know each other.
* **🧭 Friendly first-run path:** The empty Chats screen has one-click
  actions to discover builders, copy your invite, or return to World.
* **💡 Suggest, feedback, and bug reports:** Write a note in Profile, copy it
  with context, and optionally open the matching GitHub form. Nothing is
  submitted automatically.

## How global discovery works

The plugin uses the open Nostr relay protocol. Every installation generates a
local secp256k1 keypair and publishes a small BIP-340-signed presence event to
several public WebSocket relays. The public key is the machine's pseudonymous
identity; the private key stays in the local state file. A ping is a small
signed event addressed to the recipient's public key and tagged for Omarchy
Friends.

The default relay set is:

    wss://relay.primal.net
    wss://nos.lol
    wss://purplerelay.com
    wss://nostr.mom
    wss://relay.damus.io

If one relay is unavailable, the others are tried. Advanced users can provide
a comma-separated set with `OMARCHY_FRIENDS_RELAYS`. The client is dependency
free: it includes a small standard-library WebSocket and secp256k1
implementation, so normal installs do not need `pip` or a hosted Omarchy
Friends account.

The generated profile is visible by default because automatic discovery is the
point of the plugin. The **🌍 World** privacy chip hides it immediately. Do not
put a real name, email, location, or private project URL in a public profile.
Public relays can observe the pseudonymous signed events they carry; this is
not end-to-end private chat. World Spark questions and focus invitations are
bounded signed signals, not a freeform public inbox. A focus invitation expires
after three minutes unless the recipient explicitly joins.

### Updating older installs

Chat invites and encrypted DMs require the current plugin capabilities. If a
World profile shows **Invite update**, clicking it sends the person a visible
update prompt with this exact command:

    omarchy plugin update community.omarchy-friends --yes

After updating, reopen Friends or run `omarchy-shell shell rescanPlugins` if
the new Messages tab does not appear immediately. Older installations remain
visible in World, but cannot accept chat invites until they update.

### Direct invite links

Open **Profile → Invite someone directly → Copy invite**. Share the copied
`omarchy-friends://invite/<public-key>` text in any chat or community. A
recipient opens Friends, pastes it into the same Profile card, and presses
**Connect**. This creates a normal mutual friend request; both people still
choose whether to accept before messages become available.

## Local radar and privacy

* **📡 Local Radar:** Discovers opted-in peers through UDP broadcast on port
  42424. Local presence expires after 90 seconds.
* **🚀 Project Beacons:** Share a short project name, description, and URL only
  when the corresponding privacy chip is enabled.
* **🪩 Gathering Rooms:** Enter a meetup-sized room nickname manually. No
  country, city, or precise location is inferred.
* **✦ Local Pulse:** Shows only signals generated by this installation or
  received from a real peer. There are no invented users or auto-replies.

LAN packets are plaintext and unauthenticated, so treat them as discoverable by
anyone on the same broadcast network. The global layer authenticates event
authorship with signatures, but public visibility is still public visibility.

## Bar controls

* **Left-click:** Open the Friends Deck.
* **Right-click:** Cycle your status.
* **Middle-click:** Copy the optional Friend Code.
* **Bar pill:** Shows the number of current global and local peers, or the
  remaining time for an active focus session.

## Install

    omarchy plugin add https://github.com/harshithnadig/omarchy-friends.git --enable

To place the widget explicitly, add it to the right side of
`~/.config/omarchy/shell.json`:

    {
      "right": [
        { "id": "community.omarchy-friends" }
      ]
    }

Remove it with:

    omarchy plugin remove community.omarchy-friends

State, including the local private signing key, is stored at
`~/.local/state/omarchy-friends/friends_state.json` (or under
`$XDG_STATE_HOME`). The file is created with user-only permissions by the
plugin's normal state workflow.

## Development and verification

Run the engine and global protocol tests:

    python3 -m unittest discover -s tests -v

Run the Omarchy checks from the repository root:

    omarchy plugin validate .
    qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml

## License

MIT License — Omarchy Community Contributors.
