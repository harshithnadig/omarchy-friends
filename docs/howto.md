# How to use Omarchy Friends v4.15

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
- Search filters your existing conversations.
- The main composer is for text. Use **Link** only when you want to attach an optional HTTP(S) link.
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
- Current-to-current private messages use the v4.15 NIP-44/NIP-17/NIP-59 path with recipient inbox relays.
- The implementation is not independently security-audited and NIP-44 does not provide forward secrecy, so Friends is not a place for highly sensitive secrets.
- LAN radar, when enabled, has a different local-network trust boundary; do not confuse it with private internet messaging.

## Staying updated

Friends may show that a newer version is available, but v4.15 does **not** silently update itself in the background.

Use the visible **Update** action when you choose to update. The active service no longer contains a timer-driven updater.

## If something looks wrong

For the v4.15 release candidate, use `CODEX_REAL_SYSTEM_TEST.md`. It contains the real-machine checklist for Chats, Requests, World, Circles, Me, Build Network, relay interoperability, private messaging, legacy compatibility and invite handling.
