#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Time what one change to one part costs a big board, and what opening it costs (#577).

    flip_check.py <Sandbox.qml> --open JS --flip JS
                  [--flips 10] [--flip-limit 16] [--opens 3] [--open-limit 50]
                  [--timings enforce|report]
                  [--keep JS]... [--keep-each JS]... [--clayrender build/bin/clayrender]

On the XOR board of electronics-101 one switch flip blocked the window for
100 to 233 ms: the board handed out new copies of every part and every wire,
routed every wire again and solved the truth table twice over. This runs the
lab in `clayrender --paused --script` and times, with Date.now() around each
call, as the issue measured it:

  --open   run --opens times; the fastest must be under --open-limit ms
  --flip   run --flips times after the last open; the median must be under
           --flip-limit ms - a frame is 16.7 ms
  --keep       an expression that must give the very same object before
               the flips and after them - an array handed out again as a
               copy fails it
  --keep-each  a list whose every element must be the same object before
               and after, in the same order - a Repeater's delegates, listed
               afresh each time, say none of them was built again

The limits are the issue's: a flip under 16 ms at the median, an open under
50 ms. Measured on an M-series Mac a flip takes 3 to 5 ms and an open 25 to
37 ms; before #577, 85 to 125 ms and 88 to 98 ms. The fastest open is the one checked, not the median: a build beside it
slows a run down, and the fastest of three still says what an open costs.

--timings report prints the timings and fails on the object checks alone.
The limits are milliseconds measured on a Mac with a GPU; the Windows CI
runner draws without one and took 106 to 160 ms to open the board and up to
15 ms for a flip, so a fixed limit there fails on the runner, not on the
board. labs/CMakeLists.txt enforces the limits on macOS and reports them
elsewhere.

Exit 0 under the limits, 1 not, 77 no clayrender built or no GPU session.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile

SKIP = 77


def script(a):
    lines = [
        "var o = { open: [], flip: [], kept: {} }",
        "function each(x, y) {",
        "    return x.length === y.length && x.every((v, i) => v === y[i])",
        "}",
        f"for (var k = 0; k < {a.opens}; ++k) {{",
        f"    var t = Date.now(); {a.open}; o.open.push(Date.now() - t)",
        "}",
    ]
    checks = [(k, "same") for k in a.keep] + [(k, "each") for k in a.keep_each]
    for i, (k, _) in enumerate(checks):
        lines.append(f"var keep{i} = ({k})")
    lines += [
        f"for (var j = 0; j < {a.flips}; ++j) {{",
        f"    var t1 = Date.now(); {a.flip}; o.flip.push(Date.now() - t1)",
        "}",
    ]
    for i, (k, how) in enumerate(checks):
        test = f"keep{i} === ({k})" if how == "same" else f"each(keep{i}, ({k}))"
        lines.append(f"o.kept[{json.dumps(k)}] = {test}")
    lines.append("return o")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("sandbox")
    ap.add_argument("--open", required=True)
    ap.add_argument("--flip", required=True)
    ap.add_argument("--opens", type=int, default=3)
    ap.add_argument("--flips", type=int, default=10)
    ap.add_argument("--open-limit", type=float, default=50)
    ap.add_argument("--flip-limit", type=float, default=16)
    ap.add_argument("--keep", action="append", default=[])
    ap.add_argument("--keep-each", action="append", default=[])
    ap.add_argument("--timings", choices=("enforce", "report"), default="enforce")
    ap.add_argument("--clayrender", default="build/bin/clayrender")
    a = ap.parse_args()

    if not os.access(a.clayrender, os.X_OK):
        print(f"SKIP: no clayrender at {a.clayrender}")
        return SKIP

    with tempfile.TemporaryDirectory(prefix="flip-check-") as tmp:
        js = os.path.join(tmp, "flip.js")
        result = os.path.join(tmp, "result.json")
        with open(js, "w") as f:
            f.write(script(a))
        cmd = [a.clayrender, a.sandbox, "--out", os.path.join(tmp, "shot.png"),
               "--paused", "--result", result, "--script", js]
        env = dict(os.environ)
        env["CLAY_SOUND_MUTE"] = "1"
        p = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=150)
        # The marker rest_check.py and run_render_tests.py skip on: a machine
        # with no GPU session cannot load a 3D lab at all.
        if p.returncode == 1 and "graphics session" in p.stderr:
            print("SKIP: clayrender cannot reach a GPU here")
            sys.stdout.write(p.stderr)
            return SKIP
        if p.returncode != 0 or not os.path.exists(result):
            print(f"FAIL: clayrender exited {p.returncode}")
            sys.stdout.write(p.stdout + p.stderr)
            return 1
        with open(result) as f:
            r = json.load(f)
    o = r[0]["value"] if isinstance(r, list) else r

    lab = os.path.basename(os.path.dirname(os.path.abspath(a.sandbox)))
    flip_med = statistics.median(o["flip"])
    open_min = min(o["open"])
    print(f"{lab}: flip median {flip_med} ms (min {min(o['flip'])}, max {max(o['flip'])}, "
          f"limit {a.flip_limit:g}), open fastest {open_min} ms "
          f"(of {o['open']}, limit {a.open_limit:g})")
    ok = True
    enforce = a.timings == "enforce"
    if not enforce:
        print("  timings reported, not checked (--timings report)")
    if enforce and flip_med >= a.flip_limit:
        print(f"FAIL: a flip takes {flip_med} ms at the median, the limit is {a.flip_limit:g}")
        ok = False
    if enforce and open_min >= a.open_limit:
        print(f"FAIL: the fastest open took {open_min} ms, the limit is {a.open_limit:g}")
        ok = False
    for k, same in o["kept"].items():
        print(f"  {'kept' if same else 'NOT kept'}: {k}")
        if not same:
            print(f"FAIL: a flip replaced {k}")
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
