#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Run ctest once, then repeat only the failed tests that carry one label.

The network tests fail now and then on a signaling timeout and pass on a
rerun (#421). Until that is fixed, CI repeats a failed test labeled
`network` up to two more times instead of turning a pull request red that
never touched the network (#574). Every other failure fails at once, and
no test outside the label is ever repeated.

Every test that needed a repeat is named in the job summary
($GITHUB_STEP_SUMMARY) and as a warning annotation, so the flakiness
stays visible while it no longer blocks.

Usage, from the build directory:
    ctest_retry.py [--ctest ctest] [--label network] [--retries 2]
                   -- <ctest arguments of the first run>

Exit code: 0 when every selected test passed in the end, else the exit code
of the last ctest run.
"""

import argparse
import json
import os
import re
import subprocess
import sys

FAILED_LOG = os.path.join("Testing", "Temporary", "LastTestsFailed.log")


def run_ctest(ctest, args):
    # A stale log from an earlier run would name tests this run never failed
    if os.path.exists(FAILED_LOG):
        os.remove(FAILED_LOG)
    cmd = [ctest] + args
    print("+ " + " ".join(cmd), flush=True)
    return subprocess.call(cmd)


def failed_tests():
    """The tests the last ctest run failed, or None when it wrote no list."""
    if not os.path.exists(FAILED_LOG):
        return None
    names = []
    with open(FAILED_LOG, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                # "<number>:<name>"
                names.append(line.split(":", 1)[1])
    return names


def labeled_tests(ctest, label):
    """Names of the tests whose labels include `label` exactly - not the
    `-L` regex, which would also match the component label
    plugins/clay_network every test of that plugin carries."""
    out = subprocess.run([ctest, "--show-only=json-v1"], check=True,
                         capture_output=True, text=True).stdout
    names = set()
    for test in json.loads(out).get("tests", []):
        for prop in test.get("properties", []):
            if prop.get("name") == "LABELS" and label in prop.get("value", []):
                names.add(test["name"])
    return names


def name_regex(names):
    return "^(" + "|".join(re.sub(r"([^A-Za-z0-9_])", r"\\\1", n)
                           for n in sorted(names)) + ")$"


def write_summary(label, repeats, attempts):
    """repeats: {test: the attempt it passed on, or None when it never did};
    attempts: how many times the tests that never passed were run"""
    if not repeats:
        return
    lines = [f"### `{label}` tests that needed a repeat (#574)", "",
             "| test | result |", "|---|---|"]
    for name in sorted(repeats):
        result = (f"passed on attempt {repeats[name]}" if repeats[name]
                  else f"failed all {attempts} attempts")
        lines.append(f"| `{name}` | {result} |")
    text = "\n".join(lines) + "\n"
    print("\n" + text, flush=True)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text + "\n")
    if os.environ.get("GITHUB_ACTIONS"):
        for name in sorted(repeats):
            if repeats[name]:
                print(f"::warning title=Flaky {label} test::{name} failed and "
                      f"passed on attempt {repeats[name]}", flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--ctest", default="ctest")
    p.add_argument("--label", default="network")
    p.add_argument("--retries", type=int, default=2)
    p.add_argument("ctest_args", nargs=argparse.REMAINDER)
    a = p.parse_args()
    args = a.ctest_args[1:] if a.ctest_args[:1] == ["--"] else a.ctest_args

    code = run_ctest(a.ctest, args)
    if code == 0:
        return 0
    failed = failed_tests()
    if not failed:
        # ctest failed without naming a test: no tests found, bad arguments
        return code
    labeled = labeled_tests(a.ctest, a.label)
    others = [n for n in failed if n not in labeled]
    if others:
        print(f"Not repeated - failed outside the `{a.label}` label: "
              + ", ".join(others), flush=True)
        return code

    repeats = {n: None for n in failed}
    pending = list(failed)
    attempts = 1
    for attempt in range(2, 2 + a.retries):
        print(f"\nRepeating {len(pending)} failed `{a.label}` test(s), "
              f"attempt {attempt}: " + ", ".join(pending), flush=True)
        code = run_ctest(a.ctest, ["--output-on-failure",
                                   "-R", name_regex(pending)])
        now_failing = set(failed_tests() or []) if code != 0 else set()
        if code != 0 and not now_failing:
            break  # the repeat itself could not run; report what we have
        attempts = attempt
        for n in pending:
            if n not in now_failing:
                repeats[n] = attempt
        pending = [n for n in pending if n in now_failing]
        if not pending:
            break
    write_summary(a.label, repeats, attempts)
    return 0 if not pending else (code or 1)


if __name__ == "__main__":
    sys.exit(main())
