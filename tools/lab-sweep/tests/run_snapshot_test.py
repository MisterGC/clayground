#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Lab.snapshot() and Lab.restore() against real labs (#568).

street-network-101, grid scenario, recorded from step 0:

  straight   900 steps in one go                                -> record A
  restored   600 steps, snapshot written to a file, a detour (another
             demand, another scenario, 200 steps), restore, 300 steps -> B
  new proc   a new clayrender process reads the file, restores, 300 steps -> C

A, B and C must be the same bytes: a restored run goes on exactly as the
uninterrupted one, and the recording in progress comes back with it.

A lab at rest (#575): hydraulics-101 with its valve shut has nothing
flowing, so its clock rests. A snapshot taken while it rests restores and
steps on exactly like the run that was not interrupted, and the restored lab
still rests - resting is a binding on the model, not part of the snapshot.

Then the cost of a restore: sensor-fusion-101 (the most probe samples per
simulated second) and street-network-101 (the biggest model) are run to 60
simulated seconds and restored five times each, and the run after the restore
must match the run after the snapshot. The criterion is 50 ms; the check
allows 150 ms for the median because other work shares the machine, and the
measured min and median are printed for the record.

    python3 tools/lab-sweep/tests/run_snapshot_test.py --clayrender build/bin/clayrender

Needs a graphics session, like every clayrender test: without one it reports
SKIP (exit 77).
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
NO_SESSION = "needs a real graphics session"
STREET = "labs/street-network-101/Sandbox.qml"
FUSION = "labs/sensor-fusion-101/Sandbox.qml"
HYDRO = "labs/hydraulics-101/Sandbox.qml"
PROBES = ["throughput", "asked", "cars", "meanSpeed", "waiting"]
LIMIT_MS = 50
LIMIT_UNDER_LOAD_MS = 150

CHECKS = []


class NoSession(Exception):
    pass


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


def js(path):
    return json.dumps(path.replace(os.sep, "/"))


def render(tmp, name, sandbox, script):
    """Runs one clayrender process; returns the script's result value."""
    path = os.path.join(tmp, name + ".js")
    with open(path, "w", encoding="utf-8") as f:
        f.write(script)
    res = os.path.join(tmp, name + ".result.json")
    p = subprocess.run(
        [args.clayrender, sandbox, "--paused",
         "--out", os.path.join(tmp, name + ".png"), "--size", "900x600",
         "--frames", "2", "--prefs", "isolated", "--script", path, "--result", res],
        cwd=ROOT, capture_output=True, text=True,
        env=dict(os.environ, CLAY_SOUND_MUTE="1"))
    out = (p.stdout or "") + (p.stderr or "")
    if NO_SESSION in out:
        raise NoSession()
    if not check(f"{name}: clayrender ran", p.returncode == 0, f"exit {p.returncode}"):
        print(out[-3000:])
        return None
    with open(res, encoding="utf-8") as f:
        return json.load(f)[0]["value"]


def start_recording(dest):
    """The lab_sweep order: seed, plan, reset, parameters, record."""
    return f"""
    clock._frameTicker.running = false
    clock.seed = 42
    applyScenario("grid")
    Lab.scenario = "grid"
    clock.reset()
    Lab.set("demand", 1.5)
    Lab.set("speed", 15)
    recorder.lab = "labs/street-network-101/Sandbox.qml"
    recorder.destination = {dest}
    recorder.recordId = "snapshot-check"
    recorder.command = "tools/lab-sweep/tests/run_snapshot_test.py"
    recorder.probes = {json.dumps(PROBES)}
    recorder.steps = 900
    recorder.stepSize = 1 / 60
    recorder.recording = true
    function steps(n) {{ for (var i = 0; i < n; ++i) clock._advance(1 / 60) }}
"""


def timing_script(fingerprint):
    """Run to 60 s, snapshot, 300 steps; then five restores, each timed and
    each followed by the same 300 steps."""
    return f"""(function () {{
    clock._frameTicker.running = false
    function steps(n) {{ for (var i = 0; i < n; ++i) clock._advance(1 / 60) }}
    function fp() {{ return JSON.stringify({fingerprint}) }}
    steps(3600)
    var snap = Lab.snapshot()
    if (snap.error) return {{ error: snap.error }}
    var text = JSON.stringify(snap)
    steps(300)
    var straight = fp()
    var ms = [], parseMs = [], same = []
    for (var k = 0; k < 5; ++k) {{
        var t0 = Date.now()
        var r = Lab.restore(snap)
        ms.push(Date.now() - t0)
        if (!r.restored) return {{ error: JSON.stringify(r) }}
        steps(300)
        same.push(fp() === straight)
        t0 = Date.now()
        Lab.restore(JSON.parse(text))
        parseMs.push(Date.now() - t0)
        steps(300)
    }}
    return {{ time: snap.clock.time, bytes: text.length, ms: ms, parseMs: parseMs,
             same: same }}
}})()
"""


def main():
    global args
    ap = argparse.ArgumentParser()
    ap.add_argument("--clayrender", required=True)
    args = ap.parse_args()

    with tempfile.TemporaryDirectory(prefix="lab-snapshot-") as tmp:
        rec_a = os.path.join(tmp, "a.labrec")
        rec_b = os.path.join(tmp, "b.labrec")
        rec_c = os.path.join(tmp, "c.labrec")
        snap = os.path.join(tmp, "at600.snap.json")
        try:
            render(tmp, "straight", STREET, "(function () {" + start_recording(js(rec_a)) + """
    steps(900)
    recorder.recording = false
    return { written: recorder.lastFile, error: recorder.error, steps: labInfo().traffic.steps }
})()
""")
            got = render(tmp, "restored", STREET, "(function () {" + start_recording(js(rec_a + ".unused")) + f"""
    steps(600)
    var snap = Lab.snapshot()
    var w = Lab.writeSnapshot({js(snap)}, snap)
    // a detour, as an experiment trying a variant from here would take
    Lab.set("demand", 2.5)
    applyScenario("crossroads")
    steps(200)
    var r = Lab.restore(snap)
    recorder.destination = {js(rec_b)}
    steps(300)
    recorder.recording = false
    return {{ write: w, restore: r, error: recorder.error }}
}})()
""")
            if got is not None:
                check("restored: the snapshot was written and restored",
                      "written" in got["write"] and got["restore"].get("restored") is True,
                      json.dumps(got))
            got = render(tmp, "new-process", STREET, f"""(function () {{
    clock._frameTicker.running = false
    var t0 = Date.now()
    var r = Lab.restore({js(snap)})
    var ms = Date.now() - t0
    recorder.destination = {js(rec_c)}
    for (var i = 0; i < 300; ++i) clock._advance(1 / 60)
    recorder.recording = false
    return {{ restore: r, ms: ms, error: recorder.error }}
}})()
""")
            if got is not None:
                check("new-process: the file restored", got["restore"].get("restored") is True,
                      json.dumps(got["restore"]))

            texts = {}
            for name, path in (("straight", rec_a), ("restored", rec_b), ("new process", rec_c)):
                if check(f"{name}: wrote its record", os.path.isfile(path)):
                    with open(path, "rb") as f:
                        texts[name] = f.read()
            if len(texts) == 3:
                a = texts["straight"]
                head, _, table = a.partition(b"# samples\n")
                rows = [ln for ln in table.split(b"\n")[1:] if ln]
                # 900 steps of 1/60 s sampled every 0.25 s: t = 0 to 15 s
                check("the records hold the 900 steps' 61 samples",
                      b'"steps": 900' in head and len(rows) == 61,
                      f"{len(rows)} rows, {len(a)} bytes")
                check("restored at 600 and run to 900 is the straight run, byte for byte",
                      texts["restored"] == a)
                check("restored in a new process and run to 900 is the straight run, byte for byte",
                      texts["new process"] == a)

            rest = render(tmp, "resting", HYDRO, """(function () {
    clock._frameTicker.running = false
    function steps(n) { for (var i = 0; i < n; ++i) clock._advance(1 / 60) }
    function fp() { return JSON.stringify({ probes: Lab.probeSummary(),
                                            board: board.state(), r: clock.random() }) }
    root.setValve(2, false)
    steps(600)
    var restingAt = clock.resting
    clock.wake()
    var snap = Lab.snapshot()
    if (snap.error) return { error: snap.error }
    steps(300)
    var straight = fp()
    root.setValve(2, true)
    steps(120)
    var flowingBetween = !clock.resting
    var r = Lab.restore(JSON.parse(JSON.stringify(snap)))
    var restingAfter = clock.resting
    steps(300)
    return { restingAt: restingAt, flowingBetween: flowingBetween,
             restingAfter: restingAfter, restored: r.restored === true,
             same: fp() === straight, inSnapshot: JSON.stringify(snap.clock) }
})()
""")
            if rest is not None and check("resting: snapshot taken", "error" not in rest,
                                          rest.get("error", "")):
                check("resting: the lab rested at the snapshot and flowed between",
                      rest["restingAt"] and rest["flowingBetween"], json.dumps(rest))
                check("resting: restored, it rests again and steps on like the straight run",
                      rest["restored"] and rest["restingAfter"] and rest["same"],
                      json.dumps(rest))
                check("resting: neither resting nor a pending wake() is in the snapshot",
                      "resting" not in rest["inSnapshot"] and "awake" not in rest["inSnapshot"],
                      rest["inSnapshot"])

            for name, sandbox, fingerprint in (
                    ("sensor-fusion-101", FUSION,
                     "{ probes: Lab.probeSummary(), est: [kf.estX, kf.estY], "
                     "odo: [odo.estX, odo.estY], gps: gps.lastFix, r: clock.random() }"),
                    ("street-network-101", STREET,
                     "{ probes: Lab.probeSummary(), sim: root.simState, r: clock.random() }")):
                pre = 'applyScenario("grid"); Lab.set("demand", 1.5);\n' \
                    if sandbox == STREET else ""
                t = render(tmp, "timing-" + name, sandbox,
                           timing_script(fingerprint).replace(
                               "    steps(3600)", "    " + pre + "    steps(3600)", 1))
                if t is None:
                    continue
                if not check(f"{name}: snapshot at 60 s", "error" not in t, t.get("error", "")):
                    continue
                check(f"{name}: every restore at 60 s runs on like the uninterrupted run",
                      all(t["same"]), f"{t['same']}")
                ms, pm = t["ms"], t["parseMs"]
                detail = (f"restore min {min(ms)} ms, median {statistics.median(ms)} ms; "
                          f"with JSON.parse min {min(pm)} ms, median {statistics.median(pm)} ms; "
                          f"snapshot {t['bytes']} bytes at t = {t['time']:.3f} s; "
                          f"criterion {LIMIT_MS} ms")
                check(f"{name}: restoring 60 simulated seconds takes under "
                      f"{LIMIT_UNDER_LOAD_MS} ms (median, under load)",
                      statistics.median(ms) < LIMIT_UNDER_LOAD_MS, detail)
        except NoSession:
            print("SKIP  " + NO_SESSION)
            return 77

    failed = [n for n, ok in CHECKS if not ok]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
