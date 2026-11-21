#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Lab.run() against a committed study (#567).

Runs every cell of street-network-101's grid-capacity study through
`Lab.run()` - all eighteen in ONE clayrender process, one after the other -
and compares each probe's mean with the mean the committed record holds, to
the six significant figures a record carries. One process is the point: a
run that leaked state into the next (a parameter left set, a fleet left on
the plan, a clock not reset) would put every cell after the first off its
record. The first cell is run once more at the end and must come back
bit-identical to its first run.

The cells come from the study manifest, so a study that is re-swept is
checked against what it now says.

    python3 tools/lab-sweep/tests/run_lab_run_test.py --clayrender build/bin/clayrender

Needs a graphics session, like every clayrender test: without one it reports
SKIP (exit 77).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import manifest as M           # noqa: E402
import record as R             # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
STUDY = os.path.join(ROOT, "labs", "street-network-101", "studies", "grid-capacity")
NO_SESSION = "needs a real graphics session"

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


def sig6(v):
    return float(f"{v:.6g}")


def cells(m):
    """One Lab.run() options object per run of the study's matrix."""
    scenario = None
    for line in m.get("setup") or []:
        found = re.search(r'applyScenario\("([^"]+)"\)', line)
        if found:
            scenario = found.group(1)
    out = []
    for run in M.expand(m, {}, None):
        params = dict(m.get("fixed") or {})
        for name, lv in run.levels.items():
            params[name] = lv["value"]
        out.append((run, {
            "scenario": scenario, "seed": run.seed, "params": params,
            "warmupSteps": m["run"].get("warmupSteps", 0),
            "steps": m["run"]["steps"], "stepHz": m["run"]["stepHz"],
            "probes": M.recorded_probes(m)}))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clayrender", required=True)
    args = ap.parse_args()

    with open(os.path.join(STUDY, "study.md"), encoding="utf-8") as f:
        m = M.parse(f.read())
    todo = cells(m)
    check("the study has 18 cells", len(todo) == 18, f"{len(todo)}")

    opts = [o for _, o in todo]
    script = ("(function () {\n"
              f"    var cells = {json.dumps(opts)};\n"
              "    var out = [];\n"
              "    for (var i = 0; i < cells.length; ++i) out.push(Lab.run(cells[i]));\n"
              "    out.push(Lab.run(cells[0]));\n"
              "    return out;\n"
              "})()\n")
    with tempfile.TemporaryDirectory(prefix="lab-run-") as tmp:
        js = os.path.join(tmp, "cells.js")
        with open(js, "w", encoding="utf-8") as f:
            f.write(script)
        res_path = os.path.join(tmp, "result.json")
        p = subprocess.run(
            [args.clayrender, "labs/street-network-101/Sandbox.qml", "--paused",
             "--out", os.path.join(tmp, "frame.png"), "--size", "900x600",
             "--frames", "2", "--script", js, "--result", res_path],
            cwd=ROOT, capture_output=True, text=True,
            env=dict(os.environ, CLAY_SOUND_MUTE="1"))
        out = (p.stdout or "") + (p.stderr or "")
        if NO_SESSION in out:
            print("SKIP  " + NO_SESSION)
            return 77
        if not check("clayrender ran the cells", p.returncode == 0,
                     f"exit {p.returncode}"):
            print(out[-3000:])
            return 1
        with open(res_path, encoding="utf-8") as f:
            got = json.load(f)[0]["value"]

    check("one result per cell, plus the repeat", len(got) == len(todo) + 1,
          f"{len(got)}")
    for (run, _), r in zip(todo, got):
        if not check(f"{run.id}: ran", "error" not in r, r.get("error", "")):
            continue
        rec = R.read(os.path.join(STUDY, "records", run.id + ".labrec"))
        off = []
        for probe in M.recorded_probes(m):
            want = rec.stat(probe, "mean")
            have = r["probes"][probe]["mean"]
            if sig6(have) != want:
                off.append(f"{probe} {sig6(have)} != {want}")
            if r["probes"][probe]["count"] != rec.stat(probe, "count"):
                off.append(f"{probe} count {r['probes'][probe]['count']}")
        check(f"{run.id}: every mean is the record's to six figures",
              not off, "; ".join(off))
    check("the first cell run again is bit-identical",
          json.dumps(got[0], sort_keys=True) == json.dumps(got[-1], sort_keys=True))

    failed = [n for n, ok in CHECKS if not ok]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
