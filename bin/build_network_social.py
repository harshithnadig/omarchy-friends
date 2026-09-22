"""Additional public community objects for Omarchy Friends Build Network.

These are intentionally small signed metadata cards. They do not grant remote
access, execute code, collect telemetry automatically, or publish machine data
without the user explicitly creating the object.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Iterable
import time
import uuid


def _text(value, limit):
    return " ".join(str(value or "").strip().split())[:limit]


def _url(value):
    value = _text(value, 500)
    return value if value.startswith(("https://", "http://")) and not any(ord(ch) < 32 for ch in value) else ""


def _list(value: Iterable[object] | None, count=12, limit=48):
    if isinstance(value, str):
        value = value.split(",")
    result = []
    seen = set()
    for raw in value or []:
        item = _text(raw, limit)
        if item and item.casefold() not in seen:
            seen.add(item.casefold())
            result.append(item)
        if len(result) >= count:
            break
    return result


def _id(prefix):
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


@dataclass(slots=True)
class HelpRequest:
    title: str
    problem: str = ""
    tried: str = ""
    environment_tags: list[str] = field(default_factory=list)
    author: str = ""
    id: str = field(default_factory=lambda: _id("help"))
    created_at: int = field(default_factory=lambda: int(time.time()))
    status: str = "open"

    def normalize(self):
        self.title = _text(self.title, 80)
        self.problem = _text(self.problem, 600)
        self.tried = _text(self.tried, 500)
        self.environment_tags = _list(self.environment_tags, 12, 40)
        self.author = _text(self.author, 64)
        self.status = self.status if self.status in {"open", "helping", "solved", "closed"} else "open"
        return self

    def to_payload(self):
        self.normalize()
        if not self.title or not self.problem:
            raise ValueError("help request needs a title and problem")
        return {"type": "help_request", **asdict(self)}


@dataclass(slots=True)
class SolutionCard:
    title: str
    problem: str = ""
    solution: str = ""
    environment_tags: list[str] = field(default_factory=list)
    source_url: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("solution"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.title = _text(self.title, 80)
        self.problem = _text(self.problem, 500)
        self.solution = _text(self.solution, 1000)
        self.environment_tags = _list(self.environment_tags, 12, 40)
        self.source_url = _url(self.source_url)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.title or not self.solution:
            raise ValueError("solution needs a title and solution")
        return {"type": "solution_card", **asdict(self)}


@dataclass(slots=True)
class ShipPost:
    title: str
    summary: str = ""
    artifact_url: str = ""
    tags: list[str] = field(default_factory=list)
    build_room_id: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("ship"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.title = _text(self.title, 80)
        self.summary = _text(self.summary, 420)
        self.artifact_url = _url(self.artifact_url)
        self.tags = _list(self.tags, 12, 40)
        self.build_room_id = _text(self.build_room_id, 64)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.title:
            raise ValueError("ship post title is required")
        return {"type": "ship_post", **asdict(self)}


@dataclass(slots=True)
class UpdateReport:
    version: str
    result: str
    environment_tags: list[str] = field(default_factory=list)
    note: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("update"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.version = _text(self.version, 40)
        self.result = self.result if self.result in {"working", "minor_issue", "rolled_back"} else "minor_issue"
        self.environment_tags = _list(self.environment_tags, 12, 40)
        self.note = _text(self.note, 400)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.version:
            raise ValueError("Omarchy version is required")
        return {"type": "update_report", **asdict(self)}


@dataclass(slots=True)
class CommunityEvent:
    title: str
    when_text: str = ""
    location: str = ""
    event_url: str = ""
    notes: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("event"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.title = _text(self.title, 80)
        self.when_text = _text(self.when_text, 100)
        self.location = _text(self.location, 120)
        self.event_url = _url(self.event_url)
        self.notes = _text(self.notes, 420)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.title:
            raise ValueError("event title is required")
        return {"type": "community_event", **asdict(self)}


@dataclass(slots=True)
class Challenge:
    title: str
    prompt: str = ""
    deadline_text: str = ""
    rules_url: str = ""
    tags: list[str] = field(default_factory=list)
    author: str = ""
    id: str = field(default_factory=lambda: _id("challenge"))
    created_at: int = field(default_factory=lambda: int(time.time()))
    status: str = "open"

    def normalize(self):
        self.title = _text(self.title, 80)
        self.prompt = _text(self.prompt, 500)
        self.deadline_text = _text(self.deadline_text, 100)
        self.rules_url = _url(self.rules_url)
        self.tags = _list(self.tags, 12, 40)
        self.author = _text(self.author, 64)
        self.status = self.status if self.status in {"open", "judging", "closed"} else "open"
        return self

    def to_payload(self):
        self.normalize()
        if not self.title:
            raise ValueError("challenge title is required")
        return {"type": "challenge", **asdict(self)}


SOCIAL_TYPES = {
    "help_request": HelpRequest,
    "solution_card": SolutionCard,
    "ship_post": ShipPost,
    "update_report": UpdateReport,
    "community_event": CommunityEvent,
    "challenge": Challenge,
}


def parse_social_payload(payload):
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    cls = SOCIAL_TYPES.get(payload.get("type"))
    if cls is None:
        raise ValueError("unsupported social payload")
    allowed = cls.__dataclass_fields__.keys()
    return cls(**{key: value for key, value in payload.items() if key in allowed}).normalize()
