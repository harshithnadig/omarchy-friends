#!/usr/bin/env python3
"""Local CLI for exercising the Omarchy Friends build-network prototype.

This intentionally does not publish to relays yet. It gives real-system tests a
stable way to create and validate collaboration payloads before the UI and
transport adopt the format.
"""

import argparse
import json

from build_network import BuildRoom, Idea, SetupCard, TestRequest, TestResult, parse_payload


def emit(obj):
    print(json.dumps(obj.to_payload(), ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser(prog="omarchy-friends-build")
    sub = parser.add_subparsers(dest="command", required=True)

    idea = sub.add_parser("idea")
    idea.add_argument("title")
    idea.add_argument("--summary", default="")
    idea.add_argument("--tag", action="append", default=[])
    idea.add_argument("--author", default="")

    room = sub.add_parser("room")
    room.add_argument("title")
    room.add_argument("--goal", default="")
    room.add_argument("--repo", default="")
    room.add_argument("--role", action="append", default=[])
    room.add_argument("--task", action="append", default=[])
    room.add_argument("--member", action="append", default=[])
    room.add_argument("--owner", default="")

    setup = sub.add_parser("setup")
    setup.add_argument("title")
    setup.add_argument("--theme", default="")
    setup.add_argument("--plugin", action="append", default=[])
    setup.add_argument("--shell", default="")
    setup.add_argument("--terminal", default="")
    setup.add_argument("--editor", default="")
    setup.add_argument("--wallpaper", default="")
    setup.add_argument("--notes", default="")
    setup.add_argument("--author", default="")

    request = sub.add_parser("test-request")
    request.add_argument("title")
    request.add_argument("--artifact", default="")
    request.add_argument("--version", default="")
    request.add_argument("--want", action="append", default=[])
    request.add_argument("--env", action="append", default=[])
    request.add_argument("--notes", default="")
    request.add_argument("--author", default="")

    result = sub.add_parser("test-result")
    result.add_argument("request_id")
    result.add_argument("result", choices=["pass", "issue"])
    result.add_argument("--env", action="append", default=[])
    result.add_argument("--note", default="")
    result.add_argument("--author", default="")

    validate = sub.add_parser("validate")
    validate.add_argument("json_payload")

    args = parser.parse_args()

    if args.command == "idea":
        emit(Idea(args.title, args.summary, args.tag, args.author))
    elif args.command == "room":
        emit(BuildRoom(args.title, args.goal, args.repo, args.role, args.task, args.member, owner=args.owner))
    elif args.command == "setup":
        emit(SetupCard(args.title, args.theme, args.plugin, args.shell, args.terminal, args.editor, args.wallpaper, args.notes, args.author))
    elif args.command == "test-request":
        emit(TestRequest(args.title, args.artifact, args.version, args.env, args.want, args.notes, args.author))
    elif args.command == "test-result":
        emit(TestResult(args.request_id, args.result, args.env, args.note, args.author))
    elif args.command == "validate":
        obj = parse_payload(json.loads(args.json_payload))
        print(json.dumps(obj.to_payload(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
