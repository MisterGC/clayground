# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Shared parts of the net gym runs - native (run_net_gym.py, loader
instances through the inspector protocol) and browser (run_net_gym_web.py,
pages through web/Main.qml). An instance is anything with eval(list) and
eval1(expr) that evaluates expressions in the gym sandbox's scope.

The link scenarios (#301) put the host behind a bad link with
Network.linkConditions and look at one joiner that tracks the host's
stream. They measure on the joiner alone: the gym's motion source is a
function of the wall clock, so the joiner knows which sender moment its
view shows without reading the host at the same time.

The leaving scenarios (#299) take their times from the pages' own clocks
(Sandbox.qml's leftAt, disconnectedAt): the driver's polling is far coarser
than the second they are checked against.

The handshake scenario (#323) has a joiner knock with the wrong room
password and as a build of another wire version before it gets in.
"""

import json
import os
import socket
import subprocess
import sys
import time

CHECKS = []

# How far the interpolated view may be off the moment it means to show, in
# ms (10 Wu/s, so 25 ms is 0.25 Wu). Linear motion interpolates exactly, so
# what remains is frame timing - a stall or a jump is hundreds of ms.
TRACK_TOLERANCE_MS = 25.0


def check(name, ok, detail=""):
    CHECKS.append((name, ok, detail))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""),
          flush=True)
    return ok


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


def summary():
    failed = [c for c in CHECKS if not c[1]]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed", flush=True)
    return not failed


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def start_dev_server(work_dir, log_path):
    """Run clay-dev-server from this checkout as the Cloud signaling server.
    Returns (process, signaling url) or (None, reason)."""
    try:
        import wsproto  # noqa: F401 - clay-dev-server's signaling needs it
    except ImportError:
        return None, "clay-dev-server needs wsproto (pip install wsproto)"
    src = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                       "..", "..", "..", "..", "tools", "clay-dev-server"))
    port = free_port()
    serve = os.path.join(work_dir, "dev-server-root")
    os.makedirs(serve, exist_ok=True)
    env = dict(os.environ)
    env["PYTHONPATH"] = src + os.pathsep + env.get("PYTHONPATH", "")
    log = open(log_path, "w")
    proc = subprocess.Popen([sys.executable, "-m", "clay_dev_server", serve, str(port)],
                            env=env, stdout=log, stderr=subprocess.STDOUT)

    def up():
        try:
            socket.create_connection(("127.0.0.1", port), 0.5).close()
            return True
        except OSError:
            return False

    if not wait_for(up, 15, 0.2):
        proc.kill()
        return None, f"clay-dev-server did not listen on {port} (log: {log_path})"
    return proc, f"ws://127.0.0.1:{port}/peerjs"


def probes(inst, probe):
    return json.loads(inst.eval1(f"msgsWithProbe('{probe}')") or "[]")


def sync_of(inst, sender):
    stats = json.loads(inst.eval1("JSON.stringify(netRef.syncStats)") or "{}")
    return stats.get(sender, {})


def track_stats(inst):
    return json.loads(inst.eval1("trackStats()") or "{}")


def fmt(v, digits=1):
    return round(v, digits) if isinstance(v, (int, float)) else v


def check_tracking(joiner, label, window=3.0, min_frames=None):
    """The joiner's view of the tracked stream stays where it means to be."""
    joiner.eval(["resetTrackStats()"])
    time.sleep(window)
    t = track_stats(joiner)
    if min_frames is None:
        min_frames = int(window * 10)  # far below any frame rate
    ok = t.get("n", 0) >= min_frames and t.get("maxAbsErr", 1e9) < TRACK_TOLERANCE_MS
    return check(f"{label}: the view stays its delay behind the sender", ok,
                 f"frames={t.get('n')} maxErr={fmt(t.get('maxAbsErr'))}ms "
                 f"meanLag={fmt(t.get('meanLag'))}ms delay={fmt(t.get('delayMs'))} "
                 f"transit={fmt(t.get('clockOffsetMs'))}ms")


def in_order(entries, n):
    return [e.get("i") for e in entries] == list(range(n))


def scenario_loss(host, joiner, host_id, loss=0.1, window=6.0):
    """10 % of the host's state is lost both ways; the joiner still tracks,
    and reliable messages lose nothing."""
    host.eval([f"netRef.linkConditions = ({{loss: {loss}}})"])
    time.sleep(1.0)
    s0 = sync_of(joiner, host_id)
    joiner.eval(["resetTrackStats()"])
    host.eval(["sendProbes('lossy', 20)"])
    time.sleep(window)
    s1 = sync_of(joiner, host_id)
    t = track_stats(joiner)
    host.eval(["netRef.linkConditions = ({})"])

    sent = s1.get("seq", 0) - s0.get("seq", 0)
    got = s1.get("recv", 0) - s0.get("recv", 0)
    measured = 1 - got / sent if sent > 0 else -1
    # 120 updates at 10 %: 12 expected, 3 sigma is about +-10
    check(f"loss {int(loss * 100)} %: about that share of the host's state is lost",
          sent >= window * 15 and 0.02 <= measured <= 0.22,
          f"sent={sent} received={got} lost={fmt(measured * 100)}%")
    msgs = probes(joiner, "lossy")
    check(f"loss {int(loss * 100)} %: reliable messages all arrive, in order",
          in_order(msgs, 20), f"got {len(msgs)}/20: {[m.get('i') for m in msgs]}")
    check(f"loss {int(loss * 100)} %: the view stays its delay behind the sender",
          t.get("n", 0) >= window * 10 and t.get("maxAbsErr", 1e9) < TRACK_TOLERANCE_MS,
          f"frames={t.get('n')} maxErr={fmt(t.get('maxAbsErr'))}ms "
          f"meanLag={fmt(t.get('meanLag'))}ms delay={fmt(t.get('delayMs'))}")


def scenario_latency(host, joiner, host_id, latency=80, jitter=20):
    """A slow link moves the lag by its transit and nothing else."""
    host.eval([f"netRef.linkConditions = ({{latencyMs: {latency}, jitterMs: {jitter}}})"])
    # the transit estimate is the fastest update of the last 3 s
    time.sleep(4.0)
    joiner.eval(["resetTrackStats()"])
    time.sleep(3.0)
    t = track_stats(joiner)
    host.eval(["netRef.linkConditions = ({})"])
    off = t.get("clockOffsetMs")
    check(f"latency {latency}+-{jitter} ms: the transit estimate sees the conditioned delay",
          isinstance(off, (int, float)) and latency - 5 <= off <= latency + jitter + 15,
          f"clockOffsetMs={fmt(off)}")
    check(f"latency {latency}+-{jitter} ms: the view stays its delay behind the sender",
          t.get("n", 0) >= 30 and t.get("maxAbsErr", 1e9) < TRACK_TOLERANCE_MS,
          f"frames={t.get('n')} maxErr={fmt(t.get('maxAbsErr'))}ms "
          f"meanLag={fmt(t.get('meanLag'))}ms delay={fmt(t.get('delayMs'))}")


def scenario_blackout(host, joiner, host_id, dark=1.5):
    """The host's link goes dark: its state stops, reliable messages wait,
    and when the link is back they arrive in order and the view recovers."""
    host.eval(["netRef.linkConditions = ({blackout: true})"])
    time.sleep(0.3)
    host.eval(["sendProbes('dark', 5)"])
    time.sleep(dark)
    age = joiner.eval1(f"netRef.stateAgeMs('{host_id}')")
    early = probes(joiner, "dark")
    check("blackout: no state and no message gets through while dark",
          isinstance(age, (int, float)) and age >= dark * 1000 and not early,
          f"stateAgeMs={age} messages={len(early)}")

    host.eval(["netRef.linkConditions = ({})"])
    arrived = wait_for(lambda: len(probes(joiner, "dark")) >= 5, 5)
    msgs = probes(joiner, "dark")
    check("blackout: held messages arrive in order once the link is back",
          arrived and in_order(msgs, 5), f"{[m.get('i') for m in msgs]}")
    check("blackout: the host's state flows again",
          wait_for(lambda: 0 <= joiner.eval1(f"netRef.stateAgeMs('{host_id}')") < 300, 5),
          f"stateAgeMs={joiner.eval1(f'netRef.stateAgeMs({json.dumps(host_id)})')}")
    time.sleep(1.0)
    check_tracking(joiner, "blackout: after it", 2.0)


# Network.gracePeriod's default, and the ping interval in Network.qml
GRACE_MS = 5000
PING_MS = 2000


def scenario_host_leaves(host, joiners, host_id):
    """The host leaves; every joiner hears its goodbye, ends Disconnected with
    errorOccurred within 1 s, and drops it and its stream."""
    host.eval(["leaveNow()"])
    left_at = host.eval1("leftAt") or 0
    start = time.time()
    for name, j in joiners:
        ended = wait_for(lambda: (j.eval1("disconnectedAt") or 0) > 0, 10)
        took = (j.eval1("disconnectedAt") or 0) - left_at
        err = j.eval1("lastError")
        check(f"host leaves: {name} is Disconnected with errorOccurred within 1 s",
              ended and left_at > 0 and 0 <= took < 1000 and j.eval1("status") == 0
              and err == "The host left the network",
              f"after {fmt(took, 0)} ms, status={j.eval1('status')} lastError={err!r}")
        gone = wait_for(lambda: host_id not in (j.eval1("JSON.stringify(nodeList)") or ""), 30)
        took = time.time() - start
        check(f"host leaves: {name} drops the host from its nodes",
              gone, f"after {took:.1f}s, nodes={j.eval1('JSON.stringify(nodeList)')}")
        left = json.loads(j.eval1("JSON.stringify(leftLog)") or "[]")
        check(f"host leaves: {name} reports it in nodeLeft", host_id in left, str(left))
        check(f"host leaves: {name} keeps no stream from it",
              j.eval1(f"netRef.stateAgeMs('{host_id}')") == -1,
              f"stateAgeMs={j.eval1(f'netRef.stateAgeMs({json.dumps(host_id)})')}")


def scenario_short_outage(host, joiners, outage_ms=GRACE_MS - 1500):
    """The host's link is out for less than the grace period, then back:
    nobody is reported as left, on either side (#299)."""
    host.eval(["resetLogs()"])
    for _, j in joiners:
        j.eval(["resetLogs()"])
    before = host.eval1("nodeList.length")
    host.eval([f"outage({outage_ms})"])
    # the outage, then long enough for every check that was due to run
    time.sleep((outage_ms + GRACE_MS + PING_MS + 500) / 1000)
    host_left = json.loads(host.eval1("JSON.stringify(leftLog)") or "[]")
    check(f"outage {outage_ms} ms: the host loses no joiner",
          not host_left and host.eval1("nodeList.length") == before,
          f"nodeLeft={host_left} nodes {before} -> {host.eval1('nodeList.length')}")
    for name, j in joiners:
        left = json.loads(j.eval1("JSON.stringify(leftLog)") or "[]")
        check(f"outage {outage_ms} ms: {name} stays in the network",
              not left and j.eval1("connected") is True and not j.eval1("lastError"),
              f"nodeLeft={left} connected={j.eval1('connected')} "
              f"lastError={j.eval1('lastError')!r}")


def scenario_signaling_drop(host, joiner, code, late=None):
    """The host's Cloud signaling drops (#299): the network goes on, the host
    takes no joiners meanwhile, and once the server can be reached again the
    host is back on it under its code - where late, if given, joins."""
    host.eval(["resetLogs()"])
    joiner.eval(["resetLogs()"])
    check("signaling drop: the host takes joiners before",
          host.eval1("netRef.acceptingJoins") is True)
    host.eval(["netRef.linkConditions = ({dropSignaling: true})"])
    lost = wait_for(lambda: host.eval1("signalingLosses") == 1
                    and host.eval1("netRef.acceptingJoins") is False, 10)
    check("signaling drop: signalingLost, and acceptingJoins is false",
          lost, f"signalingLosses={host.eval1('signalingLosses')} "
                f"acceptingJoins={host.eval1('netRef.acceptingJoins')}")
    host.eval(["sendProbes('nosignaling', 5)"])
    arrived = wait_for(lambda: len(probes(joiner, "nosignaling")) >= 5, 5)
    check("signaling drop: the network goes on - status, nodes, messages",
          arrived and host.eval1("status") == 2 and host.eval1("connected") is True
          and joiner.eval1("connected") is True
          and not json.loads(joiner.eval1("JSON.stringify(leftLog)") or "[]"),
          f"messages={len(probes(joiner, 'nosignaling'))}/5 host status={host.eval1('status')} "
          f"joiner connected={joiner.eval1('connected')}")
    time.sleep(3.0)
    check("signaling drop: no reconnect gets through while the server is unreachable",
          host.eval1("netRef.acceptingJoins") is False)

    host.eval(["netRef.linkConditions = ({})"])
    start = time.time()
    back = wait_for(lambda: host.eval1("netRef.acceptingJoins") is True, 15)
    took = time.time() - start
    check("signaling drop: the host is back on the server once it can reach it",
          back and host.eval1("status") == 2 and not host.eval1("lastError")
          and host.eval1("signalingLosses") == 1 and host.eval1("netId") == code,
          f"after {took:.1f}s, status={host.eval1('status')} "
          f"lastError={host.eval1('lastError')!r} netId={host.eval1('netId')}")
    if late:
        name, inst = late
        inst.eval([f"joinNet('{code}')"])
        check(f"signaling drop: {name} joins the host after it is back",
              wait_for(lambda: inst.eval1("connected") is True, 25),
              f"status={inst.eval1('status')} lastError={inst.eval1('lastError')!r}")


def scenario_host_killed(kill, host_id, joiners, how):
    """The host dies without a word (#299): every joiner ends Disconnected
    with errorOccurred within the grace period plus one ping interval of the
    host going silent - the last thing the joiner received from it, on the
    joiner's clock. The driver's own kill time also counts how long the
    kill took, which a slow runner stretches; it is reported, not checked."""
    for _, j in joiners:
        j.eval(["resetLogs()"])
    limit = GRACE_MS + PING_MS
    killed_at = time.time() * 1000
    kill()
    for name, j in joiners:
        ended = wait_for(lambda: (j.eval1("disconnectedAt") or 0) > 0, limit / 1000 + 10)
        ended_at = j.eval1("disconnectedAt") or 0
        silent_at = j.eval1("lastFromHostAt") or 0
        took = ended_at - silent_at
        err = j.eval1("lastError")
        check(f"host {how}: {name} is Disconnected with errorOccurred within "
              f"grace + ping ({limit} ms) of the host going silent",
              ended and silent_at > 0 and 0 <= took <= limit
              and j.eval1("status") == 0 and bool(err),
              f"after {fmt(took, 0)} ms of silence ({fmt(ended_at - killed_at, 0)} ms "
              f"after the driver began the kill), lastError={err!r}")
        left = json.loads(j.eval1("JSON.stringify(leftLog)") or "[]")
        check(f"host {how}: {name} reports it in nodeLeft and keeps no stream",
              host_id in left and j.eval1(f"netRef.stateAgeMs('{host_id}')") == -1,
              f"nodeLeft={left}")


def scenario_handshake(host, joiner, name, code, password):
    """Joining starts with a handshake (#323). The host hosts with password;
    joiner tries a wrong one, then speaks another wire version - both are
    refused with a named reason and never become a node on the host - and
    then gets in, with the host knowing its client token."""
    def refused_as(reason, error_start):
        ok = wait_for(lambda: joiner.eval1("refusedReason") == reason, 15)
        err = joiner.eval1("lastError") or ""
        return (ok and err.startswith(error_start) and joiner.eval1("status") == 3
                and joiner.eval1("connected") is not True), err

    host.eval(["resetLogs()"])
    nodes_before = host.eval1("nodeList.length")

    joiner.eval(["roomPassword = 'not-" + password + "'", f"joinNet('{code}')"])
    ok, err = refused_as("wrong-password", "Wrong password")
    check(f"handshake: {name} with a wrong password is refused", ok,
          f"refusedReason={joiner.eval1('refusedReason')!r} lastError={err!r} "
          f"status={joiner.eval1('status')}")

    version = joiner.eval1("netRef.wireVersion")
    joiner.eval([f"roomPassword = '{password}'", f"netRef._setWireVersion({version + 1})",
                 f"joinNet('{code}')"])
    ok, err = refused_as("incompatible-version", "Incompatible version")
    check(f"handshake: {name} with another wire version gets \"incompatible version\"",
          ok, f"refusedReason={joiner.eval1('refusedReason')!r} lastError={err!r}")
    joiner.eval([f"netRef._setWireVersion({version})"])

    # Long enough for a refused joiner to have shown up if it were taken
    time.sleep(1.0)
    joined = json.loads(host.eval1("JSON.stringify(joinedLog)") or "[]")
    check(f"handshake: the host never took the refused {name}",
          not joined and host.eval1("nodeList.length") == nodes_before,
          f"nodeJoined={joined} nodes {nodes_before} -> {host.eval1('nodeList.length')}")

    joiner.eval([f"joinNet('{code}')"])
    ok = wait_for(lambda: joiner.eval1("connected") is True, 25)
    check(f"handshake: {name} joins with the right password and wire version", ok,
          f"status={joiner.eval1('status')} lastError={joiner.eval1('lastError')!r}")
    if ok:
        check_client_token(host, joiner, name)
        timing = json.loads(joiner.eval1("JSON.stringify(netRef.phaseTiming)") or "{}")
        check(f"handshake: {name} reports how long the handshake took",
              isinstance(timing.get("handshake"), (int, float)) and timing["handshake"] >= 0
              and timing.get("total", -1) >= timing["handshake"], str(timing))
    return ok


def check_client_token(host, joiner, name):
    """The host knows the joiner's client token by its node id (#323)."""
    node = joiner.eval1("netRef.nodeId")
    token = joiner.eval1("netRef.clientToken")
    seen = wait_for(lambda: json.loads(host.eval1("JSON.stringify(netRef.clientTokens)")
                                       or "{}").get(node) == token, 5)
    tokens = json.loads(host.eval1("JSON.stringify(netRef.clientTokens)") or "{}")
    return check(f"handshake: the host sees {name}'s client token", seen and bool(token),
                 f"{name} is {node} with token {token!r}, host has {tokens}")
