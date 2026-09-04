#!/usr/bin/env python3
"""Write assets-manifest.json for the Clayground Web Runtime.

    python3 make-assets-manifest.py [dir ...]        (default: assets)

Lists every file under the given directories (relative to this script's folder, i.e. next to
Main.qml) so index.html can preload them into the runtime's in-memory filesystem (/game/<path>)
before your game starts. Run it whenever you add, rename or remove an asset file - a file that
is on disk but not in the manifest is simply not preloaded, and Qt will report it as missing.
"""
import json
import os
import sys

root = os.path.dirname(os.path.abspath(__file__))
dirs = sys.argv[1:] or ["assets"]
files = []
for d in dirs:
    base = os.path.join(root, d)
    if not os.path.isdir(base):
        print(f"warning: {d}/ not found next to {os.path.basename(__file__)}", file=sys.stderr)
        continue
    for dirpath, _, names in os.walk(base):
        for n in sorted(names):
            if n.startswith("."):
                continue
            files.append(os.path.relpath(os.path.join(dirpath, n), root).replace(os.sep, "/"))
files.sort()
out = os.path.join(root, "assets-manifest.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(files, f, indent=0)
    f.write("\n")
print(f"{out}: {len(files)} file(s) from {', '.join(dirs)}")
