# Codex real-system validation — Omarchy Friends v4.15 RC

Branch: `feature/build-network`

This is **not** a feature-building task. Repository-side v4.15 work is complete and feature scope is frozen. Your job is to validate and fix only issues that require the actual Omarchy machine / real relays.

Do not merge into `main` unless Harshu explicitly asks.

## 1. Checkout the release candidate

```bash
git fetch origin
git switch feature/build-network
git pull --ff-only
git status --short
git rev-parse --abbrev-ref HEAD
git log -1 --oneline
```

Confirm the branch is exactly `feature/build-network` and the worktree is clean before testing.

## 2. Run the release gate first

```bash
bash scripts/release-gate.sh
```

Do not continue toward release while this prints any `FAIL`. Fix only the concrete failure, rerun the gate, and keep the change minimal.

Also run explicitly:

```bash
python3 -m unittest tests.test_private_messaging tests.test_private_messaging_engine -v

omarchy plugin validate .

qmllint -I "$OMARCHY_PATH/shell" \
  BarWidget.qml Panel.qml Service.qml \
  BuildNetworkPanelV3.qml BuildNetworkService.qml \
  GlassSurface.qml GlassPill.qml
```

## 3. Load the real plugin

Reload Omarchy shell/plugin using the normal local workflow.

Verify the normal Friends widget first:

- left-click opens Friends;
- the visible `🛠 Build` button opens Build Network;
- middle-click also opens Build Network;
- right-click cycles status;
- no QML/runtime warnings or crashes appear from either panel.

## 4. Visual V3 check

Check all six Build Network tabs: Discover, Build, Share, Help, Community and Create.

Validate:

- dark liquid-glass hierarchy renders correctly;
- no clipped text/action wrapping at normal laptop scale;
- scroll behavior is smooth;
- text inputs are readable with the active Omarchy theme;
- selected/hover states remain visible;
- Can Help / Pair controls are reachable;
- Setup Component composer is reachable from an owned Setup Card;
- GitHub pulse/publish controls are reachable from a room with a public GitHub repo;
- Help -> Solution is reachable for an owned help request;
- external Share copies text;
- Release diagnostics / Repair invites / Health controls are reachable.

Do not redesign the panel unless a real supported QML/API incompatibility forces a small fix.

## 5. Core Build Network smoke test

Use disposable titles prefixed `TEST —` because public objects are relay-readable.

Exercise:

1. Idea -> interested -> Start build.
2. Build Room -> join -> task doing/done -> owner testing/shipped state.
3. Public GitHub repo -> GitHub pulse -> explicitly publish one Project Activity card.
4. Setup Card -> Compare with mine -> verify no machine changes -> Copy recipe.
5. Owned Setup Card -> share one component -> verify metadata/link only.
6. Test Request -> Works / Found issue with safe environment labels.
7. Help Request -> Offer help -> Friends private-chat handoff -> author Mark solved.
8. Set `Can Help`, `Pair` and `Build with me` availability; confirm expiry/matching behavior.
9. Confirm a compatible Help Request shows helper matches.
10. Convert solved Help -> Solution without retyping original problem/environment.
11. Solution -> Worked / Partly verification.
12. Ship entry.
13. Update Pulse report -> confirm similar-environment aggregate when labels overlap.
14. Event -> Going/Interested RSVP.
15. Challenge -> Join -> Start a team/Build Room.
16. Save/hide local object behavior.
17. Generate external share text for public cards.
18. Use Release Health and confirm no unexpected queued-publish count/errors.

Useful probes:

```bash
python3 bin/build_network_app_v4.py status | python3 -m json.tool
python3 bin/build_network_app_v4.py health | python3 -m json.tool
python3 bin/build_network_app_v4.py inspect-environment | python3 -m json.tool
python3 bin/build_network_app_v4.py register-uri | python3 -m json.tool
```

## 6. Two-current-client private messaging test — REQUIRED

Use two isolated v4.15 Friends installations/state homes, A and B. They must both appear in World with the v4.15 capability set before the DM test.

Verify direct messages:

1. A and B become friends.
2. A sends a text DM to B; B receives exactly one message and popup.
3. B replies; A receives exactly one message and popup.
4. Repeat with one supported media URL.
5. Confirm the relay-facing event used for the modern DM is Nostr kind `1059`.
6. Inspect only the **outer** gift-wrap event. It must not contain the plaintext or A's true public key. The only intended routing identity in the outer event is the recipient `p` tag plus the one-time wrapper public key.
7. Tamper with a captured ciphertext/wrapper copy in an isolated test; it must fail closed instead of producing a message.

Verify private groups:

1. A creates a group with B plus a third isolated current client C when available.
2. B/C receive the group invite and can exchange messages.
3. Inspect the outer kind-1059 wrapper: group id/name, plaintext, true sender public key, and other group-member public keys must not be visible in that outer event.
4. A sent message must not duplicate locally when the optional sender copy returns through the relay.

Do **not** replace the implementation or invent another crypto scheme. Fix only a concrete interoperability/runtime bug.

## 7. Upgrade-compatibility private messaging test — REQUIRED

The v4.15 code deliberately keeps the old transport only for transition compatibility.

Using a pre-v4.15 checkout/fixture or by constructing a peer presence without `nip44-v2` / `nip17-dm-v1` capabilities:

- v4.15 -> old peer chooses the historical Friends kind-4 transport;
- the old peer can decrypt that message;
- v4.15 can decrypt a captured/fixture historical `{nonce,ciphertext,mac}` Friends payload;
- a current-to-current peer pair must prefer NIP-17/NIP-59 and must not downgrade just because the old code path still exists.

Do not delete compatibility support during this RC validation. A future release can remove it only after an explicit transition decision.

## 8. Build Network two-instance relay test

Use two Omarchy installations or isolated state homes.

Verify:

- A creates Idea; B receives it after Sync.
- B marks interested; A count increases.
- A opens Build Room; B joins; task/status changes propagate.
- Setup Card + Setup Component propagate.
- Can Help / Pair availability propagates and expires after its configured window.
- Project Activity cards propagate.
- Test result, help offer, solution verification, RSVP and challenge join propagate.
- multi-relay duplicate copies collapse to one logical object.
- newer event for the same author/object wins.
- force relay failure for a public post, confirm it is saved locally/queued, restore network, Sync, and confirm retry publishes it once.
- block B in Friends, then confirm B's Build Network top-level/nested activity is locally filtered on A.

## 9. Existing Friends regression

Do not approve v4.15 if Build Network or the messaging migration breaks the existing product. Test:

- friend request/accept;
- direct messages;
- private groups;
- World presence/waves;
- Circles/community;
- Focus ritual;
- block/report behavior;
- update banner/flow;
- profile/privacy controls.

## 10. Security/privacy regression

Confirm:

- NIP-44 official vector tests pass;
- wrong-key/wrong-recipient/tampered private ciphertext fails closed;
- modern outer gift wraps do not expose message text or real sender public key;
- modern group outer gift wraps do not expose group id/name or other members;
- invalid signatures are rejected;
- unknown Build object types fail closed;
- mismatched `d`/`type` tags vs payload are rejected;
- oversized Build event content is rejected;
- unreasonable future timestamps are rejected;
- `file://`, `javascript:` and control-character URLs do not become openable shared links;
- public relay objects never contain the Friends private key;
- shared setup/component metadata cannot execute shell/install commands;
- remote text is displayed as text, never evaluated;
- safe environment collection contains no hostname, username, IP, serial or file contents;
- public GitHub snapshot accepts only HTTPS `github.com/owner/repo` URLs and uses no credentials/tokens;
- one noisy author cannot crowd the entire local Build cache;
- existing Friends blocks are not bypassed.

Important wording: NIP-44/NIP-17/NIP-59 are standardized protocol choices, but **this Friends implementation itself has not been independently security-audited** and NIP-44 does not provide forward secrecy. Do not change the README to claim otherwise.

## 11. Invite desktop registration

Check:

```bash
xdg-mime query default x-scheme-handler/omarchy-friends
```

Then open a disposable:

```text
omarchy-friends://invite/<64-hex-pubkey>
```

Verify it reaches the installed `bin/omarchy-friends-open` handler and rejects every unsupported URL shape. Do not hard-code a developer checkout path.

## 12. What NOT to build

Do not:

- invent another social feature;
- redesign Build Network architecture;
- add remote shell execution;
- auto-install setup cards/components;
- upload configs/logs/files automatically;
- replace the v4.15 NIP-44/NIP-17/NIP-59 design with another private-message construction;
- remove legacy read/fallback compatibility merely to make tests easier;
- rebuild old V1/V2 panels.

## 13. Final report

Return:

- failures found;
- files changed to fix them;
- exact release-gate, private-messaging test, unit, plugin-validation and qmllint results;
- screenshots of all six Build Network tabs;
- current-to-current NIP-17/NIP-59 DM/group result and metadata inspection;
- v4.15-to-legacy compatibility result;
- Build Network two-instance relay/offline-retry/helper-expiry/block result;
- existing Friends regression result;
- URI registration/open result;
- security/privacy findings;
- final answer: whether all eight gates in `FINAL_RELEASE_STATUS.md` passed.

Commit/push fixes only to `feature/build-network`. Do not merge `main`.
