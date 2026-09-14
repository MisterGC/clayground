#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-table - render a study's tables into the prose that quotes them (#209).

    tools/lab-sweep/lab-table labs/electronics-101              # every marked block
    tools/lab-sweep/lab-table labs/electronics-101 --check      # stale? exit 1
    tools/lab-sweep/lab-table labs/electronics-101/studies/series-vs-parallel
    tools/lab-sweep/lab-table labs/electronics-101/paper.md

A marked block is

    <!-- table: series-vs-parallel/pair -->
    ...whatever was here is replaced...
    <!-- /table -->

`<study>/<name>` resolves against the lab's `studies/`; inside a `study.md`
the `<study>/` prefix may be dropped. The table itself is declared in the
study manifest (`tables`, see tables.py) and rendered from the committed
records in `studies/<study>/records/`. The prose around the markers is the
author's; the lines between them are this tool's.

`--check` renders without writing and reports each block as current or
stale, with a unified diff for the stale ones; that is what
`tools/lab-check/lab-check` calls, so a table typed by hand - or one left
behind by a sweep whose numbers moved - is a red line in a build rather than
a wrong number in a paper. It is pure Python over committed files: no lab,
no build, no display, so unlike the `records` check it never says NOT RUN.
"""

import argparse
import difflib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import manifest as M           # noqa: E402
import record as R             # noqa: E402
import tables as T             # noqa: E402

OPEN = re.compile(r"^<!--\s*table:\s*(\S+)\s*-->\s*$")
CLOSE = re.compile(r"^<!--\s*/table\s*-->\s*$")


class TableFileError(Exception):
    pass


def lab_dir_of(path):
    """The lab a path belongs to: the nearest ancestor (or the path itself)
    holding a Sandbox.qml."""
    d = os.path.abspath(path)
    if os.path.isfile(d):
        d = os.path.dirname(d)
    while True:
        if os.path.isfile(os.path.join(d, "Sandbox.qml")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def prose_files(path):
    """The markdown files a path means: a lab's paper.md and every
    studies/*/study.md, a study's study.md, or the one file named."""
    p = os.path.abspath(path)
    if os.path.isfile(p):
        return [p]
    if os.path.isfile(os.path.join(p, "study.md")):
        return [os.path.join(p, "study.md")]
    out = []
    paper = os.path.join(p, "paper.md")
    if os.path.isfile(paper):
        out.append(paper)
    studies = os.path.join(p, "studies")
    if os.path.isdir(studies):
        for name in sorted(os.listdir(studies)):
            doc = os.path.join(studies, name, "study.md")
            if os.path.isfile(doc):
                out.append(doc)
    return out


class Studies:
    """Manifests and records of a lab's studies, loaded once per study."""

    def __init__(self, lab_dir):
        self.lab_dir = lab_dir
        self._cache = {}

    def get(self, slug):
        if slug in self._cache:
            return self._cache[slug]
        study = os.path.join(self.lab_dir, "studies", slug)
        doc = os.path.join(study, "study.md")
        if not os.path.isfile(doc):
            raise TableFileError(f"no study {slug!r} under {os.path.relpath(study)} "
                                 "(no study.md)")
        with open(doc, "r", encoding="utf-8") as f:
            m = M.parse(f.read())
        runs = M.expand(m)
        records = {}
        rdir = os.path.join(study, "records")
        if os.path.isdir(rdir):
            for name in sorted(os.listdir(rdir)):
                if name.endswith(".labrec"):
                    rec = R.read(os.path.join(rdir, name))
                    records[name[:-len(".labrec")]] = rec
        self._cache[slug] = (m, runs, records)
        return self._cache[slug]


def resolve_ref(ref, doc_path, lab_dir):
    """`study/name`, or `name` inside a study.md."""
    if "/" in ref:
        slug, name = ref.split("/", 1)
        if not slug or not name or "/" in name:
            raise TableFileError(f"table reference {ref!r}: expected <study>/<name>")
        return slug, name
    study_dir = os.path.dirname(doc_path)
    if os.path.basename(doc_path) == "study.md" and \
            os.path.dirname(study_dir) == os.path.join(lab_dir, "studies"):
        return os.path.basename(study_dir), ref
    raise TableFileError(f"table reference {ref!r}: outside a study.md the "
                         "reference must be <study>/<name>")


def render_text(text, doc_path, lab_dir, studies):
    """Re-render every marked block in `text`.

    Returns (new_text, blocks) where blocks is a list of
    (ref, rendered lines, previous lines). Raises on a broken marker pair or
    a table that cannot be rendered - a document with one bad block is not
    half-rewritten.
    """
    lines = text.split("\n")
    out = []
    blocks = []
    i = 0
    while i < len(lines):
        m = OPEN.match(lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        ref = m.group(1)
        j = i + 1
        while j < len(lines) and not CLOSE.match(lines[j]):
            if OPEN.match(lines[j]):
                raise TableFileError(f"line {i + 1}: table block {ref!r} is never "
                                     "closed before the next one opens")
            j += 1
        if j >= len(lines):
            raise TableFileError(f"line {i + 1}: table block {ref!r} has no "
                                 "closing <!-- /table --> marker")
        previous = lines[i + 1:j]
        slug, name = resolve_ref(ref, doc_path, lab_dir)
        manifest, runs, records = studies.get(slug)
        try:
            rendered = T.render(manifest, name, runs, records)
        except T.TableError as e:
            raise TableFileError(f"line {i + 1}: {ref}: {e}") from e
        out.append(lines[i])
        out.extend(rendered)
        out.append(lines[j])
        blocks.append((ref, rendered, previous))
        i = j + 1
    return "\n".join(out), blocks


def process(path, check=False, quiet=False):
    """Render (or check) every marked block under `path`.

    Returns a list of (file, ref, ok, detail); ok is False for a stale block
    under --check, and for any block that could not be rendered. Under
    --check nothing is written. Errors are reported per file, never raised,
    so one bad paper does not hide the state of the others.
    """
    lab_dir = lab_dir_of(path)
    if lab_dir is None:
        return [(path, "", False, "not inside a lab (no Sandbox.qml above it)")]
    studies = Studies(lab_dir)
    results = []
    for doc in prose_files(path):
        rel = os.path.relpath(doc, lab_dir)
        with open(doc, "r", encoding="utf-8") as f:
            text = f.read()
        try:
            new_text, blocks = render_text(text, doc, lab_dir, studies)
        except (TableFileError, M.ManifestError, R.RecordError) as e:
            results.append((rel, "", False, str(e)))
            continue
        for ref, rendered, previous in blocks:
            same = rendered == previous
            if check:
                detail = f"{len(rendered) - 2} rows" if same else "stale"
                results.append((rel, ref, same, detail))
                if not same and not quiet:
                    diff = difflib.unified_diff(previous, rendered,
                                                f"{rel} (committed)", f"{rel} (rendered)",
                                                lineterm="")
                    print("\n".join(diff))
            else:
                results.append((rel, ref, True,
                                f"{len(rendered) - 2} rows" + ("" if same else ", rewritten")))
        if not check and new_text != text:
            with open(doc, "w", encoding="utf-8") as f:
                f.write(new_text)
    return results


def main():
    ap = argparse.ArgumentParser(
        prog="lab-table",
        description="Render a study's tables between <!-- table: --> markers.")
    ap.add_argument("path", help="a lab directory, a study directory or one .md file")
    ap.add_argument("--check", action="store_true",
                    help="render without writing; exit 1 if any block differs "
                         "from what is committed")
    args = ap.parse_args()

    results = process(args.path, check=args.check)
    bad = 0
    for rel, ref, ok, detail in results:
        tag = ("current" if args.check else "rendered") if ok else \
              ("STALE" if detail == "stale" else "ERROR")
        print(f"  {tag:8} {rel}" + (f": {ref}" if ref else "") + f"  ({detail})")
        bad += 0 if ok else 1
    if not results:
        print("  no marked table blocks found")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
