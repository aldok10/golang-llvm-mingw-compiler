#!/usr/bin/env python3
"""
resolve-go-versions.py
Fetch latest Go patch versions from go.dev for given major.minor versions,
or list the latest N major.minor versions available upstream.

Usage (resolve patches): resolve-go-versions.py 1.24 1.25 1.26
Output: 1.24.13 1.25.11 1.26.4 (one per line)

Usage (list top N major.minor): resolve-go-versions.py --list [N]
Output (default N=3): 1.24 1.25 1.26 (one per line, oldest first)
"""

import re
import sys
from urllib.request import urlopen


def parse_version(v: str) -> tuple:
    """Parse 'X.Y' or 'X.Y.Z' into numeric tuple for comparison."""
    parts = v.split(".")
    return tuple(int(p) for p in parts)


def fetch_go_versions():
    """Fetch go.dev/dl/ and return dict of {major.minor: max_patch}."""
    req = urlopen("https://go.dev/dl/", timeout=30)
    html = req.read().decode()

    latest = {}
    for m in re.finditer(r"go(\d+\.\d+)\.(\d+)\.linux-amd64\.tar\.gz", html):
        minor = m.group(1)
        patch = int(m.group(2))
        if minor not in latest or patch > latest[minor]:
            latest[minor] = patch
    return latest


def list_top_versions(n: int = 3):
    """Output the top N major.minor versions, oldest first."""
    latest = fetch_go_versions()
    # Sort newest first, take top N, then reverse for output
    sorted_versions = sorted(latest.keys(), key=parse_version, reverse=True)[:n]
    sorted_versions.reverse()
    for v in sorted_versions:
        print(v)
    if not sorted_versions:
        print("WARNING: No Go versions found on go.dev", file=sys.stderr)


def resolve_patches(wanted):
    """Resolve each major.minor to latest patch version."""
    try:
        latest = fetch_go_versions()
    except Exception as e:
        print(f"WARNING: Failed to fetch go.dev: {e}", file=sys.stderr)
        print("\n".join(wanted))
        sys.exit(0)

    for v in wanted:
        if v in latest:
            print(f"{v}.{latest[v]}")
        else:
            print(f"WARNING: Go {v} not found on go.dev, using as-is", file=sys.stderr)
            print(v)


def main():
    args = sys.argv[1:]

    if not args:
        print(f"Usage: {sys.argv[0]} [--list [N]] <major.minor> [...]", file=sys.stderr)
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
            print(f"WARNING: Failed to list Go versions: {e}", file=sys.stderr)
        return

    resolve_patches(args)


if __name__ == "__main__":
    main()
