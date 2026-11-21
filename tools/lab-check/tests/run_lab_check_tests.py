#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-check's own checks (issue #208).

Covers the half that decides what a gate REPORTS, without a lab, a build or a
graphics session: the config it reads and the purpose it demands, what each tier
owes (flows, DE, a study, a board), that a typed table is red, the remark
counter, the first-difference message a failed determinism run has to carry,
and that the scene drivers are still complete JavaScript after being templated,
and what the load check counts as the environment (#534), and that a loader that
dies or never gets ready is red in seconds with its reason (#536). The other half - driving an
actual lab - is exercised by the four lab_check_<lab> gates themselves.

    python3 tools/lab-check/tests/run_lab_check_tests.py
"""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import lab_check as L          # noqa: E402

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


class Recorder(L.Report):
    """A Report that keeps quiet, so a test can assert on what it collected."""

    def check(self, name, ok, detail=""):
        self.lines.append((name, ok, detail))
        return ok

    def note(self, text):
        pass

    def not_run(self, name, why):
        self.skipped.append((name, why))

    def detail(self, needle):
        for name, _ok, det in self.lines:
            if needle in name:
                return det
        return None


# -- the config -------------------------------------------------------------


def test_config(tmp):
    rep = Recorder()
    lab = os.path.join(tmp, "no-config-101")
    os.makedirs(lab)
    check("config: a lab without lab-check.json gets the defaults",
          L.read_config(lab, rep) == {})

    lab = os.path.join(tmp, "good-101")
    os.makedirs(lab)
    with open(os.path.join(lab, "lab-check.json"), "w") as f:
        json.dump({"steps": 120, "flows": ["a"]}, f)
    cfg = L.read_config(lab, rep)
    check("config: steps and flows are read", cfg.get("steps") == 120
          and cfg.get("flows") == ["a"], str(cfg))

    lab = os.path.join(tmp, "broken-101")
    os.makedirs(lab)
    with open(os.path.join(lab, "lab-check.json"), "w") as f:
        f.write("{not json")
    rep = Recorder()
    check("config: unparsable lab-check.json is a failure, not a default",
          L.read_config(lab, rep) is None and rep.failed(), str(rep.lines))


# -- the purpose, and what it owes -------------------------------------------


def test_purpose():
    rep = Recorder()
    check("purpose: a declared tier is read",
          L.purpose_of({"purpose": "research"}, rep) == "research" and not rep.failed())
    rep = Recorder()
    check("purpose: a missing purpose is a failure naming the three tiers",
          L.purpose_of({}, rep) is None and "teaching" in rep.detail("declares a purpose"),
          rep.detail("declares a purpose"))
    rep = Recorder()
    check("purpose: an unknown purpose is a failure that quotes it",
          L.purpose_of({"purpose": "demo"}, rep) is None
          and "'demo'" in rep.detail("declares a purpose"), rep.detail("declares a purpose"))


def test_flows_gate():
    rep = Recorder()
    L.check_flows(rep, None, [], True, {}, 100)
    check("flows: a teaching lab with an empty flows() fails",
          bool(rep.failed()), str(rep.failed()))

    rep = Recorder()
    L.check_flows(rep, None, [], False, {}, 100)
    check("flows: a research or learning lab with no flow passes",
          not rep.failed(), str(rep.failed()))


def test_flows_to_run():
    published = ["lab-intro", "lab-later"]
    check('flows: "all" runs every flow the lab publishes, a later one too',
          L.flows_to_run({"flows": "all"}, published) == published)
    check("flows: no flows key means all of them",
          L.flows_to_run({}, published) == published)
    check("flows: an explicit list is run as written",
          L.flows_to_run({"flows": ["lab-intro"]}, published) == ["lab-intro"])
    check('flows: "none" runs none',
          L.flows_to_run({"flows": "none"}, published) == [])


def test_study(tmp):
    lab = os.path.join(tmp, "study-101")
    os.makedirs(lab)
    rep = Recorder()
    L.check_study(rep, lab, "teaching")
    check("study: a teaching lab owes no study", not rep.failed())
    rep = Recorder()
    L.check_study(rep, lab, "research")
    check("study: a research lab with no study fails", bool(rep.failed()))

    study = os.path.join(lab, "studies", "q1")
    os.makedirs(os.path.join(study, "records"))
    manifest = {"manifest": "clay-lab-study/1", "study": "q1", "lab": "x/Sandbox.qml",
                "objective": {"probe": "a", "statistic": "mean", "direction": "maximize"},
                "run": {"steps": 6, "stepHz": 60, "budget": 1},
                "parameters": [{"name": "p", "kind": "eval",
                                "levels": [{"id": "l", "eval": ["x()"]}]}],
                "seeds": [42]}
    doc = "# Q\n\n## Answerability\n\n| a | b | c |\n\n```json\n" \
          + json.dumps(manifest) + "\n```\n"
    open(os.path.join(study, "study.md"), "w").write(doc)
    rep = Recorder()
    L.check_study(rep, lab, "research")
    check("study: no committed records is a failure that says so",
          bool(rep.failed()) and "no committed records" in rep.detail("study: q1"),
          rep.detail("study: q1"))
    open(os.path.join(study, "records", "l-42.labrec"), "w").write("x")
    rep = Recorder()
    L.check_study(rep, lab, "research")
    check("study: manifest + records + answerability passes",
          not rep.failed(), str(rep.lines))
    open(os.path.join(study, "study.md"), "w").write(doc.replace("## Answerability", "## Method"))
    rep = Recorder()
    L.check_study(rep, lab, "research")
    check("study: a study without an answerability section fails",
          bool(rep.failed()) and "Answerability" in rep.detail("study: q1"),
          rep.detail("study: q1"))
    open(os.path.join(study, "study.md"), "w").write("# no manifest here\n")
    rep = Recorder()
    L.check_study(rep, lab, "research")
    check("study: a study whose manifest does not parse fails",
          bool(rep.failed()) and "fence" in rep.detail("study: q1"), rep.detail("study: q1"))


def test_triad(tmp):
    lab = os.path.join(tmp, "triad-101")
    os.makedirs(lab)
    for purpose in ("teaching", "learning", "research"):
        rep = Recorder()
        L.check_triad(rep, lab, purpose)
        check(f"triad: {purpose} without paper.md fails",
              "triad: paper.md exists" in rep.failed(), str(rep.failed()))
    open(os.path.join(lab, "paper.md"), "w").write("# p\n")
    rep = Recorder()
    L.check_triad(rep, lab, "research")
    check("triad: a research lab owes no board", not rep.failed(), str(rep.failed()))
    for purpose in ("teaching", "learning"):
        rep = Recorder()
        L.check_triad(rep, lab, purpose)
        check(f"triad: a {purpose} lab without a board fails",
              bool(rep.failed()), str(rep.failed()))
    open(os.path.join(lab, "overview.grafli"), "w").write("")
    rep = Recorder()
    L.check_triad(rep, lab, "teaching")
    check("triad: paper + board passes", not rep.failed(), str(rep.failed()))


def test_tables(tmp):
    """The renderer is lab-table's; what is checked here is that a stale
    block is a FAIL that names the command, and a current one a PASS."""
    lab = os.path.join(tmp, "tables-101")
    study = os.path.join(lab, "studies", "s", "records")
    os.makedirs(study)
    open(os.path.join(lab, "Sandbox.qml"), "w").write("")
    manifest = {"manifest": "clay-lab-study/1", "study": "s", "lab": "x/Sandbox.qml",
                "objective": {"probe": "a", "statistic": "mean", "direction": "maximize"},
                "run": {"steps": 6, "stepHz": 60, "budget": 2},
                "parameters": [{"name": "p", "kind": "eval",
                                "levels": [{"id": "l", "eval": ["x()"]},
                                           {"id": "r", "eval": ["y()"]}]}],
                "seeds": [42],
                "tables": {"t": {"columns": [{"head": "a", "expr": "mean(a)", "digits": 1}]}}}
    for lid, v in (("l", 1.25), ("r", 2.5)):
        open(os.path.join(study, f"{lid}-42.labrec"), "w").write(
            "# rec\n" + json.dumps({"format": "clay-lab-record/1", "id": f"{lid}-42",
                                    "probes": [{"name": "a", "mean": v}]})
            + "\n# samples\nt\ta\n")
    open(os.path.join(lab, "studies", "s", "study.md"), "w").write(
        "# S\n```json\n" + json.dumps(manifest) + "\n```\n")
    paper = os.path.join(lab, "paper.md")
    open(paper, "w").write("intro\n<!-- table: s/t -->\n| typed |\n<!-- /table -->\n")
    rep = Recorder()
    L.check_tables(rep, lab)
    check("tables: a typed block is a failure naming lab-table",
          bool(rep.failed()) and "lab-table" in rep.detail("paper.md s/t"),
          rep.detail("paper.md s/t"))
    open(paper, "w").write(
        "intro\n<!-- table: s/t -->\n| configuration | a | records |\n|---|---|---|\n"
        "| l | 1.2 | `l-42` |\n| r | 2.5 | `r-42` |\n<!-- /table -->\n")
    rep = Recorder()
    L.check_tables(rep, lab)
    check("tables: a block equal to the rendering passes",
          not rep.failed(), str(rep.lines))
    open(paper, "w").write("intro\n<!-- table: s/t -->\nnever closed\n")
    rep = Recorder()
    L.check_tables(rep, lab)
    check("tables: an unclosed block is a failure",
          bool(rep.failed()) and "closing" in rep.detail("tables: paper.md"),
          rep.detail("tables: paper.md"))
    open(paper, "w").write("no tables\n")
    rep = Recorder()
    L.check_tables(rep, lab)
    check("tables: a lab with no marked block passes", not rep.failed())


# -- the message a failed determinism run carries ---------------------------


def test_first_difference(tmp):
    a = os.path.join(tmp, "a.labrec")
    b = os.path.join(tmp, "b.labrec")
    open(a, "w").write("head\n0.05\t4.34302\n0.10\t4.5\n")
    open(b, "w").write("head\n0.05\t4.34346\n0.10\t4.5\n")
    msg = L.first_difference(a, b)
    # The number is the whole point: "the records differ" costs an hour that
    # "line 2: 4.34302 vs 4.34346" does not.
    check("determinism: the failure names the line and both values",
          "line 2" in msg and "4.34302" in msg and "4.34346" in msg, msg)

    open(b, "w").write("head\n0.05\t4.34302\n")
    check("determinism: a length difference is reported as one",
          "lines" in L.first_difference(a, b), L.first_difference(a, b))


# -- records (#535) ----------------------------------------------------------

# A make.sh that stands in for clayrender: it writes the records only when the
# renderer it was handed ($CLAYRENDER) is the one the test expects, and says
# what a real one says when there is no display when asked to.
FAKE_MAKE = """#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "${CLAYRENDER:-}" = "$(cat "$here/expect-render")" ] || {
    echo "clayrender not found at ${CLAYRENDER:-build/bin/clayrender}" >&2; exit 1; }
if [ -f "$here/no-display" ]; then
    echo "clayrender: needs a graphics session" >&2; exit 1
fi
[ "$1" = "--out-dir" ]
printf 'a\n' > "$2/a-42.labrec"
"""


# The same, for a make.sh given one scenario per run: it writes that
# scenario's record and notes the call.
FAKE_MAKE_PER_SCENARIO = """#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$1" = "--out-dir" ]
echo "$3" >> "$here/calls"
cp "$here/$3-42.labrec" "$2/$3-42.labrec"
"""


def record_text(scenario):
    """A committed record whose command names its make.sh scenario."""
    header = {"format": "clay-lab-record/1", "id": f"{scenario}-42",
              "command": f"labs/rec-split-101/records/make.sh {scenario}"}
    return ("# Clayground lab record v1\n" + json.dumps(header, indent=2)
            + "\n# samples\nt\n0\n")


def fake_lab(tmp, name, committed):
    lab = os.path.join(tmp, name)
    rec = os.path.join(lab, "records")
    os.makedirs(rec)
    make = os.path.join(rec, "make.sh")
    with open(make, "w") as f:
        f.write(FAKE_MAKE)
    os.chmod(make, os.stat(make).st_mode | stat.S_IEXEC)
    render = os.path.join(tmp, name + "-clayrender")
    open(render, "w").close()
    with open(os.path.join(rec, "expect-render"), "w") as f:
        f.write(render)
    for fname, text in committed.items():
        with open(os.path.join(rec, fname), "w") as f:
            f.write(text)
    return lab, render


def test_records(tmp):
    work = os.path.join(tmp, "records-work")
    os.makedirs(work)

    lab, render = fake_lab(tmp, "rec-given-101", {"a-42.labrec": "a\n"})
    rep = Recorder()
    ok = L.check_records(rep, lab, work, render)
    check("records: make.sh runs with the clayrender lab-check was given",
          ok and not rep.skipped and rep.lines and rep.lines[0][1],
          str(rep.lines + rep.skipped))
    check("records: the pass counts the records it compared",
          rep.detail("records: make.sh") == "1 records", rep.detail("records: make.sh"))

    lab, render = fake_lab(tmp, "rec-session-101",
                           {"a-42.labrec": "a\n", "session.labrec": "scratch\n"})
    rep = Recorder()
    check("records: a session.labrec from Shift+R is not compared",
          L.check_records(rep, lab, os.path.join(work, "s"), render)
          and rep.detail("records: make.sh") == "1 records", str(rep.lines))

    lab, render = fake_lab(tmp, "rec-none-101", {})
    rep = Recorder()
    L.check_records(rep, lab, os.path.join(work, "n"), render)
    det = rep.detail("records: make.sh") or ""
    check("records: with nothing committed the pass says so, not '(1 records)'",
          "no committed records" in det, det)

    lab, render = fake_lab(tmp, "rec-missing-101", {"a-42.labrec": "a\n"})
    rep = Recorder()
    ok = L.check_records(rep, lab, os.path.join(work, "m"), render + "-absent")
    check("records: no clayrender is NOT RUN, counted apart from the passes",
          ok and not rep.lines and len(rep.skipped) == 1, str(rep.skipped))

    lab, render = fake_lab(tmp, "rec-display-101", {"a-42.labrec": "a\n"})
    open(os.path.join(lab, "records", "no-display"), "w").close()
    rep = Recorder()
    ok = L.check_records(rep, lab, os.path.join(work, "d"), render)
    check("records: no graphics session is NOT RUN, counted apart",
          ok and not rep.lines and len(rep.skipped) == 1, str(rep.skipped))

    # The summary and --strict, through the command line
    with open(os.path.join(lab, "lab-check.json"), "w") as f:
        json.dump({"purpose": "learning"}, f)
    open(os.path.join(lab, "Sandbox.qml"), "w").close()
    tool = os.path.join(os.path.dirname(HERE), "lab_check.py")
    base = [sys.executable, tool, lab, "--only", "records", "--clayrender", render]
    plain = subprocess.run(base, capture_output=True, text=True)
    check("records: the summary line says how many checks did not run",
          plain.returncode == 0 and "0/0 checks passed, 1 not run" in plain.stdout,
          f"exit {plain.returncode}: {plain.stdout.strip().splitlines()[-3:]}")
    strict = subprocess.run(base + ["--strict"], capture_output=True, text=True)
    check("records: --strict exits 1 when a check did not run",
          strict.returncode == 1, f"exit {strict.returncode}")

    # Records that say which make.sh run regenerates them are regenerated one
    # run each, side by side (#572)
    lab, render = fake_lab(tmp, "rec-split-101", {
        f"{sc}-42.labrec": record_text(sc) for sc in ("one", "two")})
    with open(os.path.join(lab, "records", "make.sh"), "w") as f:
        f.write(FAKE_MAKE_PER_SCENARIO)
    check("records: the scenario each record's command names is read",
          L.record_scenarios(os.path.join(lab, "records")) == ["one", "two"],
          str(L.record_scenarios(os.path.join(lab, "records"))))
    rep = Recorder()
    ok = L.check_records(rep, lab, os.path.join(work, "p"), render)
    calls = open(os.path.join(lab, "records", "calls")).read().split()
    check("records: make.sh runs once per committed record, with its scenario",
          sorted(calls) == ["one", "two"], str(calls))
    check("records: the per-record runs pass as one line",
          ok and rep.detail("records: make.sh") == "2 records", str(rep.lines))
    check("records: a record that names no scenario means one run for all",
          L.record_scenarios(os.path.join(tmp, "rec-given-101", "records")) is None)


# -- remarks ----------------------------------------------------------------


def test_remarks(tmp):
    lab = os.path.join(tmp, "remarks-101")
    os.makedirs(os.path.join(lab, "studies", "s1"))
    open(os.path.join(lab, "paper.md"), "w").write(
        "A claim {>>is this still true?<<} and {++an addition++} plus\n"
        "{--a deletion--} and {~~old~>new~~} across\nlines.\n")
    open(os.path.join(lab, "studies", "s1", "study.md"), "w").write(
        "{==highlight==}{>>why this one?<<}\n")
    rep = Recorder()
    L.check_remarks(rep, lab)
    detail = rep.detail("remarks")
    check("remarks: every CriticMarkup form is counted", "6 open" in detail, detail)
    check("remarks: counting them is never a failure", not rep.failed())

    rep = Recorder()
    L.check_remarks(rep, os.path.join(tmp, "no-config-101"))
    check("remarks: a lab with no prose counts zero",
          "0 open" in rep.detail("remarks"), rep.detail("remarks"))


# -- the strings check ------------------------------------------------------


def test_strings():
    both = {"en": ["a.one", "a.two"], "de": ["a.one", "a.two"]}
    rep = Recorder()
    L.check_strings(rep, {"langs": ["en", "de"], "keys": both,
                          "kernelKeys": {}, "flowKeys": []})
    check("strings: matching dictionaries pass", not rep.failed(), str(rep.failed()))

    rep = Recorder()
    L.check_strings(rep, {"langs": ["en", "de"],
                          "keys": {"en": ["a.one", "a.two"], "de": ["a.one"]},
                          "kernelKeys": {}, "flowKeys": []})
    check("strings: a key only English has is a failure that names it",
          bool(rep.failed()) and "a.two" in rep.detail("same keys"),
          rep.detail("same keys"))

    rep = Recorder()
    L.check_strings(rep, {"langs": ["en", "de"], "keys": both, "kernelKeys": {},
                          "flowKeys": ["flow.f.missing"]})
    check("strings: a narration key no dictionary carries is a failure",
          bool(rep.failed()) and "flow.f.missing" in rep.detail("FlowStep needs"),
          rep.detail("FlowStep needs"))

    rep = Recorder()
    L.check_strings(rep, {"langs": ["en", "de"], "keys": both,
                          "kernelKeys": {"en": ["chrome.next"],
                                         "de": ["chrome.next"]},
                          "flowKeys": ["chrome.next"]})
    check("strings: kernel chrome counts as carrying a key, as t() does",
          not rep.failed(), str(rep.failed()))

    rep = Recorder()
    L.check_strings(rep, {"langs": ["en"], "keys": {"en": ["a.one"]},
                          "kernelKeys": {}, "flowKeys": []}, require_de=True)
    check("strings: a teaching lab that ships only English fails",
          bool(rep.failed()), str(rep.failed()))

    rep = Recorder()
    L.check_strings(rep, {"langs": ["en"], "keys": {"en": ["a.one"]},
                          "kernelKeys": {}, "flowKeys": []}, require_de=False)
    check("strings: a research lab that ships only English passes",
          not rep.failed(), str(rep.failed()))

    rep = Recorder()
    L.check_strings(rep, {"langs": ["en", "de"],
                          "keys": {"en": ["a.one", "a.two"], "de": ["a.one"]},
                          "kernelKeys": {}, "flowKeys": []}, require_de=False)
    check("strings: a research lab that ships a half-translated DE still fails",
          bool(rep.failed()), str(rep.failed()))

    rep = Recorder()
    L.check_strings(rep, {"langs": [], "keys": {}, "kernelKeys": {}, "flowKeys": []},
                    require_de=False)
    check("strings: no EN at all fails for every purpose",
          bool(rep.failed()), str(rep.failed()))


# -- the drivers ------------------------------------------------------------


def lesson(**over):
    """The probe of a teaching lab with one flow that keeps every rule;
    a test changes one thing and expects exactly that thing to be red."""
    probe = {"tasks": {"f": 1}, "expects": {"f": 1}, "literals": {"f": []},
             "flowKeys": ["flow.f.go", "flow.f.go.hint"],
             "narration": {"en": {"flow.f.go": "Make the lamp light.",
                                  "flow.f.go.hint": "Which switch is open?"},
                           "de": {"flow.f.go": "Bring die Lampe zum Leuchten.",
                                  "flow.f.go.hint": "Welcher Schalter ist offen?"}}}
    probe.update(over)
    return probe


def teaching(probe, purpose="teaching"):
    rep = Recorder()
    L.check_teaching(rep, probe, ["f"], purpose)
    return rep


def test_teaching():
    """The teaching rules a program can test (#542): one failing example
    per rule, each red on its own line and on nothing else."""
    rep = teaching(lesson())
    check("teaching: a lesson that keeps every rule passes", not rep.failed(),
          str(rep.failed()))

    rep = teaching(lesson(tasks={"f": 0}))
    check("teaching: a flow with no task fails, naming the missing task",
          rep.failed() == ["teaching: f has a learner task and an expect"]
          and "no step is a task" in rep.detail("learner task"), str(rep.lines))

    rep = teaching(lesson(expects={"f": 0}))
    check("teaching: a flow with no expect fails, naming the missing expect",
          rep.failed() == ["teaching: f has a learner task and an expect"]
          and "no step carries an expect" in rep.detail("learner task"),
          str(rep.lines))

    long_de = lesson()
    long_de["narration"]["de"]["flow.f.go"] = "x" * 241
    rep = teaching(long_de)
    check("teaching: a German line of 241 characters fails, naming key and language",
          rep.failed() == ["teaching: every narration line fits in 240 characters"]
          and "flow.f.go [de] 241" in rep.detail("narration line"),
          str(rep.lines))

    long_hint = lesson()
    long_hint["narration"]["en"]["flow.f.go.hint"] = "y" * 300
    rep = teaching(long_hint)
    check("teaching: a hint is a narration line too",
          "flow.f.go.hint [en] 300" in (rep.detail("narration line") or ""),
          str(rep.lines))

    exact = lesson()
    exact["narration"]["en"]["flow.f.go"] = "z" * 240
    rep = teaching(exact)
    check("teaching: a line of exactly 240 characters passes", not rep.failed(),
          str(rep.lines))

    scripted = lesson()
    scripted["narration"]["en"]["flow.f.go.script"] = \
        "*point at the battery* " + "w" * 200 + " *face viewer* *gesticulate* " + "v" * 30
    rep = teaching(scripted)
    check("teaching: a script's *cues* do not count towards its length",
          not rep.failed(), str(rep.lines))

    other = lesson()
    other["narration"]["en"]["flow.someone-else.go"] = "u" * 400
    other["narration"]["en"]["hint.free"] = "u" * 400
    rep = teaching(other)
    check("teaching: only the lines of the flows it checks are measured",
          not rep.failed(), str(rep.lines))

    rep = teaching(lesson(literals={"f": ["go"]}))
    check("teaching: a say literal in the QML fails, naming the step",
          rep.failed() == ["teaching: no narration is written in the QML"]
          and "f.go" in rep.detail("written in the QML"), str(rep.lines))

    for purpose in ("learning", "research"):
        rep = teaching(lesson(tasks={"f": 0}, literals={"f": ["go"]}), purpose)
        check(f"teaching: a {purpose} lab owes none of the lesson rules",
              not rep.failed(), str(rep.lines))

    check("teaching: the probe counts tasks and say literals per flow",
          "++nTask" in L.PROBE_JS and "literal.push(" in L.PROBE_JS
          and "out.narration[l] = said" in L.PROBE_JS)


def test_drivers():
    """The JS is built by string templating, so a stray %% or a renamed key is
    a runtime error inside a lab an hour later. Render both here."""
    ok = True
    try:
        L.FLOW_JS % {"flow": L.js_str("f"), "maxSteps": 10}
        L.RUN_JS % {"scenario": L.js_str("s"), "steps": 5, "lab": L.js_str("l"),
                    "dest": L.js_str("/tmp/x"), "command": L.js_str("c")}
    except (KeyError, ValueError, TypeError) as e:
        ok = check("drivers: every template renders", False, str(e))
    if ok:
        check("drivers: every template renders", True)

    js = L.FLOW_JS % {"flow": L.js_str("led-basics"), "maxSteps": 42}
    check("drivers: the flow check calls the kernel's runFlow, not its own loop",
          "Lab.runFlow(" in js and '"led-basics"' in js and "maxSteps: 42" in js)
    check("drivers: braces balance in the rendered flow driver",
          js.count("{") == js.count("}"),
          f"{js.count('{')} open, {js.count('}')} close")

    # A single-quoted scenario name would end the expression early; js_str is
    # the only thing standing between a lab called it's-complicated and a
    # syntax error inside the engine.
    check("drivers: a name with a quote in it is escaped, not interpolated",
          L.js_str("it's \"x\"") == '"it\'s \\"x\\""', L.js_str("it's \"x\""))


def test_step_of():
    check("runFlow: a failure is named by its step key",
          L.step_of({"index": 3, "step": "lit"}) == "lit")
    check("runFlow: a step with no key falls back to its index",
          L.step_of({"index": 3, "step": ""}) == "step 3")
    check("runFlow: an expect that threw carries what it threw",
          L.step_of({"index": 3, "step": "lit", "error": "TypeError"})
          == "lit (TypeError)")


# -- what a load may log (#534) ----------------------------------------------


class FakeInspect(L.Inspect):
    """An inspector whose lab came up, answering from a log.jsonl on disk."""

    def wait_phase(self, phase, timeout=60.0):
        return True

    def state(self):
        return {"phase": "ready"}

    def request(self, payload, timeout=120.0):
        return {"status": {"rootLoaded": True, "alive": True}}


def load_verdict(tmp, name, entries):
    """check_load() over a lab whose loader logged `entries`, through the real
    Loader.diagnostics() reading a real log.jsonl."""
    repo = os.path.join(tmp, name)
    lab = os.path.join(repo, "labs", "some-101")
    inspect_dir = os.path.join(lab, ".clay", "inspect")
    os.makedirs(inspect_dir)
    os.makedirs(os.path.join(repo, "plugins", "clay_lab"))
    open(os.path.join(repo, ".git"), "w").close()
    open(os.path.join(repo, "plugins", "clay_lab", "LabView.qml"), "w").close()
    with open(os.path.join(inspect_dir, "log.jsonl"), "w") as f:
        for e in entries:
            f.write(json.dumps(e) + "\n")
    session = L.Loader("clayliveloader", os.path.join(lab, "Sandbox.qml"))
    session.insp = FakeInspect(inspect_dir)
    rep = Recorder()
    came_up = L.check_load(rep, session)
    clean = [ok for n, ok, _d in rep.lines if "nothing but the environment" in n]
    return repo, came_up, (clean[0] if clean else None), \
        rep.detail("nothing but the environment") or ""


# What the five labs log offscreen on macOS and on the Linux and Windows CI
# runners, word for word: the environment.
ENV_LINES = [
    {"level": "warning", "text": "The Qt Quick scene is using a rendering method "
     "that is not based on QRhi and a 3D graphics API. Qt Quick 3D is not "
     "functional in such an environment. The View3D item is not going to "
     "display anything."},
    {"level": "warning", "text": "Unexpected condition met: "
     "\"QSGRendererInterface::isApiRhiBased(rif->graphicsApi())\" in file "
     "/Users/qt/work/qt/qtquick3d/src/quick3d/qquick3dviewport.cpp, line 561"},
    {"level": "warning", "category": "qt.qpa.fonts", "text": "Populating font "
     "family aliases took 36 ms. Replace uses of missing font family "
     "\"Sans Serif\" with one that exists to avoid this cost. "},
    # ... and on the Linux CI runner
    {"level": "warning", "category": "qt.multimedia.symbolsresolver",
     "text": "Couldn't load pipewire-0.3 library"},
    {"level": "warning", "category": "qt.multimedia.symbolsresolver",
     "text": "Couldn't resolve pipewire-0.3 symbols"},
    {"level": "warning", "category": "qt.multimedia.symbolsresolver",
     "text": "Couldn't load va-x11 library"},
    {"level": "warning", "category": "qt.multimedia.symbolsresolver",
     "text": "Couldn't load va(in plugin) library"},
    {"level": "warning", "text": "PulseAudioService: pa_context_connect() failed"},
    # ... and on the Windows CI runner
    {"level": "warning", "text": "QFontDatabase: Cannot find font directory "
     "D:/a/clayground/Qt/6.10.1/msvc2022_64/lib/fonts.\nNote that Qt no longer "
     "ships fonts. Deploy some (from https://dejavu-fonts.github.io/ for "
     "example) or switch to fontconfig."},
    {"level": "log", "text": "qml: a log line is never a diagnostic"},
]


def test_load_diagnostics(tmp):
    _repo, came_up, clean, det = load_verdict(tmp, "env", ENV_LINES)
    check("load: the named environment messages alone pass the load",
          came_up and clean is True, det)
    check("load: every message the five labs log offscreen, macOS, Linux and Windows, is on the list",
          all(L.environment_name(e["text"], e.get("category", "default"))
              for e in ENV_LINES[:9]),
          str([L.environment_name(e["text"], e.get("category", "default"))
               for e in ENV_LINES[:9]]))
    check("load: the README holds the environment list, entry by entry",
          all(f"`{name}`" in open(os.path.join(os.path.dirname(HERE),
                                               "README.md")).read()
              for name, _p, _c in L.ENVIRONMENT),
          str([n for n, _p, _c in L.ENVIRONMENT]))

    # a kit file under labs/kits/ - the case the issue was filed for
    name = "kit"
    repo = os.path.join(tmp, name)
    kit = "file://" + os.path.join(repo, "labs", "kits", "hydro",
                                   "HydroElement3D.qml").replace(os.sep, "/")
    _repo, came_up, clean, det = load_verdict(tmp, name, ENV_LINES + [
        {"level": "warning",
         "text": kit + ":27: TypeError: Cannot call method 'boom' of null"}])
    check("load: a TypeError from a kit file fails the load", clean is False, det)
    check("load: ... and the output names the kit file and line",
          "labs/kits/hydro/HydroElement3D.qml:27: " in det, det)
    check("load: ... and the lab still counts as come up, so the other "
          "checks run", came_up is True)

    # the kernel, compiled into ClayLab's resources
    _repo, came_up, clean, det = load_verdict(tmp, "kernel", ENV_LINES + [
        {"level": "error", "text": "qrc:/qt/qml/Clayground/Lab/LabView.qml:25: "
         "TypeError: Cannot call method 'kernelBoom' of null"}])
    check("load: an error from plugins/clay_lab/ fails the load",
          clean is False, det)
    check("load: ... and the output names the kernel's source file",
          "plugins/clay_lab/LabView.qml:25: " in det, det)

    # a warning that names no file at all
    _repo, came_up, clean, det = load_verdict(tmp, "nofile", ENV_LINES + [
        {"level": "warning", "text": "qml: the lab warns without a location"}])
    check("load: a warning that names no file fails the load",
          clean is False and "(names no file)" in det, det)

    # a message the list does not name is not waved through for looking
    # like the machine's
    _repo, came_up, clean, det = load_verdict(tmp, "unlisted", ENV_LINES + [
        {"level": "warning", "category": "qt.qpa.fonts",
         "text": "Populating font family aliases took 36 ms. Replace uses of "
                 "missing font family \"Comic\" with one that exists."}])
    check("load: a message off the list fails, however environmental it looks",
          clean is False, det)

    # the multimedia entry holds only in its own category
    _repo, came_up, clean, det = load_verdict(tmp, "category", ENV_LINES + [
        {"level": "warning", "text": "Couldn't load va library"}])
    check("load: an environment message from the wrong category fails",
          clean is False, det)

    # repeats collapse into one line with a count
    ours, _other = L.classify_diagnostics(
        [{"level": "warning", "text": "qml: twice"}] * 2, tmp)
    check("load: a repeated message is one line with its count",
          ours == ["(names no file): [warning/default] qml: twice  (x2)"], str(ours))

    check("load: a Windows file URL names a drive path",
          L.source_file("file:///C:/x/labs/kits/k/K.qml:3: TypeError", "D:/repo")
          == "C:/x/labs/kits/k/K.qml:3", L.source_file(
              "file:///C:/x/labs/kits/k/K.qml:3: TypeError", "D:/repo"))


# -- a loader that dies or never gets ready (#536) ----------------------------

STAND_IN = os.path.join(HERE, "stand_in_loader.py")
LAB_CHECK = os.path.join(os.path.dirname(HERE), "lab_check.py")
LOAD_CHECK = os.path.join(os.path.dirname(HERE), "load_check.py")


def stand_in_lab(tmp, name):
    """A minimal learning lab for the stand-in loader to 'load'."""
    lab = os.path.join(tmp, name)
    os.makedirs(lab)
    for fname, text in (("Sandbox.qml", ""), ("paper.md", "# Paper\n"),
                        ("overview.grafli", ""),
                        ("lab-check.json", '{"purpose": "learning"}')):
        with open(os.path.join(lab, fname), "w") as f:
            f.write(text)
    return lab


def run_timed(cmd, mode):
    """(exit code, output, seconds it took) of cmd with STAND_IN_MODE=mode."""
    env = dict(os.environ, STAND_IN_MODE=mode)
    start = time.time()
    proc = subprocess.run(cmd, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, timeout=120)
    return proc.returncode, proc.stdout, time.time() - start


def run_with_stand_in(tmp, name, mode, ready_timeout):
    """lab-check over a minimal learning lab, with the stand-in as its loader."""
    lab = stand_in_lab(tmp, name)
    return run_timed(
        [sys.executable, LAB_CHECK, lab, "--loader", STAND_IN,
         "--ready-timeout", str(ready_timeout),
         "--only", "load,determinism,flows,triad,remarks"], mode)


def most_at_once(log):
    """The most intervals of a "start end" log that overlap at one instant."""
    try:
        spans = [tuple(map(float, l.split())) for l in open(log) if l.strip()]
    except OSError:
        return 0
    edges = sorted([(a, 1) for a, _b in spans] + [(b, -1) for _a, b in spans],
                   key=lambda e: (e[0], e[1]))
    now = peak = 0
    for _t, step in edges:
        now += step
        peak = max(peak, now)
    return peak


def quote(out):
    """The output a failing line carries - its last lines, where the verdict is."""
    return " | ".join(out.splitlines()[-8:])


def test_loader_watch(tmp):
    check("loader: the default ready timeout is two minutes at most",
          L.DEFAULT_READY_TIMEOUT <= 120, str(L.DEFAULT_READY_TIMEOUT))

    # a loader that dies at once: red in seconds, not after the timeout,
    # with its exit code and its last line
    code, out, took = run_with_stand_in(tmp, "crash-101", "crash", 60)
    check("loader: a loader that dies fails the check", code == 1, f"exit {code}")
    check("loader: a dead loader is seen within seconds, not the timeout",
          took < 15, f"{took:.1f} s against a 60 s timeout")
    check("loader: the FAIL line carries the loader's exit code",
          "FAIL  load: the loader keeps running  (the loader ended with exit "
          "code 3" in out, quote(out))
    check("loader: the loader's last output is printed",
          'module "Clayground.Missing" is not installed' in out, quote(out))
    check("loader: the checks that need no loader still report after a crash",
          "PASS  triad: paper.md exists" in out, quote(out))

    # a loader that stays up and never gets ready: red after the stated timeout
    code, out, took = run_with_stand_in(tmp, "never-101", "never-ready", 2)
    check("loader: a lab that never gets ready fails the check", code == 1,
          f"exit {code}")
    check("loader: the header states the ready timeout",
          "ready within 2 s" in out, out.splitlines()[0] if out else "")
    check("loader: the FAIL line states the timeout it waited",
          "FAIL  load: the lab reaches phase ready  (the lab never reached "
          "phase ready within 2 s (phase=loading))" in out, quote(out))
    check("loader: a never-ready lab ends near its timeout",
          took < 15, f"{took:.1f} s against a 2 s timeout")
    check("loader: the checks that need no loader still report after a timeout",
          "PASS  triad: paper.md exists" in out, quote(out))

    # the first process serves, every run after it stalls: one run waits the
    # timeout, the others are NOT RUN instead of each waiting it again
    code, out, took = run_with_stand_in(tmp, "stall-101", "stall-after-first", 2)
    check("loader: the first run that never gets ready fails",
          "FAIL  determinism: one  (the lab never reached phase ready within 2 s"
          in out, quote(out))
    check("loader: the runs after a stalled one are NOT RUN",
          "NOT RUN  determinism: two  (an earlier run's loader did not get the "
          "lab ready within 2 s)" in out, quote(out))
    check("loader: a stall costs one timeout, not one per run",
          took < 15, f"{took:.1f} s")

    # the first process serves, every run after it dies: each run is red with
    # the exit code, and the next run is still tried
    code, out, took = run_with_stand_in(tmp, "crash-run-101", "crash-after-first", 60)
    check("loader: a run whose loader dies fails with the exit code",
          "FAIL  determinism: one  (the loader ended with exit code 3" in out
          and "FAIL  determinism: two  (the loader ended with exit code 3" in out,
          quote(out))
    check("loader: crashing runs are seen within seconds", took < 15,
          f"{took:.1f} s against a 60 s timeout")
    check("loader: the checks that need no loader still report after a crashed run",
          "PASS  triad: paper.md exists" in out, quote(out))

    # the first process serves, the next one is up and never answers: one
    # protocol FAIL, and the checks that need no loader still report - a
    # timeout used to cost them their lines (#536)
    code, out, took = run_with_stand_in(tmp, "mute-101", "mute-after-first", 2)
    check("loader: a loader that stops answering fails one protocol line",
          code == 1 and "FAIL  protocol: no response for " in out,
          f"exit {code}: {quote(out)}")
    check("loader: the checks that need no loader still report after a protocol timeout",
          "PASS  triad: paper.md exists" in out, quote(out))
    check("loader: a protocol timeout ends within its ready timeout",
          took < 15, f"{took:.1f} s against a 2 s timeout")

    # --jobs: the stepped runs go side by side, and no more of them than
    # asked for (#572). Two scenarios are four runs, each holding its eval
    # for half a second.
    for jobs, most in ((1, 1), (3, 3)):
        lab = stand_in_lab(tmp, f"jobs{jobs}-101")
        _code, out, took = run_timed(
            [sys.executable, LAB_CHECK, lab, "--loader", STAND_IN,
             "--jobs", str(jobs), "--only", "determinism"], "slow-after-first")
        peak = most_at_once(os.path.join(lab, "stand-in-evals"))
        check(f"jobs: --jobs {jobs} runs at most {most} at once",
              1 <= peak <= most, f"{peak} at once, {took:.1f} s: {quote(out)}")
        if jobs > 1:
            check(f"jobs: --jobs {jobs} runs more than one at once", peak > 1,
                  f"{peak} at once")
        check(f"jobs: the header names --jobs {jobs}", f"jobs={jobs}," in out,
              out.splitlines()[0] if out else "")

    # A flow lab-check.json names does not wait for the first session, which
    # asks whether the lab loads: it needs nothing that session answers, so
    # the session's question and the flow's run are held at the same time
    lab = stand_in_lab(tmp, "flow-first-101")
    with open(os.path.join(lab, "lab-check.json"), "w") as f:
        json.dump({"purpose": "learning", "flows": ["f1"]}, f)
    _code, out, _took = run_timed([sys.executable, LAB_CHECK, lab, "--loader",
                                   STAND_IN, "--only", "load,flows"], "slow")
    peak = most_at_once(os.path.join(lab, "stand-in-evals"))
    check("jobs: a named flow runs beside the first session, not after it",
          peak == 2, f"{peak} at once: {quote(out)}")

    # load_check.py, the load stage for pages that are not labs, reports a
    # dead loader the same way
    lab = stand_in_lab(tmp, "load-crash-101")
    code, out, took = run_timed(
        [sys.executable, LOAD_CHECK, os.path.join(lab, "Sandbox.qml"),
         "--loader", STAND_IN], "crash")
    check("load_check: a loader that dies fails the page", code == 1,
          f"exit {code}")
    check("load_check: the FAIL line carries the loader's exit code",
          "the loader ended with exit code 3" in out, quote(out))
    check("load_check: the loader's last output is printed",
          'module "Clayground.Missing" is not installed' in out, quote(out))
    check("load_check: a dead loader is seen well within the 90 s timeout",
          took < 15, f"{took:.1f} s")


def main():
    tmp = tempfile.mkdtemp(prefix="lab-check-tests-")
    try:
        test_config(tmp)
        test_purpose()
        test_flows_gate()
        test_flows_to_run()
        test_study(tmp)
        test_triad(tmp)
        test_tables(tmp)
        test_first_difference(tmp)
        if os.name != "nt":
            # the stand-in make.sh is a bash script
            test_records(tmp)
        test_remarks(tmp)
        test_strings()
        test_teaching()
        test_drivers()
        test_step_of()
        test_load_diagnostics(tmp)
        if os.name != "nt":
            # the stand-in loader is started as an executable script
            test_loader_watch(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    failed = [n for n, ok in CHECKS if not ok]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    for name in failed:
        print("  FAILED  " + name)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
