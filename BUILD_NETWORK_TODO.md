# Build Network status — v4.14

## Implemented on `feature/build-network`

- [x] Bounded collaboration state models and fail-closed validation
- [x] Signed Nostr relay encode/decode and de-duplication
- [x] Ideas + interest signals
- [x] Ideas → Build Rooms
- [x] Build Room joins, roles, GitHub links and lifecycle states
- [x] Build task progress updates
- [x] Setup Cards with shallow safe local inspection
- [x] Safe setup comparison/diff before any manual application
- [x] Test requests + pass/issue results with environment labels
- [x] Human-help requests + offers + solved/closed lifecycle
- [x] Safe non-identifying environment context for help/update/test flows
- [x] Solution Cards + community verification counts
- [x] Ship Log / Discover feed
- [x] Opt-in Omarchy Update Pulse + similar-environment aggregates
- [x] Community events + Going/Interested RSVP
- [x] Build challenges + join/team signal
- [x] Contribution-oriented reputation; no follower-count ranking
- [x] Save/hide local community objects
- [x] Existing Friends chat handoff for private follow-up
- [x] Modern liquid-glass Build Network V3 UI
- [x] Reusable GlassSurface / GlassPill visual components
- [x] Safe `omarchy-friends://invite/<pubkey>` handler implementation
- [x] Unit tests for bounded payloads, malicious types and unsafe URLs
- [x] GitHub Actions Python compile + complete unit suite + remote-exec grep gate
- [x] Existing Friends deck kept separate and intact for regression safety

## Intentionally NOT implemented

- [ ] Auto-install/apply another person's setup. This is intentionally prohibited until a future reviewed installer can produce an exact local diff and explicit user confirmation.
- [ ] Remote shell/code execution. This is intentionally prohibited.
- [ ] Automatic upload of logs, configs, secrets or private files. This is intentionally prohibited.
- [ ] Private-message crypto migration. Existing messaging crypto is unchanged in this branch; any NIP-44/NIP-17 migration deserves its own audited change.

## Real Omarchy validation still required

- [ ] `omarchy plugin validate .`
- [ ] `qmllint` against the real Omarchy/Quickshell imports
- [ ] Reload shell and visually inspect the V3 liquid-glass deck
- [ ] Exercise every tab and action on the real machine
- [ ] Two-instance relay sync test
- [ ] Existing DM/group/World/Circle/focus regression pass
- [ ] Verify custom URI desktop registration strategy for the installed plugin path

Those remaining items require the real Omarchy runtime; they are validation/integration work, not missing product design.
