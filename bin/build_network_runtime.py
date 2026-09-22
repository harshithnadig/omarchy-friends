#!/usr/bin/env python3
"""Federated Build Network runtime for Omarchy Friends.

This is the first integrated implementation of Ideas, Build Rooms, Setup Cards
and the community Test Network. Public collaboration objects are signed with
the same pseudonymous identity as Omarchy Friends and published as tagged
Nostr parameterized-replaceable events.

Security properties of this prototype:
- remote payloads are signature-checked and normalized through build_network.py
- URLs are metadata only; this runtime never downloads or executes them
- setup sharing never installs themes/plugins/configs
- only explicitly public collaboration metadata is placed on relays
- the user's existing Omarchy Friends private key is read locally and never
  placed in Build Network state or output
"""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from build_network import (  # noqa: E402
    BuildJoin,
    BuildRoom,
    Idea,
    IdeaInterest,
    SetupCard,
    TestRequest,
    TestResult,
    parse_payload,
)
from omarchy_friends_global import (  # noqa: E402
    WebSocketClient,
    build_event,
    generate_keypair,
    verify_event,
)

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "omarchy-friends"
FRIENDS_STATE = STATE_DIR / "friends_state.json"
BUILD_STATE = STATE_DIR / "build_network_state.json"
EVENT_KIND = 30079
EVENT_TAG = "omarchy-friends-build"
EVENT_VERSION = 1
MAX_CACHE = 400
LOOKBACK_SECONDS = 30 * 24 * 60 * 60
RELAYS = tuple(
    item.strip().rstrip("/")
    for item in os.environ.get(
        "OMARCHY_FRIENDS_RELAYS",
        "wss://relay.primal.net,wss://nos.lol,wss://purplerelay.com,wss://nostr.mom,wss://relay.damus.io",
    ).split(",")
    if item.strip()
)


def _read_json(path: Path, fallback):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, type(fallback)) else fallback
    except (OSError, ValueError, TypeError):
        return fallback


def _write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    try:
        os.chmod(tmp, 0o600)
    except OSError:
        pass
    tmp.replace(path)


def _main_state():
    return _read_json(FRIENDS_STATE, {})


def _build_state():
    state = _read_json(BUILD_STATE, {})
    if not isinstance(state.get("objects"), dict):
        state["objects"] = {}
    if not isinstance(state.get("hidden"), list):
        state["hidden"] = []
    state.setdefault("schema", 1)
    return state


def _identity(state=None):
    main = _main_state()
    candidate = main.get("global_identity") if isinstance(main, dict) else None
    if isinstance(candidate, dict):
        try:
            identity = generate_keypair(candidate.get("secret_key"))
            if identity["public_key"] == str(candidate.get("public_key", "")).lower():
                return identity
        except (TypeError, ValueError, OverflowError):
            pass

    # Normally Friends has already generated the identity. Keep a fallback so
    # a tester can exercise Build Network before opening World for the first time.
    state = state if isinstance(state, dict) else _build_state()
    fallback = state.get("fallback_identity")
    try:
        identity = generate_keypair(fallback.get("secret_key")) if isinstance(fallback, dict) else generate_keypair()
    except (TypeError, ValueError, OverflowError):
        identity = generate_keypair()
    state["fallback_identity"] = identity
    _write_json(BUILD_STATE, state)
    return identity


def _handle():
    profile = _main_state().get("profile", {})
    value = str(profile.get("handle", "")).strip()[:64]
    return value or "OmarchyBuilder"


def _run_text(command, timeout=1.2):
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=timeout)
        if result.returncode == 0:
            return result.stdout.strip()
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return ""


def inspect_local_setup():
    """Return deliberately shallow, non-secret setup metadata."""
    plugins = []
    for root in (
        Path.home() / ".config" / "omarchy" / "plugins",
        Path.home() / ".local" / "share" / "omarchy" / "plugins",
    ):
        try:
            for child in sorted(root.iterdir()):
                if child.is_dir() and not child.name.startswith(".") and child.name not in plugins:
                    plugins.append(child.name[:80])
                if len(plugins) >= 32:
                    break
        except OSError:
            pass
        if len(plugins) >= 32:
            break

    shell = Path(os.environ.get("SHELL", "")).name
    terminal = os.environ.get("TERM_PROGRAM", "") or os.environ.get("TERMINAL", "")
    editor = os.environ.get("VISUAL", "") or os.environ.get("EDITOR", "")
    return {
        "theme": _run_text(["omarchy-theme-current"]),
        "plugins": plugins,
        "components": [item for item in [platform.machine(), platform.system()] if item],
        "shell": shell[:80],
        "terminal": str(terminal)[:80],
        "editor": Path(str(editor).split()[0]).name[:80] if editor else "",
    }


def _publish(payload):
    state = _build_state()
    identity = _identity(state)
    object_id = str(payload.get("id", ""))[:64]
    object_type = str(payload.get("type", ""))[:32]
    content = json.dumps({"app": "omarchy-friends", "v": EVENT_VERSION, "object": payload}, ensure_ascii=False, separators=(",", ":"))
    event = build_event(
        identity["secret_key"],
        EVENT_KIND,
        [["d", object_id], ["t", EVENT_TAG], ["type", object_type], ["alt", "Omarchy Friends Build Network object"]],
        content,
    )
    successes = 0
    relay_errors = []
    for relay_url in RELAYS:
        try:
            with WebSocketClient(relay_url, timeout=2.5) as relay:
                relay.send_json(["EVENT", event])
                response = relay.recv_json(timeout=0.8)
                if (
                    isinstance(response, list)
                    and len(response) >= 4
                    and response[0] == "OK"
                    and response[1] == event["id"]
                    and response[2] is True
                ):
                    successes += 1
                elif isinstance(response, list) and response[:1] == ["OK"] and len(response) >= 4:
                    relay_errors.append(f"{relay_url}: {str(response[3])[:160] or 'rejected'}")
                else:
                    relay_errors.append(f"{relay_url}: invalid acknowledgement")
        except TimeoutError:
            relay_errors.append(f"{relay_url}: acknowledgement timeout")
        except (OSError, EOFError, ValueError) as exc:
            relay_errors.append(f"{relay_url}: {type(exc).__name__}")
    return successes > 0, successes, relay_errors, event


def _event_payload(event):
    if not verify_event(event) or int(event.get("kind", -1)) != EVENT_KIND:
        return None
    tags = event.get("tags", [])
    if not any(isinstance(tag, list) and len(tag) > 1 and tag[0] == "t" and tag[1] == EVENT_TAG for tag in tags):
        return None
    try:
        envelope = json.loads(event.get("content", "{}"))
        if envelope.get("app") != "omarchy-friends" or int(envelope.get("v", 0)) != EVENT_VERSION:
            return None
        raw = envelope.get("object")
        obj = parse_payload(raw)
        payload = obj.to_payload()
    except (ValueError, TypeError, KeyError, json.JSONDecodeError):
        return None
    payload["public_key"] = str(event.get("pubkey", ""))[:64]
    payload["event_id"] = str(event.get("id", ""))[:64]
    payload["updated_at"] = int(event.get("created_at", 0) or 0)
    payload["mine"] = payload["public_key"] == _identity(_build_state())["public_key"]
    return payload


def _fetch_relay(relay_url):
    result = []
    sub = "build-" + str(int(time.time() * 1000))[-8:]
    query = {"kinds": [EVENT_KIND], "#t": [EVENT_TAG], "since": int(time.time()) - LOOKBACK_SECONDS, "limit": 300}
    with WebSocketClient(relay_url, timeout=2.8) as relay:
        relay.send_json(["REQ", sub, query])
        deadline = time.monotonic() + 2.4
        while time.monotonic() < deadline:
            try:
                message = relay.recv_json(timeout=max(0.08, deadline - time.monotonic()))
            except (OSError, EOFError, TimeoutError):
                break
            if not isinstance(message, list) or not message:
                continue
            if message[0] == "EOSE":
                break
            if message[0] == "EVENT" and len(message) >= 3 and message[1] == sub and isinstance(message[2], dict):
                payload = _event_payload(message[2])
                if payload:
                    result.append(payload)
        try:
            relay.send_json(["CLOSE", sub])
        except OSError:
            pass
    return result


def refresh_network():
    state = _build_state()
    objects = state.setdefault("objects", {})
    seen_events = set()
    relay_ok = 0
    errors = []
    for relay_url in RELAYS:
        try:
            items = _fetch_relay(relay_url)
            relay_ok += 1
        except (OSError, EOFError, ValueError) as exc:
            errors.append(f"{relay_url}: {type(exc).__name__}")
            continue
        for payload in items:
            event_id = payload.get("event_id")
            if event_id in seen_events:
                continue
            seen_events.add(event_id)
            key = f"{payload.get('public_key','')}:{payload.get('id','')}"
            old = objects.get(key, {})
            if int(payload.get("updated_at", 0)) >= int(old.get("updated_at", 0)):
                objects[key] = payload
    ordered = sorted(objects.items(), key=lambda item: int(item[1].get("updated_at", item[1].get("created_at", 0))), reverse=True)
    state["objects"] = dict(ordered[:MAX_CACHE])
    state["last_refresh"] = int(time.time())
    state["relay_ok"] = relay_ok
    state["last_errors"] = errors[:8]
    _write_json(BUILD_STATE, state)
    return status_payload(state)


def _all_objects(state):
    hidden = set(str(item) for item in state.get("hidden", []))
    values = []
    for key, item in state.get("objects", {}).items():
        if key not in hidden and isinstance(item, dict):
            values.append(dict(item))
    values.sort(key=lambda item: int(item.get("updated_at", item.get("created_at", 0))), reverse=True)
    return values


def status_payload(state=None):
    state = state or _build_state()
    values = _all_objects(state)
    buckets = {name: [] for name in ("ideas", "interests", "build_rooms", "joins", "setups", "tests", "results")}
    mapping = {
        "idea": "ideas",
        "idea_interest": "interests",
        "build_room": "build_rooms",
        "build_join": "joins",
        "setup_card": "setups",
        "test_request": "tests",
        "test_result": "results",
    }
    for item in values:
        bucket = mapping.get(item.get("type"))
        if bucket:
            buckets[bucket].append(item)

    interest_counts = {}
    for item in buckets["interests"]:
        interest_counts[item.get("idea_id", "")] = interest_counts.get(item.get("idea_id", ""), 0) + 1
    join_counts = {}
    for item in buckets["joins"]:
        join_counts[item.get("room_id", "")] = join_counts.get(item.get("room_id", ""), 0) + 1
    result_counts = {}
    pass_counts = {}
    for item in buckets["results"]:
        request_id = item.get("request_id", "")
        result_counts[request_id] = result_counts.get(request_id, 0) + 1
        if item.get("result") == "pass":
            pass_counts[request_id] = pass_counts.get(request_id, 0) + 1

    for idea in buckets["ideas"]:
        idea["interest_count"] = interest_counts.get(idea.get("id", ""), 0)
    for room in buckets["build_rooms"]:
        room["join_count"] = join_counts.get(room.get("id", ""), 0)
    for request in buckets["tests"]:
        request["result_count"] = result_counts.get(request.get("id", ""), 0)
        request["pass_count"] = pass_counts.get(request.get("id", ""), 0)

    identity = _identity(state)
    return {
        "ok": True,
        "profile": {"handle": _handle(), "public_key": identity["public_key"]},
        **buckets,
        "stats": {
            "ideas": len(buckets["ideas"]),
            "build_rooms": len(buckets["build_rooms"]),
            "setups": len(buckets["setups"]),
            "tests": len(buckets["tests"]),
            "builders": len({item.get("public_key") for item in values if item.get("public_key")}),
        },
        "last_refresh": int(state.get("last_refresh", 0) or 0),
        "relay_ok": int(state.get("relay_ok", 0) or 0),
        "relay_total": len(RELAYS),
        "last_errors": state.get("last_errors", [])[:8],
    }


def _store_and_publish(model, success_message):
    payload = model.to_payload()
    payload["author"] = _handle()
    ok, count, errors, event = _publish(payload)
    state = _build_state()
    payload["public_key"] = event["pubkey"]
    payload["event_id"] = event["id"]
    payload["updated_at"] = event["created_at"]
    payload["mine"] = True
    state.setdefault("objects", {})[f"{event['pubkey']}:{payload['id']}"] = payload
    state["relay_ok"] = count
    state["last_errors"] = errors[:8]
    _write_json(BUILD_STATE, state)
    result = status_payload(state)
    result.update({"ok": ok, "message": success_message if ok else "Saved locally; relays are currently unavailable"})
    return result


def _json_arg(index=2):
    try:
        value = json.loads(sys.argv[index])
        return value if isinstance(value, dict) else {}
    except (IndexError, ValueError, TypeError):
        return {}


def _find_object(object_id, kind=None):
    for item in _all_objects(_build_state()):
        if item.get("id") == object_id and (kind is None or item.get("type") == kind):
            return item
    return None


def command_create_idea():
    data = _json_arg()
    return _store_and_publish(Idea(title=data.get("title", ""), summary=data.get("summary", ""), tags=data.get("tags", []), author=_handle()), "Idea shared with Omarchy builders")


def command_interest():
    idea_id = str(_json_arg().get("idea_id", ""))[:64]
    if not _find_object(idea_id, "idea"):
        return {"ok": False, "message": "That idea is not in your current Build Network cache"}
    return _store_and_publish(IdeaInterest(idea_id=idea_id, note=_json_arg().get("note", ""), author=_handle()), "Marked interested")


def command_create_room():
    data = _json_arg()
    return _store_and_publish(BuildRoom(title=data.get("title", ""), goal=data.get("goal", ""), repo_url=data.get("repo_url", ""), roles_needed=data.get("roles_needed", []), tasks=data.get("tasks", []), source_idea_id=data.get("source_idea_id", ""), owner=_handle()), "Build Room opened")


def command_room_from_idea():
    data = _json_arg()
    idea = _find_object(str(data.get("idea_id", ""))[:64], "idea")
    if not idea:
        return {"ok": False, "message": "Refresh Build Network and try that idea again"}
    return _store_and_publish(BuildRoom(title=idea.get("title", "Untitled build"), goal=idea.get("summary", ""), repo_url=data.get("repo_url", ""), roles_needed=data.get("roles_needed", []), source_idea_id=idea.get("id", ""), owner=_handle()), "Idea promoted to a Build Room")


def command_join_room():
    data = _json_arg()
    room_id = str(data.get("room_id", ""))[:64]
    if not _find_object(room_id, "build_room"):
        return {"ok": False, "message": "That Build Room is not in your current cache"}
    return _store_and_publish(BuildJoin(room_id=room_id, role=data.get("role", "Builder"), note=data.get("note", ""), author=_handle()), "Joined the Build Room")


def command_create_setup():
    data = _json_arg()
    detected = inspect_local_setup() if data.get("use_detected", False) else {}
    return _store_and_publish(SetupCard(title=data.get("title", "My Omarchy setup"), theme=data.get("theme", detected.get("theme", "")), plugins=data.get("plugins", detected.get("plugins", [])), components=data.get("components", detected.get("components", [])), shell=data.get("shell", detected.get("shell", "")), terminal=data.get("terminal", detected.get("terminal", "")), editor=data.get("editor", detected.get("editor", "")), wallpaper_url=data.get("wallpaper_url", ""), repo_url=data.get("repo_url", ""), notes=data.get("notes", ""), author=_handle()), "Setup Card shared")


def command_create_test():
    data = _json_arg()
    return _store_and_publish(TestRequest(title=data.get("title", ""), artifact_url=data.get("artifact_url", ""), version=data.get("version", ""), environment_tags=data.get("environment_tags", []), requested_tags=data.get("requested_tags", []), notes=data.get("notes", ""), build_room_id=data.get("build_room_id", ""), author=_handle()), "Test request shared")


def command_test_result():
    data = _json_arg()
    request_id = str(data.get("request_id", ""))[:64]
    if not _find_object(request_id, "test_request"):
        return {"ok": False, "message": "That test request is not in your current cache"}
    return _store_and_publish(TestResult(request_id=request_id, result=data.get("result", "issue"), environment_tags=data.get("environment_tags", []), note=data.get("note", ""), author=_handle()), "Test result shared")


def command_hide():
    data = _json_arg()
    public_key = str(data.get("public_key", ""))[:64]
    object_id = str(data.get("id", ""))[:64]
    key = f"{public_key}:{object_id}"
    state = _build_state()
    if key not in state.setdefault("hidden", []):
        state["hidden"].append(key)
    state["hidden"] = state["hidden"][-200:]
    _write_json(BUILD_STATE, state)
    result = status_payload(state)
    result.update({"ok": True, "message": "Hidden on this device"})
    return result


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if command == "status":
            result = status_payload()
        elif command == "refresh":
            result = refresh_network()
            result["message"] = "Build Network refreshed"
        elif command == "inspect-setup":
            result = {"ok": True, "setup": inspect_local_setup()}
        elif command == "create-idea":
            result = command_create_idea()
        elif command == "interest":
            result = command_interest()
        elif command == "create-room":
            result = command_create_room()
        elif command == "room-from-idea":
            result = command_room_from_idea()
        elif command == "join-room":
            result = command_join_room()
        elif command == "create-setup":
            result = command_create_setup()
        elif command == "create-test":
            result = command_create_test()
        elif command == "test-result":
            result = command_test_result()
        elif command == "hide":
            result = command_hide()
        else:
            result = {"ok": False, "message": f"Unknown Build Network command: {command}"}
    except (ValueError, TypeError, KeyError) as exc:
        result = {"ok": False, "message": str(exc)[:240] or "Build Network rejected that payload"}
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
