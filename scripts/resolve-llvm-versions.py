#!/usr/bin/env python3
"""
resolve-llvm-versions.py
Fetch latest llvm-mingw release tags from GitHub for given LLVM major.minor versions,
or list the latest N major.minor versions available upstream.

Usage (resolve tags): resolve-llvm-versions.py 22.1 21.1
Output: 20260616 20251216 (one per line)

Usage (list top N major.minor): resolve-llvm-versions.py --list [N]
Output (default N=3): 20.1 21.1 22.1 (one per line, oldest first)

Matches by LLVM version embedded in release name, e.g.:
  "llvm-mingw 20260616 with LLVM 22.1.8" -> LLVM 22.1 -> tag 20260616
"""

import json
import os
import re
import sys
from urllib.request import Request, urlopen


def github_request(url: str) -> bytes:
    """Make a request to GitHub API with optional token auth."""
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "resolve-llvm-versions/1.0",
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, headers=headers)
    return urlopen(req, timeout=30).read()


def parse_llvm_minor(v: str) -> tuple:
    """Parse 'X.Y' into numeric tuple for comparison."""
    parts = v.split(".")
    return tuple(int(p) for p in parts)


def fetch_llvm_releases():
    """Fetch GitHub releases and return (latest_per_minor, all_minors_set).

    latest_per_minor: {llvm_minor: (patch, tag)}
    all_minors: set of all LLVM major.minor strings seen with ubuntu-22.04 assets.
    """
    data = json.loads(github_request(
        "https://api.github.com/repos/mstorsjo/llvm-mingw/releases?per_page=100",
    ))

    latest = {}
    all_minors = set()

    for release in data:
        name = release.get("name", "")
        tag = release.get("tag_name", "")
        m = re.search(r"LLVM (\d+\.\d+)\.(\d+)", name)
        if not m:
            continue
        llvm_minor = m.group(1)
        patch = int(m.group(2))

        has_asset = any(
            "msvcrt-ubuntu-22.04" in a["name"] for a in release.get("assets", [])
        )
        if not has_asset:
            continue

        all_minors.add(llvm_minor)

        if llvm_minor not in latest or patch > latest[llvm_minor][0]:
            latest[llvm_minor] = (patch, tag)

    return latest, all_minors


def list_top_versions(n: int = 3):
    """Output the top N LLVM major.minor versions, oldest first."""
    _, all_minors = fetch_llvm_releases()
    # Sort newest first, take top N, then reverse for output
    sorted_versions = sorted(all_minors, key=parse_llvm_minor, reverse=True)[:n]
    sorted_versions.reverse()
    for v in sorted_versions:
        print(v)
    if not sorted_versions:
        print("WARNING: No LLVM versions found in GitHub releases", file=sys.stderr)


def resolve_tags(wanted):
    """Resolve each major.minor to its latest release tag."""
    try:
        latest, _ = fetch_llvm_releases()
    except Exception as e:
        print(f"WARNING: Failed to fetch releases: {e}", file=sys.stderr)
        print("\n".join(wanted))
        sys.exit(0)

    for v in wanted:
        if v in latest:
            print(latest[v][1])
        else:
            print(f"WARNING: LLVM {v} not found, using as-is", file=sys.stderr)
            print(v)


def main():
    args = sys.argv[1:]

    if not args:
        print(
            f"Usage: {sys.argv[0]} [--list [N]] <llvm-major.minor> [...]",
            file=sys.stderr,
        )
        sys.exit(1)

    if args[0] == "--list":
        n = 3
        if len(args) > 1:
            try:
                n = int(args[1])
            except ValueError:
                pass
        try:
            list_top_versions(n)
        except Exception as e:
            print(
                f"WARNING: Failed to list LLVM versions: {e}", file=sys.stderr
            )
        return

    resolve_tags(args)


if __name__ == "__main__":
    main()
