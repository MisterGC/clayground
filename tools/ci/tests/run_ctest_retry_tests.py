#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Suite for tools/ci/ctest_retry.py (#574) against a real ctest: a scratch
project whose tests fail a set number of times, counted in files, so each
case can check how often every test ran.

Usage: run_ctest_retry_tests.py <cmake> <ctest> [<generator>]"""

import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "ctest_retry.py")
CMAKE, CTEST = sys.argv[1], sys.argv[2]


def single_config_generator(given):
    """The scratch project needs a single-config generator: under a
    multi-config one (Visual Studio, CMake's default on Windows, Xcode,
    Ninja Multi-Config) a test run without -C never starts, and every count
    stayed 0. The build's own generator when it is single-config, else
    Ninja when it is installed, else CMake's default with CMAKE_GENERATOR
    cleared from the environment."""
    multi = ("Visual Studio", "Xcode", "Ninja Multi-Config")
    if given and not given.startswith(multi):
        return ["-G", given]
    if shutil.which("ninja"):
        return ["-G", "Ninja"]
    os.environ.pop("CMAKE_GENERATOR", None)
    return []


GENERATOR = single_config_generator(sys.argv[3] if len(sys.argv) > 3 else
                                    os.environ.get("CMAKE_GENERATOR"))

# name, labels, how many runs fail before it passes (-1: never passes)
TESTS = [
    ("net_once", "network;integration", 1),
    ("net_twice", "network;integration", 2),
    ("net_thrice", "network;integration", 3),
    ("net_ok", "network;unit", 0),
    # carries the component label plugins/clay_network, not `network`
    ("plugin_broken", "plugins/clay_network;unit", -1),
    ("other_ok", "tools/ci", 0),
]

FLAKY_CMAKE = """\
file(READ "${COUNT}" n)
math(EXPR n "${n} + 1")
file(WRITE "${COUNT}" "${n}")
if(FAILS LESS 0 OR n LESS_EQUAL FAILS)
    message(FATAL_ERROR "run ${n}: failing")
endif()
"""

FAILED = []


def check(name, got, want):
    ok = got == want
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else f"  (got {got!r}, want {want!r})"))
    if not ok:
        FAILED.append(name)


def setup(root):
    src, build = os.path.join(root, "src"), os.path.join(root, "build")
    os.makedirs(src)
    with open(os.path.join(src, "flaky.cmake"), "w") as f:
        f.write(FLAKY_CMAKE)
    lines = ["cmake_minimum_required(VERSION 3.16)", "project(retry NONE)",
             "enable_testing()"]
    for name, labels, fails in TESTS:
        count = os.path.join(root, name + ".count").replace("\\", "/")
        lines.append(f'add_test(NAME {name} COMMAND "${{CMAKE_COMMAND}}" '
                     f'-DCOUNT={count} -DFAILS={fails} '
                     f'-P "${{CMAKE_CURRENT_SOURCE_DIR}}/flaky.cmake")')
        lines.append(f'set_tests_properties({name} PROPERTIES LABELS "{labels}")')
    with open(os.path.join(src, "CMakeLists.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    subprocess.run([CMAKE, *GENERATOR, "-S", src, "-B", build], check=True,
                   stdout=subprocess.DEVNULL)
    return build


def run(root, build, ctest_args, *extra):
    for name, _, _ in TESTS:
        with open(os.path.join(root, name + ".count"), "w") as f:
            f.write("0")
    summary = os.path.join(root, "summary.md")
    if os.path.exists(summary):
        os.remove(summary)
    env = dict(os.environ, GITHUB_STEP_SUMMARY=summary, GITHUB_ACTIONS="true")
    p = subprocess.run([sys.executable, SCRIPT, "--ctest", CTEST, *extra,
                        "--", *ctest_args], cwd=build, env=env,
                       capture_output=True, text=True)
    runs = {}
    for name, _, _ in TESTS:
        with open(os.path.join(root, name + ".count")) as f:
            runs[name] = int(f.read())
    text = open(summary).read() if os.path.exists(summary) else ""
    return p.returncode, runs, text, p.stdout


with tempfile.TemporaryDirectory() as root:
    build = setup(root)

    # all green: one run each, nothing in the summary
    code, runs, summary, _ = run(root, build, ["-R", "^(net_ok|other_ok)$"])
    check("green run exits 0", code, 0)
    check("green run runs each test once", (runs["net_ok"], runs["other_ok"]), (1, 1))
    check("green run writes no summary", summary, "")

    # flaky network tests pass on a repeat, the passing ones are not repeated
    code, runs, summary, out = run(root, build, ["-R", "^(net_once|net_twice|net_ok|other_ok)$"])
    check("flaky network tests: job passes", code, 0)
    check("net_once ran twice", runs["net_once"], 2)
    check("net_twice ran three times", runs["net_twice"], 3)
    check("passing tests ran once", (runs["net_ok"], runs["other_ok"]), (1, 1))
    check("summary names net_once", "| `net_once` | passed on attempt 2 |" in summary, True)
    check("summary names net_twice", "| `net_twice` | passed on attempt 3 |" in summary, True)
    check("summary leaves out tests that passed at once",
          ("net_ok" in summary, "other_ok" in summary), (False, False))
    check("a warning names net_once",
          "::warning title=Flaky network test::net_once failed and passed on attempt 2" in out, True)
    tmp = os.path.join(build, "Testing", "Temporary")
    first = open(os.path.join(tmp, "FirstRunTest.log")).read()
    last = open(os.path.join(tmp, "LastTest.log")).read()
    check("the first run's test log is kept apart from the repeats' (#535)",
          ("other_ok" in first, "other_ok" in last), (True, False))

    # at most two repeats: a third failure fails the job and says so
    code, runs, summary, _ = run(root, build, ["-R", "^(net_once|net_thrice)$"])
    check("three failures fail the job", code != 0, True)
    check("net_thrice ran three times, no more", runs["net_thrice"], 3)
    check("summary says net_thrice failed every attempt",
          "| `net_thrice` | failed all 3 attempts |" in summary, True)
    check("summary still names net_once", "| `net_once` | passed on attempt 2 |" in summary, True)

    # a failure outside the label: nothing is repeated, the job fails
    code, runs, summary, out = run(root, build, ["-R", "^(net_once|plugin_broken)$"])
    check("failure outside the label fails the job", code != 0, True)
    check("nothing repeated next to it", (runs["net_once"], runs["plugin_broken"]), (1, 1))
    check("it is named as not repeated", "Not repeated" in out and "plugin_broken" in out, True)
    check("no summary when nothing was repeated", summary, "")

    # --retries narrows the repeats
    code, runs, _, _ = run(root, build, ["-R", "^net_twice$"], "--retries", "1")
    check("--retries 1: two runs, job fails", (code != 0, runs["net_twice"]), (True, 2))

    # ctest that names no failed test (no tests matched) keeps its exit code
    code, _, _, _ = run(root, build, ["-R", "^nothing$", "--no-tests=error"])
    check("no tests found fails without a repeat", code != 0, True)

print(f"\n{len(FAILED)} failed" if FAILED else "\nall passed")
sys.exit(1 if FAILED else 0)
