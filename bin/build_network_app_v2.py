#!/usr/bin/env python3
"""Production-shaped Build Network runtime for Omarchy Friends.

This v2 entrypoint keeps the existing signed Nostr transport and adds richer
participation, safe local comparison helpers, environment-aware testing/help,
and object lifecycle actions. Remote metadata is never executed.
"""

from __future__ import annotations

import json
import platform
import re
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
from build_network_v2 import (
    BuildTaskUpdate,
    ChallengeJoin,
    EventRSVP,
    HelpOffer,
    SolutionVerification,
    parse_v2_payload,
)

_core_parse = core.parse_payload


def _combined_parse(payload):
    for parser in (_core_parse, parse_social_payload, parse_v2_payload):
        try:
            return parser(payload)
        except ValueError:
            pass
    raise ValueError("unsupported Build Network payload")


core.parse_payload = _combined_parse


def _json_arg(index=2):
    try:
        value = json.loads(sys.argv[index])
        return value if isinstance(value, dict) else {}
    except (IndexError, ValueError, TypeError):
        return {}


def _safe_version(text):
    match = re.search(r"\d+(?:\.\d+){1,3}", str(text or ""))
    return match.group(0)[:32] if match else ""


def safe_environment():
    """Collect non-identifying environment labels for explicit user sharing.

    No hostname, username, IP address, serial number, file content or device ID
    is collected. These values stay local unless the user explicitly publishes
    them in a help/test/update object.
    """
    arch = platform.machine()[:32]
    kernel = platform.release()[:64]
    omarchy_raw = core._run_text(["omarchy", "--version"], timeout=1.0)
    omarchy_version = _safe_version(omarchy_raw)
    gpu_line = core._run_text(["lspci"], timeout=1.0)
    gpu = ""
    lower = gpu_line.lower()
    if "nvidia" in lower:
        gpu = "NVIDIA"
    elif "amd" in lower or "ati" in lower:
        gpu = "AMD"
    elif "intel" in lower and ("vga" in lower or "display" in lower or "3d controller" in lower):
        gpu = "Intel"

    tags = []
    for value in (
        "Omarchy" + (" " + omarchy_version if omarchy_version else ""),
        arch,
        gpu,
        "Kernel " + kernel.split("-", 1)[0] if kernel else "",
    ):
        value = " ".join(str(value or "").split())[:40]
        if value and value.casefold() not in {item.casefold() for item in tags}:
            tags.append(value)
    return {
        "tags": tags[:12],
        "omarchy_version": omarchy_version,
        "architecture": arch,
        "gpu_vendor": gpu,
        "kernel": kernel,
    }


def _find(object_id, kind=None):
    return core._find_object(str(object_id or "")[:64], kind)


def _mine(item):
    return bool(item) and item.get("public_key") == core._identity(core._build_state())["public_key"]


def compare_setup(setup_id):
    card = _find(setup_id, "setup_card")
    if not card:
        raise ValueError("That Setup Card is not in your current cache")
    local = core.inspect_local_setup()
    local_plugins = {str(item).casefold(): str(item) for item in local.get("plugins", [])}
    remote_plugins = {str(item).casefold(): str(item) for item in card.get("plugins", [])}
    missing = [remote_plugins[key] for key in sorted(set(remote_plugins) - set(local_plugins))]
    already = [remote_plugins[key] for key in sorted(set(remote_plugins) & set(local_plugins))]
    local_only = [local_plugins[key] for key in sorted(set(local_plugins) - set(remote_plugins))]

    fields = []
    for key, label in (("theme", "Theme"), ("shell", "Shell"), ("terminal", "Terminal"), ("editor", "Editor")):
        current = str(local.get(key, "") or "")
        wanted = str(card.get(key, "") or "")
        if not wanted:
            status = "unspecified"
        elif current.casefold() == wanted.casefold():
            status = "match"
        else:
            status = "different"
        fields.append({"field": key, "label": label, "current": current, "wanted": wanted, "status": status})

    return {
        "setup_id": card.get("id", ""),
        "title": card.get("title", "Setup"),
        "author": card.get("author", "Builder"),
        "missing_plugins": missing[:32],
        "already_have_plugins": already[:32],
        "local_only_plugins": local_only[:32],
        "fields": fields,
        "safe": True,
        "message": "Comparison only — nothing will be installed automatically",
    }


def _aggregate_status(state=None):
    state = state or core._build_state()
    base = core.status_payload(state)
    all_objects = core._all_objects(state)
    bucket_names = (
        "help_requests", "solutions", "ship_posts", "update_reports", "events", "challenges",
        "help_offers", "solution_verifications", "event_rsvps", "challenge_joins", "task_updates",
    )
    extras = {name: [] for name in bucket_names}
    mapping = {
        "help_request": "help_requests",
        "solution_card": "solutions",
        "ship_post": "ship_posts",
        "update_report": "update_reports",
        "community_event": "events",
        "challenge": "challenges",
        "help_offer": "help_offers",
        "solution_verification": "solution_verifications",
        "event_rsvp": "event_rsvps",
        "challenge_join": "challenge_joins",
        "build_task_update": "task_updates",
    }
    for item in all_objects:
        bucket = mapping.get(item.get("type"))
        if bucket:
            extras[bucket].append(item)

    help_counts = {}
    for item in extras["help_offers"]:
        help_counts[item.get("help_id", "")] = help_counts.get(item.get("help_id", ""), 0) + 1
    for item in extras["help_requests"]:
        item["offer_count"] = help_counts.get(item.get("id", ""), 0)

    verify_counts = {}
    worked_counts = {}
    for item in extras["solution_verifications"]:
        sid = item.get("solution_id", "")
        verify_counts[sid] = verify_counts.get(sid, 0) + 1
        if item.get("result") == "worked":
            worked_counts[sid] = worked_counts.get(sid, 0) + 1
    for item in extras["solutions"]:
        sid = item.get("id", "")
        item["verification_count"] = verify_counts.get(sid, 0)
        item["worked_count"] = worked_counts.get(sid, 0)

    rsvp = {}
    for item in extras["event_rsvps"]:
        eid = item.get("event_id", "")
        row = rsvp.setdefault(eid, {"going": 0, "interested": 0})
        response = item.get("response", "interested")
        if response in row:
            row[response] += 1
    for item in extras["events"]:
        row = rsvp.get(item.get("id", ""), {"going": 0, "interested": 0})
        item.update({"going_count": row["going"], "interested_count": row["interested"]})

    challenge_counts = {}
    for item in extras["challenge_joins"]:
        cid = item.get("challenge_id", "")
        challenge_counts[cid] = challenge_counts.get(cid, 0) + 1
    for item in extras["challenges"]:
        item["join_count"] = challenge_counts.get(item.get("id", ""), 0)

    task_by_room = {}
    for item in extras["task_updates"]:
        task_by_room.setdefault(item.get("room_id", ""), []).append(item)
    for room in base.get("build_rooms", []):
        room["task_updates"] = task_by_room.get(room.get("id", ""), [])[:24]
        room["done_count"] = sum(1 for item in room["task_updates"] if item.get("status") == "done")
        room["blocked_count"] = sum(1 for item in room["task_updates"] if item.get("status") == "blocked")

    env = safe_environment()
    local_tags = {item.casefold() for item in env["tags"]}
    pulse = {}
    for report in extras["update_reports"]:
        version = report.get("version", "unknown") or "unknown"
        row = pulse.setdefault(version, {
            "version": version, "working": 0, "minor_issue": 0, "rolled_back": 0, "total": 0,
            "matching_working": 0, "matching_minor_issue": 0, "matching_rolled_back": 0, "matching_total": 0,
        })
        result = report.get("result")
        if result in ("working", "minor_issue", "rolled_back"):
            row[result] += 1
        row["total"] += 1
        report_tags = {str(item).casefold() for item in report.get("environment_tags", [])}
        if local_tags and report_tags and local_tags.intersection(report_tags):
            row["matching_total"] += 1
            if result in ("working", "minor_issue", "rolled_back"):
                row["matching_" + result] += 1
    update_pulse = sorted(pulse.values(), key=lambda row: (row["total"], row["version"]), reverse=True)

    contributions = {}
    score_fields = {
        "build_room": "builds", "setup_card": "setups", "test_result": "tests", "solution_card": "solutions",
        "solution_verification": "verifications", "ship_post": "ships", "help_offer": "helps", "build_task_update": "tasks",
    }
    for item in all_objects:
        key = item.get("public_key", "")
        if not key:
            continue
        row = contributions.setdefault(key, {
            "public_key": key, "handle": item.get("author", "OmarchyBuilder"), "builds": 0, "setups": 0,
            "tests": 0, "solutions": 0, "verifications": 0, "ships": 0, "helps": 0, "tasks": 0,
        })
        field = score_fields.get(item.get("type"))
        if field:
            row[field] += 1
        if item.get("author"):
            row["handle"] = item.get("author")
    contributors = sorted(
        contributions.values(),
        key=lambda row: row["builds"] * 3 + row["ships"] * 3 + row["solutions"] * 2 + row["helps"] * 2 + row["tests"] + row["verifications"] + row["tasks"],
        reverse=True,
    )[:40]

    feed_types = {"ship_post", "setup_card", "build_room", "idea", "solution_card", "community_event", "challenge", "help_request"}
    discover_feed = [item for item in all_objects if item.get("type") in feed_types][:120]

    saved = state.get("saved", []) if isinstance(state.get("saved"), list) else []
    base.update(extras)
    base.update({
        "update_pulse": update_pulse,
        "contributors": contributors,
        "discover_feed": discover_feed,
        "environment": env,
        "saved": saved[-200:],
    })
    base["stats"].update({
        "ships": len(extras["ship_posts"]), "solutions": len(extras["solutions"]), "help_requests": len(extras["help_requests"]),
        "events": len(extras["events"]), "challenges": len(extras["challenges"]), "helps": len(extras["help_offers"]),
        "verifications": len(extras["solution_verifications"]), "task_updates": len(extras["task_updates"]),
    })
    return base


def _finish(result):
    full = _aggregate_status(core._build_state())
    full["ok"] = result.get("ok") is True
    full["message"] = result.get("message", "")
    for key in ("setup", "comparison", "environment"):
        if key in result:
            full[key] = result[key]
    return full


def _publish(model, message):
    return core._store_and_publish(model, message)


def create_help(data):
    tags = list(data.get("environment_tags", []) or [])
    if data.get("use_detected"):
        tags.extend(safe_environment()["tags"])
    return _publish(HelpRequest(title=data.get("title", ""), problem=data.get("problem", ""), tried=data.get("tried", ""), environment_tags=tags, author=core._handle()), "Help request shared")


def offer_help(data):
    hid = str(data.get("help_id", ""))[:64]
    if not _find(hid, "help_request"):
        return {"ok": False, "message": "That help request is not in your cache"}
    tags = list(data.get("environment_tags", []) or [])
    if data.get("use_detected"):
        tags.extend(safe_environment()["tags"])
    return _publish(HelpOffer(help_id=hid, note=data.get("note", ""), environment_tags=tags, author=core._handle()), "Offered to help — use Friends chat for private follow-up")


def resolve_help(data):
    item = _find(data.get("help_id"), "help_request")
    if not item or not _mine(item):
        return {"ok": False, "message": "Only the author can close that help request"}
    status = data.get("status", "solved")
    status = status if status in {"solved", "closed"} else "solved"
    model = HelpRequest(title=item.get("title", ""), problem=item.get("problem", ""), tried=item.get("tried", ""), environment_tags=item.get("environment_tags", []), author=core._handle(), id=item.get("id", ""), created_at=item.get("created_at", 0), status=status)
    return _publish(model, "Help request updated")


def create_solution(data):
    return _publish(SolutionCard(title=data.get("title", ""), problem=data.get("problem", ""), solution=data.get("solution", ""), environment_tags=data.get("environment_tags", []), source_url=data.get("source_url", ""), author=core._handle()), "Solution added to community memory")


def verify_solution(data):
    sid = str(data.get("solution_id", ""))[:64]
    if not _find(sid, "solution_card"):
        return {"ok": False, "message": "That solution is not in your cache"}
    tags = list(data.get("environment_tags", []) or [])
    if data.get("use_detected"):
        tags.extend(safe_environment()["tags"])
    return _publish(SolutionVerification(solution_id=sid, result=data.get("result", "worked"), environment_tags=tags, note=data.get("note", ""), author=core._handle()), "Solution verification shared")


def create_ship(data):
    return _publish(ShipPost(title=data.get("title", ""), summary=data.get("summary", ""), artifact_url=data.get("artifact_url", ""), tags=data.get("tags", []), build_room_id=data.get("build_room_id", ""), author=core._handle()), "Shipped post shared")


def report_update(data):
    tags = list(data.get("environment_tags", []) or [])
    if data.get("use_detected"):
        tags.extend(safe_environment()["tags"])
    return _publish(UpdateReport(version=data.get("version", ""), result=data.get("result", "minor_issue"), environment_tags=tags, note=data.get("note", ""), author=core._handle()), "Update experience added to the pulse")


def create_event(data):
    return _publish(CommunityEvent(title=data.get("title", ""), when_text=data.get("when_text", ""), location=data.get("location", ""), event_url=data.get("event_url", ""), notes=data.get("notes", ""), author=core._handle()), "Community event shared")


def rsvp_event(data):
    eid = str(data.get("event_id", ""))[:64]
    if not _find(eid, "community_event"):
        return {"ok": False, "message": "That event is not in your cache"}
    return _publish(EventRSVP(event_id=eid, response=data.get("response", "interested"), note=data.get("note", ""), author=core._handle()), "RSVP shared")


def create_challenge(data):
    return _publish(Challenge(title=data.get("title", ""), prompt=data.get("prompt", ""), deadline_text=data.get("deadline_text", ""), rules_url=data.get("rules_url", ""), tags=data.get("tags", []), author=core._handle()), "Build challenge shared")


def join_challenge(data):
    cid = str(data.get("challenge_id", ""))[:64]
    if not _find(cid, "challenge"):
        return {"ok": False, "message": "That challenge is not in your cache"}
    return _publish(ChallengeJoin(challenge_id=cid, team_name=data.get("team_name", ""), repo_url=data.get("repo_url", ""), note=data.get("note", ""), author=core._handle()), "Joined the challenge")


def task_update(data):
    rid = str(data.get("room_id", ""))[:64]
    if not _find(rid, "build_room"):
        return {"ok": False, "message": "That Build Room is not in your cache"}
    return _publish(BuildTaskUpdate(room_id=rid, task=data.get("task", ""), status=data.get("status", "doing"), note=data.get("note", ""), author=core._handle()), "Build task updated")


def update_room(data):
    item = _find(data.get("room_id"), "build_room")
    if not item or not _mine(item):
        return {"ok": False, "message": "Only the Build Room owner can update it"}
    status = data.get("status", item.get("status", "building"))
    model = core.BuildRoom(
        title=data.get("title", item.get("title", "")),
        goal=data.get("goal", item.get("goal", "")),
        repo_url=data.get("repo_url", item.get("repo_url", "")),
        roles_needed=data.get("roles_needed", item.get("roles_needed", [])),
        tasks=data.get("tasks", item.get("tasks", [])),
        members=item.get("members", []),
        source_idea_id=item.get("source_idea_id", ""),
        owner=core._handle(), id=item.get("id", ""), created_at=item.get("created_at", 0), status=status,
    )
    return _publish(model, "Build Room updated")


def save_object(data):
    item = _find(data.get("id"))
    if not item:
        return {"ok": False, "message": "That object is not in your cache"}
    state = core._build_state()
    key = f"{item.get('public_key','')}:{item.get('id','')}"
    saved = state.setdefault("saved", [])
    if key not in saved:
        saved.append(key)
    state["saved"] = saved[-200:]
    core._write_json(core.BUILD_STATE, state)
    return {"ok": True, "message": "Saved on this device"}


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    data = _json_arg()
    try:
        if command == "status":
            result = _aggregate_status()
        elif command == "refresh":
            core.refresh_network()
            result = _aggregate_status()
            result["message"] = "Build Network refreshed"
        elif command == "inspect-setup":
            result = _aggregate_status(); result.update({"ok": True, "setup": core.inspect_local_setup(), "message": "Safe setup metadata inspected"})
        elif command == "inspect-environment":
            result = _aggregate_status(); result.update({"ok": True, "environment": safe_environment(), "message": "Safe environment labels inspected"})
        elif command == "compare-setup":
            result = _aggregate_status(); result.update({"ok": True, "comparison": compare_setup(data.get("setup_id")), "message": "Setup comparison ready"})
        elif command == "create-help": result = _finish(create_help(data))
        elif command == "offer-help": result = _finish(offer_help(data))
        elif command == "resolve-help": result = _finish(resolve_help(data))
        elif command == "create-solution": result = _finish(create_solution(data))
        elif command == "verify-solution": result = _finish(verify_solution(data))
        elif command == "ship": result = _finish(create_ship(data))
        elif command == "report-update": result = _finish(report_update(data))
        elif command == "create-event": result = _finish(create_event(data))
        elif command == "rsvp-event": result = _finish(rsvp_event(data))
        elif command == "create-challenge": result = _finish(create_challenge(data))
        elif command == "join-challenge": result = _finish(join_challenge(data))
        elif command == "task-update": result = _finish(task_update(data))
        elif command == "update-room": result = _finish(update_room(data))
        elif command == "save": result = _finish(save_object(data))
        elif command == "create-idea": result = _finish(core.command_create_idea())
        elif command == "interest": result = _finish(core.command_interest())
        elif command == "create-room": result = _finish(core.command_create_room())
        elif command == "room-from-idea": result = _finish(core.command_room_from_idea())
        elif command == "join-room": result = _finish(core.command_join_room())
        elif command == "create-setup": result = _finish(core.command_create_setup())
        elif command == "create-test": result = _finish(core.command_create_test())
        elif command == "test-result": result = _finish(core.command_test_result())
        elif command == "hide": result = _finish(core.command_hide())
        else:
            result = {"ok": False, "message": f"Unknown Build Network command: {command}"}
    except (ValueError, TypeError, KeyError) as exc:
        result = {"ok": False, "message": str(exc)[:240] or "Build Network rejected that payload"}
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
