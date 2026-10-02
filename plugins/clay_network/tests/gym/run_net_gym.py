#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Net Gym run - end-to-end verification of clay_network state sync.

Spawns three loader instances on the net-gym sandbox, connects them via
Local signaling (host + 2 joiners, Star topology) and verifies through the
inspector protocol: roster propagation, a host id every node agrees on,
senders that cannot be forged, the unreliable state channel,
sequence-guarded state flow (incl. relayed senders), interpolation
tracking, and node departure. A raw websocket that knows the LAN code
tries to register under ids that are taken (#321). Then the host's link is
conditioned - 10 % loss, latency with jitter, a blackout - and its link is
out for less than the grace period without anybody leaving. The host
leaves, hosts again and is killed (#301, #299). The host demands a room
password, and joinC is refused for a wrong one and for another wire version
before it gets in (#323).

--signaling cloud runs the same through clay-dev-server's PeerJS relay
instead (needs wsproto); the LAN code checks are Local-only and skipped,
the signaling drop is Cloud-only - a Local host is its own server.
"""

import argparse
import base64
import json
import os
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
import uuid

from netgym import (check, wait_for, summary, start_dev_server, check_tracking,
                    scenario_loss, scenario_latency, scenario_blackout,
                    scenario_host_leaves, scenario_short_outage, scenario_signaling_drop,
                    scenario_host_killed, scenario_handshake, check_client_token)

# Every node hosts and joins with it (#323)
PASSWORD = "stone"


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


def decode_lan_code(code):
    """(host, port, secret) of an "L<ip>-<port>-<secret>" code."""
    ip_part, port_part, secret = code[1:].split("-")
    ip = int(ip_part, 36)
    host = ".".join(str((ip >> s) & 0xFF) for s in (24, 16, 8, 0))
    return host, int(port_part, 36), secret


def signaling_first_reply(host, port, hello, timeout=5.0):
    """Open a websocket to a LAN signaling server the way an intruder with
    the code would - no ClayNetwork, any id it likes - send `hello` and
    return the first message the server answers with (None if it closes
    without one)."""
    s = socket.create_connection((host, port), timeout)
    try:
        key = base64.b64encode(os.urandom(16)).decode()
        s.sendall((f"GET /peerjs HTTP/1.1\r\nHost: {host}:{port}\r\n"
                   "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                   f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
                  .encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = s.recv(4096)
            if not chunk:
                return None
            buf += chunk
        head, buf = buf.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            return None

        data = json.dumps(hello).encode()
        mask = os.urandom(4)
        if len(data) < 126:
            frame = bytes([0x81, 0x80 | len(data)])
        else:
            frame = bytes([0x81, 0x80 | 126]) + struct.pack(">H", len(data))
        s.sendall(frame + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

        def need(n):
            nonlocal buf
            while len(buf) < n:
                chunk = s.recv(4096)
                if not chunk:
                    raise ConnectionError("closed")
                buf += chunk
            out, buf = buf[:n], buf[n:]
            return out

        while True:
            b0, b1 = need(2)
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", need(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", need(8))[0]
            payload = need(n)
            opcode = b0 & 0x0F
            if opcode == 0x1:
                return json.loads(payload.decode())
            if opcode == 0x8:
                return None
    except (OSError, ConnectionError, ValueError):
        return None
    finally:
        s.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--loader", required=True, help="path to clayliveloader")
    parser.add_argument("--signaling", choices=("local", "cloud"), default="local",
                        help="Local signaling, or Cloud through clay-dev-server")
    args = parser.parse_args()
    cloud = args.signaling == "cloud"

    loader = os.path.abspath(args.loader)
    loader_dir = os.path.dirname(loader)
    gym_src = os.path.dirname(os.path.abspath(__file__))

    # CLAY_NET_GYM_LOG_ROOT keeps a failed run's directory - loader logs and
    # inspector state - where CI can upload it; the system temp dir is gone
    # with the runner (#301)
    log_root = os.environ.get("CLAY_NET_GYM_LOG_ROOT") or None
    if log_root:
        os.makedirs(log_root, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix=f"clay_net_gym_{args.signaling}_", dir=log_root)
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
        signaling_url = ""
        if cloud:
            server, signaling_url = start_dev_server(tmp, os.path.join(tmp, "dev-server.log"))
            if not check("cloud: clay-dev-server signaling is up", server is not None,
                         signaling_url):
                return
            procs["dev-server"] = server

        for n in names:
            logf = open(os.path.join(tmp, f"{n}.log"), "w")
            procs[n] = subprocess.Popen(
                [loader, "--sbx", sbx, "--instance", n],
                cwd=loader_dir, env=env, stdout=logf, stderr=subprocess.STDOUT)
            insp[n] = Inspect(sandbox_dir, n)

        A, B, C = insp["host"], insp["joinB"], insp["joinC"]

        # -- 1: all instances up ------------------------------------------
        # Every instance is waited for and named, with how long it took or
        # the phase it was stuck in - "not ready" alone says nothing (#301)
        start = time.time()
        late = []
        took = {}
        for n in names:
            if insp[n].wait_phase("ready", max(1.0, 60.0 - (time.time() - start))):
                took[n] = round(time.time() - start, 1)
            else:
                st = insp[n].state()
                late.append(f"{n}: phase={st.get('phase', 'no state.json')} "
                            f"process exit={procs[n].poll()}")
        check("gym: all instances ready", not late,
              "; ".join(late) if late else f"ready after {took} s")
        if late:
            return

        # -- 2: host + join ------------------------------------------------
        for n in names:
            insp[n].eval([f"roomPassword = '{PASSWORD}'"])
            if cloud:
                insp[n].eval([f"signalingUrl = '{signaling_url}'"])
        A.eval(["hostUp()"])
        ok = wait_for(lambda: A.eval1("netId") not in (None, ""), 20)
        code = A.eval1("netId")
        check("host: network code assigned", ok and bool(code), str(code))

        if not cloud:
            check("host: LAN code carries an 8-char secret",
                  code.count("-") == 2 and len(code.split("-")[2]) == 8, str(code))

        B.eval([f"joinNet('{code}')"])
        check("joinB: connected", wait_for(lambda: B.eval1("connected") is True, 25))
        check_client_token(A, B, "joinB")

        if not cloud:
            lan_checks(B, C, code)
        scenario_handshake(A, C, "joinC", code, PASSWORD)

        host_id_on_b = B.eval1("nodeList[0]")
        run_after_join(A, B, C, names, insp, host_id_on_b, cloud, code, procs)
    except Exception as e:
        # An instance that stops answering raises here (Inspect.request).
        # finish() exits from the finally below, which would drop this
        # exception - a run cut short must not end green on the checks it
        # made before (#301)
        check("harness: ran to the end", False, repr(e))
    finally:
        finish(procs, tmp)


def lan_checks(B, C, code):
    """LAN codes (#293, #321): ids that are taken, malformed codes, wrong
    secrets. The handshake scenario then has joinC get in with the real
    code."""
    # -- 2a: whoever has the code cannot take a registered id (#321) ----
    lan_host, lan_port, lan_secret = decode_lan_code(code)
    id_b_early = B.eval1("netRef.nodeId")
    for claimed, label in (("HOST", "the host's id"), (id_b_early, "joinB's id")):
        reply = signaling_first_reply(lan_host, lan_port,
                                      {"id": claimed, "secret": lan_secret})
        check(f"intruder: registering under {label} is refused",
              bool(reply) and reply.get("type") == "ID-TAKEN", str(reply))

    # -- 2b': a malformed LAN code fails before it connects -------------
    C.eval([f"joinNet('{code}-X')"])
    check("joinC: malformed LAN code rejected",
          wait_for(lambda: C.eval1("lastError") == "Invalid LAN code", 5)
          and C.eval1("connected") is not True,
          str(C.eval1("lastError")))

    # -- 2b: a code with the wrong secret is turned away ---------------
    bad = code[:-1] + ("A" if code[-1] != "A" else "B")
    C.eval([f"joinNet('{bad}')"])
    rejected = wait_for(lambda: "Wrong LAN code" in (C.eval1("lastError") or ""), 10)
    check("joinC: wrong secret rejected", rejected and C.eval1("connected") is not True,
          str(C.eval1("lastError")))
    wait_for(lambda: C.eval1("status") in (0, 3), 5)


def run_after_join(A, B, C, names, insp, host_id_on_b, cloud, code, procs):
    """Everything after the three nodes are in: roster, sender ids, state
    flow, interpolation, the conditioned link and departures."""
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

    # -- 3b: every node names the same host (#298) ----------------------
    host_node = A.eval1("netRef.nodeId")
    hosts = {n: insp[n].eval1("netRef.hostId") for n in names}
    check("hostId: every node names the host",
          bool(host_node) and all(h == host_node for h in hosts.values())
          and host_id_on_b == host_node,
          f"host nodeId={host_node} hostId={hosts}")
    id_b = B.eval1("netRef.nodeId")
    id_c = C.eval1("netRef.nodeId")

    def senders(inst, probe):
        return [m.get("from") for m in
                json.loads(inst.eval1(f"msgsWithProbe('{probe}')") or "[]")]

    # -- 3c: a forged "from" to the host is attributed to its link -------
    # joinC speaks to the host as joinB; host and relay must both say joinC
    forged = json.dumps({"t": "m", "from": id_b, "d": {"probe": "forged"}})
    C.eval([f"netRef._sendRaw(netRef.hostId, {json.dumps(forged)})"])
    wait_for(lambda: senders(A, "forged") and senders(B, "forged"), 5)
    check("sender: forged from to the host is attributed to the real sender",
          senders(A, "forged") == [id_c],
          f"host saw {senders(A, 'forged')}, joinC is {id_c}, claimed {id_b}")
    check("sender: the host relays it under the real sender",
          senders(B, "forged") == [id_c],
          f"joinB saw {senders(B, 'forged')}")

    # -- 3d: a relayed sender outside the roster is dropped --------------
    # The host is trusted to relay, but only for nodes that joined: a
    # made-up "from" goes nowhere, the one after it (reliable, in order)
    # arrives - so its arrival proves the ghost had its chance.
    ghost = json.dumps({"t": "m", "from": "ghost0000", "d": {"probe": "ghost"}})
    after = json.dumps({"t": "m", "from": id_c, "d": {"probe": "after"}})
    A.eval([f"netRef._sendRaw('{id_b}', {json.dumps(ghost)})",
            f"netRef._sendRaw('{id_b}', {json.dumps(after)})"])
    arrived = wait_for(lambda: senders(B, "after"), 5)
    check("sender: a relayed from outside the roster is dropped",
          arrived and senders(B, "ghost") == [] and senders(B, "after") == [id_c],
          f"ghost={senders(B, 'ghost')} after={senders(B, 'after')}")

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
    # Measured on joinB alone, every frame: what it shows against the
    # sender moment it means to show (netgym.check_tracking)
    B.eval([f"trackSender('{host_id_on_b}')"])
    time.sleep(1.0)
    check_tracking(B, "interp: clean link")
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
    # Same burst stamped on arrival - the behaviour #290 removed. It
    # jumps to catch up, so the probe has to see it: a probe that skips
    # too much (backward steps are skipped) would pass the
    # check above whatever the interpolator does (#339)
    B.eval([f"trackSender('{host_id_on_b}')", "useSentAt = false"])
    time.sleep(1.0)
    B.eval(["resetSpeedStats()"])
    time.sleep(2.5)
    v_arr = B.eval1("maxObservedSpeed")
    check("interp: the speed probe sees a catch-up jump",
          v_arr is not None and v_arr >= 15.0,
          f"stamped on arrival: maxSpeed="
          f"{round(v_arr, 1) if v_arr is not None else v_arr} Wu/s")
    B.eval(["useSentAt = true", "stallMs = 0", "syncRef.delayMs = 120"])

    # -- 8: the host behind a conditioned link (#301) ---------------------
    B.eval([f"trackSender('{host_id_on_b}')"])
    time.sleep(1.0)
    scenario_loss(A, B, host_id_on_b)
    scenario_latency(A, B, host_id_on_b)
    scenario_blackout(A, B, host_id_on_b)

    # -- 7: departure --------------------------------------------------
    C.eval(["netRef.leave()"])
    check("roster: joinC departure reaches joinB",
          wait_for(lambda: B.eval1("nodeList.length") == 1, 15),
          str(B.eval1("JSON.stringify(nodeList)")))

    # -- 10: out for less than the grace period, nobody leaves (#299) ----
    scenario_short_outage(A, [("joinB", B)])

    # -- 11: the host's signaling drops and comes back (#299) -------------
    # joinC joins once it is back; only a Cloud host has a server to lose
    joiners = [("joinB", B)]
    if cloud:
        scenario_signaling_drop(A, B, code, late=("joinC", C))
        joiners.append(("joinC", C))

    # -- 9: the host leaves (#301, #299) ---------------------------------
    scenario_host_leaves(A, joiners, host_id_on_b)

    # -- 12: the host process is killed (#299) ---------------------------
    A.eval(["hostUp()"])
    rehosted = wait_for(lambda: A.eval1("netId") not in (None, "")
                        and A.eval1("connected") is True, 20)
    code2 = A.eval1("netId")
    B.eval([f"joinNet('{code2}')"])
    rejoined = wait_for(lambda: B.eval1("connected") is True, 25)
    if check("host killed: the host hosts again and joinB rejoins", rehosted and rejoined,
             str(code2)):
        scenario_host_killed(lambda: procs["host"].kill(), B.eval1("netRef.hostId"),
                             [("joinB", B)], "process killed")


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
    if not summary():
        print("Logs kept at:", tmp)
        sys.exit(1)
    shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(0)


if __name__ == "__main__":
    main()
