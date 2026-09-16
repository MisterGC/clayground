#!/usr/bin/env python3
"""Generate the clay-lab skill's block catalog from the kernel's own qdoc.

    python3 docs/scripts/lab_catalog.py            # rewrite references/catalog.md
    python3 docs/scripts/lab_catalog.py --check    # exit 1 when it is stale

One line per `Clayground.Lab` type, read from the `\\brief` of its qdoc block
in `plugins/clay_lab/*.qml`, grouped by the `\\ingroup lab-<group>` line every
type carries (#210). The hand-written catalog the skill used to carry drifted
from the kernel with every type added; this one cannot, because `--check` is
a ctest (`lab_catalog`) and a type without a brief or a group fails it.

The catalog names the file next to every brief on purpose: the brief says
what a block is for, the file's qdoc body says how to use it. The skill
repeats neither.

Stdlib only, no qdoc run needed - the briefs are read from the sources, the
same way docs/scripts/import_labs.py reads the labs.
"""

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KERNEL_DIR = os.path.join(ROOT, "plugins", "clay_lab")
OUT_FILE = os.path.join(ROOT, "skills", "clay-lab", "references", "catalog.md")
MODULE = "Clayground.Lab"

# Group id -> heading. Order is the reading order for a new author: what every
# lab has, then what a teaching lab adds, then what a build lab adds, then the
# furniture. A type declaring a group not listed here fails the check, so a
# new group is a deliberate edit in two places.
GROUPS = [
    ("lab-kernel", "Kernel", "the clock, parameters, probes, scenarios and the run record"),
    ("lab-theme", "Theme and language", "tokens, palettes, dictionaries and their switches"),
    ("lab-flow", "Flow", "the narrated walkthrough and what it points at"),
    ("lab-board", "Board", "the build lab's parts, wires and cards"),
    ("lab-chrome", "Chrome", "panels, keys, hints, watches and the stage"),
    ("lab-instruments", "Instruments", "mounted readings: scales, faces, readouts, the dock"),
    ("lab-handheld", "Handheld instruments", "what the viewer picks up and points with"),
    ("lab-camera", "Camera", "shots for a lab with a presenter"),
]

RE_QMLTYPE = re.compile(r"^\s*\\qmltype\s+(\S+)\s*$", re.M)
RE_MODULE = re.compile(r"^\s*\\inqmlmodule\s+(\S+)\s*$", re.M)
RE_GROUP = re.compile(r"^\s*\\ingroup\s+(\S+)\s*$", re.M)
RE_BLOCK = re.compile(r"/\*!(.*?)\*/", re.S)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def type_block(source):
    """The qdoc block that declares the type, or None."""
    for m in RE_BLOCK.finditer(source):
        if RE_QMLTYPE.search(m.group(1)):
            return m.group(1)
    return None


def brief_of(block):
    """The type-level \\brief: its line plus continuation lines up to a blank
    line or the next qdoc command."""
    lines = block.splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"^\s*\\brief\s+(.*)$", line)
        if not m:
            continue
        parts = [m.group(1).strip()]
        for cont in lines[i + 1:]:
            s = cont.strip()
            if not s or s.startswith("\\"):
                break
            parts.append(s)
        return " ".join(parts)
    return None


def plain(text):
    """qdoc inline markup -> markdown."""
    text = re.sub(r"\\l\s*\{([^}]*)\}", r"`\1`", text)
    # A word, not \S+: "\l Flow:" keeps its colon outside the code span.
    text = re.sub(r"\\l\s+(\w[\w.]*\w|\w)", r"`\1`", text)
    text = re.sub(r"\\[ea]\s+(\w[\w.]*\w|\w)", r"*\1*", text)
    text = re.sub(r"\\c\s+(\w[\w.]*\w|\w)", r"`\1`", text)
    return text


def collect():
    """[(group, name, brief, is_singleton, relpath)], plus a list of problems."""
    entries, problems = [], []
    for fn in sorted(os.listdir(KERNEL_DIR)):
        if not fn.endswith(".qml"):
            continue
        path = os.path.join(KERNEL_DIR, fn)
        rel = os.path.relpath(path, ROOT)
        src = read(path)
        block = type_block(src)
        if block is None:
            problems.append(f"{rel}: no qdoc block with \\qmltype")
            continue
        mod = RE_MODULE.search(block)
        if not mod or mod.group(1) != MODULE:
            problems.append(f"{rel}: \\inqmlmodule is not {MODULE}")
            continue
        name = RE_QMLTYPE.search(block).group(1)
        grp = RE_GROUP.search(block)
        if not grp:
            problems.append(f"{rel}: no \\ingroup line")
            continue
        if grp.group(1) not in [g[0] for g in GROUPS]:
            problems.append(f"{rel}: unknown group {grp.group(1)}")
            continue
        brief = brief_of(block)
        if not brief:
            problems.append(f"{rel}: no \\brief")
            continue
        singleton = re.search(r"^\s*pragma\s+Singleton\s*$", src, re.M) is not None
        entries.append((grp.group(1), name, plain(brief), singleton, rel))
    return entries, problems


def render(entries):
    out = []
    out.append("<!-- GENERATED by docs/scripts/lab_catalog.py from the qdoc briefs in")
    out.append("     plugins/clay_lab/ - do not edit. Regenerate:")
    out.append("         python3 docs/scripts/lab_catalog.py")
    out.append("     ctest lab_catalog fails when this file is stale. -->")
    out.append("")
    out.append("# Clayground.Lab — block catalog")
    out.append("")
    out.append("One line per type, from the `\\brief` of its qdoc block. The brief says")
    out.append("what a block is for; the file it names carries the full qdoc body (every")
    out.append("property and verb, and how to wire it). Read the file before using a block")
    out.append("for the first time; the skill does not repeat it.")
    for gid, title, tagline in GROUPS:
        rows = [e for e in entries if e[0] == gid]
        if not rows:
            continue
        out.append("")
        out.append(f"## {title} — {tagline}")
        out.append("")
        for _, name, brief, singleton, rel in rows:
            tag = " (singleton)" if singleton else ""
            out.append(f"- **`{name}`**{tag} — {brief} — `{rel}`")
    out.append("")
    return "\n".join(out)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true",
                    help="exit 1 when the committed catalog differs from what "
                         "the sources say")
    args = ap.parse_args(argv)

    entries, problems = collect()
    if problems:
        for p in problems:
            print(f"lab_catalog: {p}", file=sys.stderr)
        return 1
    text = render(entries)

    if args.check:
        current = read(OUT_FILE) if os.path.exists(OUT_FILE) else None
        if current != text:
            print(f"lab_catalog: {os.path.relpath(OUT_FILE, ROOT)} is stale - run "
                  f"python3 docs/scripts/lab_catalog.py", file=sys.stderr)
            return 1
        print(f"lab_catalog: {len(entries)} types, catalog current")
        return 0

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"lab_catalog: wrote {os.path.relpath(OUT_FILE, ROOT)} ({len(entries)} types)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
