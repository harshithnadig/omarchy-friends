"""Final promise-completion primitives for Omarchy Friends Build Network.

These signed objects cover the remaining collaboration promises that do not
belong in the private messaging engine: helper/pair availability, individual
setup-component sharing, and lightweight project activity cards.

All objects are metadata only. They never carry shell commands, local file
contents, credentials, or executable configuration.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Iterable
import time
import uuid

MAX_ID = 64
MAX_NAME = 96
MAX_NOTE = 500
MAX_URL = 500
MAX_TAGS = 16
MAX_TAG = 48
MAX_ROLE = 64


def _text(value, limit):
    return " ".join(str(value or "").strip().split())[:limit]


def _list(value: Iterable[object] | None, count=MAX_TAGS, limit=MAX_TAG):
    if isinstance(value, str):
        value = value.split(",")
    result = []
    seen = set()
    for raw in value or []:
        item = _text(raw, limit)
        key = item.casefold()
        if item and key not in seen:
            result.append(item)
            seen.add(key)
        if len(result) >= count:
            break
    return result


def _url(value):
    value = _text(value, MAX_URL)
    if value.startswith(("https://", "http://")) and not any(ord(ch) < 32 for ch in value):
        return value
    return ""


def _id(prefix):
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


@dataclass(slots=True)
class HelperAvailability:
    mode: str = "can_help"
    skills: list[str] = field(default_factory=list)
    environment_tags: list[str] = field(default_factory=list)
    note: str = ""
    available_minutes: int = 30
    author: str = ""
    id: str = field(default_factory=lambda: _id("helper"))
    created_at: int = field(default_factory=lambda: int(time.time()))
    status: str = "active"

    def normalize(self):
        self.mode = self.mode if self.mode in {"can_help", "pair", "building"} else "can_help"
        self.skills = _list(self.skills)
        self.environment_tags = _list(self.environment_tags)
        self.note = _text(self.note, 300)
        try:
            self.available_minutes = max(10, min(240, int(self.available_minutes)))
        except (TypeError, ValueError):
            self.available_minutes = 30
        self.author = _text(self.author, 64)
        self.status = self.status if self.status in {"active", "away", "closed"} else "active"
        return self

    def to_payload(self):
        self.normalize()
        return {"type": "helper_availability", **asdict(self)}


@dataclass(slots=True)
class SetupComponentShare:
    component_type: str
    name: str
    source_url: str = ""
    setup_id: str = ""
    tags: list[str] = field(default_factory=list)
    notes: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("component"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        allowed = {"theme", "plugin", "bar", "wallpaper", "font", "terminal", "editor", "shell", "keybindings", "other"}
        self.component_type = self.component_type if self.component_type in allowed else "other"
        self.name = _text(self.name, MAX_NAME)
        self.source_url = _url(self.source_url)
        self.setup_id = _text(self.setup_id, MAX_ID)
        self.tags = _list(self.tags)
        self.notes = _text(self.notes, MAX_NOTE)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.name:
            raise ValueError("component name is required")
        return {"type": "setup_component", **asdict(self)}


@dataclass(slots=True)
class ProjectActivity:
    activity_type: str
    title: str
    url: str = ""
    room_id: str = ""
    repo_url: str = ""
    state: str = "open"
    reference: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("activity"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.activity_type = self.activity_type if self.activity_type in {"commit", "pull_request", "issue", "release", "discussion"} else "discussion"
        self.title = _text(self.title, 140)
        self.url = _url(self.url)
        self.room_id = _text(self.room_id, MAX_ID)
        self.repo_url = _url(self.repo_url)
        self.state = self.state if self.state in {"open", "merged", "closed", "released", "info"} else "info"
        self.reference = _text(self.reference, 48)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.title:
            raise ValueError("project activity title is required")
        return {"type": "project_activity", **asdict(self)}


V3_TYPES = {
    "helper_availability": HelperAvailability,
    "setup_component": SetupComponentShare,
    "project_activity": ProjectActivity,
}


def parse_v3_payload(payload):
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    cls = V3_TYPES.get(payload.get("type"))
    if cls is None:
        raise ValueError("unsupported v3 payload")
    allowed = cls.__dataclass_fields__.keys()
    return cls(**{key: value for key, value in payload.items() if key in allowed}).normalize()
