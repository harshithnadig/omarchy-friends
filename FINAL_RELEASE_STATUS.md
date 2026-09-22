# Omarchy Friends v4.14 — final release status

This is the short release truth. Product feature brainstorming is frozen until these gates are closed.

## Current state

- Product architecture: complete for v4.14.
- Build Network backend: complete for planned v4.14 scope.
- Build Network liquid-glass V3 panel: implemented.
- Release-hardening runtime: implemented in `bin/build_network_app_v4.py`.
- Python/unit/static safety CI: green on the feature branch before this status-only commit.
- PR remains draft and must not be merged solely from CI.

## Release hardening already implemented

- offline relay-failure retry queue;
- stale Can Help / Pair expiry;
- reuse of existing Friends block list in Build Network;
- Build state corruption quarantine;
- state schema migration + private backup;
- longer bounded community-memory lookback;
- health diagnostics;
- final `scripts/release-gate.sh`;
- accurate README safety/release wording.

## Remaining gates

1. Change `PLUGIN_VERSION = "4.12.0"` to `PLUGIN_VERSION = "4.14.0"` in `bin/omarchy-friends` so the live presence/update system agrees with `manifest.json`.
2. Wire the newest already-implemented V3 actions into `BuildNetworkPanelV3.qml` using `V3_UI_WIRING_MAP.md`.
3. Make Build Network visibly discoverable from the normal Friends experience while keeping middle-click.
4. Run `bash scripts/release-gate.sh` on the actual Omarchy system until it passes with no FAIL.
5. Run real `omarchy plugin validate .` and `qmllint` against installed shell imports.
6. Two-instance relay test including offline retry, replacement/dedupe and helper expiry.
7. Regression-test Friends DMs, private groups, World, Circles, focus, blocks/reporting and update flow.
8. Validate actual desktop opening of `omarchy-friends://invite/<public-key>`.
9. Decide private-message crypto release posture: ship current application-specific implementation with accurate unaudited wording, or hold for the separately tested NIP-44 migration. Do not make stronger security claims without that migration/audit.

## Stop condition

When all nine gates above pass, cut the stable release. Do not add another social feature just because one can be imagined.
