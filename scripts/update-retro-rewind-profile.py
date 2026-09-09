#!/usr/bin/env python3
"""Update KartPad's Retro Rewind pins from an official full archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROFILE = ROOT / "builder/profiles/mkwii-rmcp01-rev0.json"
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,3}$")
VERSION_FEED = "https://update.rwfc.net/RetroRewind/RetroRewindVersion.txt"


def member_digest(bundle: zipfile.ZipFile, name: str) -> tuple[int, str]:
    info = bundle.getinfo(name)
    digest = hashlib.sha256()
    with bundle.open(info) as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return info.file_size, digest.hexdigest()


def version_key(version: str) -> tuple[int, ...]:
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"invalid Retro Rewind version: {version!r}")
    return tuple(int(part) for part in version.split("."))


def latest_version() -> str:
    request = urllib.request.Request(
        VERSION_FEED, headers={"User-Agent": "KartPad-Retro-Rewind-Updater/1"}
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        lines = response.read().decode("utf-8").splitlines()
    versions = [line.split()[0] for line in lines if line.strip()]
    if not versions:
        raise ValueError("official Retro Rewind feed is empty")
    for version in versions:
        version_key(version)
    return max(versions, key=version_key)


def download(url: str, output: Path) -> None:
    if output.is_file() and zipfile.is_zipfile(output):
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
    start = partial.stat().st_size if partial.is_file() else 0
    headers = {"User-Agent": "KartPad-Retro-Rewind-Updater/1"}
    if start:
        headers["Range"] = f"bytes={start}-"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        if start and response.status != 206:
            start = 0
        mode = "ab" if start else "wb"
        with partial.open(mode) as target:
            while chunk := response.read(1024 * 1024):
                target.write(chunk)
    os.replace(partial, output)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Pin an official Retro Rewind full ZIP without weakening checks."
    )
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("archive_url", nargs="?")
    parser.add_argument(
        "--latest",
        action="store_true",
        help="download and pin the latest official full archive",
    )
    parser.add_argument(
        "--download-dir",
        type=Path,
        default=ROOT / "private/builder/retro-rewind-downloads",
    )
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    args = parser.parse_args()

    if args.latest:
        if args.archive is not None or args.archive_url is not None:
            parser.error("--latest does not accept archive arguments")
        try:
            version = latest_version()
        except (OSError, UnicodeError, ValueError) as exc:
            parser.error(str(exc))
        args.archive_url = (
            f"https://cdn.update.rwfc.net/RetroRewind/zip/{version}-full.zip"
        )
        args.archive = args.download_dir / f"{version}-full.zip"
        try:
            download(args.archive_url, args.archive)
        except OSError as exc:
            parser.error(f"download failed: {exc}")
    elif args.archive is None or args.archive_url is None:
        parser.error("provide ARCHIVE OFFICIAL_URL or use --latest")

    archive = args.archive.resolve()
    parsed = urllib.parse.urlparse(args.archive_url)
    if parsed.scheme != "https" or parsed.netloc != "cdn.update.rwfc.net":
        parser.error("archive URL must use the official HTTPS Retro Rewind CDN")
    if not archive.is_file() or not zipfile.is_zipfile(archive):
        parser.error("archive must be a readable ZIP")

    profile = json.loads(args.profile.read_text())
    config = profile["retroRewind"]
    root = config["root"]
    version_path = f"{root}/version.txt"
    code_path = f"{root}/{config['codePul']['path']}"
    xml_path = f"{root}/{config['riivolutionXml']['path']}"
    with zipfile.ZipFile(archive) as bundle:
        version = bundle.read(version_path).decode("utf-8").strip()
        if not VERSION_PATTERN.fullmatch(version):
            parser.error("archive contains an invalid Retro Rewind version")
        code_bytes, code_hash = member_digest(bundle, code_path)
        xml_bytes, xml_hash = member_digest(bundle, xml_path)

    archive_hash = hashlib.sha256()
    with archive.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            archive_hash.update(chunk)

    config["version"] = version
    config["archive"].update(
        url=args.archive_url,
        bytes=archive.stat().st_size,
        sha256=archive_hash.hexdigest(),
    )
    config["codePul"].update(bytes=code_bytes, sha256=code_hash)
    config["riivolutionXml"].update(bytes=xml_bytes, sha256=xml_hash)
    args.profile.write_text(json.dumps(profile, indent=2) + "\n")
    print(f"Pinned Retro Rewind {version}")
    print(f"archive {archive.stat().st_size} {archive_hash.hexdigest()}")
    print(f"Code.pul {code_bytes} {code_hash}")
    print(f"XML {xml_bytes} {xml_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
