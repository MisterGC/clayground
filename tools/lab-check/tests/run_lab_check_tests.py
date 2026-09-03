#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-check's own checks (issue #208).

Covers the half that decides what a gate REPORTS, without a lab, a build or a
graphics session: the config it reads, the remark counter, the first-difference
message a failed determinism run has to carry, and that the scene drivers are
still complete JavaScript after being templated. The other half - driving an
actual lab - is exercised by the four lab_check_<lab> gates themselves.

    python3 tools/lab-check/tests/run_lab_check_tests.py
"""

import json
import os
import shutil
import sys
import tempfile

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


# -- flows: "none" needs a reason -------------------------------------------


def test_flows_gate():
    rep = Recorder()
    L.check_flows(rep, None, [], None, 100)
    check("flows: an empty flows() with nothing said about it fails",
          bool(rep.failed()), str(rep.failed()))

    rep = Recorder()
    L.check_flows(rep, None, [], "the lab is an instrument, not a lesson", 100)
    check("flows: an empty flows() with a reason in lab-check.json passes",
          not rep.failed(), str(rep.failed()))


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
                          "kernelKeys": {}, "flowKeys": []})
    check("strings: a lab that ships only English fails",
          bool(rep.failed()), str(rep.failed()))


# -- the drivers ------------------------------------------------------------


def test_drivers():
    """The JS is built by string templating, so a stray %% or a renamed key is
    a runtime error inside a lab an hour later. Render all three here."""
    ok = True
    try:
        L.PROBE_JS % {"walk": L.WALK_JS}
        L.FLOW_JS % {"walk": L.WALK_JS, "flow": L.js_str("f"), "maxSteps": 10}
        L.RUN_JS % {"scenario": L.js_str("s"), "steps": 5, "lab": L.js_str("l"),
                    "dest": L.js_str("/tmp/x"), "command": L.js_str("c")}
    except (KeyError, ValueError, TypeError) as e:
        ok = check("drivers: every template renders", False, str(e))
    if ok:
        check("drivers: every template renders", True)

    js = L.FLOW_JS % {"walk": L.WALK_JS, "flow": L.js_str("led-basics"),
                      "maxSteps": 42}
    check("drivers: the flow driver carries the flow id and the bound",
          '"led-basics"' in js and "n < 42" in js)
    check("drivers: braces balance in the rendered flow driver",
          js.count("{") == js.count("}"),
          f"{js.count('{')} open, {js.count('}')} close")

    # A single-quoted scenario name would end the expression early; js_str is
    # the only thing standing between a lab called it's-complicated and a
    # syntax error inside the engine.
    check("drivers: a name with a quote in it is escaped, not interpolated",
          L.js_str("it's \"x\"") == '"it\'s \\"x\\""', L.js_str("it's \"x\""))


def main():
    tmp = tempfile.mkdtemp(prefix="lab-check-tests-")
    try:
        test_config(tmp)
        test_flows_gate()
        test_first_difference(tmp)
        test_remarks(tmp)
        test_strings()
        test_drivers()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    failed = [n for n, ok in CHECKS if not ok]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    for name in failed:
        print("  FAILED  " + name)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
