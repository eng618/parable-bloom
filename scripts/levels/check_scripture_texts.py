#!/usr/bin/env python3
"""Prod-upload gate: every scripture_library reference must carry KJV text.

Draft content lands with explicit TODO markers. A missing/placeholder KJV is
fatal (nothing to display). A missing NET is a warning only: the app falls
back to bundled KJV offline and fetches on-demand translations when online.
Run before `task firebase:levels:upload ENV=prod`. Exits non-zero on KJV gaps.
"""

import json
import pathlib
import sys


def main() -> int:
    lib_path = (
        pathlib.Path(__file__).resolve().parent.parent.parent
        / "apps"
        / "parable-bloom"
        / "assets"
        / "data"
        / "scripture_library.json"
    )
    lib = json.loads(lib_path.read_text())["passages"]
    fatal, warnings = {}, []
    for ref, texts in lib.items():
        texts = texts if isinstance(texts, dict) else {}
        kjv = texts.get("KJV", "")
        if not kjv or "TODO" in kjv:
            fatal[ref] = "KJV"
            continue
        net = texts.get("NET", "")
        if not net or "TODO" in net:
            warnings.append(ref)
    if warnings:
        print(f"⚠️  {len(warnings)} references will use KJV fallback (no NET):")
        for ref in sorted(warnings)[:10]:
            print(f"  • {ref}")
        if len(warnings) > 10:
            print(f"  … and {len(warnings) - 10} more")
    if fatal:
        print(f"❌ {len(fatal)} references lack KJV text (prod blocked):")
        for ref in sorted(fatal):
            print(f"  • {ref}")
        return 1
    print(f"✅ All {len(lib)} references carry KJV text ({len(warnings)} on NET fallback).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
