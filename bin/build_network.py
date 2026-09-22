"""Prototype collaboration primitives for Omarchy Friends.

This module is intentionally dependency-free and side-effect free. It provides
bounded, serializable objects for Ideas, Build Rooms, Setup Cards and Test
Requests so the existing Friends transport/UI can adopt them incrementally.

The module does not execute commands, install configs or read private files.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Iterable
import time
import uuid


MAX_TITLE = 80
MAX_SUMMARY = 360
MAX_NOTE = 500
MAX_URL = 500
MAX_TAGS = 12
MAX_TAG = 32
MAX_TASKS = 24
MAX_MEMBERS = 16
MAX_PLUGINS = 32


def _clean_text(value: object, limit: int) -> str:
    text = " ".join(str(value or "").strip().split())
    return text[:limit]


def _clean_url(value: object) -> str:
    url = _clean_text(value, MAX_URL)
    if not url:
        return ""
    if url.startswith(("https://", "http://")):
        return url
    return ""


def _clean_list(values: Iterable[object] | None, *, max_items: int, item_limit: int) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for raw in values or []:
        item = _clean_text(raw, item_limit)
        if not item:
            continue
        key = item.casefold()
        if key in seen:
            continue
        seen.add(key)
        result.append(item)
        if len(result) >= max_items:
            break
    return result


def new_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


@dataclass(slots=True)
class Idea:
    title: str
    summary: str = ""
    tags: list[str] = field(default_factory=list)
    author: str = ""
    id: str = field(default_factory=lambda: new_id("idea"))
    created_at: int = field(default_factory=lambda: int(time.time()))
    status: str = "open"

    def normalize(self) -> "Idea":
        self.title = _clean_text(self.title, MAX_TITLE)
        self.summary = _clean_text(self.summary, MAX_SUMMARY)
        self.tags = _clean_list(self.tags, max_items=MAX_TAGS, item_limit=MAX_TAG)
        self.author = _clean_text(self.author, 64)
        self.status = self.status if self.status in {"open", "building", "shipped", "closed"} else "open"
        return self

    def to_payload(self) -> dict:
        self.normalize()
        if not self.title:
            raise ValueError("idea title is required")
        return {"type": "idea", **asdict(self)}


@dataclass(slots=True)
class BuildRoom:
    title: str
    goal: str = ""
    repo_url: str = ""
    roles_needed: list[str] = field(default_factory=list)
    tasks: list[str] = field(default_factory=list)
    members: list[str] = field(default_factory=list)
    source_idea_id: str = ""
    owner: str = ""
    id: str = field(default_factory=lambda: new_id("build"))
    created_at: int = field(default_factory=lambda: int(time.time()))
    status: str = "building"

    def normalize(self) -> "BuildRoom":
        self.title = _clean_text(self.title, MAX_TITLE)
        self.goal = _clean_text(self.goal, MAX_SUMMARY)
        self.repo_url = _clean_url(self.repo_url)
        self.roles_needed = _clean_list(self.roles_needed, max_items=MAX_TAGS, item_limit=MAX_TAG)
        self.tasks = _clean_list(self.tasks, max_items=MAX_TASKS, item_limit=120)
        self.members = _clean_list(self.members, max_items=MAX_MEMBERS, item_limit=64)
        self.source_idea_id = _clean_text(self.source_idea_id, 64)
        self.owner = _clean_text(self.owner, 64)
        self.status = self.status if self.status in {"building", "testing", "shipped", "archived"} else "building"
        return self

    def to_payload(self) -> dict:
        self.normalize()
        if not self.title:
            raise ValueError("build room title is required")
        return {"type": "build_room", **asdict(self)}


@dataclass(slots=True)
class SetupCard:
    title: str
    theme: str = ""
    plugins: list[str] = field(default_factory=list)
    shell: str = ""
    terminal: str = ""
    editor: str = ""
    wallpaper_url: str = ""
    notes: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: new_id("setup"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self) -> "SetupCard":
        self.title = _clean_text(self.title, MAX_TITLE)
        self.theme = _clean_text(self.theme, 80)
        self.plugins = _clean_list(self.plugins, max_items=MAX_PLUGINS, item_limit=80)
        self.shell = _clean_text(self.shell, 80)
        self.terminal = _clean_text(self.terminal, 80)
        self.editor = _clean_text(self.editor, 80)
        self.wallpaper_url = _clean_url(self.wallpaper_url)
        self.notes = _clean_text(self.notes, MAX_NOTE)
        self.author = _clean_text(self.author, 64)
        return self

    def to_payload(self) -> dict:
        self.normalize()
        if not self.title:
            raise ValueError("setup title is required")
        return {"type": "setup_card", **asdict(self)}


@dataclass(slots=True)
class TestRequest:
    title: str
    artifact_url: str = ""
    version: str = ""
    environment_tags: list[str] = field(default_factory=list)
    requested_tags: list[str] = field(default_factory=list)
    notes: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: new_id("test"))
    created_at: int = field(default_factory=lambda: int(time.time()))
    status: str = "open"

    def normalize(self) -> "TestRequest":
        self.title = _clean_text(self.title, MAX_TITLE)
        self.artifact_url = _clean_url(self.artifact_url)
        self.version = _clean_text(self.version, 40)
        self.environment_tags = _clean_list(self.environment_tags, max_items=MAX_TAGS, item_limit=MAX_TAG)
        self.requested_tags = _clean_list(self.requested_tags, max_items=MAX_TAGS, item_limit=MAX_TAG)
        self.notes = _clean_text(self.notes, MAX_NOTE)
        self.author = _clean_text(self.author, 64)
        self.status = self.status if self.status in {"open", "testing", "done", "closed"} else "open"
        return self

    def to_payload(self) -> dict:
        self.normalize()
        if not self.title:
            raise ValueError("test request title is required")
        return {"type": "test_request", **asdict(self)}


@dataclass(slots=True)
class TestResult:
    request_id: str
    result: str
    environment_tags: list[str] = field(default_factory=list)
    note: str = ""
    author: str = ""
    id: str = field(default_factory=lambda: new_id("result"))
    created_at: int = field(default_factory=lambda: int(time.time()))

    def normalize(self) -> "TestResult":
        self.request_id = _clean_text(self.request_id, 64)
        self.result = self.result if self.result in {"pass", "issue"} else "issue"
        self.environment_tags = _clean_list(self.environment_tags, max_items=MAX_TAGS, item_limit=MAX_TAG)
        self.note = _clean_text(self.note, MAX_NOTE)
        self.author = _clean_text(self.author, 64)
        return self

    def to_payload(self) -> dict:
        self.normalize()
        if not self.request_id:
            raise ValueError("request_id is required")
        return {"type": "test_result", **asdict(self)}


ALLOWED_TYPES = {
    "idea": Idea,
    "build_room": BuildRoom,
    "setup_card": SetupCard,
    "test_request": TestRequest,
    "test_result": TestResult,
}


def parse_payload(payload: object):
    """Validate a remote collaboration payload and return a normalized model.

    Unknown keys are ignored deliberately so the format can evolve without
    making older clients crash.
    """
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    kind = payload.get("type")
    cls = ALLOWED_TYPES.get(kind)
    if cls is None:
        raise ValueError("unsupported collaboration payload")
    allowed = cls.__dataclass_fields__.keys()
    kwargs = {key: value for key, value in payload.items() if key in allowed}
    obj = cls(**kwargs)
    return obj.normalize()
