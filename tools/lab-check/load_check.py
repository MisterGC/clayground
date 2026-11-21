#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Load one sandbox offscreen and fail on any QML warning or error (#532).

    load_check.py <Sandbox.qml> [--loader build/bin/clayliveloader] [--settle 2]

lab-check's load stage, for a page that is not a lab: the kernel's demo page
and a kit's sandbox have no paper, no flows and no records, so the full gate
has nothing to judge them by - but a warning they log on load is still a
defect in the kernel or the kit, and nothing else loads them.

Stricter than lab-check about whose warning it is. lab-check blames the lab
only for a diagnostic that names the lab's directory; here the page exists to
exercise the kernel, so a warning from a kernel file (qrc:/qt/qml/Clayground/
...) counts as much as one from the page. What does NOT count is the
environment: offscreen has no RHI, so Qt Quick 3D warns about every View3D
on every headless run, and the font database complains about a missing
"Sans Serif" alias - neither names a QML or JS file, and neither is in the
qml/js categories.

Exit 0 clean, 1 a warning or the page did not load, 77 no loader built.
"""

import argparse
import json
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab_check  # noqa: E402

SKIP = 77
QML_CATEGORIES = ("qml", "js")


def from_qml(entry):
    """A diagnostic raised by QML or JS code - the page's, a kit's or the
    kernel's - as opposed to by Qt itself about the environment."""
    if entry.get("category", "default") in QML_CATEGORIES:
        return True
    text = entry.get("text", "")
    return ".qml:" in text or ".js:" in text


def problems(log_path):
    out = []
    try:
        with open(log_path) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get("level") not in ("warning", "error", "critical", "fatal"):
                    continue
                if from_qml(entry):
                    out.append(f"[{entry.get('level')}/{entry.get('category', 'default')}] "
                               f"{entry.get('text', '')}")
    except OSError:
        pass
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("sandbox")
    ap.add_argument("--loader", default=None)
    ap.add_argument("--settle", type=float, default=2.0,
                    help="seconds to let the page run after it is ready - timers "
                         "and deferred loaders warn after the first frame")
    args = ap.parse_args()

    sandbox = os.path.abspath(args.sandbox)
    if not os.path.isfile(sandbox):
        print(f"load-check: {sandbox} does not exist", file=sys.stderr)
        return 1
    root = lab_check.repo_root(os.path.dirname(sandbox))
    loader = os.path.abspath(args.loader or os.path.join(root, "build", "bin",
                                                         "clayliveloader"))
    if not (os.path.isfile(loader) and os.access(loader, os.X_OK)):
        print(f"SKIP  {loader} does not exist")
        return SKIP

    page = os.path.relpath(sandbox, root)
    with lab_check.Loader(loader, sandbox) as session:
        ready = session.ready(timeout=90)
        if ready:
            time.sleep(args.settle)
        state = session.insp.state()
        found = problems(os.path.join(session.insp.dir, "log.jsonl"))
    shutil.rmtree(os.path.join(os.path.dirname(sandbox), ".clay"), ignore_errors=True)

    if not ready:
        print(f"FAIL  {page} never reached phase ready (phase={state.get('phase')})")
        for p in found:
            print("      " + p)
        return 1
    if found:
        print(f"FAIL  {page} logged {len(found)} QML warning(s)/error(s):")
        for p in found:
            print("      " + p)
        return 1
    print(f"PASS  {page} loaded with no QML warning or error")
    return 0


if __name__ == "__main__":
    sys.exit(main())
