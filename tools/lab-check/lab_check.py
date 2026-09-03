#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-check - the lab contract as a failing test (#208).

    tools/lab-check/lab-check labs/electronics-101
    tools/lab-check/lab-check labs/electronics-101 --only flows,strings
    tools/lab-check/lab-check labs/electronics-101 --keep      # keep the workdir

The contract a lab signs - deterministic, flows are tests, records regenerate,
both languages say the same things - was discipline and nothing else until this
existed, and discipline decays quietly: a record whose committed bytes no longer
regenerate is still a file, and a lab with no flow still opens. One run of this
turns each of those into a named PASS/FAIL line and a non-zero exit.

WHAT IS CHECKED, IN ORDER

  load          the lab boots and logs nothing of its own
  determinism   every scenario, two stepped runs, byte-identical records
  flows         every flow runs to its end, with its expects holding
  strings       EN and DE say the same set of things, flows included
  records       records/make.sh and studies/* regenerate the committed bytes
  remarks       open CriticMarkup marks in the prose (reported, never failed)

Exit 0 when everything passed, 1 on any FAIL, 77 (the ctest SKIP_RETURN_CODE)
when the machine cannot run the check at all - no clayliveloader built.

WHY THE LOADER AND NOT clayrender. Issue #208 proposed `clayrender --paused`.
clayrender needs a real graphics session and refuses to run under
QT_QPA_PLATFORM=offscreen, so a gate built on it could never be green in CI -
and a gate that only runs on one desk is a footnote again. clayliveloader runs
offscreen, and its inspector protocol *returns eval values*, which is the other
half of what #208 wanted from #207. The same route tools/lab-new's boot tests
take. The records check is the one part that still shells out to clayrender
(that is what the committed `command` field says regenerates a record); it
reports itself as not-run rather than failing when there is no display.

WHY A RUN IS STEPPED. Left alone a lab advances on a FrameAnimation, and a
frame is a wall-clock interval: two runs of one seed then sample different
instants. Every run here pauses the clock first (`time`/`paused`, the same
control the dojo's transport uses), applies the scenario - which resets the
clock, the seeded RNG and every probe - and then advances sim time by hand in
1/60 s steps. Sim time is a function of the step count and of nothing else.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

SKIP = 77
CHECK_ORDER = ["load", "determinism", "flows", "strings", "records", "remarks"]
DEFAULT_STEPS = 600
DEFAULT_MAX_FLOW_STEPS = 20000


# --------------------------------------------------------------------------
# reporting


class Report:
    """Every line this tool prints, and the verdict it adds up to."""

    def __init__(self):
        self.lines = []

    def check(self, name, ok, detail=""):
        self.lines.append((name, ok, detail))
        print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
        return ok

    def note(self, text):
        # Not a check: something worth reading that cannot be red.
        print("      " + text)

    def failed(self):
        return [n for n, ok, _d in self.lines if not ok]


# --------------------------------------------------------------------------
# the inspector protocol, minus everything this tool does not need


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

    def wait_phase(self, phase, timeout=60.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.state().get("phase") == phase:
                return True
            time.sleep(0.1)
        return False

    def request(self, payload, timeout=120.0):
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

    def eval1(self, expr, timeout=120.0):
        return self.request({"action": "eval", "eval": [expr]},
                            timeout).get("eval", {}).get(expr)

    def eval_json(self, expr, timeout=120.0):
        """Evaluate an expression whose value is JSON.

        The protocol reports an array or object as null, so everything that
        carries an answer goes over the wire stringified - and an expression
        that threw comes back as {"error": ...}, which is an answer too.
        """
        raw = self.eval1("JSON.stringify(%s)" % expr, timeout)
        if isinstance(raw, dict) and "error" in raw:
            return {"__error__": raw["error"]}
        if not isinstance(raw, str):
            return {"__error__": f"expected a JSON string, got {raw!r}"}
        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:
            return {"__error__": f"unparsable answer: {e} ({raw[:120]!r})"}


class Loader:
    """One clayliveloader process, driven offscreen through .clay/inspect."""

    def __init__(self, loader, sandbox, quiet=True):
        self.loader = loader
        self.sandbox = sandbox
        self.lab_dir = os.path.dirname(sandbox)
        self.quiet = quiet
        self.proc = None
        self.insp = None

    def __enter__(self):
        # A stale .clay from an earlier run would answer "ready" before this
        # process has even started, and every question after that would be
        # asked of a corpse.
        shutil.rmtree(os.path.join(self.lab_dir, ".clay"), ignore_errors=True)

        env = dict(os.environ)
        env["QT_QPA_PLATFORM"] = "offscreen"
        env["QT_DISABLE_SHADER_DISK_CACHE"] = "1"
        bindir = os.path.dirname(os.path.abspath(self.loader))
        env.setdefault("QML2_IMPORT_PATH", os.path.join(bindir, "qml"))
        sink = subprocess.DEVNULL if self.quiet else None
        # The loader resolves Clayground plugins via a cwd-relative "qml"
        # import path, so it runs from the binary's directory.
        self.proc = subprocess.Popen(
            [self.loader, "--sbx", self.sandbox],
            env=env, cwd=bindir, stdout=sink, stderr=sink)
        self.insp = Inspect(os.path.join(self.lab_dir, ".clay", "inspect"))
        return self

    def __exit__(self, *exc):
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        return False

    def ready(self, timeout=90.0):
        return self.insp.wait_phase("ready", timeout=timeout)

    def fresh_root(self, timeout=90.0):
        """A newly created root with the clock paused since before it existed.

        Pausing is a property of the loader, not of the scene, so it survives
        the reload - which is what makes "no wall-clock frame ran before
        applyScenario" true rather than hoped for. The reload also throws away
        everything the previous run built.

        A reload only answers "requested": the load has not happened yet, and
        while the phase is still the OLD terminal one, waitForRoot returns at
        once. Waiting on the GENERATION instead is the only way to know the
        answer came from the new root - without it every run after the first
        measures the scene the previous run left behind, which is a
        determinism check that compares two different experiments.

        The clock of the OUTGOING root is reset, AFTER the pause and before
        the reload, and neither half of that order is housekeeping. The loader
        captures viewState() from every root it is about to throw away and
        re-applies it to the next one, and a lab's viewState carries its sim
        time - so Lab.applyViewState() re-steps the brand-new clock to where
        the finished run left it, and a "fresh" root arrives having already
        replayed the previous run. Resetting before the pause is no better:
        the ticker keeps running in the gap and the capture picks up whatever
        wall-clock time elapsed between the two requests, which is how the
        first run of a session ends up being the only one that differs.
        """
        before = self.insp.request({"action": "time", "paused": True}) \
                     .get("status", {}).get("generation", 0)
        self.insp.eval1("(function(){ if (Lab.clock) Lab.clock.reset(); })()")
        self.insp.request({"action": "reload"})
        deadline = time.time() + timeout
        while time.time() < deadline:
            r = self.insp.request({"action": "waitForRoot",
                                   "timeoutMs": int(timeout * 1000)},
                                  timeout=timeout + 10)
            if r.get("status", {}).get("generation", 0) > before:
                return r.get("phase") == "ready"
            time.sleep(0.05)
        return False

    def diagnostics(self):
        """Warnings and errors the loader streamed, split into the lab's own
        and the environment's.

        Split by the file a diagnostic names, not by its category: offscreen
        has no RHI, so Qt Quick 3D warns about every View3D on every headless
        run whatever the scene is. A QML diagnostic from the sandbox always
        carries `<file>:<line>:<col>`, so naming the lab directory is exactly
        the test for "this one is ours".
        """
        ours, other = [], []
        path = os.path.join(self.insp.dir, "log.jsonl")
        try:
            with open(path) as f:
                for line in f:
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if entry.get("level") not in ("warning", "error"):
                        continue
                    body = entry.get("text", "")
                    cat = entry.get("category", "default")
                    text = f"[{entry.get('level')}/{cat}] {body}"
                    (ours if self.lab_dir in body else other).append(text)
        except OSError:
            pass
        return ours, other


# --------------------------------------------------------------------------
# the scene-side drivers
#
# Each one is a single self-contained expression: the protocol's eval keeps no
# scope between requests, so a driver cannot leave helpers behind for the next.

PROBE_JS = """
(function () {
    %(walk)s
    var out = { scenarios: [], flows: [], flowsError: "", langs: [],
                keys: {}, kernelKeys: {}, flowKeys: [], recorderOk: false };
    try { out.scenarios = root.scenarios() } catch (e) { out.scenariosError = String(e) }
    try { out.flows = root.flows ? root.flows() : [] }
    catch (e) { out.flowsError = String(e) }
    try {
        for (var l in LabLang._dicts) {
            out.langs.push(l);
            out.keys[l] = Object.keys(LabLang._dicts[l]);
        }
        for (var k in LabLang._kernel) out.kernelKeys[k] = Object.keys(LabLang._kernel[k]);
    } catch (e) { out.langsError = String(e) }
    // Which narration keys the flows actually ask for: `flow.<flowId>.<key>`
    // for every step that carries one, plus whatever a task names as its hint.
    try {
        var found = [];
        _walk(root, [], function (o) {
            var id = null;
            try { id = o.flowId } catch (e) { return }
            if (!id || o.steps === undefined) return;
            for (var i = 0; i < o.steps.length; ++i) {
                var s = o.steps[i];
                if (s.key) found.push("flow." + id + "." + s.key);
                try { if (s.task && s.task.hint) found.push(String(s.task.hint)) } catch (e) {}
            }
            if (o.titleKey) found.push(String(o.titleKey));
        });
        out.flowKeys = found;
    } catch (e) { out.flowKeysError = String(e) }
    return out;
})()
"""

# Shared by everything that has to find a Flow (or every Flow) in the scene.
# A lab declares its flows as plain children of the root, so the default
# property is the whole search space; `seen` guards against the cycles a QML
# object graph is full of.
WALK_JS = """
function _walk(o, seen, visit) {
    if (!o || seen.indexOf(o) >= 0) return;
    seen.push(o);
    visit(o);
    var kids = [];
    try { var d = o.data; if (d) for (var i = 0; i < d.length; ++i) kids.push(d[i]) }
    catch (e) {}
    for (var k = 0; k < kids.length; ++k) _walk(kids[k], seen, visit);
}
"""

RUN_JS = """
(function () {
    var out = { scenario: %(scenario)s, timeBefore: -1, rows: 0, file: "",
                error: "", steps: %(steps)d };
    if (!Lab.clock) { out.error = "the lab has no SimClock"; return out }
    out.timeBefore = Lab.clock.time;
    if (!root.applyScenario(%(scenario)s)) {
        out.error = "applyScenario(" + %(scenario)s + ") returned false";
        return out;
    }
    var rec = null;
    try {
        rec = Qt.createQmlObject("import Clayground.Lab; DataRecorder {}", root);
    } catch (e) { out.error = "cannot create a DataRecorder: " + e; return out }
    rec.lab = %(lab)s;
    rec.destination = %(dest)s;
    rec.recordId = %(scenario)s;
    rec.command = %(command)s;
    rec.steps = %(steps)d;
    rec.stepSize = 1 / 60;
    rec.recording = true;
    for (var i = 0; i < %(steps)d; ++i) Lab.clock._advance(1 / 60);
    rec.recording = false;
    out.rows = rec.rows;
    out.file = rec.lastFile;
    out.error = rec.error;
    out.timeAfter = Lab.clock.time;
    rec.destroy();
    return out;
})()
"""

FLOW_JS = """
(function () {
    %(walk)s
    var id = %(flow)s;
    var out = { flowId: id, found: false, started: false, steps: 0, total: 0,
                reached: -1, unresolvedVerbs: [], failedTasks: [],
                failedExpects: [], finished: false, error: "" };
    var flow = null;
    _walk(root, [], function (o) {
        if (flow) return;
        var fid = null;
        try { fid = o.flowId } catch (e) { return }
        if (fid === id && o.steps !== undefined && typeof o.start === "function")
            flow = o;
    });
    if (!flow) { out.error = "flows() names '" + id + "' but no Flow carries that id"; return out }
    out.found = true;
    out.total = flow.steps.length;

    // A flow may only do what a user could do: every verb it names has to be
    // in the lab's own action map. Flow.run() merely warns about the rest and
    // carries on, which is how a step can quietly do nothing at all.
    var verbs = {};
    try { verbs = root.flowActions ? root.flowActions() : {} } catch (e) {}
    function checkActions(list, where) {
        if (!list) return;
        for (var i = 0; i < list.length; ++i) {
            var a = list[i];
            if (!a || a.length === 0) continue;
            var v = a[0];
            if (v === "let") v = a[2];
            if (!verbs[v]) out.unresolvedVerbs.push(where + ": " + v);
        }
    }
    for (var s = 0; s < flow.steps.length; ++s) {
        var st = flow.steps[s];
        checkActions(st.demo, st.key);
        try { if (st.task && st.task.solve) checkActions(st.task.solve, st.key) } catch (e) {}
    }

    // An expect belongs to the step it stands in and is asserted WHILE that
    // step is current, retried every tick until the step ends. Two reasons
    // for that rather than one shot: a demo's effect reaches the readouts a
    // sample later, and the next step's demo has already run by the time a
    // step change is observable from out here - so asserting on the way out
    // would test one lesson's claim against the next lesson's board.
    var pending = -1;
    function watchStep(i) {
        pending = (i >= 0 && i < flow.steps.length && flow.steps[i].expect) ? i : -1;
    }
    function tryPending() {
        if (pending < 0) return;
        var held = false;
        try { held = !!flow.steps[pending].expect(flow.nameOf) } catch (e) { held = false }
        if (held) pending = -1;
    }
    function closeStep() {
        if (pending >= 0) out.failedExpects.push(flow.steps[pending].key);
        pending = -1;
    }

    flow.finished.connect(function () { out.finished = true });
    flow.pacing = "auto";
    var ok = false;
    try { ok = root.startFlow(id) } catch (e) { out.error = String(e); return out }
    if (ok === false) { out.error = "startFlow('" + id + "') returned false"; return out }
    out.started = true;

    var last = flow.index;
    out.reached = last;
    watchStep(last);
    var stuck = 0;
    var solvedFor = -1;
    var n = 0;
    while (n < %(maxSteps)d && !out.finished) {
        // ONCE per task, never once per frame: a verb like flipSwitch is a
        // toggle, so calling solve() every tick would flip the switch sixty
        // times a second and whether the task looks done would come down to
        // the parity of the sample interval.
        if (flow.waiting && solvedFor !== flow.index) {
            flow.solve();
            solvedFor = flow.index;
            stuck = 0;
        }
        Lab.clock._advance(1 / 60);
        ++n;
        if (flow.index !== last) {
            closeStep();
            last = flow.index;
            watchStep(last);
            if (last > out.reached) out.reached = last;
            stuck = 0;
        } else if (flow.waiting) {
            // solve() performs the task; the step ends on the next probe
            // sample. Two sim seconds is many samples - a task still waiting
            // after that is one its own solution does not satisfy.
            if (++stuck > 120) {
                out.failedTasks.push(flow.step ? flow.step.key : String(last));
                stuck = 0;
                flow.next();
            }
        }
        tryPending();
    }
    closeStep();
    out.steps = n;
    if (!out.finished) out.error = "still running after " + n + " steps";
    return out;
})()
"""


def js_str(text):
    return json.dumps(str(text))


# --------------------------------------------------------------------------
# the checks


def check_load(rep, session):
    ok = session.insp.wait_phase("ready", timeout=90)
    st = session.insp.state()
    if not rep.check("load: the lab reaches phase ready", ok,
                     f"phase={st.get('phase')}"):
        return False
    snap = session.insp.request({"action": "snapshot"})
    env = snap.get("status", {})
    rep.check("load: a root object exists",
              env.get("rootLoaded") is True and env.get("alive") is True,
              f"alive={env.get('alive')} rootLoaded={env.get('rootLoaded')}")
    ours, other = session.diagnostics()
    for line in other[:4]:
        rep.note("(environment, not the lab) " + line)
    return rep.check("load: the lab logged no qml warning or error", not ours,
                     "; ".join(ours[:4]))


def one_run(spawn, lab_dir, lab_id, scenario, steps, dest):
    """One stepped run of one scenario, in a process of its own.

    A process of its own is the whole point. Two runs sharing a loader share
    everything a QML engine does not throw away with the root - and the loader
    is worse than neutral here, because it hands the outgoing root's
    viewState() to the incoming one. Under one process electronics-101's parts
    come back numbered part12 in the first run and part20 in the second, which
    is a difference between two records with identical numbers in them: a
    determinism failure that says nothing about determinism. `make.sh` runs
    each record in its own process for the same reason.
    """
    with spawn() as session:
        if not session.ready():
            return {"__error__": "the lab never reached phase ready"}
        if not session.fresh_root():
            return {"__error__": "the lab did not come back from a reload"}
        return session.insp.eval_json(RUN_JS % {
            "scenario": js_str(scenario),
            "steps": steps,
            "lab": js_str(lab_id),
            "dest": js_str(dest),
            "command": js_str(f"tools/lab-check/lab-check {lab_dir}"),
        }, timeout=300)


def check_determinism(rep, spawn, lab_dir, lab_id, scenarios, steps, workdir):
    all_ok = True
    for scenario in scenarios:
        paths = []
        broke = None
        for rep_no in ("a", "b"):
            dest = os.path.join(workdir, f"{scenario}-{rep_no}.labrec")
            res = one_run(spawn, lab_dir, lab_id, scenario, steps, dest)
            if res.get("__error__") or res.get("error"):
                broke = res.get("__error__") or res.get("error")
                break
            if not os.path.isfile(dest):
                broke = f"no record written to {dest}"
                break
            paths.append((dest, res))
        if broke:
            all_ok = rep.check(f"determinism: {scenario}", False, broke) and all_ok
            continue
        a, b = paths[0][0], paths[1][0]
        same = open(a, "rb").read() == open(b, "rb").read()
        detail = f"{paths[0][1].get('rows')} sampled ticks, {os.path.getsize(a)} bytes"
        if not same:
            detail = first_difference(a, b)
        all_ok = rep.check(f"determinism: {scenario}", same, detail) and all_ok
    return all_ok


def first_difference(a, b):
    """The first line the two records disagree on - the number to look at."""
    la = open(a, encoding="utf-8", errors="replace").read().splitlines()
    lb = open(b, encoding="utf-8", errors="replace").read().splitlines()
    for i in range(min(len(la), len(lb))):
        if la[i] != lb[i]:
            return f"line {i + 1}: {la[i][:70]!r} vs {lb[i][:70]!r}"
    return f"{len(la)} vs {len(lb)} lines"


def check_flows(rep, spawn, flows, flows_none_reason, max_steps):
    if flows_none_reason is not None:
        return rep.check("flows: none, and lab-check.json says why", True,
                         flows_none_reason[:80])
    if not flows:
        return rep.check(
            "flows: the lab has at least one", False,
            'flows() is empty - add a flow, or say "flows": "none" with a '
            '"flowsReason" in lab-check.json')
    all_ok = True
    for flow_id in flows:
        # A flow builds a board and leaves it there; the next flow has to
        # start where a learner starts, which is a lab nobody has touched.
        with spawn() as session:
            if not (session.ready() and session.fresh_root()):
                all_ok = rep.check(f"flows: {flow_id}", False,
                                   "the lab did not come up for this run")
                continue
            res = session.insp.eval_json(
                FLOW_JS % {"walk": WALK_JS, "flow": js_str(flow_id),
                           "maxSteps": max_steps},
                timeout=600)
        if res.get("__error__"):
            all_ok = rep.check(f"flows: {flow_id}", False, res["__error__"]) and all_ok
            continue
        problems = []
        if res.get("error"):
            problems.append(res["error"])
        for verb in res.get("unresolvedVerbs", []):
            problems.append("unresolved verb " + verb)
        for key in res.get("failedTasks", []):
            problems.append("task never satisfied: " + key)
        for key in res.get("failedExpects", []):
            problems.append("expect failed: " + key)
        if not res.get("finished"):
            problems.append("finished: false")
        detail = "; ".join(problems) if problems else \
            f"{res.get('total')} steps, {res.get('steps')} sim frames"
        all_ok = rep.check(f"flows: {flow_id}", not problems, detail) and all_ok
    return all_ok


def check_strings(rep, probe):
    langs = probe.get("langs", [])
    keys = probe.get("keys", {})
    kernel = probe.get("kernelKeys", {})
    ok = rep.check("strings: the lab registers EN and DE",
                   "en" in langs and "de" in langs, "languages=" + ",".join(sorted(langs)))
    if not ok:
        return False
    en, de = set(keys.get("en", [])), set(keys.get("de", []))
    only_en, only_de = sorted(en - de), sorted(de - en)
    parity = rep.check(
        "strings: EN and DE carry the same keys", not only_en and not only_de,
        f"{len(only_en)} only in EN ({', '.join(only_en[:4])}), "
        f"{len(only_de)} only in DE ({', '.join(only_de[:4])})"
        if (only_en or only_de) else f"{len(en)} keys")

    # A flow's narration is looked up as flow.<flowId>.<key> with a fallback
    # to the kernel chrome, so both dictionaries are the search space.
    have = {l: set(keys.get(l, [])) | set(kernel.get(l, [])) for l in ("en", "de")}
    wanted = sorted(set(probe.get("flowKeys", [])))
    missing = [k for k in wanted
               if k not in have["en"] or k not in have["de"]]
    flow_ok = rep.check(
        "strings: every key a FlowStep needs exists in EN and DE", not missing,
        f"{len(missing)} missing: {', '.join(missing[:4])}" if missing
        else f"{len(wanted)} flow keys")
    return parity and flow_ok


def check_records(rep, lab_dir, workdir, render):
    """Regenerate what is committed and compare, without touching the tree.

    The record's own `command` field says what regenerates it, so that is what
    runs here - `records/make.sh` for a lab's own records, `lab-sweep` for a
    study's. Both drive clayrender, which needs a real graphics session; with
    none, this reports that it did not run rather than inventing a verdict.
    """
    jobs = []
    make = os.path.join(lab_dir, "records", "make.sh")
    if os.path.isfile(make):
        jobs.append(("make.sh", [make, "--out-dir"], os.path.join(lab_dir, "records")))
    studies = os.path.join(lab_dir, "studies")
    if os.path.isdir(studies):
        for name in sorted(os.listdir(studies)):
            study = os.path.join(studies, name)
            if os.path.isdir(os.path.join(study, "records")):
                sweep = os.path.join(repo_root(lab_dir), "tools", "lab-sweep", "lab-sweep")
                jobs.append((f"studies/{name}", [sweep, study, "--records-dir"],
                             os.path.join(study, "records")))
    if not jobs:
        return rep.check("records: nothing committed to regenerate", True,
                         "no records/make.sh and no studies/*/records")
    if not render or not os.path.isfile(render):
        rep.note("records: NOT RUN - clayrender is not built, so the "
                 "committed records were not regenerated")
        return True

    all_ok = True
    for label, cmd, committed in jobs:
        out = os.path.join(workdir, label.replace("/", "-"))
        os.makedirs(out, exist_ok=True)
        env = dict(os.environ)
        env["QT_DISABLE_SHADER_DISK_CACHE"] = "1"
        proc = subprocess.run(cmd + [out], cwd=repo_root(lab_dir), env=env,
                              capture_output=True, text=True)
        if proc.returncode != 0:
            # Both streams: make.sh reports on stderr, lab-sweep echoes
            # clayrender's own output on stdout, and the sentence that says
            # "there is no display here" can arrive on either.
            tail = (proc.stdout + "\n" + proc.stderr).strip().splitlines()
            # "there is no clayrender here" and "there is no display here" are
            # both answers about the machine, not about the records. Saying
            # NOT RUN is the honest report; a red line would train people to
            # ignore it, and a green one would be a lie.
            missing = ("graphics session", "render control",
                       "clayrender not found", "build clayrender")
            if any(any(m in l for m in missing) for l in tail):
                rep.note(f"records: {label} NOT RUN - "
                         + next(l.strip() for l in tail
                                if any(m in l for m in missing))[:100])
                continue
            all_ok = rep.check(f"records: {label} regenerates", False,
                               f"exit {proc.returncode}: "
                               + (tail[-1][:120] if tail else "")) and all_ok
            continue
        drifted = []
        for name in sorted(os.listdir(committed)):
            if not name.endswith(".labrec"):
                continue
            fresh = os.path.join(out, name)
            if not os.path.isfile(fresh):
                drifted.append(name + " (not regenerated)")
            elif open(fresh, "rb").read() != open(os.path.join(committed, name), "rb").read():
                drifted.append(name)
        all_ok = rep.check(
            f"records: {label} regenerates to the committed bytes", not drifted,
            ", ".join(drifted[:4]) if drifted
            else f"{len(os.listdir(out))} records") and all_ok
    return all_ok


# {>>comment<<}, {++insertion++}, {--deletion--}, {~~old~>new~~}, {==highlight==}
CRITIC = re.compile(r"\{(>>.*?<<|\+\+.*?\+\+|--.*?--|~~.*?~~|==.*?==)\}", re.S)


def check_remarks(rep, lab_dir):
    """Count the marks a human left in the prose. Never red.

    An open remark is a conversation, not a defect - but a paper carrying
    fourteen of them is worth knowing about before it is cited.
    """
    total = 0
    for path in prose_files(lab_dir):
        try:
            n = len(CRITIC.findall(open(path, encoding="utf-8").read()))
        except OSError:
            continue
        if n:
            rep.note(f"{n} open mark(s) in {os.path.relpath(path, lab_dir)}")
        total += n
    return rep.check("remarks: counted (never a failure)", True,
                     f"{total} open CriticMarkup mark(s)")


def prose_files(lab_dir):
    paper = os.path.join(lab_dir, "paper.md")
    if os.path.isfile(paper):
        yield paper
    studies = os.path.join(lab_dir, "studies")
    if os.path.isdir(studies):
        for name in sorted(os.listdir(studies)):
            study = os.path.join(studies, name, "study.md")
            if os.path.isfile(study):
                yield study


# --------------------------------------------------------------------------


def repo_root(start):
    path = os.path.abspath(start)
    while path != os.path.dirname(path):
        # A worktree's .git is a FILE pointing at the real one, so "is a
        # directory" would walk straight past the root of every worktree.
        if os.path.exists(os.path.join(path, ".git")):
            return path
        path = os.path.dirname(path)
    return os.path.abspath(start)


def read_config(lab_dir, rep):
    """lab-check.json beside Sandbox.qml: what this lab's gate checks.

    Absent is not an error - a lab that never wrote one still gets the
    defaults - but "flows": "none" is, unless it comes with a reason.
    """
    path = os.path.join(lab_dir, "lab-check.json")
    cfg = {}
    if os.path.isfile(path):
        try:
            cfg = json.load(open(path, encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as e:
            rep.check("config: lab-check.json parses", False, str(e))
            return None
    return cfg


def main():
    ap = argparse.ArgumentParser(
        description="Check one lab against the lab contract (#208).")
    ap.add_argument("lab", help="the lab directory (labs/<slug>)")
    ap.add_argument("--loader", default=None,
                    help="path to clayliveloader (default: build/bin/clayliveloader)")
    ap.add_argument("--clayrender", default=None,
                    help="path to clayrender, for the records check")
    ap.add_argument("--only", default=None,
                    help="comma-separated subset of: " + ",".join(CHECK_ORDER))
    ap.add_argument("--steps", type=int, default=None,
                    help="override the stepped-run length (lab-check.json wins otherwise)")
    ap.add_argument("--keep", action="store_true", help="keep the temp workdir")
    ap.add_argument("--verbose", action="store_true",
                    help="let the loader write to this terminal")
    args = ap.parse_args()

    lab_dir = os.path.abspath(args.lab.rstrip("/"))
    sandbox = os.path.join(lab_dir, "Sandbox.qml")
    if not os.path.isfile(sandbox):
        print(f"lab-check: no Sandbox.qml in {lab_dir}", file=sys.stderr)
        return 2
    lab_id = os.path.basename(lab_dir)
    root = repo_root(lab_dir)
    loader = os.path.abspath(args.loader or os.path.join(root, "build", "bin",
                                                         "clayliveloader"))
    render = os.path.abspath(args.clayrender or os.path.join(root, "build", "bin",
                                                             "clayrender"))
    wanted = CHECK_ORDER if not args.only else [
        c.strip() for c in args.only.split(",") if c.strip()]
    unknown = [c for c in wanted if c not in CHECK_ORDER]
    if unknown:
        print(f"lab-check: unknown check(s): {', '.join(unknown)}", file=sys.stderr)
        return 2

    rep = Report()
    cfg = read_config(lab_dir, rep)
    if cfg is None:
        return 1
    steps = args.steps or int(cfg.get("steps", DEFAULT_STEPS))
    max_flow_steps = int(cfg.get("maxFlowSteps", DEFAULT_MAX_FLOW_STEPS))

    print(f"lab-check {lab_id}  (steps={steps}, checks={','.join(wanted)})")

    needs_scene = any(c in wanted for c in ("load", "determinism", "flows", "strings"))
    if needs_scene and not (os.path.isfile(loader) and os.access(loader, os.X_OK)):
        print(f"SKIP  {loader} does not exist - build it with "
              "`cmake --build build --target clayliveloader`")
        return SKIP

    workdir = tempfile.mkdtemp(prefix=f"lab-check-{lab_id}-")
    try:
        if needs_scene:
            def spawn():
                return Loader(loader, sandbox, quiet=not args.verbose)
            run_scene_checks(rep, spawn, cfg, wanted, lab_dir, lab_id,
                             steps, max_flow_steps, workdir)
        if "records" in wanted:
            check_records(rep, lab_dir, workdir, render)
        if "remarks" in wanted:
            check_remarks(rep, lab_dir)
    except TimeoutError as e:
        rep.check(f"protocol: {e}", False)
    finally:
        if args.keep:
            print(f"workdir kept: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)
        shutil.rmtree(os.path.join(lab_dir, ".clay"), ignore_errors=True)

    failed = rep.failed()
    print(f"\n{len(rep.lines) - len(failed)}/{len(rep.lines)} checks passed "
          f"({lab_id})")
    for name in failed:
        print("  FAILED  " + name)
    return 1 if failed else 0


def run_scene_checks(rep, spawn, cfg, wanted, lab_dir, lab_id, steps,
                     max_flow_steps, workdir):
    # One session answers everything that is a QUESTION about the lab - does
    # it load, what does it call its scenarios, what does it say in German.
    # The runs that are EXPERIMENTS each get their own process further down.
    with spawn() as session:
        loaded = check_load(rep, session) if "load" in wanted else session.ready()
        if not loaded:
            # Nothing after this can mean anything: every other check asks the
            # lab a question, and a lab that did not load answers nonsense.
            rep.check("load: the lab came up", False,
                      "phase=" + str(session.insp.state().get("phase")))
            return
        probe = session.insp.eval_json(PROBE_JS % {"walk": WALK_JS})

    if probe.get("__error__"):
        rep.check("contract: the lab answers scenarios()/flows()", False,
                  probe["__error__"] + " - a lab's root needs `id: root`")
        return

    scenarios = cfg.get("scenarios", "all")
    if scenarios == "all":
        scenarios = probe.get("scenarios", [])
    rep.check("contract: scenarios() answers with a non-empty list",
              isinstance(scenarios, list) and len(scenarios) > 0,
              ", ".join(scenarios) if isinstance(scenarios, list) else str(scenarios))

    if "determinism" in wanted and scenarios:
        check_determinism(rep, spawn, lab_dir, lab_id, scenarios, steps, workdir)

    if "flows" in wanted:
        declared = cfg.get("flows")
        reason = None
        if declared == "none":
            reason = cfg.get("flowsReason", "")
            if not reason:
                rep.check('flows: "none" needs a "flowsReason"', False,
                          "lab-check.json says the lab has no flow but not why")
                reason = None
                flows = probe.get("flows", [])
            else:
                flows = []
        else:
            flows = declared if isinstance(declared, list) else probe.get("flows", [])
        check_flows(rep, spawn, flows, reason, max_flow_steps)

    if "strings" in wanted:
        check_strings(rep, probe)


if __name__ == "__main__":
    sys.exit(main())
