#!/usr/bin/env python3
"""Release-hardening layer for Omarchy Friends Build Network v4.14.

This module intentionally adds no new social product concepts. It closes
release-quality gaps around stale availability, blocked builders, offline
publishing, durable community memory, state migration and health diagnostics.

The existing v3 implementation remains the source of truth for product actions.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import sys
import time

import build_network_app_v3 as app

core = app.base.core
APP_VERSION = "4.14.0"
STATE_SCHEMA = 2
MAX_PENDING = 64
DURABLE_TYPES = {
    "solution_card",
    "setup_card",
    "setup_component",
    "ship_post",
    "project_activity",
}

_previous_aggregate = app.aggregate_v3
_previous_store_and_publish = core._store_and_publish
_previous_refresh_network = core.refresh_network


def _blocked_pubkeys():
    main = core._main_state()
    global_state = main.get("global", {}) if isinstance(main, dict) else {}
    values = global_state.get("blocked_pubkeys", []) if isinstance(global_state, dict) else []
    return {
        str(value).strip().lower()
        for value in values
        if isinstance(value, str) and len(value.strip()) == 64
    }


def _helper_live(item, now=None):
    if not isinstance(item, dict) or item.get("status") != "active":
        return False
    now = int(time.time()) if now is None else int(now)
    try:
        created = int(item.get("created_at", 0) or 0)
        minutes = max(10, min(240, int(item.get("available_minutes", 30) or 30)))
    except (TypeError, ValueError, OverflowError):
        return False
    return created > 0 and created + minutes * 60 >= now


def _not_blocked(item, blocked):
    return not isinstance(item, dict) or str(item.get("public_key", "")).lower() not in blocked


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
            result[key] = [item for item in values if _not_blocked(item, blocked)]

    helpers = [
        item for item in result.get("helpers", [])
        if _not_blocked(item, blocked) and _helper_live(item)
    ]
    result["helpers"] = helpers
    result["pairing"] = [
        item for item in helpers
        if item.get("mode") in {"pair", "building"}
    ][:40]

    # Recompute matches after blocked/stale helpers have been removed.
    for request in result.get("help_requests", []):
        request["helper_matches"] = app._match_helpers(request, helpers)

    stats = result.setdefault("stats", {})
    stats["helpers"] = len(helpers)
    stats["blocked_filtered"] = len(blocked)
    state_obj = state if isinstance(state, dict) else core._build_state()
    stats["pending_publish"] = len(state_obj.get("pending_publish", [])) if isinstance(state_obj.get("pending_publish"), list) else 0
    result["release"] = {
        "app_version": APP_VERSION,
        "state_schema": int(state_obj.get("schema", 1) or 1),
        "pending_publish": stats["pending_publish"],
        "blocked_filtered": len(blocked),
    }
    return result


# Existing v2/v3 commands use these names dynamically when returning status.
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
    filtered.append(payload)
    state["pending_publish"] = filtered[-MAX_PENDING:]
    core._write_json(core.BUILD_STATE, state)
    result["message"] = "Saved locally; Friends will retry this on the next Build Network sync"
    return result


core._store_and_publish = _store_and_publish_durable


def _retry_pending():
    state = core._build_state()
    pending = state.get("pending_publish", [])
    if not isinstance(pending, list) or not pending:
        return {"retried": 0, "published": 0, "remaining": 0}

    remaining = []
    published = 0
    retried = 0
    objects = state.setdefault("objects", {})
    for payload in pending[-MAX_PENDING:]:
        if not isinstance(payload, dict):
            continue
        retried += 1
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
            remaining.append(payload)
    state["pending_publish"] = remaining[-MAX_PENDING:]
    core._write_json(core.BUILD_STATE, state)
    return {"retried": retried, "published": published, "remaining": len(remaining)}


def refresh_release():
    retry = _retry_pending()
    result = _previous_refresh_network()
    result = aggregate_release(core._build_state())
    result["retry"] = retry
    return result


core.refresh_network = refresh_release


# Live discovery stays bounded, but knowledge should not disappear after one month.
# A one-year lookback is still capped by the existing relay/query limits.
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
