"""Richer participation objects for Omarchy Friends Build Network v2.

These objects add collaboration state without adding remote execution. They are
small signed metadata events that reference existing public objects.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Iterable
import time
import uuid

MAX_ID = 64
MAX_NOTE = 500
MAX_TAGS = 12
MAX_TAG = 40
MAX_ROLE = 48
MAX_TASK = 120
MAX_NAME = 80
MAX_URL = 500


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
class HelpOffer:
    help_id: str
    note: str = ""
    environment_tags: list[str] = field(default_factory=list)
    author: str = ""
    id: str = field(default_factory=lambda: _id("help_offer"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.help_id = _text(self.help_id, MAX_ID)
        self.note = _text(self.note, 300)
        self.environment_tags = _list(self.environment_tags)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.help_id:
            raise ValueError("help_id is required")
        return {"type": "help_offer", **asdict(self)}


@dataclass(slots=True)
class SolutionVerification:
    solution_id: str
    result: str = "worked"
    environment_tags: list[str] = field(default_factory=list)
    note: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("solution_verify"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.solution_id = _text(self.solution_id, MAX_ID)
        self.result = self.result if self.result in {"worked", "partial", "did_not_work"} else "partial"
        self.environment_tags = _list(self.environment_tags)
        self.note = _text(self.note, 300)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.solution_id:
            raise ValueError("solution_id is required")
        return {"type": "solution_verification", **asdict(self)}


@dataclass(slots=True)
class EventRSVP:
    event_id: str
    response: str = "interested"
    note: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("rsvp"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.event_id = _text(self.event_id, MAX_ID)
        self.response = self.response if self.response in {"going", "interested"} else "interested"
        self.note = _text(self.note, 180)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.event_id:
            raise ValueError("event_id is required")
        return {"type": "event_rsvp", **asdict(self)}


@dataclass(slots=True)
class ChallengeJoin:
    challenge_id: str
    team_name: str = ""
    repo_url: str = ""
    note: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("challenge_join"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.challenge_id = _text(self.challenge_id, MAX_ID)
        self.team_name = _text(self.team_name, MAX_NAME)
        self.repo_url = _url(self.repo_url)
        self.note = _text(self.note, 240)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.challenge_id:
            raise ValueError("challenge_id is required")
        return {"type": "challenge_join", **asdict(self)}


@dataclass(slots=True)
class BuildTaskUpdate:
    room_id: str
    task: str
    status: str = "doing"
    note: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: _id("task"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self):
        self.room_id = _text(self.room_id, MAX_ID)
        self.task = _text(self.task, MAX_TASK)
        self.status = self.status if self.status in {"todo", "doing", "done", "blocked"} else "doing"
        self.note = _text(self.note, 240)
        self.author = _text(self.author, 64)
        return self

    def to_payload(self):
        self.normalize()
        if not self.room_id or not self.task:
            raise ValueError("room_id and task are required")
        return {"type": "build_task_update", **asdict(self)}


V2_TYPES = {
    "help_offer": HelpOffer,
    "solution_verification": SolutionVerification,
    "event_rsvp": EventRSVP,
    "challenge_join": ChallengeJoin,
    "build_task_update": BuildTaskUpdate,
}


def parse_v2_payload(payload):
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    cls = V2_TYPES.get(payload.get("type"))
    if cls is None:
        raise ValueError("unsupported v2 payload")
    allowed = cls.__dataclass_fields__.keys()
    return cls(**{key: value for key, value in payload.items() if key in allowed}).normalize()
