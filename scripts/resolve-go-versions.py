#!/usr/bin/env python3
"""
resolve-go-versions.py
Fetch latest Go patch versions from go.dev for given major.minor versions.

Usage: resolve-go-versions.py 1.24 1.25 1.26
Output: 1.24.13 1.25.11 1.26.4 (one per line)
"""

import re
import sys
from urllib.request import urlopen


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <major.minor> [...]", file=sys.stderr)
        sys.exit(1)

    wanted = sys.argv[1:]

    try:
        req = urlopen("https://go.dev/dl/", timeout=30)
        html = req.read().decode()
    except Exception as e:
        print(f"WARNING: Failed to fetch go.dev: {e}", file=sys.stderr)
        print("\n".join(wanted))
        sys.exit(0)

    # latest[minor] = max_patch
    latest = {}
    for m in re.finditer(r"go(\d+\.\d+)\.(\d+)\.linux-amd64\.tar\.gz", html):
        minor = m.group(1)
        patch = int(m.group(2))
        if minor not in latest or patch > latest[minor]:
            latest[minor] = patch

    for v in wanted:
        if v in latest:
            print(f"{v}.{latest[v]}")
        else:
            print(f"WARNING: Go {v} not found on go.dev, using as-is", file=sys.stderr)
            print(v)


if __name__ == "__main__":
    main()
