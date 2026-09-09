#!/usr/bin/env python3
"""Fail when the official Retro Rewind feed is newer than KartPad's pin."""

from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "builder/profiles/mkwii-rmcp01-rev0.json"


def version_key(version: str) -> tuple[int, ...]:
    parts = version.split(".")
    if not 2 <= len(parts) <= 4 or any(not part.isdigit() for part in parts):
        raise ValueError(f"invalid Retro Rewind version: {version!r}")
    return tuple(int(part) for part in parts)


def latest_release(text: str) -> tuple[str, str]:
    releases: list[tuple[str, str]] = []
    for line in text.splitlines():
        fields = line.split()
        if not fields:
            continue
        version_key(fields[0])
        if len(fields) < 2 or not fields[1].startswith(
            "https://cdn.update.rwfc.net/RetroRewind/zip/"
        ):
            raise ValueError("official Retro Rewind feed contains an invalid archive URL")
        releases.append((fields[0], fields[1]))
    if not releases:
        raise ValueError("official Retro Rewind feed is empty")
    return max(releases, key=lambda release: version_key(release[0]))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="emit machine-readable status")
    args = parser.parse_args()
    profile = json.loads(PROFILE.read_text())
    config = profile["retroRewind"]
    request = urllib.request.Request(
        config["versionManifestUrl"],
        headers={"User-Agent": "KartPad-Retro-Rewind-Version-Watch/1"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        current, update_url = latest_release(response.read().decode("utf-8"))
    pinned = config["version"]
    update_required = version_key(current) > version_key(pinned)
    if args.json:
        print(json.dumps({
            "pinned": pinned,
            "current": current,
            "updateUrl": update_url,
            "updateRequired": update_required,
        }, separators=(",", ":")))
    else:
        print(f"KartPad pins Retro Rewind {pinned}; official feed reports {current}")
    return 2 if update_required else 0


if __name__ == "__main__":
    raise SystemExit(main())
