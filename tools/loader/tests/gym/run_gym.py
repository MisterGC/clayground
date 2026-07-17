#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Crew Gym run — end-to-end verification of the inspector protocol v2.

Drives the gym sandbox exclusively through the file-based protocol an agent
uses (.clay/inspect/), covering: attach, log stream, scenarios + rearm,
time control (pause/step/scale), synthetic input, trace, and auto-flag.

Default mode copies the gym into a temp dir and spawns clayliveloader
offscreen (CI-safe, source tree stays clean). --attach <sandbox-dir> runs
the same checks against an already-running loader/dojo instance.
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok, detail))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


class Inspect:
    def __init__(self, inspect_dir):
        self.dir = inspect_dir
        self.request_path = os.path.join(inspect_dir, "request.json")
        self.response_path = os.path.join(inspect_dir, "response.json")

    def state(self):
        try:
            with open(os.path.join(self.dir, "state.json")) as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return {}

    def wait_phase(self, phase, timeout=15.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.state().get("phase") == phase:
                return True
            time.sleep(0.1)
        return False

    def request(self, payload, timeout=10.0):
        rid = str(uuid.uuid4())[:8]
        payload = dict(payload)
        payload["id"] = rid
        with open(self.request_path, "w") as f:
            json.dump(payload, f)
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                with open(self.response_path) as f:
                    resp = json.load(f)
                if resp.get("requestId") == rid:
                    return resp
            except (OSError, json.JSONDecodeError):
                pass
            time.sleep(0.05)
        raise TimeoutError(f"no response for {payload.get('action')} ({rid})")

    def eval(self, exprs, timeout=10.0):
        resp = self.request({"action": "eval", "eval": exprs}, timeout)
        return resp.get("eval", {})

    def eval1(self, expr):
        return self.eval([expr]).get(expr)


def wait_for(cond, timeout=10.0, interval=0.1):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if cond():
            return True
        time.sleep(interval)
    return False


def run(insp, sandbox_dir, attended):
    # -- 1: attach --------------------------------------------------------
    ok = insp.wait_phase("ready", timeout=20)
    st = insp.state()
    check("attach: phase ready", ok, f"phase={st.get('phase')}")
    check("attach: protocolVersion >= 2", st.get("protocolVersion", 0) >= 2,
          f"protocolVersion={st.get('protocolVersion')}")
    check("attach: runId present", bool(st.get("runId")),
          f"runId={st.get('runId')}")

    # -- 2: baseline + log stream ----------------------------------------
    snap = insp.request({"action": "snapshot"})
    check("snapshot: has rootProperties", "rootProperties" in snap)
    check("snapshot: scenarios listed",
          snap.get("scenarios") == ["start", "near-coin", "error-probe"],
          str(snap.get("scenarios")))
    insp.eval(["console.log('gym-marker')"])
    log_path = os.path.join(insp.dir, "log.jsonl")

    def marker_logged():
        try:
            with open(log_path) as f:
                return any("gym-marker" in ln for ln in f)
        except OSError:
            return False
    check("log.jsonl: eval marker streamed", wait_for(marker_logged, 5))

    # -- 3: scenario via reload + rearm ----------------------------------
    insp.request({"action": "reload", "scenario": "near-coin", "rearm": True})
    insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)
    insp.wait_phase("ready", timeout=10)
    px = insp.eval1("player.xWu")
    check("scenario near-coin: player placed", px is not None and abs(px - 10) < 0.6,
          f"player.xWu={px}")

    # -- 4: time control --------------------------------------------------
    insp.eval(["applyScenario('start')"])
    resp = insp.request({"action": "time", "paused": True})
    check("time: paused", resp.get("paused") is True)
    x1 = insp.eval1("enemy.xWu")
    time.sleep(0.5)
    x2 = insp.eval1("enemy.xWu")
    check("time pause: enemy frozen", x1 == x2, f"{x1} vs {x2}")

    resp = insp.request({"action": "time", "step": 30})
    check("time step: 30 frames acked", resp.get("stepped") == 30,
          f"stepped={resp.get('stepped')}")
    x3 = insp.eval1("enemy.xWu")
    moved = None if (x2 is None or x3 is None) else abs(x3 - x2)
    check("time step: exact distance (30 * 2/60 Wu)",
          moved is not None and abs(moved - 1.0) < 0.01, f"moved={moved}")

    insp.request({"action": "time", "paused": False, "scale": 0.1})
    xa = insp.eval1("enemy.xWu")
    time.sleep(2.0)
    xb = insp.eval1("enemy.xWu")
    slow = None if (xa is None or xb is None) else abs(xb - xa)
    check("time scale 0.1: ~10% speed", slow is not None and 0.2 < slow < 0.7,
          f"moved={slow} (normal would be ~4.0)")
    insp.request({"action": "time", "scale": 1.0})

    # -- 5: synthetic input + trace --------------------------------------
    # Movement check drives AWAY from the coin: the vendored qml-box2d does
    # not re-fire begin-contact for a fixture pair that already met once, so
    # the scoring run below must be the coin's first player crossing.
    insp.eval(["applyScenario('start')"])
    px1 = insp.eval1("player.xWu")
    insp.request({"action": "input",
                  "gamepad": {"axisX": -1.0, "durationMs": 600}})
    time.sleep(0.9)
    px2 = insp.eval1("player.xWu")
    check("input: player moved (gamepad axis)", px1 is not None
          and px2 is not None and px2 < px1 - 0.5, f"{px1} -> {px2}")

    insp.eval(["applyScenario('near-coin')"])
    tstart = insp.request({"action": "trace", "start": True,
                           "watch": ["player.xWu", "gym.score"],
                           "interval": 100, "stopWhen": "score > 0",
                           "timeout": 10000})
    check("trace: start reports wall-clock epoch",
          tstart.get("epochMs", 0) > 0, f"epochMs={tstart.get('epochMs')}")
    insp.request({"action": "input",
                  "gamepad": {"axisX": 1.0, "durationMs": 2500}})

    def trace_done():
        try:
            with open(insp.response_path) as f:
                resp = json.load(f)
            return resp.get("action") == "trace" and "stoppedBy" in resp
        except (OSError, json.JSONDecodeError):
            return False
    check("trace: completed", wait_for(trace_done, 15))
    with open(insp.response_path) as f:
        tresp = json.load(f)
    check("trace: stopped by condition (coin collected)",
          tresp.get("stoppedBy") == "condition",
          f"stoppedBy={tresp.get('stoppedBy')}")
    try:
        with open(os.path.join(insp.dir, "trace.jsonl")) as f:
            meta = json.loads(f.readline())
    except (OSError, json.JSONDecodeError):
        meta = {}
    check("trace: jsonl meta line carries matching epoch",
          meta.get("meta") == "trace_start"
          and meta.get("epochMs") == tstart.get("epochMs"),
          f"meta={meta.get('meta')} epochMs={meta.get('epochMs')}")
    score = insp.eval1("gym.score")
    check("input: coin collected via gameplay", score == 1, f"score={score}")

    # -- 6: rearm across a real file-watch reload ------------------------
    if attended:
        print("SKIP  rearm-on-edit (attended mode leaves your files alone)")
    else:
        sbx = os.path.join(sandbox_dir, "Sandbox.qml")
        with open(sbx, "a") as f:
            f.write("\n// gym-touch\n")
        ok = wait_for(lambda: insp.state().get("phase") == "reloading", 10) \
            or insp.state().get("phase") == "ready"
        insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)
        insp.wait_phase("ready", timeout=10)
        px = insp.eval1("player.xWu")
        score = insp.eval1("gym.score")
        check("rearm: scenario reapplied after edit",
              px is not None and abs(px - 10) < 0.6 and score == 0,
              f"player.xWu={px} score={score}")

    # -- 7: auto-flag on runtime error -----------------------------------
    for f in glob.glob(os.path.join(insp.dir, "autoflag_*")):
        os.remove(f)
    insp.request({"action": "reload", "scenario": "error-probe"})
    insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)

    def autoflag_written():
        return len(glob.glob(os.path.join(insp.dir, "autoflag_*.json"))) > 0
    ok = check("auto-flag: artifact after runtime error",
               wait_for(autoflag_written, 8))
    if ok:
        with open(sorted(glob.glob(os.path.join(insp.dir, "autoflag_*.json")))[-1]) as f:
            flag = json.load(f)
        check("auto-flag: carries trigger + diagnostics",
              "trigger" in flag and "logTail" in flag and "tree" in flag)

    failed = [c for c in CHECKS if not c[1]]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    return len(failed) == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", help="path to clayliveloader binary")
    ap.add_argument("--attach", metavar="SANDBOX_DIR",
                    help="attach to a running instance serving this sandbox dir")
    ap.add_argument("--keep", action="store_true",
                    help="keep the temp workdir for inspection")
    args = ap.parse_args()

    if args.attach:
        sandbox_dir = os.path.abspath(args.attach)
        insp = Inspect(os.path.join(sandbox_dir, ".clay", "inspect"))
        ok = run(insp, sandbox_dir, attended=True)
        sys.exit(0 if ok else 1)

    if not args.loader:
        ap.error("--loader is required unless --attach is used")

    src = os.path.dirname(os.path.abspath(__file__))
    workdir = tempfile.mkdtemp(prefix="crew-gym-")
    sandbox_dir = os.path.join(workdir, "gym")
    shutil.copytree(src, sandbox_dir,
                    ignore=shutil.ignore_patterns(".clay", "__pycache__"))

    env = dict(os.environ)
    env.setdefault("QT_QPA_PLATFORM", "offscreen")
    # The loader resolves Clayground plugins via a cwd-relative "qml" import
    # path, so run it from the binary's directory (build/bin).
    loader_bin = os.path.abspath(args.loader)
    loader_dir = os.path.dirname(loader_bin)
    env.setdefault("QML2_IMPORT_PATH", os.path.join(loader_dir, "qml"))
    proc = subprocess.Popen(
        [loader_bin, "--sbx", os.path.join(sandbox_dir, "Sandbox.qml")],
        env=env, cwd=loader_dir,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        insp = Inspect(os.path.join(sandbox_dir, ".clay", "inspect"))
        ok = run(insp, sandbox_dir, attended=False)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        if args.keep:
            print(f"workdir kept: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
