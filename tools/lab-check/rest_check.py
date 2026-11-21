#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Count the frames a lab draws in three seconds, at rest or moving (#575).

    rest_check.py <Sandbox.qml> --expect rest|moving
                  [--eval JS]... [--wait-for JS] [--clayrender build/bin/clayrender]

A lab in which nothing moves has nothing new to show, and a frame drawn
anyway is the whole 3D scene, shadow passes included, sixty times a second:
electronics-101 and hydraulics-101 did that at rest, at 10 to 12 % CPU, and
nothing said so. This runs `clayrender --stats 180` - 180 slots of 1/60 s,
after the uncounted second it lets pass - and reads two numbers off it:
`rendered`, the frames the window really drew, and `cpuMs`, what each slot
cost the whole process.

  rest    no frame drawn, and the mean slot under MAX_REST_CPU of a slot
  moving  at least MIN_MOVING_SHARE of the slots drawn - the lab woke up

The `--eval`s set the state up (close a valve, close a switch) and run before
the measurement; `--wait-for` must hold before it, or clayrender exits 3 and
so does the check - which is how a state that cannot be seen in a frame count
(a professor who is away has no body loaded) is asserted too.

Exit 0 as expected, 1 not, 77 no clayrender built.
"""

import argparse
import json
import os
import subprocess
import sys

SKIP = 77
SLOTS = 180                 # three seconds of 1/60 s
SLOT_MS = 1000.0 / 60
# The issue's limit is 2 % of a core; measured at rest the whole process takes
# 0.8 to 1.1 %. Three times the limit leaves room for a machine that is busy
# with other builds - the frame count is what this check is about, and that
# does not move with load.
MAX_REST_CPU = 0.06
# Moving, a lab draws every slot (180 of 180 measured). Half of them is
# enough to say it woke, and a loaded machine still clears it.
MIN_MOVING_SHARE = 0.5


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("sandbox")
    ap.add_argument("--expect", choices=("rest", "moving"), required=True)
    ap.add_argument("--eval", action="append", default=[])
    ap.add_argument("--wait-for", default="")
    ap.add_argument("--clayrender", default="build/bin/clayrender")
    a = ap.parse_args()

    if not os.access(a.clayrender, os.X_OK):
        print(f"SKIP: no clayrender at {a.clayrender}")
        return SKIP

    cmd = [a.clayrender, a.sandbox]
    for e in a.eval:
        cmd += ["--eval", e]
    if a.wait_for:
        cmd += ["--wait-for", a.wait_for]
    cmd += ["--stats", str(SLOTS)]
    env = dict(os.environ)
    env["CLAY_SOUND_MUTE"] = "1"
    p = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=150)
    if p.returncode != 0:
        print(f"FAIL: clayrender exited {p.returncode}"
              + (" - --wait-for never held: " + a.wait_for if p.returncode == 3 else ""))
        sys.stdout.write(p.stderr)
        return 1
    stats = None
    for line in p.stdout.splitlines():
        try:
            stats = json.loads(line)
        except json.JSONDecodeError:
            continue
    if not stats or "rendered" not in stats:
        print("FAIL: clayrender printed no --stats line")
        sys.stdout.write(p.stdout + p.stderr)
        return 1

    rendered = stats["rendered"]
    cpu = stats["cpuMs"]["mean"] / SLOT_MS
    print(f"{os.path.basename(os.path.dirname(os.path.abspath(a.sandbox)))}: "
          f"{rendered} of {stats['frames']} slots drawn, "
          f"CPU {cpu * 100:.1f} % of a slot (median slot {stats['cpuMs']['median']} ms)")
    if a.expect == "rest":
        ok = rendered == 0 and cpu < MAX_REST_CPU
        if not ok:
            print(f"FAIL: at rest a lab draws nothing and stays under "
                  f"{MAX_REST_CPU * 100:.0f} % CPU")
    else:
        ok = rendered >= MIN_MOVING_SHARE * stats["frames"]
        if not ok:
            print(f"FAIL: moving, a lab draws at least "
                  f"{MIN_MOVING_SHARE * 100:.0f} % of its slots")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
