# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""A reload asked to start fresh puts a running lab back to a clean start (#566).

A plain reload hands the outgoing root's viewState() to the next one, and a
lab's view state carries its scenario, its sim time and every parameter. So
a loader that is kept running carried state from one question to the next:
a reload into "tunnel" after "open-sky" came up in "open-sky" at the old
time, and a GPS noise of 8 stayed 8. With `"fresh": true` the reload drops
the view state. Checked here, in ONE loader process:

  1. after open-sky ran 2 s with gpsSigma 8, a fresh reload into "tunnel"
     comes up in "tunnel", at sim time 0, with gpsSigma at its declared 3;
  2. two fresh reloads, each followed by the same 600 stepped 1/60 s frames,
     write byte-identical records.

The clock is paused before anything else (`time`/`paused`, a property of
the loader that survives a reload), so no wall-clock frame runs between a
root's creation and the steps; sim time is a function of the step count.

  run_fresh_reload_test.py --loader <clayliveloader> --lab <labs/sensor-fusion-101>

The lab is copied, with labs/kits beside it, into a temporary directory, so
the test never writes .clay/ into the source tree.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

from run_reload_test import write_request

STEPS = 600
SCENARIO = "tunnel"

RECORD_JS = """
(function () {
    var rec = Qt.createQmlObject("import Clayground.Lab; DataRecorder {}", root);
    rec.lab = "fresh-reload-test";
    rec.destination = %(dest)s;
    rec.recordId = %(scenario)s;
    rec.steps = %(steps)d;
    rec.stepSize = 1 / 60;
    rec.recording = true;
    for (var i = 0; i < %(steps)d; ++i) Lab.clock._advance(1 / 60);
    rec.recording = false;
    var out = { rows: rec.rows, error: rec.error, time: Lab.clock.time };
    rec.destroy();
    return JSON.stringify(out);
})()
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", required=True)
    ap.add_argument("--lab", required=True, help="labs/sensor-fusion-101")
    ap.add_argument("--timeout", type=float, default=60.0)
    args = ap.parse_args()
    args.loader = os.path.abspath(args.loader)

    lab = os.path.abspath(args.lab)
    kits = os.path.join(os.path.dirname(lab), "kits")
    work = tempfile.mkdtemp(prefix="clay-fresh-")
    try:
        labs = os.path.join(work, "labs")
        shutil.copytree(lab, os.path.join(labs, os.path.basename(lab)),
                        ignore=shutil.ignore_patterns(".clay"))
        if os.path.isdir(kits):
            shutil.copytree(kits, os.path.join(labs, "kits"),
                            ignore=shutil.ignore_patterns(".clay"))
        sandbox = os.path.join(labs, os.path.basename(lab), "Sandbox.qml")
        return run(args, sandbox, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run(args, sandbox, work):
    inspect = os.path.join(os.path.dirname(sandbox), ".clay", "inspect")
    env = dict(os.environ)
    env["QT_QPA_PLATFORM"] = env.get("QT_QPA_PLATFORM", "offscreen")
    env["CLAY_SOUND_MUTE"] = "1"
    log_path = os.path.join(work, "loader.log")
    log = open(log_path, "w")
    proc = subprocess.Popen([args.loader, "--sbx", sandbox], env=env,
                            cwd=os.path.dirname(args.loader),
                            stdout=log, stderr=subprocess.STDOUT)

    def state():
        try:
            with open(os.path.join(inspect, "state.json")) as f:
                return json.load(f)
        except (OSError, ValueError):
            return None

    def request(req, timeout=args.timeout):
        req = dict(req, id=uuid.uuid4().hex[:8])
        write_request(inspect, req)
        end = time.time() + timeout
        while time.time() < end:
            try:
                with open(os.path.join(inspect, "response.json")) as f:
                    resp = json.load(f)
                if resp.get("requestId") == req["id"]:
                    return resp
            except (OSError, ValueError):
                pass
            if proc.poll() is not None:
                raise RuntimeError("the loader exited")
            time.sleep(0.005)
        raise RuntimeError("no answer to %s" % req.get("action"))

    def ev(expr):
        r = request({"action": "eval", "eval": [expr]})
        return r.get("eval", {}).get(expr)

    def ev_json(expr):
        raw = ev("JSON.stringify(%s)" % expr)
        if not isinstance(raw, str):
            raise RuntimeError("%s answered %r" % (expr, raw))
        return json.loads(raw)

    def wait_for_generation(after):
        # waitForRoot can answer for the outgoing root while the new one is
        # still loading; the generation only moves once the new one is it
        end = time.time() + args.timeout
        while time.time() < end:
            s = state()
            if s and s.get("phase") == "ready" and s.get("generation", 0) > after:
                return s["generation"]
            if proc.poll() is not None:
                raise RuntimeError("the loader exited")
            time.sleep(0.01)
        raise RuntimeError("the reload never became the root")

    def reload(**kw):
        before = state().get("generation", 0)
        resp = request(dict({"action": "reload"}, **kw))
        if kw.get("fresh") and resp.get("fresh") is not True:
            raise RuntimeError("the reload did not acknowledge fresh: %r" % resp)
        wait_for_generation(before)

    failures = []

    def check(name, ok, detail=""):
        print("%s  %s%s" % ("PASS" if ok else "FAIL", name,
                            "  (%s)" % detail if detail else ""))
        if not ok:
            failures.append(name)

    try:
        wait_for_generation(0)
        request({"action": "time", "paused": True})

        # 1. a lab that has run: open-sky, 2 s in, GPS noise 8
        ev("(function(){ applyScenario('open-sky'); Lab.set('gpsSigma', 8);"
           " for (var i = 0; i < 120; ++i) Lab.clock._advance(1 / 60); })()")
        before = ev_json("Lab.labInfo()")
        check("the lab ran before the reload",
              before["scenario"] == "open-sky" and before["params"]["gpsSigma"] == 8
              and before["time"] > 1.9, json.dumps({k: before[k] for k in
                                                    ("scenario", "time")}))

        reload(fresh=True, scenario=SCENARIO)
        after = ev_json("Lab.labInfo()")
        declared = ev("Lab.parameter('gpsSigma').defaultValue")
        check("a fresh reload comes up in the scenario it names",
              after["scenario"] == SCENARIO, "scenario=%r" % after["scenario"])
        check("a fresh reload starts at sim time 0",
              after["time"] == 0, "time=%r" % after["time"])
        check("a fresh reload starts with the declared parameters",
              after["params"]["gpsSigma"] == declared == 3,
              "gpsSigma=%r, declared %r" % (after["params"]["gpsSigma"], declared))

        # 2. two fresh reloads, the same 600 steps, byte-identical records
        paths = []
        for run_no in ("a", "b"):
            reload(fresh=True, scenario=SCENARIO)
            dest = os.path.join(work, "%s-%s.labrec" % (SCENARIO, run_no))
            res = ev_json(RECORD_JS % {"dest": json.dumps(dest),
                                       "scenario": json.dumps(SCENARIO),
                                       "steps": STEPS})
            res = json.loads(res) if isinstance(res, str) else res
            if res.get("error") or not os.path.isfile(dest):
                check("record %s is written" % run_no, False,
                      res.get("error") or "no file at " + dest)
                break
            paths.append((dest, res))
        if len(paths) == 2:
            a = open(paths[0][0], "rb").read()
            b = open(paths[1][0], "rb").read()
            check("two fresh reloads, %d steps each, write byte-identical records"
                  % STEPS, a == b and len(a) > 0,
                  "%d rows, %d bytes, sim time %.3f s"
                  % (paths[0][1]["rows"], len(a), paths[0][1]["time"]))
    except RuntimeError as e:
        check("the run reaches its end", False, str(e))
    finally:
        alive = proc.poll() is None
        if alive:
            proc.terminate()
            try:
                proc.wait(10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        log.close()

    if failures:
        print("--- last lines of the loader's log ---")
        with open(log_path, errors="replace") as f:
            for line in f.read().splitlines()[-30:]:
                print(line)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
