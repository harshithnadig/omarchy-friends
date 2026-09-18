# Omarchy Friends: product thesis

## North star

Omarchy Friends should feel like noticing another human in the room, not
opening another social network:

> Signals, not feeds.

An empty state is a feature. Every person, project, status, and reply must be
backed by an opted-in local installation or an action the user just took.

## Why this lane

The Omarchy marketplace already has strong chat/BBS, companion/pet, focus
timer, music, sports, and presence experiments. The first plugin competition
also shows that a tiny bar interaction can be memorable when it is complete,
playful, and immediately useful. Reddit feedback repeatedly emphasizes polish,
discovery, and trust over a large volume of half-finished plugins.

Friends should therefore own the narrow space between a status indicator and a
chat app: a small, consent-aware moment of human connection.

## Shipped in 2.2

* Real local UDP presence with expiry and bounded packet sizes.
* A truthful local radar with no hard-coded people or global activity.
* Bounded, opt-in interests with shared-ground matching and an explanation for
  each match.
* Manual gathering rooms for meetup-sized local radars, with room-aware
  matching and a room privacy switch.
* Visible success/failure feedback for actions and a one-tap reply hello from
  the local pulse.
* Friend Codes for manually saving trusted peers.
* Explicit hello, high-five, coffee, kudos, rice, and co-work signals, with a
  bounded icebreaker for a shared-ground match.
* Solo focus sessions plus recipient-controlled co-work invites.
* Field-level sharing controls and a visible plaintext/unauthenticated LAN
  boundary.
* Unit tests for migration, privacy, presence, deduplication, interactions,
  rice sharing, and co-work invites.

## Best next additions

1. **Presence rituals:** one-tap “I’m here”, “pair for 25”, and “ship bell”
   signals with a clear pending/accepted state. No chat box.
2. **Beacon history:** show “what changed since last seen” for a trusted peer,
   using only their explicitly shared status/project fields.
3. **Pairing card:** generate a printable or copyable Friend Code card with a
   one-sentence privacy explanation, so two people can pair without account
   setup.
4. **Conversation memory:** keep a tiny, local-only record of mutual signals so
   a returning peer feels familiar without creating a public social graph.
5. **Graceful transport upgrades:** add an explicitly configured unicast or
   encrypted transport only after the consent and key model is designed; do
   not quietly turn Friend Codes into authentication.

## Non-goals

* A global matchmaking service or hosted social graph.
* Fake companion users, generated replies, or a pre-populated activity feed.
* Freeform chat, public profiles, inferred location, or background telemetry.
* Another pet, Pomodoro, radio, or generic notification plugin.

## Quality gates

Before each release, verify:

1. A fresh install starts empty and says why.
2. Every visible online person can be traced to a recent presence packet.
3. Every outgoing interaction has a target, consent boundary, and failure
   state.
4. Privacy defaults and network limitations are documented in the README.
5. The repository passes the Omarchy validator, QML lint, unit tests, and
   whitespace checks.

## Research references

* [Omarchy plugin marketplace](https://plugins.omarchy.org/)
* [Marketplace submission and security boundary](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)
* [DHH's first plugin competition winners](https://omarchy.org/news/2026/08/the-first-plugin-competition-winners/)
* [Omarchy patronage and the upcoming competition](https://en-au.omarchy.org/news/2026/09/omacom-patronage-is-open-to-everyone/)
* [Reddit discussion on marketplace quality and discovery](https://www.reddit.com/r/omarchy/comments/1w4dqx8/omarchy_plugin_marketplace_is_growing_to_fast/)
* [Omarchy Archive's community/X sweep](https://www.omarchyarchive.com/resources/)
