# Build Network event model — v1 prototype

Build Network uses the existing Omarchy Friends pseudonymous secp256k1 identity and Nostr transport primitives, but keeps its public collaboration data separate from DMs/community chat.

## Nostr envelope

- event kind: `30079` (parameterized replaceable)
- `d` tag: object id
- `t` tag: `omarchy-friends-build`
- `type` tag: logical object type
- content: bounded JSON envelope

Example shape:

```json
{
  "app": "omarchy-friends",
  "v": 1,
  "object": {
    "type": "idea",
    "id": "idea_...",
    "title": "Visual keybinding editor",
    "summary": "...",
    "tags": ["Hyprland", "QML"],
    "author": "PixelComet-1234",
    "created_at": 1780000000,
    "status": "open"
  }
}
```

The Nostr event signature/public key is the actual authorship boundary. Display handles in payloads are presentation metadata, not authentication.

## Core collaboration object types

- `idea`: title, summary, tags, status
- `idea_interest`: `idea_id`, optional note
- `build_room`: title, goal, repo URL, roles needed, tasks, source idea, status
- `build_join`: `room_id`, role, note
- `setup_card`: title, theme, plugin names, components, shell, terminal, editor, wallpaper/repo URLs, notes
- `test_request`: title, artifact URL, version, requested environment tags, notes, optional Build Room
- `test_result`: request id, `pass`/`issue`, environment tags, note

## Community loop object types

- `help_request`: problem, what was already tried, environment tags
- `solution_card`: problem + reusable solution + environment tags + optional source
- `ship_post`: shipped artifact summary/link/tags
- `update_report`: Omarchy version + `working` / `minor_issue` / `rolled_back`
- `community_event`: title, human-entered time/location, optional event URL
- `challenge`: title, prompt, deadline text, optional rules URL/tags

## Replaceability and de-duplication

The pair `(event.pubkey, d-tag/object-id)` is the logical object key. The client caches the newest valid event for that author/object. Duplicate relay copies collapse through event id + logical key checks.

Interests, joins and test results are separate objects with their own ids; they do not mutate another person's signed object.

## Validation rules

Before a remote event enters the cache:

1. verify Nostr event id/signature;
2. require kind `30079` and `t=omarchy-friends-build`;
3. parse the v1 envelope;
4. dispatch only a known object type;
5. normalize/bound all strings/lists;
6. strip non-HTTP(S) URLs;
7. ignore unknown fields;
8. reject unknown types.

No Build Network object contains executable commands or file contents.

## Privacy boundaries

Build Network cards are public relay-readable metadata. They are not DMs.

- Setup inspection is intentionally shallow and user-triggered; it does not read dotfile contents.
- Update Pulse is based only on explicit reports; there is no automatic telemetry.
- Human Help cards should contain only problem/environment context the user chooses to share.
- Private follow-up uses the existing Friends relationship/DM system.

## Future protocol work

Before declaring the protocol stable, Codex/maintainers should test relay compatibility, event replacement semantics, spam/rate limits, moderation/block propagation and migration/version behavior. If private Build Room metadata is added later, it should reuse audited/standardized Nostr private-message encryption rather than inventing another encryption construction.
