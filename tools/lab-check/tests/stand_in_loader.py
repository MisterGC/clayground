#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""A stand-in for clayliveloader, for lab-check's own tests (#536).

    stand_in_loader.py --sbx <lab>/Sandbox.qml

What it does is chosen by STAND_IN_MODE, which lab-check passes through
with the rest of its environment:

  crash              print two lines and exit 3 at once
  never-ready        report phase "loading" and stay up until terminated
  mute               report phase "ready" and never answer a request
  stall-after-first  the first process serves the lab; every later one is
                     never-ready
  crash-after-first  the first process serves the lab; every later one is
                     crash
  mute-after-first   the first process serves the lab; every later one is
                     mute
  slow               serve the lab, holding each eval for 0.5 s and noting
                     when it held it in <lab>/stand-in-evals - which is how
                     a test sees how many runs went at the same time (#572)
  slow-after-first   the first process serves the lab; every later one is
                     slow

Serving the lab means phase "ready" and an answer to every inspector request:
a snapshot with a live root, to `time` whether it was started with --paused,
and to any eval the probe JSON of a lab with two scenarios and no flows.
Started with --instance <name> it serves under .clay/inspect/i/<name>/, as
the loader does. That is all lab-check's first session asks before it
starts a process per run. The first process is the one that creates
<lab>/stand-in-first, outside the .clay that lab-check removes: an exclusive
create, because the runs start side by side and a counter in a file was read
half-written, so a later process took itself for the first (#572).
"""

import json
import os
import sys
import time

PROBE = {"scenarios": ["one", "two"], "flows": [], "expects": {},
         "langs": ["en"], "keys": {"en": []}}


def write_json(path, value):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(value, f)
    os.replace(tmp, path)


def crash():
    print("stand-in loader: starting", flush=True)
    print("stand-in loader: module \"Clayground.Missing\" is not installed",
          file=sys.stderr, flush=True)
    sys.exit(3)


def never_ready(inspect):
    write_json(os.path.join(inspect, "state.json"), {"phase": "loading"})
    while True:
        time.sleep(0.1)


def mute(inspect):
    write_json(os.path.join(inspect, "state.json"), {"phase": "ready"})
    while True:
        time.sleep(0.1)


def serve(inspect, paused, hold_log=None):
    write_json(os.path.join(inspect, "state.json"), {"phase": "ready"})
    request = os.path.join(inspect, "request.json")
    done = None
    while True:
        try:
            with open(request) as f:
                req = json.load(f)
        except (OSError, json.JSONDecodeError):
            req = None
        if req and req.get("id") != done:
            done = req.get("id")
            resp = {"requestId": done,
                    "status": {"rootLoaded": True, "alive": True}}
            if req.get("action") == "eval" and hold_log:
                start = time.time()
                time.sleep(0.5)
                with open(hold_log, "a") as f:
                    f.write(f"{start} {time.time()}\n")
            if req.get("action") == "eval":
                resp["eval"] = {e: json.dumps(PROBE) for e in req.get("eval", [])}
            elif req.get("action") == "time":
                resp["paused"] = req.get("paused", paused)
            write_json(os.path.join(inspect, "response.json"), resp)
        time.sleep(0.02)


def main():
    lab = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--sbx") + 1]))
    inspect = os.path.join(lab, ".clay", "inspect")
    if "--instance" in sys.argv:
        inspect = os.path.join(inspect, "i", sys.argv[sys.argv.index("--instance") + 1])
    os.makedirs(inspect, exist_ok=True)
    try:
        os.close(os.open(os.path.join(lab, "stand-in-first"),
                         os.O_CREAT | os.O_EXCL | os.O_WRONLY))
        first = True
    except FileExistsError:
        first = False

    mode = os.environ.get("STAND_IN_MODE", "crash")
    if mode.endswith("-after-first"):
        mode = "serve" if first else mode[:-len("-after-first")]
    if mode == "stall":
        mode = "never-ready"
    if mode == "slow":
        serve(inspect, "--paused" in sys.argv, os.path.join(lab, "stand-in-evals"))
    if mode == "crash":
        crash()
    elif mode == "never-ready":
        never_ready(inspect)
    elif mode == "mute":
        mute(inspect)
    elif mode != "slow":
        serve(inspect, "--paused" in sys.argv)


if __name__ == "__main__":
    main()
