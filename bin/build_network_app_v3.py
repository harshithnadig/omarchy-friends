#!/usr/bin/env python3
"""Promise-complete Build Network entrypoint for Omarchy Friends v4.14.

This layer extends v2 without replacing its stable collaboration logic. It adds
Can Help / Pair availability and matching, individual setup-component sharing,
project activity cards, an explicit public-GitHub snapshot helper, Help ->
Solution conversion, safe external share text, and idempotent invite URI
registration.

Security boundary: remote cards are metadata only. This module does not execute
remote commands, install shared setup components, read dotfile contents, or
send private chat history to relays.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

import build_network_app_v2 as base
from build_network_social import SolutionCard
from build_network_v3 import (
    HelperAvailability,
    ProjectActivity,
    SetupComponentShare,
    parse_v3_payload,
)


_previous_parse = base.core.parse_payload
_base_aggregate = base._aggregate_status


def _combined_parse_v3(payload):
    try:
        return _previous_parse(payload)
    except ValueError:
        return parse_v3_payload(payload)


base.core.parse_payload = _combined_parse_v3


def _json_arg(index=2):
    try:
        value = json.loads(sys.argv[index])
        return value if isinstance(value, dict) else {}
    except (IndexError, ValueError, TypeError):
        return {}


def _norm_tags(values):
    out = []
    seen = set()
    for raw in values or []:
        value = " ".join(str(raw or "").strip().split())[:48]
        key = value.casefold()
        if value and key not in seen:
            out.append(value)
            seen.add(key)
        if len(out) >= 16:
            break
    return out


def _own_public_key():
    return base.core._identity(base.core._build_state())["public_key"]


def _latest_own_helper():
    mine = [
        item for item in base.core._all_objects(base.core._build_state())
        if item.get("type") == "helper_availability" and item.get("public_key") == _own_public_key()
    ]
    return mine[0] if mine else None


def _match_helpers(help_request, helpers):
    """Return useful human matches without pretending this is a popularity rank."""
    help_tags = {str(item).casefold() for item in help_request.get("environment_tags", []) if item}
    haystack = " ".join([
        str(help_request.get("title", "")),
        str(help_request.get("problem", "")),
        str(help_request.get("tried", "")),
        " ".join(help_request.get("environment_tags", []) or []),
    ]).casefold()
    matches = []
    for helper in helpers:
        if helper.get("status") != "active" or helper.get("public_key") == help_request.get("public_key"):
            continue
        env = {str(item).casefold() for item in helper.get("environment_tags", []) if item}
        skills = [str(item).casefold() for item in helper.get("skills", []) if item]
        env_overlap = sorted(help_tags.intersection(env))
        skill_hits = [skill for skill in skills if skill and skill in haystack]
        score = len(env_overlap) * 3 + len(skill_hits) * 2
        if score <= 0 and helper.get("mode") != "pair":
            continue
        matches.append({
            "public_key": helper.get("public_key", ""),
            "handle": helper.get("author", "OmarchyBuilder"),
            "mode": helper.get("mode", "can_help"),
            "available_minutes": helper.get("available_minutes", 30),
            "note": helper.get("note", ""),
            "environment_overlap": env_overlap[:6],
            "skill_hits": skill_hits[:6],
            "match_score": score,
        })
    matches.sort(key=lambda item: (-item["match_score"], item["handle"].casefold()))
    return matches[:12]


def aggregate_v3(state=None):
    state = state or base.core._build_state()
    status = _base_aggregate(state)
    objects = base.core._all_objects(state)
    helpers = [item for item in objects if item.get("type") == "helper_availability"]
    components = [item for item in objects if item.get("type") == "setup_component"]
    activities = [item for item in objects if item.get("type") == "project_activity"]

    for request in status.get("help_requests", []):
        request["helper_matches"] = _match_helpers(request, helpers)

    room_activity = {}
    for item in activities:
        room_activity.setdefault(item.get("room_id", ""), []).append(item)
    for room in status.get("build_rooms", []):
        room["project_activity"] = room_activity.get(room.get("id", ""), [])[:16]

    setup_components = {}
    for item in components:
        setup_components.setdefault(item.get("setup_id", ""), []).append(item)
    for setup in status.get("setups", []):
        setup["shared_components"] = setup_components.get(setup.get("id", ""), [])[:24]

    status.update({
        "helpers": helpers[:80],
        "setup_components": components[:120],
        "project_activity": activities[:160],
        "pairing": [item for item in helpers if item.get("status") == "active" and item.get("mode") in {"pair", "building"}][:40],
    })
    status["stats"].update({
        "helpers": len([item for item in helpers if item.get("status") == "active"]),
        "setup_components": len(components),
        "project_activity": len(activities),
    })
    return status


# Make all existing v2 commands return the richer status too.
base._aggregate_status = aggregate_v3


def set_availability(data):
    tags = list(data.get("environment_tags", []) or [])
    if data.get("use_detected", True):
        tags.extend(base.safe_environment()["tags"])
    previous = _latest_own_helper()
    model = HelperAvailability(
        mode=data.get("mode", "can_help"),
        skills=_norm_tags(data.get("skills", [])),
        environment_tags=_norm_tags(tags),
        note=data.get("note", ""),
        available_minutes=data.get("available_minutes", 30),
        author=base.core._handle(),
        id=previous.get("id") if previous else None,
        created_at=previous.get("created_at", 0) if previous else 0,
        status=data.get("status", "active"),
    ) if previous else HelperAvailability(
        mode=data.get("mode", "can_help"),
        skills=_norm_tags(data.get("skills", [])),
        environment_tags=_norm_tags(tags),
        note=data.get("note", ""),
        available_minutes=data.get("available_minutes", 30),
        author=base.core._handle(),
        status=data.get("status", "active"),
    )
    return base._publish(model, "Availability shared with Omarchy builders")


def share_component(data):
    setup_id = str(data.get("setup_id", ""))[:64]
    if setup_id and not base._find(setup_id, "setup_card"):
        return {"ok": False, "message": "That Setup Card is not in your cache"}
    model = SetupComponentShare(
        component_type=data.get("component_type", "other"),
        name=data.get("name", ""),
        source_url=data.get("source_url", ""),
        setup_id=setup_id,
        tags=data.get("tags", []),
        notes=data.get("notes", ""),
        author=base.core._handle(),
    )
    return base._publish(model, "Setup component shared")


def publish_activity(data):
    room_id = str(data.get("room_id", ""))[:64]
    if room_id and not base._find(room_id, "build_room"):
        return {"ok": False, "message": "That Build Room is not in your cache"}
    model = ProjectActivity(
        activity_type=data.get("activity_type", "discussion"),
        title=data.get("title", ""),
        url=data.get("url", ""),
        room_id=room_id,
        repo_url=data.get("repo_url", ""),
        state=data.get("state", "info"),
        reference=data.get("reference", ""),
        author=base.core._handle(),
    )
    return base._publish(model, "Project activity shared")


def solution_from_help(data):
    help_item = base._find(data.get("help_id"), "help_request")
    if not help_item:
        return {"ok": False, "message": "That help request is not in your cache"}
    solution = " ".join(str(data.get("solution", "")).strip().split())
    if not solution:
        return {"ok": False, "message": "Write the solution before publishing it"}
    model = SolutionCard(
        title=(str(data.get("title", "")).strip() or help_item.get("title", "Solved Omarchy issue")),
        problem=help_item.get("problem", ""),
        solution=solution,
        environment_tags=help_item.get("environment_tags", []),
        source_url=data.get("source_url", ""),
        author=base.core._handle(),
    )
    return base._publish(model, "Help thread turned into a reusable Solution Card")


def _github_repo_parts(repo_url):
    parsed = urllib.parse.urlparse(str(repo_url or ""))
    if parsed.scheme != "https" or parsed.hostname not in {"github.com", "www.github.com"}:
        raise ValueError("GitHub snapshot only accepts https://github.com/owner/repo URLs")
    parts = [item for item in parsed.path.split("/") if item]
    if len(parts) < 2:
        raise ValueError("GitHub repository URL is incomplete")
    owner = re.sub(r"[^A-Za-z0-9_.-]", "", parts[0])[:100]
    repo = re.sub(r"[^A-Za-z0-9_.-]", "", parts[1].removesuffix(".git"))[:100]
    if not owner or not repo:
        raise ValueError("GitHub repository URL is invalid")
    return owner, repo


def _github_json(url):
    request = urllib.request.Request(
        url,
        headers={"Accept": "application/vnd.github+json", "User-Agent": "omarchy-friends-build-network"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=3.5) as response:
            data = json.loads(response.read(256_000).decode("utf-8"))
            return data
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError) as exc:
        raise ValueError("GitHub snapshot is temporarily unavailable") from exc


def github_snapshot(repo_url):
    owner, repo = _github_repo_parts(repo_url)
    root = f"https://api.github.com/repos/{owner}/{repo}"
    commits = _github_json(root + "/commits?per_page=3")
    pulls = _github_json(root + "/pulls?state=open&per_page=5")
    issues_raw = _github_json(root + "/issues?state=open&per_page=8")
    issues = [item for item in issues_raw if "pull_request" not in item][:5] if isinstance(issues_raw, list) else []

    activity = []
    for item in commits if isinstance(commits, list) else []:
        commit = item.get("commit", {}) if isinstance(item, dict) else {}
        message = str(commit.get("message", "")).split("\n", 1)[0][:140]
        activity.append({"activity_type": "commit", "title": message, "url": item.get("html_url", ""), "reference": str(item.get("sha", ""))[:7], "state": "info"})
    for item in pulls if isinstance(pulls, list) else []:
        activity.append({"activity_type": "pull_request", "title": str(item.get("title", ""))[:140], "url": item.get("html_url", ""), "reference": "#" + str(item.get("number", "")), "state": "open"})
    for item in issues:
        activity.append({"activity_type": "issue", "title": str(item.get("title", ""))[:140], "url": item.get("html_url", ""), "reference": "#" + str(item.get("number", "")), "state": "open"})
    return {"repo_url": f"https://github.com/{owner}/{repo}", "items": activity[:13], "public_only": True}


def share_text_for(object_id):
    item = base._find(object_id)
    if not item:
        raise ValueError("That object is not in your cache")
    kind = item.get("type", "community")
    title = item.get("title") or item.get("name") or "Omarchy community update"
    author = item.get("author", "OmarchyBuilder")
    detail = item.get("summary") or item.get("goal") or item.get("problem") or item.get("solution") or item.get("notes") or item.get("prompt") or ""
    link = item.get("artifact_url") or item.get("repo_url") or item.get("source_url") or item.get("event_url") or item.get("url") or ""
    icon = {
        "idea": "💡", "build_room": "🛠", "setup_card": "🖥", "setup_component": "✨",
        "test_request": "🧪", "help_request": "🆘", "solution_card": "🧠", "ship_post": "🚀",
        "community_event": "📍", "challenge": "🏆", "project_activity": "🔗",
    }.get(kind, "✦")
    lines = [f"{icon} {title}", f"by {author}"]
    if detail:
        lines.append(str(detail)[:360])
    if link:
        lines.append(str(link))
    lines.append("Shared from Omarchy Friends")
    return "\n".join(lines)


def ensure_uri_registration():
    """Best-effort, idempotent registration for omarchy-friends:// links."""
    handler = (Path(__file__).resolve().parent / "omarchy-friends-open").resolve()
    applications = Path.home() / ".local" / "share" / "applications"
    desktop = applications / "omarchy-friends.desktop"
    python = Path(sys.executable).resolve()
    def desk_quote(path):
        return '"' + str(path).replace('\\', '\\\\').replace('"', '\\"') + '"'
    content = "\n".join([
        "[Desktop Entry]",
        "Type=Application",
        "Name=Omarchy Friends",
        "Comment=Open Omarchy Friends invite links",
        f"Exec={desk_quote(python)} {desk_quote(handler)} %u",
        "NoDisplay=true",
        "Terminal=false",
        "MimeType=x-scheme-handler/omarchy-friends;",
        "Categories=Network;Chat;",
        "",
    ])
    applications.mkdir(parents=True, exist_ok=True)
    changed = True
    try:
        changed = desktop.read_text(encoding="utf-8") != content
    except OSError:
        pass
    if changed:
        desktop.write_text(content, encoding="utf-8")
        try:
            os.chmod(desktop, 0o644)
        except OSError:
            pass
        for command in (
            ["xdg-mime", "default", desktop.name, "x-scheme-handler/omarchy-friends"],
            ["update-desktop-database", str(applications)],
        ):
            try:
                subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0, check=False)
            except (OSError, subprocess.SubprocessError):
                pass
    return {"registered": desktop.exists(), "desktop_file": str(desktop), "handler": str(handler), "changed": changed}


def _finish(result, **extra):
    full = aggregate_v3(base.core._build_state())
    full["ok"] = result.get("ok") is True
    full["message"] = result.get("message", "")
    full.update(extra)
    return full


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    data = _json_arg()
    try:
        # Status is called when the QML service starts. Registration is local,
        # idempotent, and only reruns xdg-mime when the desktop entry changes.
        if command in {"status", "register-uri"}:
            registration = ensure_uri_registration()
            if command == "register-uri":
                result = aggregate_v3(); result.update({"ok": registration["registered"], "registration": registration, "message": "Invite link handler registered" if registration["registered"] else "Invite handler registration needs local validation"})
                print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
                return 0 if result.get("ok") else 1

        if command == "set-availability":
            result = _finish(set_availability(data))
        elif command == "share-component":
            result = _finish(share_component(data))
        elif command == "project-activity":
            result = _finish(publish_activity(data))
        elif command == "solution-from-help":
            result = _finish(solution_from_help(data))
        elif command == "github-snapshot":
            snapshot = github_snapshot(data.get("repo_url", ""))
            result = aggregate_v3(); result.update({"ok": True, "github_snapshot": snapshot, "message": "Public GitHub activity loaded locally"})
        elif command == "share-text":
            text = share_text_for(data.get("id", ""))
            result = aggregate_v3(); result.update({"ok": True, "share_text": text, "message": "Share text ready"})
        else:
            return base.main()
    except (ValueError, TypeError, KeyError, OSError) as exc:
        result = {"ok": False, "message": str(exc)[:240] or "Build Network rejected that action"}
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
