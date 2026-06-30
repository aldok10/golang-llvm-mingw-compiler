#!/usr/bin/env python3
"""
resolve-llvm-versions.py
Fetch latest llvm-mingw release tags from GitHub for given LLVM major.minor versions.

Usage: resolve-llvm-versions.py 22.1 21.1
Output: 20260616 20251216 (one per line)

Matches by LLVM version embedded in release name, e.g.:
  "llvm-mingw 20260616 with LLVM 22.1.8" -> LLVM 22.1 -> tag 20260616
"""

import json
import re
import subprocess
import sys
from urllib.request import urlopen

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <llvm-major.minor> [...]", file=sys.stderr)
        sys.exit(1)

    wanted = sys.argv[1:]

    try:
        req = urlopen("https://api.github.com/repos/mstorsjo/llvm-mingw/releases?per_page=100", timeout=30)
        data = json.loads(req.read())
    except Exception as e:
        print(f"WARNING: Failed to fetch releases: {e}", file=sys.stderr)
        print("\n".join(wanted))
        sys.exit(0)

    # latest[llvm_minor] = (patch, tag)
    latest = {}

    for release in data:
        name = release.get("name", "")
        tag = release.get("tag_name", "")
        m = re.search(r"LLVM (\d+\.\d+)\.(\d+)", name)
        if not m:
            continue
        llvm_minor = m.group(1)
        patch = int(m.group(2))

        has_asset = any("msvcrt-ubuntu-22.04" in a["name"] for a in release.get("assets", []))
        if not has_asset:
            continue

        if llvm_minor not in latest or patch > latest[llvm_minor][0]:
            latest[llvm_minor] = (patch, tag)

    for v in wanted:
        if v in latest:
            print(latest[v][1])
        else:
            print(f"WARNING: LLVM {v} not found, using as-is", file=sys.stderr)
            print(v)

if __name__ == "__main__":
    main()
