# Codex real-system validation — Omarchy Friends v4.15 RC

Branch: `feature/build-network`

This is **not** a feature-building task. Repository-side v4.15 work is complete and feature scope is frozen. Your job is to validate and fix only issues that require the actual Omarchy machine / public relay behavior / rendered QML.

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

## 6. Two-current-client private messaging / inbox-relay test — REQUIRED

Use two isolated v4.15 Friends installations/state homes, A and B. A third current instance C is useful for the group test.

### 6.1 Prove NIP-17 inbox metadata on real relays

Before testing DMs:

1. Let A and B perform normal World sync.
2. Capture/query the selected public relays and confirm each identity publishes a valid signed **kind `10050`** event with `relay` tags.
3. Confirm Friends accepts only inbox relay URLs that overlap its locally configured `OMARCHY_FRIENDS_RELAYS` / default `GLOBAL_RELAYS`; an arbitrary relay URL from remote metadata must not become a new outbound destination.
4. Confirm the effective inbox list is bounded to the implementation maximum.
5. Note which concrete relay(s) accept kind `10050` and later kind `1059`.

If the selected public relays reject these event kinds or demand authentication such as NIP-42, capture the exact relay response. Fix only that demonstrated compatibility issue; do **not** add speculative authentication/protocol code.

### 6.2 Direct messages

1. A and B become friends and both advertise the complete v4.15 capability set.
2. A sends a text DM to B; B receives exactly one message and popup.
3. B replies; A receives exactly one message and popup.
4. Repeat with one supported media URL.
5. Confirm the relay-facing modern message is Nostr kind `1059`.
6. Confirm A sends B's gift wrap **only to B's verified configured inbox relay list**, not blindly to every World relay.
7. Inspect only the outer gift-wrap event. It must not contain the plaintext or A's true public key. The intended routing identity is B's `p` tag plus the one-time wrapper public key.
8. Tamper with a captured ciphertext/wrapper copy in an isolated test; it must fail closed instead of producing a message.
9. Construct/capture an outer gift wrap decryptable by B whose inner kind-14 rumor addresses only another key; B must reject it.

### 6.3 Restart / anti-downgrade

1. After A has observed B as a modern peer and cached B's verified inbox list, stop both clients.
2. Restart from the same state homes.
3. Confirm the friendship still remembers the modern private protocol and cached inbox metadata.
4. Let B's World presence become stale/absent, then send from A. The client must not silently choose historical kind-4 merely because the live presence cache expired.
5. If the cached inbox list is unusable/expired and cannot be refreshed, the modern send should fail visibly rather than silently changing cryptographic transport.

### 6.4 Private groups

1. A creates a group with B plus current client C when available.
2. B/C receive the group invite and can exchange messages.
3. Confirm each recipient gets an individually wrapped kind-1059 event on that recipient's inbox relays.
4. Inspect the outer wrapper: group id/name, plaintext, true sender public key and other group-member public keys must not be visible there.
5. A sent message must not duplicate locally when the sender copy returns through the relay.

Do **not** replace the implementation or invent another crypto scheme. Fix only a concrete interoperability/runtime bug.

## 7. Upgrade-compatibility private messaging test — REQUIRED

The v4.15 code deliberately keeps the old transport only for transition compatibility.

Using a pre-v4.15 checkout/fixture or a peer that has **never** advertised the complete modern capability set:

- v4.15 -> never-upgraded peer chooses the historical Friends kind-4 transport;
- the old peer can decrypt that message;
- v4.15 can decrypt a captured/fixture historical `{nonce,ciphertext,mac}` Friends payload;
- a current-to-current friendship that has already upgraded remains modern across stale presence/restart and must not downgrade merely because legacy code still exists.

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
- the 65,535-byte private plaintext ceiling behaves as an application resource cap, not a claimed NIP-44 protocol maximum;
- wrong-key/wrong-recipient/tampered private ciphertext fails closed;
- wrong-inner-recipient kind-14 rumor fails closed;
- kind-10050 events require a valid signature and expected author;
- unconfigured remote relay URLs are not followed as arbitrary network destinations;
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
- weaken inbox-relay verification or allow arbitrary remote relay URLs merely to make interoperability tests pass;
- add NIP-42 or another relay-auth path unless a real selected relay demonstrates that it is required;
- remove legacy read/fallback compatibility merely to make tests easier;
- rebuild old V1/V2 panels.

## 13. Final report

Return:

- failures found;
- files changed to fix them;
- exact release-gate, private-messaging test, unit, plugin-validation and qmllint results;
- screenshots of all six Build Network tabs;
- kind-10050 publish/fetch results and concrete relays tested;
- current-to-current NIP-17/NIP-59 DM/group result, inbox routing and outer-event metadata inspection;
- restart/anti-downgrade result;
- v4.15-to-legacy compatibility result;
- Build Network two-instance relay/offline-retry/helper-expiry/block result;
- existing Friends regression result;
- URI registration/open result;
- security/privacy findings;
- final answer: whether all ten gates in `FINAL_RELEASE_STATUS.md` passed.

Commit/push fixes only to `feature/build-network`. Do not merge `main`.