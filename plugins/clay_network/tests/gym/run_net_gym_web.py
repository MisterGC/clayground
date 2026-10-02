#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Net Gym in the browser (#301) - the WASM backend against Cloud signaling.

Two headless Chrome pages run the Clayground Web Runtime from a starter
bundle with the gym loaded (web/Main.qml around Sandbox.qml): one hosts, one
joins, through clay-dev-server's PeerJS relay - the public PeerJS server is
too flaky for CI. The runner drives the pages over HTTP (web/Main.qml says
how) with the same expressions and the same link scenarios as the native
gym (netgym.py): state flow, interpolation on a clean link, 10 % loss,
latency with jitter, a blackout, an outage shorter than the grace period, a
signaling drop the host comes back from, the host leaving, and - hosting
again - the host page crashing (#299). The host demands a room password,
and the joiner is refused for a wrong one and for another wire version
before it gets in (#323).

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
                    scenario_signaling_drop, scenario_host_killed, scenario_handshake)

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "..", "tools", "webdojo", "tests"))
from wasm_smoke_test import IsolatedHandler, launch_browser  # noqa: E402

ROLES = ("host", "joiner")

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
            ok = run(inst["host"], inst["joiner"], signaling_url, args.timeout)
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


def on_console(role, log, msg):
    log.write(msg.text + "\n")
    log.flush()
    if "GYM:" in msg.text or "QML Error" in msg.text or "rror" in msg.type:
        print(f"[{role}] {msg.text}", flush=True)


def on_page_error(role, log, err):
    log.write(f"pageerror: {err}\n")
    print(f"[{role}] pageerror: {err}", flush=True)


def run(H, J, signaling_url, timeout):
    up = wait_for(lambda: H.ready() and J.ready(), timeout, 0.5)
    if not check("gym: both pages loaded the gym", up):
        return False

    for i in (H, J):
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

    J.eval([f"trackSender('{host_id}')"])
    time.sleep(1.0)
    check_tracking(J, "interp: clean link")

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
