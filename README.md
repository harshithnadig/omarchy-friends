# Omarchy Friends 👥

**Omarchy World: find real people who are building on Omarchy right now.**

Friends is a small human layer in the bar. A fresh install creates a memorable
pseudonymous identity, appears in the Friends tab while it is running, and can
receive a friendly wave without anyone having to copy a code. The experience
is global and federated, with the original LAN radar and co-work tools still
available when people are nearby.

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
* **⌨️ Friends Deck:** Press `?` for help, `h/l` to move between tabs, `j/k` to
  select a person, `Enter` to say hello, `s` to send the World Spark, and `f`
  to offer a focus ritual. The tab shortcuts are `1` World, `2` Friends,
  `3` Messages, `4` Showcase, and `5` Profile.
* **✨ Shared ground:** Optional interests, status, project beacon, room, app,
  and music fields help people discover an honest conversation starter.
* **🍅 Co-work:** Keep the explicit 25-minute focus sessions and invites for
  people on the local radar or saved as private shortcuts.
* **🛡️ Human controls:** Hide from the world, block a profile, rate-limit
  signals, or keep using only the local radar. Friend Codes remain an
  optional private shortcut for people who already know each other.
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

    wss://relay.damus.io
    wss://nos.lol
    wss://relay.nostr.band

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
