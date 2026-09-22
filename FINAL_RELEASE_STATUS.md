# Omarchy Friends v4.14 — final release status

Feature scope is frozen. The repository-side v4.14 work is complete; do not add another product feature before release.

## Repo-side release candidate

- Product architecture: complete for v4.14.
- Build Network backend: complete for planned v4.14 scope.
- Liquid-glass V3 panel: implemented.
- Release runtime: `bin/build_network_app_v4.py`.
- `manifest.json` and the live Friends engine both advertise `4.14.0`.
- Build Network is visibly reachable from the normal Friends panel and remains available by middle-click.
- V3 UI exposes Can Help / Pair, helper matches, setup-component sharing, public GitHub pulse/activity publishing, Help -> Solution, external Share, invite repair and health diagnostics.
- Current private messaging remains the existing application-specific implementation; release wording must continue to describe it accurately as not formally audited. NIP-44 migration belongs in a separate compatibility-tested release.

## Release hardening implemented

- relay-failed public objects are queued locally and retried in bounded batches;
- stale Can Help / Pair availability expires from the latest signed replacement event;
- existing Friends blocks filter Build Network top-level and nested activity locally;
- corrupt Build state is quarantined;
- state schema migration creates a private backup;
- durable community knowledge has a longer bounded lookback;
- one Nostr identity cannot crowd the whole local cache because of per-author fairness limits;
- malformed relay events are rejected for bad metadata/tag agreement, oversized content and unreasonable future timestamps;
- Build Network QML work is serialized so timer refresh/status operations do not race user writes;
- health diagnostics and `scripts/release-gate.sh` are included;
- CI compiles the active modules, runs the complete unit suite, enforces the remote-execution safety boundary and runs the static release gate.

## Remaining gates — real Omarchy only

1. Run `bash scripts/release-gate.sh` on the actual Omarchy installation and require no `FAIL`.
2. Pass real `omarchy plugin validate .` and `qmllint -I "$OMARCHY_PATH/shell" ...` against the installed shell imports.
3. Run a two-instance test for relay sync, replacement/dedupe, offline publish retry, helper expiry and block filtering.
4. Regression-test existing Friends DMs, private groups, World, Circles, focus, blocks/reporting and update flow.
5. Open a real `omarchy-friends://invite/<public-key>` URI through the desktop handler installed from the actual plugin path.
6. Visually inspect all six Build Network tabs at normal laptop scale for clipping, scroll/input usability and obvious action reachability.

## Stop condition

When those six real-system gates pass, cut the stable release. Do not reopen feature brainstorming for v4.14.
