#!/usr/bin/env python3
"""Unified CLI for the Omarchy Friends Build Network prototype.

It layers community loops (help, solutions, ship log, update pulse, events and
challenges) on the core collaboration runtime without touching the mature
Friends messaging engine.
"""

from __future__ import annotations

import json
import sys

import build_network_runtime as core
from build_network_social import (
    Challenge,
    CommunityEvent,
    HelpRequest,
    ShipPost,
    SolutionCard,
    UpdateReport,
    parse_social_payload,
)

# Teach the core relay reader about the extra signed object families while
# preserving the strict normalizer used by the core collaboration types.
_core_parse = core.parse_payload


def _combined_parse(payload):
    try:
        return _core_parse(payload)
    except ValueError:
        return parse_social_payload(payload)


core.parse_payload = _combined_parse


def _json_arg(index=2):
    try:
        value = json.loads(sys.argv[index])
        return value if isinstance(value, dict) else {}
    except (IndexError, ValueError, TypeError):
        return {}


def combined_status(state=None):
    state = state or core._build_state()
    base = core.status_payload(state)
    extras = {
        "help_requests": [],
        "solutions": [],
        "ship_posts": [],
        "update_reports": [],
        "events": [],
        "challenges": [],
    }
    mapping = {
        "help_request": "help_requests",
        "solution_card": "solutions",
        "ship_post": "ship_posts",
        "update_report": "update_reports",
        "community_event": "events",
        "challenge": "challenges",
    }
    all_objects = core._all_objects(state)
    for item in all_objects:
        bucket = mapping.get(item.get("type"))
        if bucket:
            extras[bucket].append(item)

    # Opt-in Update Pulse: aggregate only reports that people explicitly post.
    pulse = {}
    for report in extras["update_reports"]:
        version = report.get("version", "unknown") or "unknown"
        row = pulse.setdefault(version, {"version": version, "working": 0, "minor_issue": 0, "rolled_back": 0, "total": 0})
        result = report.get("result")
        if result in ("working", "minor_issue", "rolled_back"):
            row[result] += 1
        row["total"] += 1
    update_pulse = sorted(pulse.values(), key=lambda row: row["total"], reverse=True)

    # Contribution reputation, deliberately based on useful actions rather than
    # follower counts or engagement farming.
    contributions = {}
    labels = {
        "build_room": "builds",
        "setup_card": "setups",
        "test_result": "tests",
        "solution_card": "solutions",
        "ship_post": "ships",
        "help_request": "help_requests",
    }
    for item in all_objects:
        key = item.get("public_key", "")
        if not key:
            continue
        row = contributions.setdefault(key, {
            "public_key": key,
            "handle": item.get("author", "OmarchyBuilder"),
            "builds": 0,
            "setups": 0,
            "tests": 0,
            "solutions": 0,
            "ships": 0,
            "help_requests": 0,
        })
        field = labels.get(item.get("type"))
        if field:
            row[field] += 1
        if item.get("author"):
            row["handle"] = item.get("author")
    contributors = sorted(contributions.values(), key=lambda row: row["builds"] + row["setups"] + row["tests"] + row["solutions"] + row["ships"], reverse=True)[:40]

    feed_types = {"ship_post", "setup_card", "build_room", "idea", "solution_card", "community_event", "challenge", "help_request"}
    discover_feed = [item for item in all_objects if item.get("type") in feed_types][:120]

    base.update(extras)
    base["update_pulse"] = update_pulse
    base["contributors"] = contributors
    base["discover_feed"] = discover_feed
    base["stats"].update({
        "ships": len(extras["ship_posts"]),
        "solutions": len(extras["solutions"]),
        "help_requests": len(extras["help_requests"]),
        "events": len(extras["events"]),
        "challenges": len(extras["challenges"]),
    })
    return base


def _finish(result):
    state = core._build_state()
    full = combined_status(state)
    full["ok"] = result.get("ok") is True
    full["message"] = result.get("message", "")
    if result.get("setup") is not None:
        full["setup"] = result["setup"]
    return full


def create_help():
    data = _json_arg()
    return core._store_and_publish(HelpRequest(title=data.get("title", ""), problem=data.get("problem", ""), tried=data.get("tried", ""), environment_tags=data.get("environment_tags", []), author=core._handle()), "Help request shared")


def create_solution():
    data = _json_arg()
    return core._store_and_publish(SolutionCard(title=data.get("title", ""), problem=data.get("problem", ""), solution=data.get("solution", ""), environment_tags=data.get("environment_tags", []), source_url=data.get("source_url", ""), author=core._handle()), "Solution added to community memory")


def create_ship():
    data = _json_arg()
    return core._store_and_publish(ShipPost(title=data.get("title", ""), summary=data.get("summary", ""), artifact_url=data.get("artifact_url", ""), tags=data.get("tags", []), build_room_id=data.get("build_room_id", ""), author=core._handle()), "Shipped post shared")


def report_update():
    data = _json_arg()
    return core._store_and_publish(UpdateReport(version=data.get("version", ""), result=data.get("result", "minor_issue"), environment_tags=data.get("environment_tags", []), note=data.get("note", ""), author=core._handle()), "Update experience added to the pulse")


def create_event():
    data = _json_arg()
    return core._store_and_publish(CommunityEvent(title=data.get("title", ""), when_text=data.get("when_text", ""), location=data.get("location", ""), event_url=data.get("event_url", ""), notes=data.get("notes", ""), author=core._handle()), "Community event shared")


def create_challenge():
    data = _json_arg()
    return core._store_and_publish(Challenge(title=data.get("title", ""), prompt=data.get("prompt", ""), deadline_text=data.get("deadline_text", ""), rules_url=data.get("rules_url", ""), tags=data.get("tags", []), author=core._handle()), "Build challenge shared")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if command == "status":
            result = combined_status()
        elif command == "refresh":
            core.refresh_network()
            result = combined_status()
            result["message"] = "Build Network refreshed"
        elif command == "inspect-setup":
            result = {"ok": True, "setup": core.inspect_local_setup(), "message": "Safe setup metadata inspected"}
        elif command == "create-help":
            result = _finish(create_help())
        elif command == "create-solution":
            result = _finish(create_solution())
        elif command == "ship":
            result = _finish(create_ship())
        elif command == "report-update":
            result = _finish(report_update())
        elif command == "create-event":
            result = _finish(create_event())
        elif command == "create-challenge":
            result = _finish(create_challenge())
        elif command == "create-idea":
            result = _finish(core.command_create_idea())
        elif command == "interest":
            result = _finish(core.command_interest())
        elif command == "create-room":
            result = _finish(core.command_create_room())
        elif command == "room-from-idea":
            result = _finish(core.command_room_from_idea())
        elif command == "join-room":
            result = _finish(core.command_join_room())
        elif command == "create-setup":
            result = _finish(core.command_create_setup())
        elif command == "create-test":
            result = _finish(core.command_create_test())
        elif command == "test-result":
            result = _finish(core.command_test_result())
        elif command == "hide":
            result = _finish(core.command_hide())
        else:
            result = {"ok": False, "message": f"Unknown Build Network command: {command}"}
    except (ValueError, TypeError, KeyError) as exc:
        result = {"ok": False, "message": str(exc)[:240] or "Build Network rejected that payload"}
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
