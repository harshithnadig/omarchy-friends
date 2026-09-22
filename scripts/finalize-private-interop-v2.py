#!/usr/bin/env python3
"""Run the final private interop patch with one intentional two-site wording edit."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]


def patch_resource_limit_wording():
    path = ROOT / "bin" / "omarchy_friends_private.py"
    text = path.read_text(encoding="utf-8")
    old = 'raise ValueError("private message size is outside NIP-44 v2 limits")'
    new = 'raise ValueError("private message size is outside the Friends NIP-44 resource limit")'
    count = text.count(old)
    if count != 2:
        raise RuntimeError(f"NIP-44 resource-limit wording: expected two matches, found {count}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def main():
    patch_resource_limit_wording()
    patcher = runpy.run_path(str(ROOT / "scripts" / "finalize-private-interop.py"))
    # patch_private_module() is deliberately skipped: its only two edits were
    # the paired wording replacements handled above.
    for name in (
        "patch_engine_constants_and_state",
        "patch_presence_and_modern_capability",
        "patch_nip17_inbox_methods",
        "patch_private_publish_routing",
        "patch_receiver_membership_validation",
        "patch_periodic_inbox_publication_and_listener",
        "patch_tests",
    ):
        patcher[name]()
    print("final NIP-17 inbox interoperability hardening applied")


if __name__ == "__main__":
    main()
