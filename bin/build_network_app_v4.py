#!/usr/bin/env python3
"""Release-hardening layer for Omarchy Friends Build Network v4.14.

This module intentionally adds no new social product concepts. It closes
release-quality gaps around stale availability, blocked builders, offline
publishing, cache fairness, durable community memory, state migration and
health diagnostics.

The existing v3 implementation remains the source of truth for product actions.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import time

import build_network_app_v3 as app

core = app.base.core
APP_VERSION = "4.15.1"
STATE_SCHEMA = 2
MAX_PENDING = 64
MAX_RETRY_PER_SYNC = 4
MAX_CACHE_PER_AUTHOR = 60
MAX_OWN_CACHE = 160

_previous_aggregate = app.aggregate_v3
_previous_store_and_publish = core._store_and_publish
_previous_event_payload = core._event_payload

# v4.14-final: strict relay event envelope guard
MAX_EVENT_CONTENT_BYTES = 32 * 1024
MAX_FUTURE_SECONDS = 10 * 60


def _event_metadata_precheck(event, now=None):
    if not isinstance(event, dict):
        return False
    now = int(time.time()) if now is None else int(now)
    content = event.get("content", "")
    if not isinstance(content, str) or len(content.encode("utf-8", errors="ignore")) > MAX_EVENT_CONTENT_BYTES:
        return False
    try:
        created_at = int(event.get("created_at", 0) or 0)
    except (TypeError, ValueError, OverflowError):
        return False
    return created_at > 0 and created_at <= now + MAX_FUTURE_SECONDS


def _event_tags_match_payload(event, payload):
    if not isinstance(payload, dict):
        return False
    tags = event.get("tags", []) if isinstance(event, dict) else []
    d_values = [tag[1] for tag in tags if isinstance(tag, list) and len(tag) > 1 and tag[0] == "d"]
    type_values = [tag[1] for tag in tags if isinstance(tag, list) and len(tag) > 1 and tag[0] == "type"]
    return (
        len(d_values) == 1
        and len(type_values) == 1
        and str(d_values[0]) == str(payload.get("id", ""))
        and str(type_values[0]) == str(payload.get("type", ""))
    )


def _release_event_payload(event):
    if not _event_metadata_precheck(event):
        return None
    payload = _previous_event_payload(event)
    if payload is None or not _event_tags_match_payload(event, payload):
        return None
    return payload


core._event_payload = _release_event_payload


def _blocked_pubkeys():
    """Reuse the private/social engine's local block list."""
    main = core._main_state()
    global_state = main.get("global", {}) if isinstance(main, dict) else {}
    values = global_state.get("blocked_pubkeys", []) if isinstance(global_state, dict) else []
    result = set()
    for value in values:
        value = str(value or "").strip().lower()
        if len(value) != 64:
            continue
        try:
            int(value, 16)
        except ValueError:
            continue
        result.add(value)
    return result


def _helper_live(item, now=None):
    """Availability expires from the most recent signed replacement event."""
    if not isinstance(item, dict) or item.get("status") != "active":
        return False
    now = int(time.time()) if now is None else int(now)
    try:
        created = int(item.get("created_at", 0) or 0)
        updated = int(item.get("updated_at", 0) or 0)
        anchor = max(created, updated)
        minutes = max(10, min(240, int(item.get("available_minutes", 30) or 30)))
    except (TypeError, ValueError, OverflowError):
        return False
    return anchor > 0 and anchor + minutes * 60 >= now


def _not_blocked(item, blocked):
    return not isinstance(item, dict) or str(item.get("public_key", "")).lower() not in blocked


def _filtered(values, blocked):
    return [item for item in values or [] if _not_blocked(item, blocked)]


def _trim_fair(objects, own_public_key, blocked=None):
    """Keep a noisy signed identity from crowding the whole local cache."""
    blocked = blocked or set()
    ordered = sorted(
        ((key, value) for key, value in (objects or {}).items() if isinstance(value, dict)),
        key=lambda item: int(item[1].get("updated_at", item[1].get("created_at", 0)) or 0),
        reverse=True,
    )
    counts = {}
    kept = []
    for key, payload in ordered:
        public_key = str(payload.get("public_key", "")).lower()
        if public_key in blocked:
            continue
        limit = MAX_OWN_CACHE if public_key == own_public_key else MAX_CACHE_PER_AUTHOR
        current = counts.get(public_key, 0)
        if current >= limit:
            continue
        counts[public_key] = current + 1
        kept.append((key, payload))
        if len(kept) >= core.MAX_CACHE:
            break
    return dict(kept)


def _recompute_derived(result, blocked):
    """Blocked authors should not remain visible indirectly through counters/nested data."""
    help_offers = result.get("help_offers", [])
    offer_counts = {}
    for item in help_offers:
        hid = item.get("help_id", "")
        offer_counts[hid] = offer_counts.get(hid, 0) + 1
    for item in result.get("help_requests", []):
        item["offer_count"] = offer_counts.get(item.get("id", ""), 0)

    verification_counts = {}
    worked_counts = {}
    for item in result.get("solution_verifications", []):
        sid = item.get("solution_id", "")
        verification_counts[sid] = verification_counts.get(sid, 0) + 1
        if item.get("result") == "worked":
            worked_counts[sid] = worked_counts.get(sid, 0) + 1
    for item in result.get("solutions", []):
        sid = item.get("id", "")
        item["verification_count"] = verification_counts.get(sid, 0)
        item["worked_count"] = worked_counts.get(sid, 0)

    rsvp = {}
    for item in result.get("event_rsvps", []):
        eid = item.get("event_id", "")
        row = rsvp.setdefault(eid, {"going": 0, "interested": 0})
        response = item.get("response", "interested")
        if response in row:
            row[response] += 1
    for item in result.get("events", []):
        row = rsvp.get(item.get("id", ""), {"going": 0, "interested": 0})
        item["going_count"] = row["going"]
        item["interested_count"] = row["interested"]

    challenge_counts = {}
    for item in result.get("challenge_joins", []):
        cid = item.get("challenge_id", "")
        challenge_counts[cid] = challenge_counts.get(cid, 0) + 1
    for item in result.get("challenges", []):
        item["join_count"] = challenge_counts.get(item.get("id", ""), 0)

    allowed_tasks = result.get("task_updates", [])
    tasks_by_room = {}
    for item in allowed_tasks:
        tasks_by_room.setdefault(item.get("room_id", ""), []).append(item)
    allowed_activity = result.get("project_activity", [])
    activity_by_room = {}
    for item in allowed_activity:
        activity_by_room.setdefault(item.get("room_id", ""), []).append(item)
    for room in result.get("build_rooms", []):
        rid = room.get("id", "")
        room["task_updates"] = tasks_by_room.get(rid, [])[:24]
        room["done_count"] = sum(1 for item in room["task_updates"] if item.get("status") == "done")
        room["blocked_count"] = sum(1 for item in room["task_updates"] if item.get("status") == "blocked")
        room["project_activity"] = activity_by_room.get(rid, [])[:16]

    components_by_setup = {}
    for item in result.get("setup_components", []):
        components_by_setup.setdefault(item.get("setup_id", ""), []).append(item)
    for setup in result.get("setups", []):
        setup["shared_components"] = components_by_setup.get(setup.get("id", ""), [])[:24]

    environment = result.get("environment", {}) if isinstance(result.get("environment"), dict) else {}
    local_tags = {str(item).casefold() for item in environment.get("tags", []) if item}
    pulse = {}
    for report in result.get("update_reports", []):
        version = report.get("version", "unknown") or "unknown"
        row = pulse.setdefault(version, {
            "version": version,
            "working": 0,
            "minor_issue": 0,
            "rolled_back": 0,
            "total": 0,
            "matching_working": 0,
            "matching_minor_issue": 0,
            "matching_rolled_back": 0,
            "matching_total": 0,
        })
        status = report.get("result")
        if status in {"working", "minor_issue", "rolled_back"}:
            row[status] += 1
        row["total"] += 1
        remote_tags = {str(item).casefold() for item in report.get("environment_tags", []) if item}
        if local_tags and remote_tags and local_tags.intersection(remote_tags):
            row["matching_total"] += 1
            if status in {"working", "minor_issue", "rolled_back"}:
                row["matching_" + status] += 1
    result["update_pulse"] = sorted(
        pulse.values(), key=lambda row: (row["total"], row["version"]), reverse=True
    )


def aggregate_release(state=None):
    """Return v3 status with release-time trust and freshness filtering."""
    result = _previous_aggregate(state)
    blocked = _blocked_pubkeys()

    public_lists = (
        "ideas", "interests", "build_rooms", "joins", "setups", "tests", "results",
        "help_requests", "help_offers", "solutions", "solution_verifications",
        "ship_posts", "update_reports", "events", "event_rsvps", "challenges",
        "challenge_joins", "task_updates", "setup_components", "project_activity",
        "discover_feed", "contributors",
    )
    for key in public_lists:
        values = result.get(key)
        if isinstance(values, list):
            result[key] = _filtered(values, blocked)

    helpers = [
        item for item in result.get("helpers", [])
        if _not_blocked(item, blocked) and _helper_live(item)
    ]
    result["helpers"] = helpers
    result["pairing"] = [
        item for item in helpers
        if item.get("mode") in {"pair", "building"}
    ][:40]

    _recompute_derived(result, blocked)

    for request in result.get("help_requests", []):
        request["helper_matches"] = app._match_helpers(request, helpers)

    stats = result.setdefault("stats", {})
    stats.update({
        "ideas": len(result.get("ideas", [])),
        "build_rooms": len(result.get("build_rooms", [])),
        "setups": len(result.get("setups", [])),
        "tests": len(result.get("tests", [])),
        "ships": len(result.get("ship_posts", [])),
        "solutions": len(result.get("solutions", [])),
        "help_requests": len(result.get("help_requests", [])),
        "events": len(result.get("events", [])),
        "challenges": len(result.get("challenges", [])),
        "helps": len(result.get("help_offers", [])),
        "verifications": len(result.get("solution_verifications", [])),
        "task_updates": len(result.get("task_updates", [])),
        "helpers": len(helpers),
        "setup_components": len(result.get("setup_components", [])),
        "project_activity": len(result.get("project_activity", [])),
        "blocked_filtered": len(blocked),
    })

    state_obj = state if isinstance(state, dict) else core._build_state()
    pending = state_obj.get("pending_publish", [])
    stats["pending_publish"] = len(pending) if isinstance(pending, list) else 0
    result["release"] = {
        "app_version": APP_VERSION,
        "state_schema": int(state_obj.get("schema", 1) or 1),
        "pending_publish": stats["pending_publish"],
        "blocked_filtered": len(blocked),
    }
    return result


app.aggregate_v3 = aggregate_release
app.base._aggregate_status = aggregate_release


def _prepare_state():
    """Recover corrupt Build state and migrate schema with one private backup."""
    path = core.BUILD_STATE
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.exists():
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                raise ValueError("state is not an object")
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            corrupt = path.with_name(f"{path.stem}.corrupt-{int(time.time())}{path.suffix}")
            try:
                path.replace(corrupt)
                os.chmod(corrupt, 0o600)
            except OSError:
                pass

    state = core._build_state()
    try:
        schema = int(state.get("schema", 1) or 1)
    except (TypeError, ValueError):
        schema = 1
    if schema < STATE_SCHEMA:
        backup = path.with_name(f"{path.stem}.schema-{schema}.bak{path.suffix}")
        if path.exists() and not backup.exists():
            try:
                shutil.copy2(path, backup)
                os.chmod(backup, 0o600)
            except OSError:
                pass
        state["schema"] = STATE_SCHEMA
        state.setdefault("pending_publish", [])
        core._write_json(path, state)
    elif not isinstance(state.get("pending_publish"), list):
        state["pending_publish"] = []
        core._write_json(path, state)
    return state


def _store_and_publish_durable(model, success_message):
    """Remember relay-failed objects so a later Sync can republish them."""
    payload = model.to_payload()
    result = _previous_store_and_publish(model, success_message)
    if result.get("ok") is True:
        return result

    state = core._build_state()
    pending = state.setdefault("pending_publish", [])
    key = f"{payload.get('type','')}:{payload.get('id','')}"
    filtered = [
        item for item in pending
        if isinstance(item, dict)
        and f"{item.get('type','')}:{item.get('id','')}" != key
    ]
    if len(filtered) >= MAX_PENDING:
        result["message"] = "Saved locally, but the retry queue is full; this item was not queued for automatic retry"
        core._write_json(core.BUILD_STATE, state)
        return result
    filtered.append(payload)
    state["pending_publish"] = filtered
    core._write_json(core.BUILD_STATE, state)
    result["message"] = "Saved locally; Friends will retry this on the next Build Network sync"
    return result


core._store_and_publish = _store_and_publish_durable


def _retry_pending():
    """Retry a small oldest-first batch so an outage never freezes the UI for minutes."""
    state = core._build_state()
    pending = state.get("pending_publish", [])
    if not isinstance(pending, list) or not pending:
        return {"retried": 0, "published": 0, "remaining": 0}

    queue = [item for item in pending[-MAX_PENDING:] if isinstance(item, dict)]
    batch = queue[:MAX_RETRY_PER_SYNC]
    untouched = queue[MAX_RETRY_PER_SYNC:]
    failed = []
    published = 0
    objects = state.setdefault("objects", {})

    for payload in batch:
        try:
            model = core.parse_payload(payload)
            normalized = model.to_payload()
            ok, count, errors, event = core._publish(normalized)
        except (ValueError, TypeError, KeyError, OSError):
            ok = False
            count = 0
            errors = []
            event = None
        if ok and isinstance(event, dict):
            normalized["public_key"] = str(event.get("pubkey", ""))[:64]
            normalized["event_id"] = str(event.get("id", ""))[:64]
            normalized["updated_at"] = int(event.get("created_at", 0) or 0)
            normalized["mine"] = True
            objects[f"{normalized['public_key']}:{normalized.get('id','')}"] = normalized
            state["relay_ok"] = count
            state["last_errors"] = errors[:8]
            published += 1
        else:
            failed.append(payload)

    state["pending_publish"] = (failed + untouched)[-MAX_PENDING:]
    core._write_json(core.BUILD_STATE, state)
    return {
        "retried": len(batch),
        "published": published,
        "remaining": len(state["pending_publish"]),
    }


def _refresh_network_fair():
    """Refresh verified events while enforcing local block and per-author fairness."""
    state = core._build_state()
    objects = state.setdefault("objects", {})
    blocked = _blocked_pubkeys()
    seen_events = set()
    relay_ok = 0
    errors = []

    for relay_url in core.RELAYS:
        try:
            items = core._fetch_relay(relay_url)
            relay_ok += 1
        except (OSError, EOFError, ValueError) as exc:
            errors.append(f"{relay_url}: {type(exc).__name__}")
            continue
        for payload in items:
            public_key = str(payload.get("public_key", "")).lower()
            if public_key in blocked:
                continue
            event_id = payload.get("event_id")
            if event_id in seen_events:
                continue
            seen_events.add(event_id)
            key = f"{public_key}:{payload.get('id','')}"
            old = objects.get(key, {})
            if int(payload.get("updated_at", 0) or 0) >= int(old.get("updated_at", 0) or 0):
                objects[key] = payload

    own_key = core._identity(state)["public_key"]
    state["objects"] = _trim_fair(objects, own_key, blocked)
    state["last_refresh"] = int(time.time())
    state["relay_ok"] = relay_ok
    state["last_errors"] = errors[:8]
    core._write_json(core.BUILD_STATE, state)
    return state


def refresh_release():
    retry = _retry_pending()
    state = _refresh_network_fair()
    result = aggregate_release(state)
    result["retry"] = retry
    return result


core.refresh_network = refresh_release


# Community memory should outlive a normal live feed. The relay query still has
# an explicit result cap, so this is bounded even with the longer time window.
core.LOOKBACK_SECONDS = 365 * 24 * 60 * 60


def health_payload():
    state = _prepare_state()
    status = aggregate_release(state)
    return {
        "ok": True,
        "message": "Release health ready",
        "app_version": APP_VERSION,
        "state_schema": state.get("schema", 1),
        "objects": len(state.get("objects", {})) if isinstance(state.get("objects"), dict) else 0,
        "pending_publish": len(state.get("pending_publish", [])) if isinstance(state.get("pending_publish"), list) else 0,
        "retry_batch_size": MAX_RETRY_PER_SYNC,
        "max_cache_per_author": MAX_CACHE_PER_AUTHOR,
        "blocked_filtered": len(_blocked_pubkeys()),
        "active_helpers": len(status.get("helpers", [])),
        "relay_ok": status.get("relay_ok", 0),
        "relay_total": status.get("relay_total", 0),
        "last_refresh": status.get("last_refresh", 0),
    }


def main():
    _prepare_state()
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    if command == "health":
        print(json.dumps(health_payload(), ensure_ascii=False, separators=(",", ":")))
        return 0
    return app.main()


if __name__ == "__main__":
    raise SystemExit(main())
