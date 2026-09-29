#!/usr/bin/env python3
"""Write assets-manifest.json for the Clayground Web Runtime.

    python3 make-assets-manifest.py [dir ...]        (default: assets)

Lists every file under the given directories (relative to this script's folder, i.e. next to
Main.qml), plus every compiled shader (*.qsb) anywhere below it, so index.html can preload them
into the runtime's in-memory filesystem (/game/<path>) before your game starts. Qt opens these
files only from a local path - a ShaderEffect's `fragmentShader: "shaders/x.frag.qsb"` fails
over http - and the runtime serves a preloaded .qsb for its relative URL. Run it whenever you
add, rename or remove such a file - a file that is on disk but not in the manifest is simply not
preloaded, and Qt will report it as missing.
"""
import json
import os
import sys


def collect(root, dirs):
    """Relative paths (with /) of the files under dirs, plus every *.qsb below root."""
    files = set()
    for d in dirs:
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            print(f"warning: {d}/ not found in {root}", file=sys.stderr)
            continue
        for dirpath, _, names in os.walk(base):
            for n in names:
                if not n.startswith("."):
                    files.add(os.path.relpath(os.path.join(dirpath, n), root).replace(os.sep, "/"))
    for dirpath, subdirs, names in os.walk(root):
        subdirs[:] = [s for s in subdirs if not s.startswith(".")]
        for n in names:
            if n.endswith(".qsb"):
                files.add(os.path.relpath(os.path.join(dirpath, n), root).replace(os.sep, "/"))
    return sorted(files)


if __name__ == "__main__":
    root = os.path.dirname(os.path.abspath(__file__))
    dirs = sys.argv[1:] or ["assets"]
    files = collect(root, dirs)
    out = os.path.join(root, "assets-manifest.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(files, f, indent=0)
        f.write("\n")
    print(f"{out}: {len(files)} file(s) from {', '.join(dirs)} and *.qsb")
