#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Net Gym run - end-to-end verification of clay_network state sync.

Spawns three loader instances on the net-gym sandbox, connects them via
Local signaling (host + 2 joiners, Star topology) and verifies through the
inspector protocol: roster propagation, the unreliable state channel,
sequence-guarded state flow (incl. relayed senders), interpolation
tracking, and node departure.
"""

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok, detail))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


class Inspect:
    def __init__(self, sandbox_dir, instance):
        self.dir = os.path.join(sandbox_dir, ".clay", "inspect", "i", instance)
        self.request_path = os.path.join(self.dir, "request.json")
        self.response_path = os.path.join(self.dir, "response.json")

    def state(self):
        try:
            with open(os.path.join(self.dir, "state.json")) as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return {}

    def wait_phase(self, phase, timeout=30.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.state().get("phase") == phase:
                return True
            time.sleep(0.1)
        return False

    def request(self, payload, timeout=10.0):
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
            time.sleep(0.03)
        raise TimeoutError(f"no response for {payload.get('action')} ({rid})")

    def eval(self, exprs, timeout=10.0):
        return self.request({"action": "eval", "eval": exprs}, timeout).get("eval", {})

    def eval1(self, expr):
        return self.eval([expr]).get(expr)


def wait_for(cond, timeout=15.0, interval=0.15):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if cond():
                return True
        except Exception:
            pass
        time.sleep(interval)
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--loader", required=True, help="path to clayliveloader")
    args = parser.parse_args()

    loader = os.path.abspath(args.loader)
    loader_dir = os.path.dirname(loader)
    gym_src = os.path.dirname(os.path.abspath(__file__))

    tmp = tempfile.mkdtemp(prefix="clay_net_gym_")
    sandbox_dir = os.path.join(tmp, "gym")
    shutil.copytree(gym_src, sandbox_dir,
                    ignore=shutil.ignore_patterns(".clay", "__pycache__", "*.py"))
    sbx = os.path.join(sandbox_dir, "Sandbox.qml")

    env = dict(os.environ)
    env.setdefault("QT_QPA_PLATFORM", "offscreen")

    names = ["host", "joinB", "joinC"]
    procs = {}
    insp = {}
    try:
        for n in names:
            logf = open(os.path.join(tmp, f"{n}.log"), "w")
            procs[n] = subprocess.Popen(
                [loader, "--sbx", sbx, "--instance", n],
                cwd=loader_dir, env=env, stdout=logf, stderr=subprocess.STDOUT)
            insp[n] = Inspect(sandbox_dir, n)

        A, B, C = insp["host"], insp["joinB"], insp["joinC"]

        # -- 1: all instances up ------------------------------------------
        up = all(insp[n].wait_phase("ready") for n in names)
        check("gym: all instances ready", up)
        if not up:
            return finish(procs, tmp)

        # -- 2: host + join ------------------------------------------------
        A.eval(["hostUp()"])
        ok = wait_for(lambda: A.eval1("netId") not in (None, ""), 20)
        code = A.eval1("netId")
        check("host: network code assigned", ok and bool(code), str(code))

        check("host: LAN code carries a secret", code.count("-") == 2, str(code))

        B.eval([f"joinNet('{code}')"])
        check("joinB: connected", wait_for(lambda: B.eval1("connected") is True, 25))

        # -- 2b: a code with the wrong secret is turned away ---------------
        bad = code[:-1] + ("A" if code[-1] != "A" else "B")
        C.eval([f"joinNet('{bad}')"])
        rejected = wait_for(lambda: "Wrong LAN code" in (C.eval1("lastError") or ""), 10)
        check("joinC: wrong secret rejected", rejected and C.eval1("connected") is not True,
              str(C.eval1("lastError")))
        wait_for(lambda: C.eval1("status") in (0, 3), 5)
        C.eval([f"joinNet('{code}')"])
        check("joinC: connected", wait_for(lambda: C.eval1("connected") is True, 25))

        host_id_on_b = B.eval1("nodeList[0]")

        # -- 3: roster propagation (star topology) ------------------------
        check("roster: host sees 2 nodes",
              wait_for(lambda: A.eval1("nodeList.length") == 2, 10),
              str(A.eval1("JSON.stringify(nodeList)")))
        check("roster: joinB sees host + joinC",
              wait_for(lambda: B.eval1("nodeList.length") == 2, 10),
              str(B.eval1("JSON.stringify(nodeList)")))
        check("roster: joinC sees host + joinB",
              wait_for(lambda: C.eval1("nodeList.length") == 2, 10),
              str(C.eval1("JSON.stringify(nodeList)")))

        # -- 4: unreliable state channel negotiated ------------------------
        check("transport: state channel unreliable",
              wait_for(lambda: "unreliable" in
                       (B.eval1("JSON.stringify(netRef.peerStats)") or ""), 10),
              str(B.eval1("JSON.stringify(netRef.peerStats)")))

        # -- 5: state flow, direct and relayed -----------------------------
        time.sleep(2.0)
        sync_b = json.loads(B.eval1("JSON.stringify(netRef.syncStats)") or "{}")
        host_flow = sync_b.get(host_id_on_b, {})
        check("state: flowing from host at ~20Hz",
              host_flow.get("recv", 0) >= 25 and host_flow.get("ageMs", 9999) < 500,
              f"recv={host_flow.get('recv')} age={host_flow.get('ageMs')}ms")
        relayed = [k for k in sync_b if k != host_id_on_b]
        check("state: relayed joiner stream visible on joinB",
              len(relayed) == 1 and sync_b[relayed[0]].get("recv", 0) > 10,
              str(relayed))
        check("state: no stale drops on loopback",
              all(v.get("dropped", 0) == 0 for v in sync_b.values()),
              str({k: v.get("dropped") for k, v in sync_b.items()}))

        # -- 6: interpolation tracks the sender ----------------------------
        B.eval([f"trackSender('{host_id_on_b}')"])
        time.sleep(1.0)
        diffs = []
        for _ in range(4):
            rx = B.eval1("remoteX")
            ex = A.eval1("emitterX")
            if rx is not None and ex is not None and rx >= 0:
                d = abs(ex - rx)
                diffs.append(min(d, 100 - d))  # emitter wraps at 100
            time.sleep(0.3)
        check("interp: remote view tracks sender",
              len(diffs) >= 3 and max(diffs) < 8.0,
              f"diffs={[round(d, 2) for d in diffs]}")
        off = B.eval1("syncRef.clockOffsetMs")
        check("interp: snapshots placed on the sender's clock",
              isinstance(off, (int, float)) and off == off,  # a number, not NaN
              f"clockOffsetMs={off}")

        # -- 6b: auto delay sizes itself from the stream (#291) --------------
        # Loopback at 20 Hz: about 2 x 50 ms plus a few ms of lateness.
        B.eval(["syncRef.autoDelay = true"])
        time.sleep(3.0)
        d_clean = B.eval1("syncRef.effectiveDelayMs")
        check("interp: auto delay settles near 2x period on loopback",
              d_clean is not None and 80 <= d_clean <= 150,
              f"effectiveDelayMs={round(d_clean, 1) if d_clean is not None else d_clean}")
        B.eval(["jitterMs = 120"])
        time.sleep(4.0)
        d_jit = B.eval1("syncRef.effectiveDelayMs")
        check("interp: auto delay grows under arrival jitter",
              d_clean is not None and d_jit is not None and d_jit > d_clean + 40,
              f"effectiveDelayMs={round(d_jit, 1) if d_jit is not None else d_jit}")
        B.eval(["jitterMs = 0", "syncRef.autoDelay = false"])

        # -- 6c: a late burst plays back at the sender's speed (#290) -------
        # Hold the stream for 150 ms at a time and release it in one burst
        # into a 300 ms buffer (the buffer must cover the stall, otherwise a
        # catch-up jump is inevitable whatever the stamping). With sender
        # timestamps the interpolated value keeps the sender's 10 Wu/s.
        B.eval([f"trackSender('{host_id_on_b}')", "syncRef.delayMs = 300", "stallMs = 150"])
        time.sleep(1.0)
        B.eval(["resetSpeedStats()"])
        time.sleep(2.5)
        v_sent = B.eval1("maxObservedSpeed")
        check("interp: burst arrival does not outrun the sender",
              v_sent is not None and v_sent < 15.0,
              f"maxSpeed={round(v_sent, 1) if v_sent is not None else v_sent} Wu/s (sender 10)")
        # Same burst stamped on arrival, for comparison (not a check: it is
        # the behaviour #290 removed, printed so a regression stays visible)
        B.eval([f"trackSender('{host_id_on_b}')", "useSentAt = false"])
        time.sleep(1.0)
        B.eval(["resetSpeedStats()"])
        time.sleep(2.5)
        v_arr = B.eval1("maxObservedSpeed")
        print(f"info  interp: same burst stamped on arrival -> maxSpeed="
              f"{round(v_arr, 1) if v_arr is not None else v_arr} Wu/s")
        B.eval(["useSentAt = true", "stallMs = 0", "syncRef.delayMs = 120"])

        # -- 7: departure --------------------------------------------------
        C.eval(["netRef.leave()"])
        check("roster: joinC departure reaches joinB",
              wait_for(lambda: B.eval1("nodeList.length") == 1, 15),
              str(B.eval1("JSON.stringify(nodeList)")))

    finally:
        return finish(procs, tmp)


def finish(procs, tmp):
    for p in procs.values():
        try:
            p.terminate()
        except Exception:
            pass
    time.sleep(1)
    for p in procs.values():
        try:
            p.kill()
        except Exception:
            pass
    failed = [c for c in CHECKS if not c[1]]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    if failed:
        print("Logs kept at:", tmp)
        sys.exit(1)
    shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(0)


if __name__ == "__main__":
    main()
