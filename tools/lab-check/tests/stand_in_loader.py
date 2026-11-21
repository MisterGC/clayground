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

Serving the lab means phase "ready" and an answer to every inspector request:
a snapshot with a live root, and to any eval the probe JSON of a lab with two
scenarios and no flows. That is all lab-check's first session asks before it
starts a process per run. The count of processes so far is kept in
<lab>/stand-in-spawns, outside the .clay that lab-check removes per process.
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


def serve(inspect):
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
            if req.get("action") == "eval":
                resp["eval"] = {e: json.dumps(PROBE) for e in req.get("eval", [])}
            write_json(os.path.join(inspect, "response.json"), resp)
        time.sleep(0.02)


def main():
    lab = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--sbx") + 1]))
    inspect = os.path.join(lab, ".clay", "inspect")
    os.makedirs(inspect, exist_ok=True)
    counter = os.path.join(lab, "stand-in-spawns")
    try:
        with open(counter) as f:
            n = int(f.read() or 0)
    except OSError:
        n = 0
    with open(counter, "w") as f:
        f.write(str(n + 1))

    mode = os.environ.get("STAND_IN_MODE", "crash")
    if mode.endswith("-after-first"):
        mode = "serve" if n == 0 else mode[:-len("-after-first")]
    if mode == "stall":
        mode = "never-ready"
    if mode == "crash":
        crash()
    elif mode == "never-ready":
        never_ready(inspect)
    elif mode == "mute":
        mute(inspect)
    else:
        serve(inspect)


if __name__ == "__main__":
    main()
