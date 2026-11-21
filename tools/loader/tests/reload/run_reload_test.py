# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Reload one lab in a running loader again and again; the loader has to survive.

The loader died within a handful of reloads (#565): when a reload came less
than 500 ms after the first load, or two reloads came less than 200 ms apart,
the loader built its overlays twice on one engine. The first set was never
deleted, outlived its engine at the next reload, and an animation still
running in it crashed the process. With Qt 6.10 that is a SIGSEGV within a
few reloads; with Qt 6.11 the leak does not crash, so the test also reads the
loader's log: overlays are built at most once per engine.

Each reload is sent as soon as the previous one is the root - the timing an
agent driving the loader has, and the one that built the second set.

  run_reload_test.py --loader <clayliveloader> --lab <labs/name> [--reloads 50]

The lab is copied, with labs/kits beside it, into a temporary directory, so
the test never writes .clay/ into the source tree or into the directory of a
lab check running at the same time.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", required=True)
    ap.add_argument("--lab", required=True, help="a lab directory under labs/")
    ap.add_argument("--reloads", type=int, default=50)
    ap.add_argument("--timeout", type=float, default=30.0,
                    help="seconds one reload may take to become the root")
    args = ap.parse_args()
    args.loader = os.path.abspath(args.loader)

    lab = os.path.abspath(args.lab)
    kits = os.path.join(os.path.dirname(lab), "kits")
    work = tempfile.mkdtemp(prefix="clay-reload-")
    try:
        labs = os.path.join(work, "labs")
        shutil.copytree(lab, os.path.join(labs, os.path.basename(lab)),
                        ignore=shutil.ignore_patterns(".clay"))
        if os.path.isdir(kits):
            shutil.copytree(kits, os.path.join(labs, "kits"),
                            ignore=shutil.ignore_patterns(".clay"))
        sandbox = os.path.join(labs, os.path.basename(lab), "Sandbox.qml")
        return run(args, sandbox, os.path.join(work, "loader.log"))
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run(args, sandbox, log_path):
    inspect = os.path.join(os.path.dirname(sandbox), ".clay", "inspect")
    env = dict(os.environ)
    env["QT_QPA_PLATFORM"] = env.get("QT_QPA_PLATFORM", "offscreen")
    env["CLAY_SOUND_MUTE"] = "1"
    log = open(log_path, "w")
    proc = subprocess.Popen([args.loader, "--sbx", sandbox], env=env,
                            cwd=os.path.dirname(args.loader),
                            stdout=log, stderr=subprocess.STDOUT)

    def state():
        try:
            with open(os.path.join(inspect, "state.json")) as f:
                return json.load(f)
        except (OSError, ValueError):
            return None

    def request(req, timeout=args.timeout):
        req = dict(req, id=uuid.uuid4().hex[:8])
        tmp = os.path.join(inspect, "request.tmp")
        with open(tmp, "w") as f:
            json.dump(req, f)
        os.replace(tmp, os.path.join(inspect, "request.json"))
        end = time.time() + timeout
        while time.time() < end:
            try:
                with open(os.path.join(inspect, "response.json")) as f:
                    resp = json.load(f)
                if resp.get("requestId") == req["id"]:
                    return resp
            except (OSError, ValueError):
                pass
            if proc.poll() is not None:
                return None
            time.sleep(0.005)
        return None

    def wait_for_generation(after):
        # waitForRoot can answer for the outgoing root while the new one is
        # still loading; the generation only moves once the new one is it
        end = time.time() + args.timeout
        while time.time() < end:
            s = state()
            if s and s.get("phase") == "ready" and s.get("generation", 0) > after:
                return s["generation"]
            if proc.poll() is not None:
                return None
            time.sleep(0.005)
        return None

    failure = None
    done = 0
    t0 = time.time()
    generation = wait_for_generation(0)
    if generation is None:
        failure = "the first load never became ready"
    for i in range(args.reloads if failure is None else 0):
        if request({"action": "reload"}) is None:
            failure = "reload %d was not answered" % (i + 1)
            break
        request({"action": "waitForRoot", "timeoutMs": int(args.timeout * 1000)})
        nxt = wait_for_generation(generation)
        if nxt is None:
            failure = "reload %d never became the root" % (i + 1)
            break
        generation = nxt
        done += 1
    elapsed = time.time() - t0

    # Long enough for the last reload's overlays (built 200 ms after it) and
    # for an animation in a leaked set to run into its dead engine
    time.sleep(1.0)
    alive = proc.poll() is None
    if alive:
        proc.terminate()
        try:
            proc.wait(10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    log.close()
    if not alive and failure is None:
        failure = "the loader exited after the last reload"

    with open(log_path, errors="replace") as f:
        lines = f.read().splitlines()
    built = 0
    for line in lines:
        if line.startswith("Engine about to be destroyed"):
            built = 0
        elif line.startswith("Overlays created successfully"):
            built += 1
            if built > 1 and failure is None:
                failure = "the overlays were built twice on one engine"

    print("reloads: %d of %d in %.1f s, loader %s, exit %s"
          % (done, args.reloads, elapsed, "alive" if alive else "dead",
             proc.returncode))
    if failure:
        print("FAIL: " + failure)
        print("--- last lines of the loader's log ---")
        for line in lines[-30:]:
            print(line)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
