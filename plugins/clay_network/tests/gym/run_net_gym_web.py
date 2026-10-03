#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Net Gym in the browser (#301) - the WASM backend against Cloud signaling.

Headless Chrome pages run the Clayground Web Runtime from a starter
bundle with the gym loaded (web/Main.qml around Sandbox.qml): one hosts, one
joins, through clay-dev-server's PeerJS relay - the public PeerJS server is
too flaky for CI. The runner drives the pages over HTTP (web/Main.qml says
how) with the same expressions and the same link scenarios as the native
gym (netgym.py): state flow, interpolation on a clean link, 10 % loss,
latency with jitter, a blackout, an outage shorter than the grace period, a
signaling drop the host comes back from, the host leaving, and - hosting
again - the host page crashing (#299). The host demands a room password,
and the joiner is refused for a wrong one and for another wire version
before it gets in (#323). Two more pages join for a while so that four
nodes stream 100 keyed objects each at 30 Hz, and leave again (#302). The
joiner and joinB join again behind 100+-20 ms each way, and every page's
session time is compared with the others' (#304). The host runs 30
replicated enemies at 20 Hz and the joiner its avatar; joinB joins late and
sees them as the host does. joinC, out of the network, opens a PeerJS
connection of its own to the joiner, which closes it: in Star only the host
connects to a joiner (#306).

Usage:
    python3 run_net_gym_web.py <starter-dir> [--timeout 600] [--headed]

Requires: pip install playwright wsproto
"""

import argparse
import collections
import functools
import http.server
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import uuid

import netgym
from netgym import (check, wait_for, check_tracking, scenario_loss, scenario_latency,
                    scenario_blackout, scenario_host_leaves, scenario_short_outage,
                    scenario_signaling_drop, scenario_host_killed, scenario_handshake,
                    scenario_keyed, scenario_session_clock, scenario_objects)

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "..", "tools", "webdojo", "tests"))
from wasm_smoke_test import IsolatedHandler, launch_browser  # noqa: E402

ROLES = ("host", "joiner", "joinB", "joinC")

# WebRTC between two pages of one browser: host candidates must be real
# addresses (an mDNS name needs multicast, which a CI container may lack),
# and neither page may be throttled for not having the focus.
CHROME_ARGS = [
    "--disable-features=WebRtcHideLocalIpsWithMdns",
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
]


class Bridge:
    """Requests waiting for a page, and the answers that came back."""

    def __init__(self):
        self.lock = threading.Condition()
        self.pending = {r: collections.deque() for r in ROLES}
        self.replies = {}
        self.last_poll = {r: 0.0 for r in ROLES}


class GymHandler(IsolatedHandler):
    """Serves the bundle under /<role>/ and the bridge at /<role>/gym/*."""

    def __init__(self, *args, bridge=None, **kwargs):
        self.bridge = bridge
        super().__init__(*args, **kwargs)

    def split_role(self):
        parts = self.path.split("?", 1)[0].lstrip("/").split("/", 1)
        if len(parts) == 2 and parts[0] in ROLES:
            return parts[0], parts[1]
        return None, None

    def do_GET(self):
        role, rest = self.split_role()
        if role and rest == "gym/next":
            with self.bridge.lock:
                self.bridge.last_poll[role] = time.time()
                req = self.bridge.pending[role].popleft() if self.bridge.pending[role] else None
            if req is None:
                self.send_response(204)
                self.end_headers()
                return
            body = json.dumps(req).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if role:
            self.path = "/" + rest
        super().do_GET()

    def do_POST(self):
        role, rest = self.split_role()
        if not (role and rest == "gym/reply"):
            self.send_error(404)
            return
        n = int(self.headers.get("Content-Length", 0))
        reply = json.loads(self.rfile.read(n) or b"{}")
        with self.bridge.lock:
            self.bridge.replies[reply.get("id")] = reply.get("eval", {})
            self.bridge.lock.notify_all()
        self.send_response(204)
        self.end_headers()


class WebInstance:
    """A page, spoken to like the native gym's Inspect."""

    def __init__(self, bridge, role, page):
        self.bridge, self.role, self.page = bridge, role, page

    def ready(self):
        return time.time() - self.bridge.last_poll[self.role] < 2.0

    def eval(self, exprs, timeout=15.0):
        rid = str(uuid.uuid4())[:8]
        with self.bridge.lock:
            self.bridge.pending[self.role].append({"id": rid, "eval": list(exprs)})
            deadline = time.time() + timeout
            while rid not in self.bridge.replies:
                left = deadline - time.time()
                if left <= 0:
                    raise TimeoutError(f"{self.role}: no answer to {exprs}")
                self.bridge.lock.wait(left)
            return self.bridge.replies.pop(rid)

    def eval1(self, expr):
        return self.eval([expr]).get(expr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("starter_dir")
    ap.add_argument("--timeout", type=int, default=180,
                    help="seconds for both pages to boot and connect")
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix="clay_net_gym_web_")
    serve = os.path.join(tmp, "site")
    shutil.copytree(args.starter_dir, serve)
    shutil.copy2(os.path.join(HERE, "Sandbox.qml"), serve)
    shutil.copy2(os.path.join(HERE, "web", "Main.qml"), serve)

    ok = False
    server = dev = None
    try:
        dev, signaling_url = netgym.start_dev_server(tmp, os.path.join(tmp, "dev-server.log"))
        if not check("cloud: clay-dev-server signaling is up", dev is not None, signaling_url):
            return 1

        bridge = Bridge()
        handler = functools.partial(GymHandler, directory=serve, bridge=bridge)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_address[1]}"
        print(f"Serving {serve} at {base}/<role>/", flush=True)

        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser = launch_browser(p, headless=not args.headed, args=CHROME_ARGS)
            if browser is None:
                check("browser: Chromium available", False,
                      "try: python -m playwright install chromium")
                return 1
            inst = {}
            logs = {}
            for role in ROLES:
                page = browser.new_context().new_page()
                logs[role] = open(os.path.join(tmp, f"{role}.console.log"), "w")
                page.on("console", functools.partial(on_console, role, logs[role]))
                page.on("pageerror", functools.partial(on_page_error, role, logs[role]))
                page.goto(f"{base}/{role}/index.html")
                inst[role] = WebInstance(bridge, role, page)
            ok = run(inst["host"], inst["joiner"], inst["joinB"], inst["joinC"],
                     signaling_url, args.timeout)
            browser.close()
    except Exception as e:  # a harness failure is a failed run, said as such
        check("harness: ran to the end", False, repr(e))
    finally:
        if server:
            server.shutdown()
        if dev:
            dev.terminate()
        ok = netgym.summary() and ok
        if ok:
            shutil.rmtree(tmp, ignore_errors=True)
        else:
            print("Logs kept at:", tmp)
    return 0 if ok else 1


# Every page's console, by role, for checks on what a page logged
CONSOLE = collections.defaultdict(list)


def on_console(role, log, msg):
    CONSOLE[role].append(msg.text)
    log.write(msg.text + "\n")
    log.flush()
    if "GYM:" in msg.text or "QML Error" in msg.text or "rror" in msg.type:
        print(f"[{role}] {msg.text}", flush=True)


def on_page_error(role, log, err):
    log.write(f"pageerror: {err}\n")
    print(f"[{role}] pageerror: {err}", flush=True)


def run(H, J, B, C, signaling_url, timeout):
    up = wait_for(lambda: all(i.ready() for i in (H, J, B, C)), timeout, 0.5)
    if not check("gym: all four pages loaded the gym", up,
                 f"ready: {[i.role for i in (H, J, B, C) if i.ready()]}"):
        return False

    for i in (H, J, B, C):
        i.eval([f"signalingUrl = '{signaling_url}'"])
    H.eval(["roomPassword = 'stone'", "hostUp()"])
    got_code = wait_for(lambda: H.eval1("netId") not in (None, ""), 30)
    code = H.eval1("netId")
    if not check("host: network code assigned", got_code and bool(code), str(code)):
        return False
    if not scenario_handshake(H, J, "joiner", code, "stone"):
        return False

    host_id = H.eval1("netRef.nodeId")
    joiner_id = J.eval1("netRef.nodeId")
    check("roster: host sees the joiner",
          wait_for(lambda: joiner_id in (H.eval1("JSON.stringify(nodeList)") or ""), 10),
          str(H.eval1("JSON.stringify(nodeList)")))
    check("hostId: the joiner names the host",
          J.eval1("netRef.hostId") == host_id and J.eval1("nodeList[0]") == host_id,
          f"host nodeId={host_id} joiner hostId={J.eval1('netRef.hostId')}")

    time.sleep(2.0)
    flow = netgym.sync_of(J, host_id)
    check("state: flowing from host at ~20Hz",
          flow.get("recv", 0) >= 25 and flow.get("ageMs", 9999) < 500,
          f"recv={flow.get('recv')} age={flow.get('ageMs')}ms")

    # State flowing proves nothing about the channel: a fallback to one
    # that retransmits carries it too, only late (#363)
    def channels():
        return {"host": netgym.peer_stats(H).get(joiner_id, {}),
                "joiner": netgym.peer_stats(J).get(host_id, {})}
    lossy = wait_for(lambda: all(s.get("stateOrdered") is False
                                 and s.get("stateMaxRetransmits") == 0
                                 for s in channels().values()), 10)
    check("transport: the state channel is unordered and never retransmits", lossy,
          str({r: {k: s.get(k) for k in ("stateChannel", "stateOrdered", "stateMaxRetransmits")}
               for r, s in channels().items()}))

    J.eval([f"trackSender('{host_id}')"])
    time.sleep(1.0)
    check_tracking(J, "interp: clean link")

    keyed_four_nodes(H, J, B, C, code)

    # One session clock on every page (#304); joinB leaves again after it
    scenario_session_clock(H, [("joiner", J), ("joinB", B)], code)
    B.eval(["netRef.leave()"])
    check("session clock: joinB leaves, two nodes again",
          wait_for(lambda: H.eval1("nodeList.length") == 1
                   and J.eval1("connected") is True, 15),
          f"host nodes={H.eval1('nodeList.length')} joiner connected={J.eval1('connected')}")

    # Replicated objects, joinB joins late and leaves again (#306)
    scenario_objects(H, ("joiner", J), ("joinB", B), code)
    scenario_stray_connection(J, C, signaling_url)

    scenario_loss(H, J, host_id)
    scenario_latency(H, J, host_id)
    scenario_blackout(H, J, host_id)
    scenario_short_outage(H, [("joiner", J)])
    scenario_signaling_drop(H, J, code)
    scenario_host_leaves(H, [("joiner", J)], host_id)

    # The host hosts again and its page crashes: no goodbye, no closed
    # connection a script could still send - only silence (#299)
    H.eval(["hostUp()"])
    rehosted = wait_for(lambda: H.eval1("netId") not in (None, "")
                        and H.eval1("connected") is True, 30)
    code2 = H.eval1("netId")
    J.eval([f"joinNet('{code2}')"])
    rejoined = wait_for(lambda: J.eval1("connected") is True, 45)
    if check("host killed: the host hosts again and the joiner rejoins",
             rehosted and rejoined, str(code2)):
        scenario_host_killed(lambda: crash_page(H.page), J.eval1("netRef.hostId"),
                             [("joiner", J)], "page crashed")
    return True


def keyed_four_nodes(H, J, B, C, code):
    """joinB and joinC make four (maxNodes), every node streams keyed state,
    and the two leave again - the scenarios after this one count two."""
    for i in (B, C):
        i.eval(["roomPassword = 'stone'", f"joinNet('{code}')"])
    joined = wait_for(lambda: all(i.eval1("connected") is True for i in (B, C))
                      and all(i.eval1("nodeList.length") == 3 for i in (H, J, B, C)), 45)
    if check("keyed: joinB and joinC join, four nodes see each other", joined,
             f"nodes per node: {[i.eval1('nodeList.length') for i in (H, J, B, C)]}"):
        scenario_keyed([("host", H), ("joiner", J), ("joinB", B), ("joinC", C)], H)
    for i in (B, C):
        i.eval(["netRef.leave()"])
    check("keyed: joinB and joinC leave, two nodes again",
          wait_for(lambda: all(i.eval1("nodeList.length") == 1 for i in (H, J)), 15),
          f"nodes per node: {[i.eval1('nodeList.length') for i in (H, J)]}")


def scenario_stray_connection(J, C, signaling_url):
    """joinC, out of the network, opens a PeerJS connection of its own to
    the joiner - what a stranger could do with a node's id (#306). The
    joiner closes it: in Star only the host connects to a joiner, so
    nothing it trusts comes over a link without a handshake. Its message
    never arrives, and the joiner stays in the network."""
    joiner_id = J.eval1("netRef.nodeId")
    stray_id = "stray" + uuid.uuid4().hex[:10]
    C.page.evaluate("""([url, strayId, target]) => {
        const u = new URL(url);
        window.__stray = {opened: false, closed: false};
        const peer = new Peer(strayId, {host: u.hostname, path: u.pathname, key: 'peerjs',
            port: parseInt(u.port) || 443, secure: u.protocol === 'wss:',
            config: {iceServers: []}});
        window.__strayPeer = peer;
        peer.on('open', () => {
            const conn = peer.connect(target, {reliable: true, serialization: 'json'});
            conn.on('open', () => {
                window.__stray.opened = true;
                conn.send({t: 'm', d: {probe: 'stray'}});
            });
            conn.on('close', () => { window.__stray.closed = true; });
        });
    }""", [signaling_url, stray_id, joiner_id])
    # The sync Playwright API hands over console events only while it is
    # called, so the wait goes through the page instead of sleeping
    def logged():
        J.page.wait_for_timeout(200)
        return any("Closed an incoming connection from " + stray_id in line
                   for line in CONSOLE["joiner"])
    closed = wait_for(logged, 20, 0.05)
    time.sleep(2.0)
    stray = C.page.evaluate("() => window.__stray")
    msgs = J.eval1("msgsWithProbe('stray')")
    check("stray connection: the joiner closes an incoming connection that is not the host's",
          closed, f"joiner logged it: {closed}, stray side {stray}")
    check("stray connection: nothing it sends arrives, the joiner stays in the network",
          msgs == "[]" and J.eval1("connected") is True,
          f"stray messages on the joiner: {msgs}, connected={J.eval1('connected')}")
    C.page.evaluate("() => { if (window.__strayPeer) window.__strayPeer.destroy(); }")


def crash_page(page):
    """Crash the page's renderer, the browser's kill -9. The DevTools
    Page.crash never answers once the page is gone, so the crash comes from
    a navigation Chrome answers by crashing, which fails at once."""
    try:
        page.goto("chrome://crash", timeout=5000)
    except Exception:
        pass  # "page crashed" is the point


if __name__ == "__main__":
    sys.exit(main())
