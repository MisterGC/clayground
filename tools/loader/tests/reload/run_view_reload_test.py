# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""A reload and a restart keep the running lesson and the selection (#569).

Before, a reload came back without the lesson that ran - the step went from 3
to none - and with nothing selected, and a new loader process started from
nothing at all. Now a lab's view state carries each running flow
(Flow.state()) and the part in hand, the loader says when that view is back
(state.json `viewRestore`, after "ready"), and it saves the view to
.clay/inspect/view-state.json, which a loader started with --restore-view
comes back to.

  run_view_reload_test.py --loader <clayliveloader> --lab <labs/electronics-101>
                          [--flow series-parallel] [--step 3]

With the clock paused, the flow is started and walked to --step, a part is
selected and the clock stepped, then:

  1. a plain reload: the same flow at the same step, with the same names,
     checkpoints, time in the step and answers, the same part selected and the
     same snapshot; state.json said "ready" and then "restored" for that
     generation, and events.jsonl holds view_state_restored after the ready;
  2. a `snapshot` response shows the flow's step without its checkpoints;
  3. another part is selected, the loader killed once it has saved that view
     (as the dojo kills its child to restart it), and a new loader started
     with --restore-view, --paused and --lab-src, as a dojo respawn may be:
     a second later the lesson, the new selection and the snapshot - sim time
     included - are back, restored from the saved file, and the clock held;
  4. a loader started without --restore-view starts without the lesson.

The lab is copied, with labs/kits beside it, into a temporary directory.
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_reload_test import write_request  # noqa: E402

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


class Loader:
    """One clayliveloader process on the sandbox, driven through .clay/inspect."""

    def __init__(self, args, sandbox, work, extra, tag):
        self.args = args
        self.inspect = os.path.join(os.path.dirname(sandbox), ".clay", "inspect")
        env = dict(os.environ)
        env["QT_QPA_PLATFORM"] = env.get("QT_QPA_PLATFORM", "offscreen")
        env["CLAY_SOUND_MUTE"] = "1"
        self.log_path = os.path.join(work, f"loader-{tag}.log")
        self.log = open(self.log_path, "w")
        self.proc = subprocess.Popen([args.loader, "--sbx", sandbox] + extra, env=env,
                                     cwd=os.path.dirname(args.loader),
                                     stdout=self.log, stderr=subprocess.STDOUT)
        self.states = []    # every distinct state.json seen while waiting

    def state(self):
        try:
            with open(os.path.join(self.inspect, "state.json")) as f:
                s = json.load(f)
        except (OSError, ValueError):
            return None
        if s.get("pid") != self.proc.pid:
            return None
        if not self.states or self.states[-1] != s:
            self.states.append(s)
        return s

    def request(self, req):
        req = dict(req, id=uuid.uuid4().hex[:8])
        write_request(self.inspect, req)
        end = time.time() + self.args.timeout
        while time.time() < end:
            try:
                with open(os.path.join(self.inspect, "response.json")) as f:
                    resp = json.load(f)
                if resp.get("requestId") == req["id"]:
                    return resp
            except (OSError, ValueError):
                pass
            if self.proc.poll() is not None:
                return None
            time.sleep(0.005)
        return None

    def ev(self, expr):
        resp = self.request({"action": "eval", "eval": [expr]})
        return None if resp is None else resp.get("eval", {}).get(expr)

    def wait_for_generation(self, after):
        end = time.time() + self.args.timeout
        while time.time() < end:
            s = self.state()
            if s and s.get("phase") == "ready" and s.get("generation", 0) > after \
                    and s.get("viewRestore") != "restoring":
                return s["generation"]
            if self.proc.poll() is not None:
                return None
            time.sleep(0.001)
        return None

    def events(self):
        try:
            with open(os.path.join(self.inspect, "events.jsonl")) as f:
                return [json.loads(line) for line in f if line.strip()]
        except (OSError, ValueError):
            return []

    def stop(self, kill=False):
        if self.proc.poll() is None:
            if kill:
                self.proc.kill()
            else:
                self.proc.terminate()
            try:
                self.proc.wait(10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        self.log.close()

    def tail(self):
        with open(self.log_path, errors="replace") as f:
            return f.read().splitlines()[-30:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", required=True)
    ap.add_argument("--lab", required=True, help="a lab directory under labs/")
    ap.add_argument("--flow", default="series-parallel")
    ap.add_argument("--step", type=int, default=3)
    ap.add_argument("--timeout", type=float, default=60.0)
    args = ap.parse_args()
    args.loader = os.path.abspath(args.loader)

    lab = os.path.abspath(args.lab)
    kits = os.path.join(os.path.dirname(lab), "kits")
    work = tempfile.mkdtemp(prefix="clay-viewreload-")
    loaders = []
    try:
        labs = os.path.join(work, "labs")
        shutil.copytree(lab, os.path.join(labs, os.path.basename(lab)),
                        ignore=shutil.ignore_patterns(".clay"))
        if os.path.isdir(kits):
            shutil.copytree(kits, os.path.join(labs, "kits"),
                            ignore=shutil.ignore_patterns(".clay"))
        sandbox = os.path.join(labs, os.path.basename(lab), "Sandbox.qml")
        code = run(args, sandbox, work, loaders)
    finally:
        for ld in loaders:
            ld.stop()
        if any(not ok for _, ok in CHECKS):
            for ld in loaders:
                print(f"--- last lines of {os.path.basename(ld.log_path)} ---")
                for line in ld.tail():
                    print(line)
        shutil.rmtree(work, ignore_errors=True)
    failed = [n for n, ok in CHECKS if not ok]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    return code if code else (1 if failed else 0)


def place(ld, flow):
    """The learner's place as data: the flow, the selection, the answers, the run."""
    out = ld.ev("JSON.stringify({ flow: Lab._flows[%s].state(), selected: selectedId,"
                " answers: answers, snapshot: Lab.snapshot() })" % json.dumps(flow))
    return None if out is None else json.loads(out)


def run(args, sandbox, work, loaders):
    name = os.path.basename(os.path.dirname(sandbox))
    flow = json.dumps(args.flow)

    ld = Loader(args, sandbox, work, [], "first")
    loaders.append(ld)
    generation = ld.wait_for_generation(0)
    if not check(f"{name}: the first load became ready", generation is not None):
        return 1
    check(f"{name}: the clock paused", ld.request({"action": "time", "paused": True}) is not None)

    walked = ld.ev("(function () { var f = Lab._flows[%s]; f.start();"
                   " for (var i = 0; i < %d; ++i) f.next();"
                   " for (var k = 0; k < 90; ++k) clock._advance(1 / 60);"
                   " return f.index })()" % (flow, args.step))
    check(f"{name}: the lesson {args.flow} is at step {args.step}", walked == args.step,
          f"{walked}")
    parts = ld.ev("JSON.stringify(board.parts.map(function (p) { return p.id }))")
    parts = json.loads(parts) if parts else []
    if not check(f"{name}: the board has parts to select", len(parts) >= 2, f"{parts}"):
        return 1
    ld.ev(f"(function () {{ selectedId = {parts[-1]}; return selectedId }})()")
    ld.ev("(function () { answers = { guess: 'dimmer' }; return 1 })()")
    before = place(ld, args.flow)
    check(f"{name}: part {parts[-1]} is selected", before and before["selected"] == parts[-1],
          f"{before and before['selected']}")

    # 1. a plain reload
    if ld.request({"action": "reload"}) is None:
        check(f"{name}: the reload answered", False)
        return 1
    nxt = ld.wait_for_generation(generation)
    if not check(f"{name}: the reload became the root", nxt is not None):
        return 1
    generation = nxt
    after = place(ld, args.flow)
    for key in ("flow", "selected", "answers", "snapshot"):
        check(f"{name}: after the reload the {key} is as before",
              after is not None and after.get(key) == before.get(key),
              "" if after is None else f"{json.dumps(after.get(key))[:120]} vs "
                                       f"{json.dumps(before.get(key))[:120]}")
    cps = ((after or {}).get("flow") or {}).get("checkpoints") or {}
    check(f"{name}: the lesson's checkpoints hold the lab without the lessons",
          len(cps) == args.step + 1
          and all("flows" not in (cp.get("view") or {}) for cp in cps.values()),
          f"{len(cps)} checkpoints")
    seen = [(s.get("generation"), s.get("phase"), s.get("viewRestore")) for s in ld.states]
    final = ld.state() or {}
    check(f"{name}: state.json says the view of generation {generation} is restored",
          final.get("viewRestore") == "restored"
          and final.get("viewRestoredGeneration") == generation, f"{seen[-3:]}")
    evs = ld.events()
    kinds = [e.get("type") + ":" + str((e.get("data") or {}).get("phase", "")) for e in evs]
    ready_at = max((i for i, k in enumerate(kinds) if k == "phase_change:ready"), default=-1)
    restored = [e for e in evs[ready_at + 1:] if e.get("type") == "view_state_restored"]
    check(f"{name}: events.jsonl has view_state_restored after the ready",
          len(restored) == 1 and restored[0]["data"].get("ok") is True
          and restored[0]["data"].get("generation") == generation
          and restored[0]["data"].get("source") == "reload",
          f"{restored and restored[0]['data']}")

    # 2. what a reader is shown
    snap = ld.request({"action": "snapshot"}) or {}
    shown = ((snap.get("viewState") or {}).get("flows") or {}).get(args.flow) or {}
    check(f"{name}: a snapshot response shows the lesson's step without its checkpoints",
          shown.get("index") == args.step and "checkpoints" not in shown,
          f"keys {sorted(shown)}")
    check(f"{name}: the status envelope says the view is restored",
          (snap.get("status") or {}).get("viewRestore") == "restored")

    # 3. a killed loader and a new one with --restore-view
    other = parts[0]
    ld.ev(f"(function () {{ selectedId = {other}; return selectedId }})()")
    want = place(ld, args.flow)
    saved_path = os.path.join(ld.inspect, "view-state.json")
    end = time.time() + 15
    saved = None
    while time.time() < end:
        try:
            with open(saved_path) as f:
                saved = json.load(f)
            if (saved.get("viewState") or {}).get("selected") == other:
                break
        except (OSError, ValueError):
            pass
        time.sleep(0.1)
    check(f"{name}: the loader saved the view with part {other} selected",
          saved is not None and (saved.get("viewState") or {}).get("selected") == other)
    ld.stop(kill=True)

    t0 = time.time()
    # as a dojo respawn starts it: its own options (--lab-src, --paused) and
    # --restore-view beside them
    ld2 = Loader(args, sandbox, work, ["--restore-view", "--paused", "--lab-src"], "restart")
    loaders.append(ld2)
    g2 = ld2.wait_for_generation(0)
    took = time.time() - t0
    if not check(f"{name}: the restarted loader became ready", g2 is not None):
        return 1
    # a second of wall clock: a clock that runs would have left the restored time
    time.sleep(1.0)
    paused = (ld2.request({"action": "time"}) or {}).get("paused")
    check(f"{name}: --paused holds the restored lab", paused is True, f"paused={paused}")
    back = place(ld2, args.flow)
    for key in ("flow", "selected", "answers", "snapshot"):
        check(f"{name}: after the restart the {key} is as before",
              back is not None and back.get(key) == want.get(key),
              "" if back is None else f"{json.dumps(back.get(key))[:120]} vs "
                                      f"{json.dumps(want.get(key))[:120]}")
    st = ld2.state() or {}
    check(f"{name}: the restarted loader says the view is restored",
          st.get("viewRestore") == "restored" and st.get("viewRestoredGeneration") == g2,
          f"{st.get('viewRestore')}")
    rs = [e for e in ld2.events() if e.get("type") == "view_state_restored"]
    check(f"{name}: it came from the saved file",
          len(rs) == 1 and rs[0]["data"].get("source") == "restart",
          f"{rs and rs[0]['data']} in {took:.1f} s")
    ld2.stop()

    # 4. without --restore-view a loader starts clean
    ld3 = Loader(args, sandbox, work, [], "plain")
    loaders.append(ld3)
    if not check(f"{name}: a loader without --restore-view became ready",
                 ld3.wait_for_generation(0) is not None):
        return 1
    plain = place(ld3, args.flow)
    check(f"{name}: and starts without the lesson",
          plain is not None and plain.get("flow") is None, f"{plain and plain.get('flow')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
