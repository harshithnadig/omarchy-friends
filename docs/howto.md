# How to use Omarchy Friends v4.16

Friends is the human layer of Omarchy: real builders, private conversations, a public community room and a Build Network for collaborating on useful things.

There are no hosted Friends accounts and no fake users. Public discovery is pseudonymous; private conversation state stays local unless you send something.

## The 60-second tour

1. **Open Friends** — left-click the 👥 pill in your bar. It opens on **Chats**.
2. **Meet someone** — open **World**. Search or use `All / New / Building / Friends`, then choose the person's one relationship action: **Connect**, **Accept**, or **Message**.
3. **Handle requests separately** — **Requests** has **Received** and **Sent**. Requests never clutter your Chats list.
4. **Talk privately** — after you are friends, open **New chat** and choose them. That conversation gets its own message history and stays separate from every other person/group.
5. **Meet the community** — **Circles** opens the public Omarchy Circle room.
6. **Build together** — use the visible **Build** entry or middle-click the bar pill to open Build Network.

## Main navigation

| View | What it is |
|---|---|
| **Chats** | Opened private/group conversations only. |
| **Requests** | Received connection requests and Sent/pending requests. |
| **World** | Live Omarchy people, projects, interests and relationship state. |
| **Circles** | Public Omarchy community room. |
| **Build** | Collaboration workspace: ideas, builds, setups, tests, help, solutions and community work. |
| **Me** | Your pseudonymous profile, presence and privacy controls. |

## Chats

Chats intentionally does **not** show every friend.

- Use **New chat** to choose from your complete friends list.
- Once you open a person, that private conversation appears in the conversation rail.
- Messages for one friend never get mixed into another friend's conversation.
- Private groups have their own conversation too.
- Search finds loaded direct and group messages by text, reply text, shared media URL, or attachment name. Open a result to jump to the matching message. Search runs over the decrypted messages already loaded in this app session; the search query and index are not saved or sent to relays.
- Use **Pin** in the selected chat header to keep a direct or group conversation above recent chats. Pins are encrypted and stored on this device only; up to 20 conversations can be pinned.
- Use **Mute** in the selected chat header to stop notifications from that conversation on this device. Messages remain visible in the chat and continue to affect unread counts.
- **Reply** on a message to quote its short text in the composer; the parent message is checked against this conversation before sending.
- Choose **Forward…** from a message's **⋯** menu to send its text or shared link to an existing friend or group. The confirmation dialog tells you that attached files and the original sender are not included; nothing is sent until you press **Forward**.
- Use the message's **⋯** menu to react, reply, edit your sent text-only messages for up to 15 minutes, delete the message for yourself, or (for your own sent messages) delete for everyone. The menu keeps the chat bubble compact; each person has one reaction per message, and the chat shows reaction totals.
- **Delete for me** removes the message from this device's encrypted message journal and chat view; it does not send an event to other participants. **Delete for everyone** sends the encrypted deletion event and remains best effort.
- **Read receipts** are off by default. Enable them in Me → Privacy to send an encrypted read notice when you open a chat; direct-chat receipts go to that friend and group receipts go to the current group members. Only compatible Friends clients show the read status.
- **Delete for everyone** is available on confirmed messages you sent. It sends an encrypted deletion event and replaces the message content with a tombstone on clients that process it.
- Use the single **📎 attachment button** to choose a file, a folder to send as a ZIP, or a link. File and folder selection opens the desktop's native chooser through the XDG FileChooser portal; the selected local item is staged in the composer for you to send.
- Files up to 16 KiB travel inside the encrypted private message. Larger files and folders up to 100 MiB are encrypted on your device and uploaded to your configured HTTPS Blossom server. Set that server in **Me → Large files** first; its own size limits and policies apply.
- The encrypted message contains the decryption key and download pointer. Recipients use **Save to Downloads**; folders arrive as ZIP archives and are not extracted automatically.
- Failed sends remain in the local encrypted history with a failed status; they are not reported as sent.
- **Focus** and **Build** are contextual actions for the selected conversation.

## Requests

Requests has two states:

- **Received** — another builder wants to connect. Accepting establishes the friendship and lets you start a private chat.
- **Sent** — requests you sent from World or a direct invite that are still waiting for the other person.

This state is deliberately separate from Chats so a busy request list cannot bury the person you actually want to talk to.

## World

World is a discovery surface, not a social-media feed.

- **All** — everyone currently visible.
- **New** — people you have not already connected with.
- **Building** — people sharing a current project.
- **Friends** — your friends who are currently visible.

Each person has one clear action based on relationship state:

- **Connect** — send a connection request;
- **Accept** — accept their request;
- **Requested** — your request is pending;
- **Needs update** — their current client is too old for the modern chat flow;
- **Message** — open their private conversation.

World cards show useful project/status/common-ground context without repeating Wave/Focus/Build buttons everywhere.

## Circles

**Omarchy Circle** is public and relay-readable. Use it for questions, discoveries, small wins and finding people to continue with privately.

Do not post passwords, private links, personal addresses, credentials or sensitive logs there.

## Me

Me is split into three ideas:

- **About you** — display name and optional project information.
- **Presence** — avatar, status and up to four interests.
- **Privacy** — control whether your public beacon shares World visibility, active app, music, project, interests and room.

**Copy invite** creates:

```text
omarchy-friends://invite/<public-key>
```

A compatible installed Friends client can use that link to start the connection flow without depending on both people appearing in World at the same moment.

## Build Network

Open it from the visible **Build** entry or middle-click the Friends bar pill.

The six workspaces are:

- **Discover** — useful community work;
- **Build** — Build Rooms, roles, tasks and public GitHub activity;
- **Share** — Setup Cards/components and Test Network;
- **Help** — Human Help, Can Help/Pair/Building availability and helper matching;
- **Community** — solutions, shipping, update reports, events and challenges;
- **Create** — publish a new supported public object.

Setup sharing is review-first. Friends does not automatically install another person's setup or execute remote shell commands.

## Privacy and security

- Your global identity is pseudonymous and locally generated.
- Public World/Circles/Build Network objects are relay-readable.
- You can hide from World from **Me → Privacy**.
- Current-to-current private messages use the NIP-44/NIP-17/NIP-59 path with recipient inbox relays, introduced in v4.15.
- Replies use the standard encrypted NIP-17 reply reference; reactions are encrypted NIP-17 kind-7 events. Reactions require a known message in the same conversation.
- Chat rows show encrypted-state-backed unread counts. Opening a direct chat or group advances a device-local read cursor; read state is not sent to relays or other devices.
- Current peers receive deletion in an encrypted NIP-17 kind-5 event; the legacy compatibility path carries the deletion in its existing encrypted envelope. Relay acceptance means at least one configured recipient relay acknowledged it. Deletion is not secure erasure: it cannot erase copies already saved, exported, backed up, or retained by another client or relay.
- The implementation is not independently security-audited and NIP-44 does not provide forward secrecy, so Friends is not a place for highly sensitive secrets.
- Opt-in encrypted read receipts are available between compatible Friends clients and remain off by default. Device-local unread counts are separate from those receipts and are never sent to relays or other devices. Typing indicators, voice/video calls, verified device identities, and account/key recovery are not implemented.
- LAN Radar is off on new profiles because its UDP discovery is visible to devices on the local network. Enable **Me → Privacy → LAN sharing** only on a network where you want nearby users to discover you. Existing saved choices are preserved. LAN signals are separate from encrypted internet DMs.

## Staying updated

Friends may show that a newer version is available, but it does **not** silently update itself in the background.

Use the visible **Update** action when you choose to update. The active service no longer contains a timer-driven updater.

## If something looks wrong

For the v4.16.0 release candidate, use `CODEX_REAL_SYSTEM_TEST.md`. It contains the real-machine checklist for Chats, Requests, World, Circles, Me, Build Network, relay interoperability, private messaging, legacy compatibility, attachments and invite handling.
