# Build Network event model — v4.15

Build Network uses the existing Omarchy Friends pseudonymous secp256k1 identity and Nostr transport primitives. Its collaboration data is public relay-readable metadata and remains separate from private Friends DMs/groups.

## Nostr envelope

- event kind: `30079` (parameterized replaceable)
- `d` tag: logical object id
- `t` tag: `omarchy-friends-build`
- `type` tag: normalized logical object type
- content: bounded JSON envelope

Conceptual shape:

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

The signed Nostr event public key is the authorship boundary. Display handles are presentation metadata, not authentication.

## Supported logical objects

### Build flow

- `idea` — title, summary, tags, status.
- `idea_interest` — reference to an idea plus optional note.
- `build_room` — goal, HTTPS repository URL, roles, tasks, source idea and lifecycle state.
- `build_join` — room reference, role and note.
- `project_activity` — explicit public GitHub-derived activity metadata tied to a room/repository.

### Setup and testing

- `setup_card` — shallow setup metadata and safe links.
- `setup_component` — one explicit component/reference from a setup card.
- `test_request` — artifact/version, requested environment labels and optional Build Room reference.
- `test_result` — request reference, pass/issue result, safe environment labels and note.

### Help and community memory

- `help_request` — problem, bounded already-tried context and safe environment labels.
- `help_offer` — help-request reference and note.
- `helper_availability` — short-lived Can Help / Pair / Building availability, skills and expiry metadata.
- `solution_card` — reusable solution plus optional source/help reference and environment labels.
- `solution_verification` — Worked / Partly / Did-not-work verification with optional environment context.

### Shipping and community

- `ship_post` — shipped artifact summary/link/tags.
- `update_report` — explicit Omarchy version + working/minor-issue/rolled-back report.
- `community_event` — title, human-entered time/location and optional safe URL.
- `event_rsvp` — event reference + Going/Interested state.
- `challenge` — prompt/deadline text/rules URL/tags.
- `challenge_join` — challenge reference plus optional team/build metadata.

The exact normalized object vocabulary is enforced by the Python model layers; unknown object types fail closed.

## Replaceability and de-duplication

The pair `(event.pubkey, d-tag/object-id)` is the logical object key. The local cache keeps the newest valid replacement for an author/object. Duplicate copies arriving from multiple relays collapse through event-id and logical-key checks.

Participation objects such as interests, joins, results, offers, verifications and RSVPs are separately signed objects. One user never mutates another user's signed object.

## Validation and resource rules

Before a remote event enters the usable cache, Friends:

1. verifies the Nostr event id/signature;
2. requires kind `30079` and the Build Network tag;
3. bounds event content before parsing;
4. parses the supported envelope version;
5. requires the `d`/`type` tags to agree with the normalized payload;
6. dispatches only an allowlisted object type;
7. normalizes and bounds strings/lists/IDs;
8. strips/rejects unsupported URLs and keeps only HTTP(S) links where links are allowed;
9. rejects unreasonable future timestamps;
10. ignores unknown fields and rejects unknown object types;
11. applies per-author cache fairness and total cache bounds;
12. filters existing Friends-blocked public keys, including relevant derived/nested activity.

No Build Network event contains executable shell commands or arbitrary file contents.

## Publish reliability

A locally created public object is saved even when relay publication fails. Failed publishes are queued as bounded metadata-only payloads and retried in bounded batches on later sync. A successful retry must not create multiple logical copies.

## Expiring availability

Can Help / Pair / Building availability is intentionally temporary. The latest signed replacement event determines the current state, and stale availability expires so a user does not appear permanently available after leaving.

## Privacy boundaries

Build Network objects are public. They are not DMs.

- setup inspection is intentionally shallow and user-triggered;
- Update Pulse is explicit reporting, not telemetry;
- Human Help contains only context the user deliberately publishes;
- safe environment metadata excludes hostname, username, IP address, serial numbers and file contents;
- private follow-up uses the existing Friends conversation system;
- private chat is never silently summarized into a Solution Card or other public object.

## Private-message relationship

Current Friends-to-Friends private messaging uses NIP-44 v2 + NIP-17 kind-14 + NIP-59 seals/gift wraps with signed kind-10050 inbox relay lists. That stack is intentionally separate from public Build Network kind-30079 objects.

The Friends implementation has not received an independent security audit, and NIP-44 does not provide forward secrecy.

## Release status

The repository-side event model is implemented and covered by normalization, signature, metadata/tag-agreement, URL, timestamp, retry, fairness, expiry and block-filtering tests. Real public-relay replacement/dedupe/offline-retry behavior still has to pass the two-instance checks in `CODEX_REAL_SYSTEM_TEST.md` before v4.15 stable.