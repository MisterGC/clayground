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

  load          the lab boots and logs nothing but the named environment
  determinism   every scenario, two stepped runs, byte-identical records
  flows         every flow runs to its end, with its expects holding
  strings       EN and DE say the same set of things, flows included
  teaching      a teaching lab's lessons keep the rules a program can test
  records       records/make.sh and studies/* regenerate the committed bytes
  tables        every <!-- table: --> block renders to the committed bytes
  study         a research lab has a study with records and answerability
  triad         paper.md, and the board the purpose owes
  remarks       open CriticMarkup marks in the prose (reported, never failed)

WHAT THE PURPOSE DECIDES (#209). lab-check.json declares what the lab is FOR,
and the gate asks for what that purpose owes and nothing more: a teaching lab
owes a flow with a learner task and an expect, German, and a storyboard; a
research lab owes a
study with committed records and an answerability table; a learning lab owes
its paper and a concept board. Everything a lab HAS is still checked whatever
the tier - a research lab that ships a flow has it run, one that ships German
has the parity checked - because a half-translated dictionary or a flow that
no longer finishes is a defect however the lab is labelled. Only the
"at least one" demands are tiered.

WHAT A LESSON IS HELD TO (#542). The skill's teaching rules are mostly
judgement - whether a step explains, whether a task needs the idea - and the
skill marks which. The ones a program can test, the teaching check tests, for
a teaching lab: every flow has a step the learner acts on and an expect;
every line a flow can say, hints and answered variants included, fits in 240
characters in every language once a script's *cues* are taken out; and no
step's narration is a `say` literal in the QML instead of a strings.js key.

Exit 0 when everything passed, 1 on any FAIL, 2 when the command line or the
lab directory is wrong (no Sandbox.qml, an unknown check), 77 (the ctest
SKIP_RETURN_CODE) when the machine cannot run the check at all - no
clayliveloader built.

WHY THE LOADER IS WATCHED (#536). Every wait on the inspector also asks
whether the loader process is still there. One that ended - a crash, a
module it could not load - fails the run it was serving at once, with its
exit code and its last lines of output, instead of being polled for minutes
by a check that cannot tell a dead process from a slow one. A lab that never
gets ready fails after --ready-timeout (90 s by default, printed in the
header), and the loader runs still to come are NOT RUN rather than each
waiting out the same timeout again. Neither stops the checks that need no
loader: records, tables, study, triad and remarks report either way.

A check this machine cannot run - the records check without a clayrender that
starts - is a NOT RUN line, never a PASS: the summary counts them apart
("12/12 checks passed, 2 not run"), and `--strict` exits 1 when there is one,
for a gate whose job is to regenerate the records rather than to skip them
(#535).

WHY THE LOADER AND NOT clayrender. Issue #208 proposed
`clayrender --paused --result -`, which exists now (#207) and is the right
command for asking ONE lab ONE question by hand. It is the wrong one for a
gate: clayrender needs a real graphics session and refuses to run under
QT_QPA_PLATFORM=offscreen, so every lab_check_<lab> would skip on a headless
runner, and a gate that only runs on one desk is the footnote this tool exists
to remove. clayliveloader runs offscreen and its inspector protocol returns
eval values, so the same questions get the same answers - the route
tools/lab-new's boot tests already take. The records check is the one part that
still shells out to clayrender (that is what the committed `command` field says
regenerates a record); with no display it reports itself as NOT RUN rather than
inventing a verdict.

The flow check is `Lab.runFlow()` (#207) called through that protocol, not a
second implementation of it: one place decides what "the task was solved" and
"the expect held" mean, and this is not it.

WHY A RUN IS STEPPED. Left alone a lab advances on a FrameAnimation, and a
frame is a wall-clock interval: two runs of one seed then sample different
instants. Every run here starts its loader with `--paused` - the same
control the dojo's transport uses, set before the lab's root exists, so not
one wall-clock frame runs - applies the scenario - which resets the clock, the
seeded RNG and every probe - and then advances sim time by hand in 1/60 s
steps. Sim time is a function of the step count and of nothing else.
"""

import argparse
import collections
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid

SKIP = 77
CHECK_ORDER = ["load", "determinism", "flows", "strings", "teaching", "records",
               "tables", "study", "triad", "remarks"]
PURPOSES = ("learning", "teaching", "research")
DEFAULT_STEPS = 600
DEFAULT_MAX_FLOW_STEPS = 20000
# The longest narration line a lesson may say, in characters, in any language
# (#542): the skill's "one idea per step" made countable. A line longer than
# this usually holds two ideas, and the German is longer than the English.
MAX_NARRATION = 240
# How long a loader gets to bring the lab to phase ready, per process. It used
# to be 90 s per wait with nothing watching the process, so a loader that had
# died was polled for the full time of every wait left (#536).
DEFAULT_READY_TIMEOUT = 90
# How many loader and clayrender processes a check runs at once (#572), the
# same default as lab-sweep's --jobs. The runs are independent processes, so
# the only limit is the machine; ctest is told through PROCESSORS.
DEFAULT_JOBS = 4
# The lines of loader output a failure quotes.
LOADER_TAIL = 12
# How often a wait looks at the inspector's files, in seconds. The loader
# watches request.json every 10 ms; a 50 ms poll here made every answer wait
# for the poll rather than for the loader (#572).
POLL = 0.01
# What Shift+R writes in the dojo: a frame-driven scratch run, gitignored, never
# regenerated by make.sh. Compared, it turned the check red for having
# pressed a key (#535).
SCRATCH_RECORDS = {"session.labrec"}

# lab-sweep owns the study manifest, the record reader and the table renderer;
# the study and tables checks are those modules asked about committed files.
SWEEP_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         "lab-sweep")
sys.path.insert(0, SWEEP_DIR)
import lab_table as LT         # noqa: E402
import manifest as M           # noqa: E402
import record as R             # noqa: E402


# --------------------------------------------------------------------------
# reporting


class Report:
    """Every line this tool prints, and the verdict it adds up to."""

    def __init__(self):
        self.lines = []
        self.skipped = []

    def check(self, name, ok, detail=""):
        self.lines.append((name, ok, detail))
        print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
        return ok

    def not_run(self, name, why):
        # A check this machine cannot run. Counted apart from the passes: a
        # skipped check reported as passed is how "0/0 checks passed" came to
        # mean "every record regenerates" (#535).
        self.skipped.append((name, why))
        print("NOT RUN  " + name + f"  ({why})")

    def note(self, text):
        # Not a check: something worth reading that cannot be red.
        print("      " + text)

    def failed(self):
        return [n for n, ok, _d in self.lines if not ok]


# --------------------------------------------------------------------------
# the inspector protocol, minus everything this tool does not need


class LoaderDied(Exception):
    """The loader process ended while the check was waiting on it."""

    def __init__(self, code, tail, waiting_for):
        self.code = code
        self.tail = tail
        self.waiting_for = waiting_for
        super().__init__(str(self))

    def __str__(self):
        how = describe_exit(self.code)
        return f"the loader {how} while waiting for {self.waiting_for}"


def describe_exit(code):
    """An exit code the way a reader looks it up: a negative Popen code is a
    signal on POSIX, and its name is what a crash report says."""
    if code is not None and code < 0:
        try:
            import signal
            return f"was killed by signal {-code} ({signal.Signals(-code).name})"
        except (ValueError, ImportError):
            return f"was killed by signal {-code}"
    return f"ended with exit code {code}"


class LoaderStalled(Exception):
    """A loader that is still running never got its lab to phase ready."""


class Inspect:
    def __init__(self, inspect_dir, alive=None):
        self.dir = inspect_dir
        # Called on every poll with what is being waited for; raises
        # LoaderDied once the process has ended (#536).
        self.alive = alive or (lambda waiting_for: None)
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
            self.alive(f"phase {phase}")
            time.sleep(POLL)
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
            self.alive(f"an answer to {payload.get('action')}")
            time.sleep(POLL)
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
    """One clayliveloader process, driven offscreen through .clay/inspect.

    `paused` starts it with `--paused`: the lab's root is created with the
    clock already paused, which is what a stepped run needs (#572).
    `instance` starts it with `--instance <name>`, so it serves its protocol
    under .clay/inspect/i/<name>/ and leaves the rest of .clay alone - which
    is what lets several loaders of one lab run at the same time.
    `storage_dir` sets CLAY_STORAGE_DIR, the QML LocalStorage it uses: loaders
    of one lab that open the same database at the same time race on its
    version, and the loser logs "SQL: database version mismatch" (#572).
    """

    def __init__(self, loader, sandbox, quiet=True,
                 ready_timeout=DEFAULT_READY_TIMEOUT, paused=False,
                 instance=None, storage_dir=None):
        self.loader = loader
        self.sandbox = sandbox
        self.lab_dir = os.path.dirname(sandbox)
        self.quiet = quiet
        self.ready_timeout = ready_timeout
        self.paused = paused
        self.instance = instance
        self.storage_dir = storage_dir
        self.proc = None
        self.insp = None
        self.tail = collections.deque(maxlen=LOADER_TAIL)
        self.reader = None

    def __enter__(self):
        # A stale .clay from an earlier run would answer "ready" before this
        # process has even started, and every question after that would be
        # asked of a corpse. An instance clears only its own directory: the
        # rest belongs to the loaders running beside it.
        inspect_dir = os.path.join(self.lab_dir, ".clay", "inspect")
        if self.instance:
            inspect_dir = os.path.join(inspect_dir, "i", self.instance)
            shutil.rmtree(inspect_dir, ignore_errors=True)
        else:
            shutil.rmtree(os.path.join(self.lab_dir, ".clay"), ignore_errors=True)

        env = dict(os.environ)
        env["QT_QPA_PLATFORM"] = "offscreen"
        env["QT_DISABLE_SHADER_DISK_CACHE"] = "1"
        bindir = os.path.dirname(os.path.abspath(self.loader))
        env.setdefault("QML2_IMPORT_PATH", os.path.join(bindir, "qml"))
        if self.storage_dir:
            os.makedirs(self.storage_dir, exist_ok=True)
            env["CLAY_STORAGE_DIR"] = self.storage_dir
        # The loader resolves Clayground plugins via a cwd-relative "qml"
        # import path, so it runs from the binary's directory. Its output is
        # always read - shown with --verbose, kept as a tail without - because
        # the last lines of a loader that died are the reason it died (#536).
        cmd = [self.loader, "--sbx", self.sandbox]
        if self.paused:
            cmd.append("--paused")
        if self.instance:
            cmd += ["--instance", self.instance]
        self.proc = subprocess.Popen(
            cmd, env=env, cwd=bindir, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
        self.reader = threading.Thread(target=self._read_output, daemon=True)
        self.reader.start()
        self.insp = Inspect(inspect_dir, alive=self.check_alive)
        return self

    def _read_output(self):
        for raw in iter(self.proc.stdout.readline, b""):
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
            self.tail.append(line)
            if not self.quiet:
                print(line, flush=True)

    def check_alive(self, waiting_for):
        if self.proc is None or self.proc.poll() is None:
            return
        # Let the reader take what the pipe still holds: a crash's last words
        # are often still in flight when the exit is seen.
        if self.reader:
            self.reader.join(timeout=2)
        raise LoaderDied(self.proc.returncode, list(self.tail), waiting_for)

    def __exit__(self, *exc):
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self.reader:
            self.reader.join(timeout=2)
        if self.proc and self.proc.stdout:
            self.proc.stdout.close()
        return False

    def ready(self, timeout=None):
        return self.insp.wait_phase(
            "ready", timeout=self.ready_timeout if timeout is None else timeout)

    def paused_root(self, timeout=None):
        """Whether the root this loader created has a clock that never ran.

        A loader started with `--paused` creates its root with the clock
        already paused, so "no wall-clock frame ran before applyScenario" is
        true by construction. This asks the loader to confirm it, and is the
        first request a run makes, so a loader that is up and never answers
        is found within the ready timeout rather than the run's.

        It used to take a pause request, a clock reset and a reload: pausing
        by request leaves the frames that ran before it, so a fresh root had
        to be reloaded into, and a plain reload hands the outgoing root's
        viewState() - sim time, scenario and parameters - to the incoming one,
        which the reset was there to defuse. A loader that is already running
        gets a clean root with `{"action": "reload", "fresh": true}` (#566);
        a run here needs neither, because its root is the process's first and
        has nothing to inherit (#572).
        """
        if timeout is None:
            timeout = self.ready_timeout
        r = self.insp.request({"action": "time"}, timeout=max(1.0, timeout))
        return r.get("paused") is True

    def diagnostics(self):
        """Warnings and errors the loader streamed, split into the lab's own
        and the environment's - see classify_diagnostics()."""
        entries = []
        path = os.path.join(self.insp.dir, "log.jsonl")
        try:
            with open(path) as f:
                for line in f:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
        except OSError:
            pass
        return classify_diagnostics(entries, repo_root(self.lab_dir))


# --------------------------------------------------------------------------
# what a load may log
#
# The ENVIRONMENT is a short list of named messages, and nothing else is
# (#534). The check used to file a message as the lab's only when it named a
# file inside the lab's own folder, so a TypeError thrown by a kit under
# labs/kits/ or by the kernel in plugins/clay_lab/ - code the lab runs and
# cannot run without - was "environment, not the lab", and the gate passed a
# lab that threw while loading. Inverting the test is the fix: a message is
# the environment's only when it is one of these, by name, and the README's
# "What counts as the environment" lists the same entries. A new one belongs
# on the list only when it comes from the machine whatever the lab is.

ENVIRONMENT = [
    # (name, the message's pattern, the logging category it must come from -
    # None for any)
    #
    # Offscreen has no RHI, so Qt Quick 3D refuses every View3D on every
    # headless run, whatever the scene is.
    ("qtquick3d-no-rhi",
     re.compile(r"^The Qt Quick scene is using a rendering method that is not "
                r"based on QRhi and a 3D graphics API\."), None),
    # The same refusal, as the soft assert Qt Quick 3D logs right after it.
    ("qtquick3d-no-rhi-assert",
     re.compile(r'^Unexpected condition met: '
                r'"QSGRendererInterface::isApiRhiBased\('), None),
    # Under QT_QPA_PLATFORM=offscreen on macOS Qt asks for its own default
    # family, "Sans Serif", which the system does not have, and says so once.
    ("offscreen-default-font",
     re.compile(r"^Populating font family aliases took \d+ ms\. Replace uses "
                r'of missing font family "Sans Serif"'), None),
    # On Linux Qt Multimedia (clay_sound pulls it in) loads optional system
    # libraries - PipeWire, VA-API - at run time and logs each one a machine
    # lacks, twice; the CI runner lacks them all. Held to its own category, so
    # the same words from anywhere else are not waved through.
    ("linux-multimedia-libraries",
     re.compile(r"^Couldn't (load|resolve) \S.* (library|symbols)$"),
     "qt.multimedia.symbolsresolver"),
    # The same Qt Multimedia on a Linux machine with no PulseAudio server to
    # connect to, such as the CI runner.
    ("linux-no-pulseaudio",
     re.compile(r"^PulseAudioService: pa_context_connect\(\) failed$"), None),
    # Offscreen on Windows reads fonts from the Qt installation's lib/fonts,
    # which a Qt install does not ship, so the machine has no fonts at all.
    # Two lines: the second says "Note that Qt no longer ships fonts. ...".
    ("offscreen-no-font-directory",
     re.compile(r"^QFontDatabase: Cannot find font directory "), None),
    # The inspector replaces its state.json and response.json by renaming a
    # new file over them, and on Windows that fails while a reader has the
    # file open - which lab-check, polling every 10 ms with runs side by side,
    # does now and then (#572). The inspector retries and says it did; one
    # that SUCCEEDED is the check reading its own protocol, not the lab. A
    # replace that never succeeded logs "failed to write" and still fails.
    ("inspector-replace-retry",
     re.compile(r'^ClayInspector: replacing "[^"]*/\.clay/inspect/[^"]*" '
                r"took \d+ attempts$"), None),
]

# A QML or JS location as Qt prints it at the start of a diagnostic:
# file:///.../X.qml:12:5, qrc:/qt/qml/Clayground/Lab/X.qml:12, /abs/x.js:3.
QML_LOCATION = re.compile(r"^((?:file:|qrc:)?/\S*?\.(?:qml|m?js))((?::\d+){0,2})")


def environment_name(text, category="default"):
    """The ENVIRONMENT entry a message is, or None when it is not one."""
    for name, pattern, cat in ENVIRONMENT:
        if (cat is None or cat == category) and pattern.search(text):
            return name
    return None


def source_file(text, repo):
    """The file a diagnostic names, as a path a reader can open, or None.

    A kit or lab file arrives as a file:// URL and is shown relative to the
    repository; a plugin's QML is compiled into its resources and arrives as
    qrc:/qt/qml/Clayground/<Module>/<path>, which is shown as the source file
    plugins/clay_<module>/<path> when that exists, the URL otherwise.
    """
    m = QML_LOCATION.match(text)
    if not m:
        return None
    url, where = m.group(1), m.group(2)
    path = url
    if url.startswith("file:"):
        path = url[len("file:"):]
        # file:///Users/x is /Users/x; file:///C:/x is C:/x on Windows
        while path.startswith("//"):
            path = path[1:]
        if re.match(r"^/[A-Za-z]:/", path):
            path = path[1:]
    elif url.startswith("qrc:"):
        parts = url[len("qrc:"):].lstrip("/").split("/")
        if len(parts) > 4 and parts[:3] == ["qt", "qml", "Clayground"]:
            src = os.path.join(repo, "plugins", "clay_" + parts[3].lower(), *parts[4:])
            if os.path.isfile(src):
                path = src
    if os.path.isabs(path):
        try:
            rel = os.path.relpath(path, repo)
            if not rel.startswith(".."):
                path = rel
        except ValueError:
            pass
    return path.replace(os.sep, "/") + where


def classify_diagnostics(entries, repo):
    """(ours, environment) from log.jsonl entries.

    ours is every warning or error that is not on the ENVIRONMENT list, as one
    line per distinct message that starts with the file it names - or with
    "(names no file)", which fails the load as well: a console.warn or a Qt
    warning raised for the scene carries no location and is still something
    the lab made happen. environment is one line per ENVIRONMENT entry seen.
    """
    ours, counts, env = [], {}, {}
    for entry in entries:
        level = entry.get("level")
        if level not in ("warning", "error"):
            continue
        body = entry.get("text", "").strip()
        cat = entry.get("category", "default")
        name = environment_name(body, cat)
        if name:
            env[name] = env.get(name, 0) + 1
            continue
        where = source_file(body, repo)
        if where:
            body = body[QML_LOCATION.match(body).end():].lstrip(":").strip()
        text = f"{where or '(names no file)'}: [{level}/{cat}] {body}"
        if text not in counts:
            ours.append(text)
            counts[text] = 0
        counts[text] += 1
    ours = [t + (f"  (x{counts[t]})" if counts[t] > 1 else "") for t in ours]
    other = [f"{name} (x{n})" for name, n in env.items()]
    return ours, other


# --------------------------------------------------------------------------
# the scene-side drivers
#
# Each one is a single self-contained expression: the protocol's eval keeps no
# scope between requests, so a driver cannot leave helpers behind for the next.

PROBE_JS = """
(function () {
    var out = { scenarios: [], flows: [], flowsError: "", langs: [],
                keys: {}, kernelKeys: {}, flowKeys: [], tasks: {},
                literals: {}, narration: {} };
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
    // for every step that carries one, plus a task's hint and the flow title.
    // Every Flow files itself with the kernel as soon as its id is known
    // (#207), so this reads a registry rather than walking the object graph.
    try {
        var found = [];
        out.expects = {};
        for (var fi = 0; fi < Lab.flowIds.length; ++fi) {
            var id = Lab.flowIds[fi];
            var f = Lab._flows[id];
            if (!f) continue;
            var nExpect = 0, nTask = 0, literal = [];
            for (var i = 0; i < f.steps.length; ++i) {
                var st = f.steps[i];
                if (st.key) found.push("flow." + id + "." + st.key);
                try { if (st.task && st.task.hint) found.push(String(st.task.hint)) }
                catch (e) {}
                // a teaching flow owes at least one expect (#209): a lesson
                // with no asserted number cannot break when the lab drifts
                try { if (st.expect) ++nExpect } catch (e) {}
                // ...and one step the learner acts on (#542): a question
                // the panel takes and a wiring task are tasks as well
                try { if (st.task) ++nTask } catch (e) {}
                // a narration line typed into the QML rather than strings.js
                // (#542): one language only, and invisible to the checks below
                try {
                    if (st.say && String(st.say).trim() !== "")
                        literal.push(st.key ? st.key : "step " + i);
                } catch (e) {}
            }
            out.expects[id] = nExpect;
            out.tasks[id] = nTask;
            out.literals[id] = literal;
            if (f.titleKey) found.push(String(f.titleKey));
        }
        out.flowKeys = found;
        out.registered = Lab.flowIds.slice();
        // The text of every line a flow can say, in every language: the
        // lab's flow.* keys - answered variants and scripts included, which
        // no step names until it runs - and the hints the steps name.
        for (var l in LabLang._dicts) {
            var d = LabLang._dicts[l], said = {};
            for (var k in d)
                if (k.indexOf("flow.") === 0 || found.indexOf(k) >= 0)
                    said[k] = String(d[k]);
            out.narration[l] = said;
        }
    } catch (e) { out.flowKeysError = String(e) }
    return out;
})()
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
    var r = Lab.runFlow(%(flow)s, { maxSteps: %(maxSteps)d });
    // The lab's own entry point is what a learner triggers, and a lab may
    // refuse an id it does not publish; runFlow calls it when it exists, so
    // the only thing left to say here is whether the id was one of the
    // lab's own rather than merely a registered Flow.
    r.published = (root.flows ? root.flows() : []).indexOf(%(flow)s) >= 0;
    return r;
})()
"""


def js_str(text):
    return json.dumps(str(text))


# --------------------------------------------------------------------------
# the checks


def check_load(rep, session):
    """Whether the lab came up. A lab that came up and logged something of its
    own fails the load and still gets every other check: the scene answers
    questions, and one FAIL line hides less than a verdict cut short."""
    ok = session.ready()
    st = session.insp.state()
    if not rep.check("load: the lab reaches phase ready", ok,
                     f"phase={st.get('phase')}" if ok else
                     never_ready(session)):
        return False
    snap = session.insp.request({"action": "snapshot"})
    env = snap.get("status", {})
    rep.check("load: a root object exists",
              env.get("rootLoaded") is True and env.get("alive") is True,
              f"alive={env.get('alive')} rootLoaded={env.get('rootLoaded')}")
    ours, other = session.diagnostics()
    for line in other:
        rep.note("(environment, see the README's list) " + line)
    # every distinct one: a message nobody sees cannot be put on the list or
    # fixed, and repeats are already folded into a count
    for line in ours:
        rep.note(line)
    rep.check("load: nothing but the environment logged a warning or error",
              not ours, f"{len(ours)} message(s), first: {ours[0]}" if ours else "")
    return True


def never_ready(session):
    return (f"the lab never reached phase ready within "
            f"{session.ready_timeout:g} s (phase={session.insp.state().get('phase')})")


def report_died(rep, name, died):
    """A run whose loader ended: the FAIL line says how, and the loader's last
    lines follow it - the reason is in them, not in the check (#536)."""
    rep.check(name, False, str(died))
    if died.tail:
        rep.note("the loader's last output:")
        for line in died.tail:
            rep.note("  " + line)
    else:
        rep.note("the loader printed nothing")


class Outcome:
    """What one run in a loader of its own came to, for the report to say.

    kind is "value" (the body answered: value holds it), "stalled" (the
    loader never got the lab ready, or did not start paused), "skipped" (an
    earlier run had stalled before this one started) or "died" (the
    process ended: died holds the LoaderDied). A run is carried out on a
    worker thread and reported on the main one, in the order the checks have
    always printed, so the output does not depend on which run ended first.
    """

    def __init__(self, kind, value=None, detail="", died=None):
        self.kind = kind
        self.value = value
        self.detail = detail
        self.died = died


def run_fresh(spawn, body):
    """body(session) in a loader of its own, on a root paused from birth.

    A loader that never gets the lab ready is a property of the lab or the
    machine, not of the one run, and the next process would wait out the
    same timeout for the same answer - which is how six scenarios became
    fifteen minutes (#353). So once a run has stalled, a run that has not
    started yet does not start (#536); report_run() says which of the
    stalled ones is the FAIL line."""
    if spawn.stalled:
        return Outcome("skipped", detail=spawn.stalled)
    try:
        with spawn() as session:
            if not session.ready():
                detail = never_ready(session)
            elif not session.paused_root():
                detail = "the loader did not start with its clock paused (--paused)"
            else:
                return Outcome("value", value=body(session))
            spawn.stalled = (f"an earlier run's loader did not get the lab ready "
                             f"within {session.ready_timeout:g} s")
            return Outcome("stalled", detail=detail)
    except LoaderDied as died:
        return Outcome("died", died=died)


def report_run(rep, spawn, name, outcome):
    """The run's value, or None once a FAIL or NOT RUN line under `name` has
    said why not. Of the runs that stalled, the first one reported is the
    FAIL; every later one is NOT RUN, as when the runs went one at a time."""
    if outcome.kind == "value":
        return outcome.value
    if outcome.kind == "died":
        report_died(rep, name, outcome.died)
    elif outcome.kind == "stalled" and not spawn.stall_reported:
        spawn.stall_reported = True
        rep.check(name, False, outcome.detail)
    else:
        rep.not_run(name, spawn.stalled or outcome.detail)
    return None


class Inline:
    """An executor that runs what it is handed at once, on this thread: the
    pool's stand-in where a caller passes none."""

    def submit(self, fn, *args):
        fut = concurrent.futures.Future()
        try:
            fut.set_result(fn(*args))
        except BaseException as e:  # noqa: B036 - handed to result()
            fut.set_exception(e)
        return fut


def one_run(session, lab_dir, lab_id, scenario, steps, dest):
    """One stepped run of one scenario, in a process of its own.

    A process of its own is the whole point. Two runs sharing a loader share
    everything a QML engine does not throw away with the root - and before
    the fresh reload (#566) the loader was worse than neutral here, because
    it handed the outgoing root's viewState() to the incoming one. Under one
    process electronics-101's parts
    come back numbered part12 in the first run and part20 in the second, which
    is a difference between two records with identical numbers in them: a
    determinism failure that says nothing about determinism. `make.sh` runs
    each record in its own process for the same reason.
    """
    return session.insp.eval_json(RUN_JS % {
        "scenario": js_str(scenario),
        "steps": steps,
        "lab": js_str(lab_id),
        "dest": js_str(dest),
        "command": js_str(f"tools/lab-check/lab-check {lab_dir}"),
    }, timeout=300)


def start_determinism(pool, spawn, lab_dir, lab_id, scenarios, steps, workdir):
    """Hand every run of the determinism check to the pool: two per scenario,
    each in a loader of its own. Returns what check_determinism() reports."""
    runs = []
    for scenario in scenarios:
        pair = []
        for rep_no in ("a", "b"):
            dest = os.path.join(workdir, f"{scenario}-{rep_no}.labrec")
            pair.append((dest, pool.submit(
                run_fresh, spawn,
                lambda s, sc=scenario, d=dest: one_run(s, lab_dir, lab_id, sc,
                                                       steps, d))))
        runs.append((scenario, pair))
    return runs


def check_determinism(rep, spawn, runs):
    all_ok = True
    for scenario, pair in runs:
        paths = []
        broke = None
        name = f"determinism: {scenario}"
        for dest, fut in pair:
            # A run after a failed one says nothing more: its outcome is
            # dropped, as it was never started when the runs went in turn
            res = report_run(rep, spawn, name, fut.result())
            if res is None:
                # report_run has written this scenario's line already
                all_ok = False
                break
            if res.get("__error__") or res.get("error"):
                broke = res.get("__error__") or res.get("error")
                break
            if not os.path.isfile(dest):
                broke = f"no record written to {dest}"
                break
            paths.append((dest, res))
        if broke:
            all_ok = rep.check(name, False, broke) and all_ok
            continue
        if len(paths) < 2:
            continue
        a, b = paths[0][0], paths[1][0]
        same = open(a, "rb").read() == open(b, "rb").read()
        detail = f"{paths[0][1].get('rows')} sampled ticks, {os.path.getsize(a)} bytes"
        if not same:
            detail = first_difference(a, b)
        all_ok = rep.check(f"determinism: {scenario}", same, detail) and all_ok
    return all_ok


def first_difference(a, b):
    """The first line the two records disagree on - the number to look at.
    Lines keep their endings, so a line-ending difference (a CRLF checkout
    on Windows) shows as one rather than as two identical-looking lines."""
    la = open(a, encoding="utf-8", errors="replace", newline="").read().splitlines(True)
    lb = open(b, encoding="utf-8", errors="replace", newline="").read().splitlines(True)
    for i in range(min(len(la), len(lb))):
        if la[i] != lb[i]:
            body_a, body_b = la[i].rstrip("\r\n"), lb[i].rstrip("\r\n")
            if body_a == body_b:
                return (f"line {i + 1}: line endings differ, "
                        f"{la[i][len(body_a):]!r} vs {lb[i][len(body_b):]!r}")
            return f"line {i + 1}: {body_a[:70]!r} vs {body_b[:70]!r}"
    return f"{len(la)} vs {len(lb)} lines"


def start_flows(pool, spawn, flows, max_steps):
    """Hand every flow to the pool, each in a loader of its own: a flow builds
    a board and leaves it there, and the next flow has to start where a
    learner starts, which is a lab nobody has touched."""
    return [(flow_id, pool.submit(
        run_fresh, spawn,
        lambda s, f=flow_id: s.insp.eval_json(
            FLOW_JS % {"flow": js_str(f), "maxSteps": max_steps},
            timeout=600)))
        for flow_id in flows]


def check_flows(rep, spawn, flows, require, expects, runs):
    """Run every published flow; a teaching lab must also HAVE one.

    `require` is whether the purpose owes a flow (teaching). `expects` maps a
    flow id to how many of its steps carry an `expect`, read from the kernel's
    registry, for the PASS line; whether a lesson has enough of them is the
    teaching check's question, not whether it runs (#542).
    """
    if not flows:
        if require:
            return rep.check(
                "flows: the lab has at least one", False,
                'flows() is empty and a teaching lab owes a flow with expects')
        return rep.check("flows: none published, none owed by this purpose", True)
    all_ok = True
    for flow_id, fut in runs:
        res = report_run(rep, spawn, f"flows: {flow_id}", fut.result())
        if res is None:
            all_ok = False
            continue
        if res.get("__error__"):
            all_ok = rep.check(f"flows: {flow_id}", False, res["__error__"]) and all_ok
            continue
        problems = []
        if res.get("error"):
            problems.append(res["error"])
        if not res.get("published", True):
            problems.append("flows() does not publish this id")
        for verb in res.get("unresolvedVerbs", []):
            problems.append("unresolved verb " + str(verb))
        for entry in res.get("failedTasks", []):
            problems.append("task never satisfied: " + step_of(entry))
        for entry in res.get("failedExpects", []):
            problems.append("expect failed: " + step_of(entry))
        if not res.get("finished"):
            problems.append("finished: false")
        n_expect = (expects or {}).get(flow_id, 0)
        detail = "; ".join(problems) if problems else \
            f"{res.get('steps')} sim frames, {n_expect} expect(s)"
        all_ok = rep.check(f"flows: {flow_id}", not problems, detail) and all_ok
    return all_ok


def step_of(entry):
    """Name a runFlow failure by its step key, with the index as a fallback.

    runFlow reports {index, step} (plus `error` when an expect threw). The
    key is what the author reads; the index is what is left when a step has
    no key, which is legal.
    """
    if not isinstance(entry, dict):
        return str(entry)
    name = entry.get("step") or f"step {entry.get('index')}"
    return f"{name} ({entry['error']})" if entry.get("error") else name


def check_strings(rep, probe, require_de=True):
    """EN is owed by every lab; DE by a teaching lab (#209). A DE dictionary
    that exists is checked whatever the purpose - saying different things in
    two languages is a bug, not a tier."""
    langs = probe.get("langs", [])
    keys = probe.get("keys", {})
    kernel = probe.get("kernelKeys", {})
    if not rep.check("strings: the lab registers EN", "en" in langs,
                     "languages=" + ",".join(sorted(langs))):
        return False
    if "de" not in langs:
        return rep.check("strings: the lab registers DE", not require_de,
                         "owed by a teaching lab" if require_de
                         else "not owed by this purpose; EN only")
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


# A performance script's stage directions - *point at the battery* - are not
# said, so they do not count towards a line's length.
CUE = re.compile(r"\*[^*\n]*\*")


def spoken(text):
    """What a narration line says: its cues taken out, its spaces folded."""
    return " ".join(CUE.sub(" ", str(text)).split())


def check_teaching(rep, probe, flows, purpose, limit=MAX_NARRATION):
    """The rules of teaching.md and flows.md that a program can test (#542).

    Per flow: at least one step the learner acts on (a task - a question the
    lab takes an answer to and a wiring task are tasks too) and at least one
    expect. For the lab: every line a flow can say fits in `limit`
    characters in every language, and no step's narration is a `say`
    literal in the QML. Everything else teaching.md asks is judgement and
    marked so there.
    """
    if purpose != "teaching":
        return rep.check("teaching: no lesson rules owed by this purpose", True,
                         purpose)
    all_ok = True
    tasks = probe.get("tasks", {})
    expects = probe.get("expects", {})
    for flow_id in flows:
        problems = []
        n_task, n_expect = tasks.get(flow_id, 0), expects.get(flow_id, 0)
        if not n_task:
            problems.append("no step is a task - a lesson has the learner act "
                            "at least once")
        if not n_expect:
            problems.append("no step carries an expect - a lesson asserts at "
                            "least one measured value")
        all_ok = rep.check(
            f"teaching: {flow_id} has a learner task and an expect", not problems,
            "; ".join(problems) if problems
            else f"{n_task} task(s), {n_expect} expect(s)") and all_ok

    prefixes = tuple(f"flow.{f}." for f in flows)
    hints = set(probe.get("flowKeys", []))
    long_lines, counted = [], 0
    for lang, said in sorted(probe.get("narration", {}).items()):
        for key, text in sorted(said.items()):
            if not (key.startswith(prefixes) or key in hints):
                continue
            counted += 1
            n = len(spoken(text))
            if n > limit:
                long_lines.append(f"{key} [{lang}] {n}")
    all_ok = rep.check(
        f"teaching: every narration line fits in {limit} characters",
        not long_lines,
        f"{len(long_lines)} longer: " + ", ".join(long_lines[:4]) if long_lines
        else f"{counted} line(s)") and all_ok

    literal = [f"{f}.{k}" for f in flows for k in probe.get("literals", {}).get(f, [])]
    all_ok = rep.check(
        "teaching: no narration is written in the QML", not literal,
        f"{len(literal)} step(s) with a say literal: " + ", ".join(literal[:4])
        + " - move the line to strings.js as flow.<flowId>.<key>"
        if literal else "") and all_ok
    return all_ok


def record_scenarios(committed):
    """The make.sh argument each committed record's `command` field names, in
    file order - or None when one of them names something else, or there is
    none. `labs/<lab>/records/make.sh <scenario>` is what make.sh writes into
    every record, so running it per record is running what the record says
    regenerates it, and the runs can go side by side (#572)."""
    scenarios = []
    for name in sorted(os.listdir(committed)):
        if not name.endswith(".labrec") or name in SCRATCH_RECORDS:
            continue
        try:
            command = R.read(os.path.join(committed, name)).header.get("command", "")
        except (OSError, ValueError, R.RecordError):
            return None
        parts = str(command).split()
        if len(parts) != 2 or not parts[0].endswith("records/make.sh"):
            return None
        scenarios.append(parts[1])
    return scenarios or None


def run_command(cmd, cwd, env):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


def start_records(pool, lab_dir, workdir, render, jobs=DEFAULT_JOBS):
    """Hand the regenerating runs to the pool; check_records() reports them.

    The record's own `command` field says what regenerates it, so that is what
    runs here - `records/make.sh` for a lab's own records, `lab-sweep` for a
    study's. Both drive clayrender, which needs a real graphics session; with
    none, each job is a NOT RUN line rather than an invented verdict.

    Both are handed `render`, the clayrender this check was given: make.sh as
    $CLAYRENDER, lab-sweep as --clayrender. Each used to look for
    build/bin/clayrender itself, so a build folder of another name, or a lab
    outside the checkout, regenerated nothing whatever --clayrender said
    (#535).

    make.sh runs once per committed record when every record names its
    scenario, else once for all of them; lab-sweep runs once per study, with
    `jobs` runs of its own at a time.
    """
    jobs_ = []
    make = os.path.join(lab_dir, "records", "make.sh")
    if os.path.isfile(make):
        committed = os.path.join(lab_dir, "records")
        per = record_scenarios(committed)
        base = script_command(make) + ["--out-dir"]
        jobs_.append(("make.sh", committed,
                      [lambda out, sc=sc: base + [out, sc] for sc in per]
                      if per else [lambda out: base + [out]]))
    studies = os.path.join(lab_dir, "studies")
    if os.path.isdir(studies):
        for name in sorted(os.listdir(studies)):
            study = os.path.join(studies, name)
            if os.path.isdir(os.path.join(study, "records")):
                # Beside this tool, the lab-sweep it imports above - not under
                # the lab's checkout, which for a lab generated into a temp
                # tree has no tools/ (#531)
                sweep = os.path.join(SWEEP_DIR, "lab_sweep.py")
                cmd = [sys.executable, sweep, study, "--jobs", str(jobs),
                       "--clayrender", render or "", "--records-dir"]
                jobs_.append((f"studies/{name}", os.path.join(study, "records"),
                              [lambda out, c=cmd: c + [out]]))
    if not jobs_ or not render or not os.path.isfile(render):
        return {"jobs": [(label, committed, None, None)
                         for label, committed, _c in jobs_]}

    started = []
    env = dict(os.environ)
    env["QT_DISABLE_SHADER_DISK_CACHE"] = "1"
    env["CLAYRENDER"] = render
    for label, committed, commands in jobs_:
        out = os.path.join(workdir, label.replace("/", "-"))
        os.makedirs(out, exist_ok=True)
        # Forward slashes: make.sh puts the path into a JS string, where a
        # Windows backslash starts an escape
        futs = [pool.submit(run_command, command(out.replace(os.sep, "/")),
                            repo_root(lab_dir), env)
                for command in commands]
        started.append((label, committed, out, futs))
    return {"jobs": started}


def check_records(rep, lab_dir, workdir, render, started=None):
    """Regenerate what is committed and compare, without touching the tree.

    `started` is what start_records() handed to a pool; without it the runs
    are carried out here, one after the other."""
    if started is None:
        started = start_records(Inline(), lab_dir, workdir, render)
    jobs = started["jobs"]
    if not jobs:
        return rep.check("records: nothing committed to regenerate", True,
                         "no records/make.sh and no studies/*/records")
    if not render or not os.path.isfile(render):
        for label, _committed, _out, _futs in jobs:
            rep.not_run(f"records: {label} regenerates",
                        f"no clayrender at {render}")
        return True

    all_ok = True
    for label, committed, out, futs in jobs:
        procs = [f.result() for f in futs]
        proc = next((p for p in procs if p.returncode != 0), None)
        if proc is not None:
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
                rep.not_run(f"records: {label} regenerates",
                            next(l.strip() for l in tail
                                 if any(m in l for m in missing))[:100])
                continue
            all_ok = rep.check(f"records: {label} regenerates", False,
                               f"exit {proc.returncode}: "
                               + (tail[-1][:120] if tail else "")) and all_ok
            continue
        drifted = []
        first_diff = None
        compared = 0
        for name in sorted(os.listdir(committed)):
            if not name.endswith(".labrec") or name in SCRATCH_RECORDS:
                continue
            compared += 1
            fresh = os.path.join(out, name)
            if not os.path.isfile(fresh):
                drifted.append(name + " (not regenerated)")
                continue
            kept = os.path.join(committed, name)
            if open(fresh, "rb").read() != open(kept, "rb").read():
                drifted.append(name)
                first_diff = first_diff or f"{name} {first_difference(kept, fresh)}"
        # The count is what was COMPARED: the files the run wrote said
        # "(2 records)" for a lab with none committed (#535)
        written = len([n for n in os.listdir(out) if n.endswith(".labrec")])
        all_ok = rep.check(
            f"records: {label} regenerates to the committed bytes", not drifted,
            ", ".join(drifted[:4]) if drifted
            else (f"{compared} records" if compared else
                  f"no committed records to compare; the run wrote {written}")) \
            and all_ok
        if first_diff:
            rep.note(f"records: first difference in {first_diff}")
    return all_ok


def check_tables(rep, lab_dir):
    """Every <!-- table: --> block in the lab's prose renders to what is
    committed. Pure: the records are files, the renderer is lab-table's."""
    results = LT.process(lab_dir, check=True, quiet=True)
    if not results:
        return rep.check("tables: no marked table blocks", True,
                         "nothing rendered from records yet")
    all_ok = True
    for rel, ref, ok, detail in results:
        name = f"tables: {rel}" + (f" {ref}" if ref else "")
        if not ok and detail == "stale":
            detail = "differs from the records - run tools/lab-sweep/lab-table " \
                     + display_path(lab_dir)
        all_ok = rep.check(name, ok, detail) and all_ok
    return all_ok


ANSWERABILITY = re.compile(r"^#{2,4}\s+Answerability\b", re.M)


def check_study(rep, lab_dir, purpose):
    """A research lab owes a study: a study.md whose manifest parses, committed
    records, and an answerability section - the argument that the model holds
    for the question, which no tool can make for it (#209)."""
    studies = os.path.join(lab_dir, "studies")
    found = []
    if os.path.isdir(studies):
        for name in sorted(os.listdir(studies)):
            if os.path.isfile(os.path.join(studies, name, "study.md")):
                found.append(name)
    if purpose != "research":
        return rep.check("study: none owed by this purpose", True,
                         f"{len(found)} present" if found else "")
    if not rep.check("study: a research lab has at least one study",
                     bool(found), ", ".join(found) if found else "no studies/<slug>/study.md"):
        return False
    all_ok = True
    for name in found:
        study = os.path.join(studies, name)
        problems = []
        try:
            with open(os.path.join(study, "study.md"), encoding="utf-8") as f:
                text = f.read()
            M.parse(text)
        except (OSError, M.ManifestError) as e:
            problems.append(str(e).splitlines()[0])
            text = ""
        rdir = os.path.join(study, "records")
        n = len([x for x in os.listdir(rdir) if x.endswith(".labrec")]) \
            if os.path.isdir(rdir) else 0
        if not n:
            problems.append("no committed records/*.labrec")
        if text and not ANSWERABILITY.search(text):
            problems.append("no '## Answerability' section")
        all_ok = rep.check(f"study: {name}", not problems,
                           "; ".join(problems) if problems else f"{n} records") and all_ok
    return all_ok


def check_triad(rep, lab_dir, purpose):
    """paper.md for every lab; overview.grafli where the purpose owes a board
    (teaching: the storyboard, learning: the concept map)."""
    ok = rep.check("triad: paper.md exists",
                   os.path.isfile(os.path.join(lab_dir, "paper.md")))
    board = os.path.isfile(os.path.join(lab_dir, "overview.grafli"))
    if purpose == "research":
        return rep.check("triad: board not owed by a research lab", True,
                         "overview.grafli present" if board else "") and ok
    return rep.check("triad: overview.grafli exists", board,
                     "" if board else f"a {purpose} lab owes a board") and ok


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


def display_path(path):
    """path relative to the working directory, or absolute where it cannot be:
    on Windows a lab in the temp dir on C: has no relative path from a
    checkout on D: - relpath raises."""
    try:
        return os.path.relpath(path)
    except ValueError:
        return os.path.abspath(path)


def script_command(script):
    """The command that runs a shell script. On Windows a .sh is not a
    program (WinError 193): it runs through the bash that comes with Git, not
    the first bash on the PATH, which can be WSL's."""
    if os.name != "nt":
        return [script]
    git = shutil.which("git")
    bash = None
    if git:
        root = os.path.dirname(os.path.dirname(os.path.realpath(git)))
        cand = os.path.join(root, "bin", "bash.exe")
        bash = cand if os.path.isfile(cand) else None
    return [bash or shutil.which("bash") or "bash", script]


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

    Parsing only; purpose_of() says whether what it read is a lab this gate
    can judge.
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


def purpose_of(cfg, rep):
    """The tier this lab declares, or None after a FAIL line.

    Required since #209: the purpose decides which checks are demands, so a
    lab without one cannot be judged - defaulting to the strictest tier would
    fail a research lab for the flow it never owed, and defaulting to the
    loosest would pass a lesson with no lesson in it.
    """
    p = cfg.get("purpose")
    if p in PURPOSES:
        return p
    rep.check("config: lab-check.json declares a purpose", False,
              (f"{p!r} is not one of " if p is not None else "missing; one of ")
              + ", ".join(PURPOSES))
    return None


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
    ap.add_argument("--ready-timeout", type=float, default=DEFAULT_READY_TIMEOUT,
                    help="seconds one loader gets to bring the lab to phase "
                         f"ready (default {DEFAULT_READY_TIMEOUT})")
    ap.add_argument("--jobs", type=int, default=DEFAULT_JOBS,
                    help="loader and clayrender processes to run at once - the "
                         "stepped runs, the flows and the records "
                         f"(default {DEFAULT_JOBS})")
    ap.add_argument("--keep", action="store_true", help="keep the temp workdir")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 when a check did not run (records without a "
                         "clayrender that starts), not only when one failed")
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
    purpose = purpose_of(cfg, rep)
    if purpose is None:
        return 1
    steps = args.steps or int(cfg.get("steps", DEFAULT_STEPS))
    max_flow_steps = int(cfg.get("maxFlowSteps", DEFAULT_MAX_FLOW_STEPS))

    jobs = max(1, args.jobs)
    print(f"lab-check {lab_id}  ({purpose}, steps={steps}, "
          f"ready within {args.ready_timeout:g} s, jobs={jobs}, "
          f"checks={','.join(wanted)})")

    needs_scene = any(c in wanted for c in ("load", "determinism", "flows",
                                            "strings", "teaching"))
    if needs_scene and not (os.path.isfile(loader) and os.access(loader, os.X_OK)):
        print(f"SKIP  {loader} does not exist - build it with "
              "`cmake --build build --target clayliveloader`")
        return SKIP

    workdir = tempfile.mkdtemp(prefix=f"lab-check-{lab_id}-")
    # One pool for every process the check starts: the records runs go in
    # first, since they need nothing the scene says, and run while the first
    # session asks the lab its questions (#572).
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=jobs)
    try:
        # The .clay of an earlier check, once: each loader of this one only
        # clears its own instance directory
        shutil.rmtree(os.path.join(lab_dir, ".clay"), ignore_errors=True)
        if needs_scene:
            runs = iter(range(1, 1 << 30))
            lock = threading.Lock()

            def spawn(stepped=True):
                # A stepped run gets a paused clock and an empty settings
                # store of its own; the first session, which asks whether the
                # lab loads, runs the lab as a person sees it, ticking, on the
                # store it was given - where it is now the only loader. Every
                # one serves under an instance of its own, the first session
                # too: flows can be running beside it.
                with lock:
                    n = next(runs)
                name = f"lab-check-{n}"
                return Loader(loader, sandbox, quiet=not args.verbose,
                              ready_timeout=args.ready_timeout, paused=stepped,
                              instance=name,
                              storage_dir=os.path.join(workdir, "storage", name)
                              if stepped else None)
            spawn.stalled = None
            spawn.stall_reported = False
        # A flow is usually the longest run of a check, so flows that
        # lab-check.json names go first - they need nothing the first session
        # answers - and the records after them
        flow_runs = None
        if needs_scene and "flows" in wanted and isinstance(cfg.get("flows"), list):
            flow_runs = start_flows(pool, spawn, flows_to_run(cfg, []),
                                    max_flow_steps)
        records = start_records(pool, lab_dir, workdir, render, jobs) \
            if "records" in wanted else None
        if needs_scene:
            try:
                run_scene_checks(rep, spawn, pool, cfg, purpose, wanted, lab_dir,
                                 lab_id, steps, max_flow_steps, workdir,
                                 flow_runs)
            except TimeoutError as e:
                # A loader that is up and no longer answers. The scene checks
                # left cannot ask it anything; the checks below never needed
                # it, and one hang used to cost them their lines (#536).
                rep.check(f"protocol: {e}", False)
        if records is not None:
            check_records(rep, lab_dir, workdir, render, started=records)
        if "tables" in wanted:
            check_tables(rep, lab_dir)
        if "study" in wanted:
            check_study(rep, lab_dir, purpose)
        if "triad" in wanted:
            check_triad(rep, lab_dir, purpose)
        if "remarks" in wanted:
            check_remarks(rep, lab_dir)
    finally:
        # Runs not started yet are dropped; the ones running end within their
        # own timeouts
        pool.shutdown(wait=True, cancel_futures=True)
        if args.keep:
            print(f"workdir kept: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)
        shutil.rmtree(os.path.join(lab_dir, ".clay"), ignore_errors=True)

    failed = rep.failed()
    print(f"\n{len(rep.lines) - len(failed)}/{len(rep.lines)} checks passed, "
          f"{len(rep.skipped)} not run ({lab_id})")
    for name in failed:
        print("  FAILED  " + name)
    for name, _why in rep.skipped:
        print("  NOT RUN  " + name)
    if failed:
        return 1
    if rep.skipped and args.strict:
        print("  --strict: a check that did not run is not a pass")
        return 1
    return 0


def flows_to_run(cfg, published):
    """The flow ids a run checks: an explicit list as written, "none" as
    none, and anything else - "all", or no key at all - as whatever the lab's
    flows() answers. So a flow a lab publishes after its lab-check.json was
    written is run without the file changing (#531).

    Whether none is ALLOWED is the purpose's call, so the flowsReason of #208
    is no longer read."""
    declared = cfg.get("flows")
    if declared == "none":
        return []
    return list(declared) if isinstance(declared, list) else list(published)


def run_scene_checks(rep, spawn, pool, cfg, purpose, wanted, lab_dir, lab_id,
                     steps, max_flow_steps, workdir, flow_runs=None):
    """`flow_runs` are flows already handed to the pool, when lab-check.json
    named them; otherwise the flows are the ones the lab publishes."""
    # One session answers everything that is a QUESTION about the lab - does
    # it load, what does it call its scenarios, what does it say in German.
    # The runs that are EXPERIMENTS each get their own process further down.
    try:
        with spawn(stepped=False) as session:
            loaded = check_load(rep, session) if "load" in wanted else session.ready()
            if not loaded:
                # Nothing after this can mean anything: every other check asks
                # the lab a question, and a lab that did not load answers
                # nonsense.
                rep.check("load: the lab came up", False, never_ready(session))
                return
            probe = session.insp.eval_json(PROBE_JS)
    except LoaderDied as died:
        report_died(rep, "load: the loader keeps running", died)
        rep.check("load: the lab came up", False, "the loader is gone")
        return

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

    # Every run is handed to the pool before the first is reported: the
    # flows first, as a flow is usually the longest run there is, then the
    # determinism pairs. The report reads them back in the order it always
    # printed them.
    flows = flows_to_run(cfg, probe.get("flows", [])) if "flows" in wanted else []
    if flow_runs is None:
        flow_runs = start_flows(pool, spawn, flows, max_flow_steps)
    det_runs = start_determinism(pool, spawn, lab_dir, lab_id, scenarios, steps,
                                 workdir) \
        if "determinism" in wanted and isinstance(scenarios, list) else []
    try:
        if det_runs:
            check_determinism(rep, spawn, det_runs)

        if "flows" in wanted:
            check_flows(rep, spawn, flows, purpose == "teaching",
                        probe.get("expects", {}), flow_runs)
    except TimeoutError:
        # A hang ends the scene checks; the runs not started yet need not
        for _name, pair in det_runs:
            for _dest, fut in pair:
                fut.cancel()
        for _flow, fut in flow_runs:
            fut.cancel()
        raise

    if "strings" in wanted:
        check_strings(rep, probe, require_de=(purpose == "teaching"))

    if "teaching" in wanted:
        check_teaching(rep, probe, flows_to_run(cfg, probe.get("flows", [])),
                       purpose)


if __name__ == "__main__":
    sys.exit(main())
