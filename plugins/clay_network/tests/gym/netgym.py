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

The keyed scenario (#302) has four nodes stream 100 objects each, every
object under its own key, at 30 Hz, while jitter on the host's link makes
the datagrams of one frame overtake each other.

The thirty interpolators scenario (#305) has a joiner show 30 of the
host's keyed objects through one StateInterpolator each, while they stream
and after they stopped, and measures what that costs the joiner: the
updated() signals per second, the value objects made per frame, and the
process's CPU time against the same joiner with none.

The replicated objects scenario (#306) has the host run 30 enemies at
20 Hz - a position and a mood string each - and a joiner its avatar; a node
that joins late sees all of them as the others do, with the session
properties, and its own avatar passes to the host when it leaves.

The session clock scenario (#304) has the joiners join again behind
100+-20 ms each way and compares every node's session time against the
wall clock they share: instances on one machine have one wall clock, so
sessionTime - Date.now() is the same on every node whose session clock
agrees with the host's.
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


def scenario_keyed(nodes, host, keys=100, hz=30, window=5.0, jitter_ms=6):
    """Every node streams `keys` objects under their own keys at `hz` (#302).
    A frame's updates leave as a few batched datagrams; jitter on the
    host's link - which every relayed batch crosses twice - makes them
    overtake each other. Every receiver gets every key of every other
    node, none dropped behind another key, in batches of at most about
    1200 bytes. The jitter stays below a frame, so an update never
    overtakes the one for the same key before it either."""
    ids = {name: inst.eval1("netRef.nodeId") for name, inst in nodes}
    for _, inst in nodes:
        inst.eval(["resetKeyed()"])
    host.eval([f"netRef.linkConditions = ({{jitterMs: {jitter_ms}}})"])
    for _, inst in nodes:
        inst.eval([f"startKeyed({keys}, {hz})"])
    time.sleep(window)
    for _, inst in nodes:
        inst.eval(["stopKeyed()"])
    # syncStats is refreshed with each pong: wait for one after the last state
    time.sleep((PING_MS + 500) / 1000)
    host.eval(["netRef.linkConditions = ({})"])
    ticks = {name: inst.eval1("keyedTick") or 0 for name, inst in nodes}
    label = f"keyed {keys} keys at {hz} Hz on {len(nodes)} nodes, {jitter_ms} ms jitter"
    check(f"{label}: every node sent about {int(window * hz)} frames",
          all(t >= window * hz * 0.6 for t in ticks.values()), str(ticks))

    for rname, rinst in nodes:
        seen = json.loads(rinst.eval1("keyedReport()") or "{}")
        stats = json.loads(rinst.eval1("JSON.stringify(netRef.syncStats)") or "{}")
        for sname, _ in nodes:
            if sname == rname:
                continue
            sent = ticks[sname]
            got = seen.get(ids[sname], {})
            st = stats.get(ids[sname], {})
            kstats = st.get("keys", {})
            recv = sum(k.get("recv", 0) for k in kstats.values())
            dropped = sum(k.get("dropped", 0) for k in kstats.values())
            batches = st.get("batches", 0)
            per_batch = recv / batches if batches else 0
            check(f"{label}: {rname} gets every key of {sname}, none dropped",
                  got.get("keys") == keys and got.get("minN", 0) >= sent * 0.95
                  and got.get("back", 1) == 0 and dropped == 0,
                  f"keys={got.get('keys')} per key {got.get('minN')}..{got.get('maxN')} "
                  f"of {sent} sent, newest frame >= {got.get('minLast')}, "
                  f"older-after-newer={got.get('back')} dropped={dropped}")
            check(f"{label}: {rname} gets {sname}'s in batches of <= 1200 B",
                  batches > 0 and per_batch >= 20 and st.get("maxBatchBytes", 1e9) <= 1200,
                  f"{recv} states in {batches} datagrams ({fmt(per_batch)} per datagram), "
                  f"largest {st.get('maxBatchBytes')} B")
    for _, inst in nodes:
        inst.eval(["resetKeyed()"])


# How far apart two nodes' session times may be (#304)
SESSION_TOLERANCE_MS = 10.0


def clock_offsets(insts):
    """sessionTime - Date.now() per node, each read in one go on its node."""
    out = {}
    for name, inst in insts:
        r = json.loads(inst.eval1("clockReading()") or "{}")
        out[name] = (r.get("s", -1) - r.get("w", 0)) if r.get("s", -1) >= 0 else None
    return out


def scenario_session_clock(host, joiners, code, latency=80, jitter=40, readings=25):
    """The joiners leave, put their link behind latency + 0..jitter ms each
    way - 100+-20 ms - and join again (#304). Their session clocks sync to
    the host's through that link: every node's session time is within
    SESSION_TOLERANCE_MS of every other's. A message's sentAt is the
    sender's session time and its transit is the link's; the interpolator
    takes the offset of the host's stream from the network."""
    label = f"session clock, {latency + jitter // 2}+-{jitter // 2} ms each way"
    for _, j in joiners:
        j.eval(["netRef.leave()"])
    wait_for(lambda: host.eval1("nodeList.length") == 0, 10)
    for _, j in joiners:
        j.eval([f"netRef.linkConditions = ({{latencyMs: {latency}, jitterMs: {jitter}}})",
                f"joinNet('{code}')"])
    joined = wait_for(lambda: all(j.eval1("connected") is True for _, j in joiners)
                      and host.eval1("nodeList.length") == len(joiners), 30)
    synced = joined and wait_for(
        lambda: all(j.eval1("netRef.sessionTimeSynced") is True for _, j in joiners), 10)
    check(f"{label}: the joiners join again and their clocks sync", synced,
          f"connected={[j.eval1('connected') for _, j in joiners]} "
          f"synced={[j.eval1('netRef.sessionTimeSynced') for _, j in joiners]}")
    if not synced:
        for _, j in joiners:
            j.eval(["netRef.linkConditions = ({})"])
        return
    # The rest of the burst refines what synced
    time.sleep(2.5)

    nodes = [("host", host)] + list(joiners)
    worst = 0.0
    worst_at = {}
    spreads = []
    for _ in range(readings):
        offs = clock_offsets(nodes)
        vals = [v for v in offs.values() if v is not None]
        spread = max(vals) - min(vals) if len(vals) == len(nodes) else float("inf")
        spreads.append(spread)
        if spread >= worst:
            worst, worst_at = spread, offs
        time.sleep(0.2)
    host_off = worst_at.get("host") or 0
    check(f"{label}: Network.sessionTime differs by <= {SESSION_TOLERANCE_MS:g} ms "
          f"between instances", worst <= SESSION_TOLERANCE_MS,
          f"worst spread {fmt(worst, 2)} ms over {readings} readings "
          f"(mean {fmt(sum(spreads) / len(spreads), 2)} ms), joiners vs host then: "
          f"{ {n: fmt(v - host_off, 2) for n, v in worst_at.items() if n != 'host' and v is not None} }")

    # Reliable messages carry their send time on the session clock
    (bname, B), (cname, C) = joiners[0], joiners[1]
    host.eval(["sendProbes('clock', 5)"])
    C.eval(["sendProbes('clockRelayed', 5)"])
    wait_for(lambda: len(probes(B, "clock")) >= 5 and len(probes(B, "clockRelayed")) >= 5, 5)
    for probe, sender, hops in (("clock", "host", 1), ("clockRelayed", cname, 2)):
        msgs = probes(B, probe)
        same = [abs(m.get("sentAt", -1) - m.get("st", -2)) <= 1.0 for m in msgs]
        transit = [m.get("at", 0) - m.get("sentAt", 0) for m in msgs]
        check(f"{label}: messageReceived on {bname} gets the {sender}'s session time as sentAt",
              len(msgs) == 5 and all(same),
              f"sentAt - sender's sessionTime: "
              f"{[fmt(m.get('sentAt', -1) - m.get('st', 0), 2) for m in msgs]}")
        lo, hi = hops * latency - SESSION_TOLERANCE_MS, hops * (latency + jitter) + 25
        check(f"{label}: a message from the {sender} took {hops} conditioned "
              f"link{'s' if hops > 1 else ''} by the session clock",
              len(transit) == 5 and all(lo <= t <= hi for t in transit),
              f"sessionTime on arrival - sentAt: {[fmt(t) for t in transit]} ms, "
              f"expected {lo:g}..{hi:g}")

    # The offset of a sender's timeline is the network's, once per sender
    host_id = host.eval1("netRef.nodeId")
    B.eval([f"trackSender('{host_id}')"])
    time.sleep(3.5)
    # Read together. The interpolator took the network's estimate at its
    # last push, up to 50 ms ago; a slewing clock moves it by at most
    # 0.05 ms per ms meanwhile, 2.5 ms
    net_off, interp_off = json.loads(B.eval1(
        f"JSON.stringify([netRef.transitMs('{host_id}'), syncRef.clockOffsetMs])") or "[null, null]")
    check(f"{label}: {bname}'s transit estimate for the host is the conditioned delay",
          isinstance(net_off, (int, float)) and latency - SESSION_TOLERANCE_MS <= net_off
          <= latency + jitter, f"transitMs={fmt(net_off)}")
    check(f"{label}: the interpolator places the host's stream with the network's estimate",
          isinstance(interp_off, (int, float)) and isinstance(net_off, (int, float))
          and abs(interp_off - net_off) <= 2.5,
          f"clockOffsetMs={fmt(interp_off, 2)} transitMs={fmt(net_off, 2)}")
    check_tracking(B, f"{label}: on the session clock")
    # A handler without the network still gets a timeline it can place
    B.eval(["sharedClock = false", f"trackSender('{host_id}')"])
    time.sleep(3.5)
    check_tracking(B, f"{label}: on the wall clock, offset estimated by the interpolator")
    B.eval(["sharedClock = true"])

    for _, j in joiners:
        j.eval(["netRef.linkConditions = ({})"])


def cpu_seconds(pid):
    """User plus system CPU time a process has used so far, in seconds, or
    None where neither /proc nor ps can tell."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            fields = f.read().rsplit(")", 1)[1].split()
        return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
    except (OSError, IndexError, ValueError):
        pass
    try:
        out = subprocess.run(["ps", "-o", "time=", "-p", str(pid)],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        # [[dd-]hh:]mm:ss[.cc]
        days = 0
        if "-" in out:
            d, out = out.split("-", 1)
            days = int(d)
        secs = 0.0
        for part in out.split(":"):
            secs = secs * 60 + float(part)
        return days * 86400 + secs
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def measure(joiner, cpu, window):
    """The joiner's interpolator counts and CPU share over window seconds."""
    joiner.eval(["resetInterpCounts()"])
    c0 = cpu() if cpu else None
    t0 = time.time()
    time.sleep(window)
    r = json.loads(joiner.eval1("interpReport()") or "{}")
    c1 = cpu() if cpu else None
    took = time.time() - t0
    r["secs"] = took
    r["cpu"] = (c1 - c0) / took * 100 if c0 is not None and c1 is not None else None
    return r


def scenario_thirty_interpolators(host, joiner, cpu=None, n=30, hz=20, window=5.0):
    """The joiner shows n of the host's keyed objects, each through its own
    StateInterpolator on the network's clock (#305). Measured on the joiner
    over window seconds each: with no interpolator, while the objects
    stream at hz, and once they stopped - past the delay and the
    extrapolation, when there is nothing left to blend. cpu() returns the
    joiner process's CPU seconds; its share is in % of one core."""
    label = f"{n} interpolators"
    host_id = host.eval1("netRef.nodeId")
    joiner.eval(["interpCount = 0", "resetKeyed()"])
    host.eval(["resetKeyed()"])
    time.sleep(1.0)
    base = measure(joiner, cpu, window)

    joiner.eval([f"interpSender = '{host_id}'", f"interpCount = {n}"])
    host.eval([f"startKeyed({n}, {hz})"])
    time.sleep(1.5)
    live = measure(joiner, cpu, window)
    host.eval(["stopKeyed()"])
    # The default delay (120 ms) plus the extrapolation (200 ms) are over
    time.sleep(1.0)
    idle = measure(joiner, cpu, window)
    joiner.eval(["interpCount = 0", "interpSender = ''", "resetKeyed()"])
    host.eval(["resetKeyed()"])

    def per_sec(r, k):
        return r.get(k, 0) / r["secs"] if r.get("secs") else 0

    def frames(r):
        return per_sec(r, "updates") / n if n else 0

    print(f"MEASURE  {label}, {window:g} s each on the joiner: "
          f"cpu none={fmt(base['cpu'])}% streaming={fmt(live['cpu'])}% "
          f"stopped={fmt(idle['cpu'])}% of one core", flush=True)
    print(f"MEASURE  {label} streaming at {hz} Hz: {fmt(per_sec(live, 'pushes'))} pushes/s, "
          f"{fmt(per_sec(live, 'updates'))} updated()/s ({fmt(frames(live))} per interpolator), "
          f"{fmt(per_sec(live, 'fresh'))} new value objects/s", flush=True)
    print(f"MEASURE  {label} stopped: {fmt(per_sec(idle, 'updates'))} updated()/s, "
          f"{fmt(per_sec(idle, 'fresh'))} new value objects/s", flush=True)

    check(f"{label}: every one gets its object's states and blends them",
          live.get("n") == n and live.get("minUpdates", 0) >= window * 10
          and per_sec(live, "pushes") >= n * hz * 0.6,
          f"n={live.get('n')} pushes/s={fmt(per_sec(live, 'pushes'))} "
          f"fewest updates={live.get('minUpdates')}")
    check(f"{label}: no value object made per frame while they stream",
          live.get("updates", 0) > 0 and live.get("fresh", -1) == 0,
          f"{live.get('fresh')} new value objects in {live.get('updates')} updated()")
    check(f"{label}: nothing left to blend, no work per frame",
          idle.get("n") == n and idle.get("updates", -1) == 0,
          f"{idle.get('updates')} updated() in {fmt(idle.get('secs'))} s after the stream stopped")
    return base, live, idle


def objects_of(inst):
    return json.loads(inst.eval1("objectsReport()") or "{}")


def agree(a, b, keys=("type", "owner", "x", "mood", "spawnIndex", "token")):
    """The objects two reports show differently, by id."""
    oa, ob = a.get("objects", {}), b.get("objects", {})
    out = {}
    for oid in set(oa) | set(ob):
        da, db = oa.get(oid), ob.get(oid)
        if da is None or db is None:
            out[oid] = (da, db)
            continue
        diff = {k: (da.get(k), db.get(k)) for k in keys
                if (abs(da.get(k) - db.get(k)) > 1e-6
                    if isinstance(da.get(k), (int, float)) and isinstance(db.get(k), (int, float))
                    else da.get(k) != db.get(k))}
        if diff:
            out[oid] = diff
    return out


def scenario_objects(host, joiner, late, code, n=30, hz=20, window=3.0):
    """Replicated objects (#306). The host spawns n enemies and moves them
    at hz, each with a mood string, the joiner spawns its avatar; a node
    that joins late sees every one of them where the others show it, with
    owner and spawn props, and the session properties. The late node's own
    avatar passes to the host when it leaves; at the end every object is
    despawned and no node keeps a sequence entry for any of them."""
    (jname, J), (lname, L) = joiner, late
    label = f"objects, {n} host enemies at {hz} Hz"
    host_id = host.eval1("netRef.nodeId")
    host.eval([f"spawnEnemies({n})",
               "netRef.setSessionProperty('seed', 1234)",
               "netRef.setSessionProperty('level', 'crypt')",
               "objectsMoving = true"])
    J.eval(["spawnAvatar()", "objectsMoving = true"])
    shown = wait_for(lambda: len(objects_of(J).get("objects", {})) == n + 1
                     and len(objects_of(host).get("objects", {})) == n + 1, 10)
    check(f"{label}: host and {jname} show the enemies and the avatar", shown,
          f"host {len(objects_of(host).get('objects', {}))}, "
          f"{jname} {len(objects_of(J).get('objects', {}))} of {n + 1}")
    time.sleep(window)
    st = json.loads(J.eval1("JSON.stringify(netRef.syncStats)") or "{}").get(host_id, {})
    check(f"{label}: {jname} gets them in batches of <= 1200 B",
          st.get("batches", 0) > 0 and st.get("maxBatchBytes", 1e9) <= 1200,
          f"{st.get('batches')} datagrams, largest {st.get('maxBatchBytes')} B")
    host.eval(["objectsMoving = false"])
    J.eval(["objectsMoving = false"])
    # The settled states: interpolation delay, extrapolation, settleMs
    time.sleep(1.5)
    diff = agree(objects_of(host), objects_of(J))
    check(f"{label}: at rest, {jname} shows every position and mood the host does",
          shown and not diff, f"{len(diff)} differ: {dict(list(diff.items())[:3])}")

    L.eval([f"joinNet('{code}')"])
    joined = wait_for(lambda: L.eval1("connected") is True, 45)
    seen = joined and wait_for(lambda: len(objects_of(L).get("objects", {})) == n + 1, 15)
    time.sleep(0.5)
    rep_l = objects_of(L)
    diff = agree(objects_of(host), rep_l)
    check(f"{label}: {lname}, joining late, sees every object as the host does",
          seen and not diff,
          f"{len(rep_l.get('objects', {}))} of {n + 1}; {len(diff)} differ: "
          f"{dict(list(diff.items())[:3])}")
    session = rep_l.get("session", {})
    check(f"{label}: {lname} gets the session properties",
          session.get("seed") == 1234 and session.get("level") == "crypt", str(session))

    avatar = L.eval1("spawnAvatar()")
    on_host = wait_for(lambda: avatar in objects_of(host).get("objects", {}), 10)
    L.eval(["netRef.leave()"])
    passed = on_host and wait_for(
        lambda: all(objects_of(i).get("objects", {}).get(avatar, {}).get("owner") == host_id
                    for i in (host, J)), 10)
    check(f"{label}: {lname}'s avatar passes to the host when it leaves", passed,
          f"owner on host={objects_of(host).get('objects', {}).get(avatar, {}).get('owner')} "
          f"on {jname}={objects_of(J).get('objects', {}).get(avatar, {}).get('owner')}")
    check(f"{label}: {lname} shows nothing once out of the network",
          wait_for(lambda: not objects_of(L).get("objects"), 5),
          f"{len(objects_of(L).get('objects', {}))} left")

    J.eval(["despawnAll('gymAvatar')"])
    host.eval(["despawnAll('')"])
    cleared = wait_for(lambda: not objects_of(host).get("objects")
                       and not objects_of(J).get("objects"), 10)
    entries = {name: objects_of(i).get("seqEntries") for name, i in (("host", host), (jname, J))}
    check(f"{label}: all despawned, no node keeps a sequence entry for them",
          cleared and all(e == 0 for e in entries.values()), str(entries))
