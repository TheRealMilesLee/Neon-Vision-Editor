#!/usr/bin/env python3
"""Automate README/CHANGELOG release docs updates.

Usage:
  scripts/prepare_release_docs.py v0.4.6
  scripts/prepare_release_docs.py v0.4.6 --date 2026-02-12
  scripts/prepare_release_docs.py 0.4.6 --date 2026-02-12
"""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
README = ROOT / "README.md"
CHANGELOG = ROOT / "CHANGELOG.md"


def normalize_tag(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        raise ValueError("Tag cannot be empty.")
    return raw if raw.startswith("v") else f"v{raw}"


def read_text(path: pathlib.Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Missing file: {path}")
    return path.read_text(encoding="utf-8")


def write_text(path: pathlib.Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def has_changelog_section(changelog: str, tag: str) -> bool:
    return re.search(rf"^## \[{re.escape(tag)}\] - \d{{4}}-\d{{2}}-\d{{2}}$", changelog, flags=re.M) is not None


def add_changelog_section(changelog: str, tag: str, date: str) -> str:
    heading = f"## [{tag}] - {date}"
    template = (
        f"{heading}\n\n"
        "### Added\n"
        "- TODO\n\n"
        "### Improved\n"
        "- TODO\n\n"
        "### Fixed\n"
        "- TODO\n\n"
    )
    first_release = re.search(r"^## \[", changelog, flags=re.M)
    if not first_release:
        return changelog.rstrip() + "\n\n" + template
    idx = first_release.start()
    return changelog[:idx] + template + changelog[idx:]


def extract_changelog_section(changelog: str, tag: str) -> str:
    pattern = re.compile(
        rf"^## \[{re.escape(tag)}\] - [^\n]*\n(?P<body>.*?)(?=^## \[|\Z)",
        flags=re.M | re.S,
    )
    match = pattern.search(changelog)
    if not match:
        raise ValueError(f"Could not find CHANGELOG section for {tag}")
    return match.group("body").strip()


def summarize_section(section_body: str, limit: int = 5) -> list[str]:
    bullets: list[str] = []
    for line in section_body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            bullets.append(stripped)
    if not bullets:
        return ["- See CHANGELOG.md entry."]
    return bullets[:limit]


def upsert_readme_summary(readme: str, tag: str, bullets: list[str]) -> str:
    block = "### {} (summary)\n\n{}\n\n".format(tag, "\n".join(bullets))
    header = "## Changelog\n\n"
    if header not in readme:
        raise ValueError("README missing '## Changelog' section")

    # Remove existing summary for the same tag first.
    same_tag_pattern = re.compile(
        rf"^### {re.escape(tag)} \(summary\)\n\n.*?(?=^### |\Z)",
        flags=re.M | re.S,
    )
    readme = same_tag_pattern.sub("", readme)

    insert_at = readme.index(header) + len(header)
    return readme[:insert_at] + block + readme[insert_at:]


def update_readme_release_refs(readme: str, tag: str) -> str:
    readme = re.sub(
        r"(?m)^> Latest release: \*\*.*\*\*$",
        f"> Latest release: **{tag}**",
        readme,
    )
    readme = re.sub(
        r"(?m)^- Latest release: \*\*.*\*\*$",
        f"- Latest release: **{tag}**",
        readme,
    )
    readme = re.sub(
        r"(?m)^- Tag: `.*`$",
        f"- Tag: `{tag}`",
        readme,
    )
    readme = re.sub(
        r"(?m)^git rev-parse --verify .*$",
        f"git rev-parse --verify {tag}",
        readme,
    )
    return readme


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare README and CHANGELOG for a release tag.")
    parser.add_argument("tag", help="Release tag, e.g. v0.4.6")
    parser.add_argument(
        "--date",
        help="Release date for a new CHANGELOG section (YYYY-MM-DD). Defaults to today.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tag = normalize_tag(args.tag)
    release_date = args.date or dt.date.today().isoformat()

    changelog = read_text(CHANGELOG)
    if not has_changelog_section(changelog, tag):
        changelog = add_changelog_section(changelog, tag, release_date)
        write_text(CHANGELOG, changelog)
        print(f"Added CHANGELOG template for {tag} ({release_date}).")
    else:
        print(f"Found existing CHANGELOG section for {tag}.")

    changelog = read_text(CHANGELOG)
    section = extract_changelog_section(changelog, tag)
    bullets = summarize_section(section, limit=5)

    readme = read_text(README)
    readme = update_readme_release_refs(readme, tag)
    readme = upsert_readme_summary(readme, tag, bullets)
    write_text(README, readme)
    print(f"Updated README release references and {tag} summary.")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - CLI friendly
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
