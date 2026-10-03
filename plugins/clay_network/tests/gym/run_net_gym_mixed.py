#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Net Gym across backends (#307) - a native node and a browser node in one
network, through clay-dev-server's PeerJS relay.

A native loader instance (driven like run_net_gym.py, through the
inspector protocol) and a headless Chrome page (driven like
run_net_gym_web.py, through web/Main.qml) run the gym sandbox. First the
native node hosts and the page joins, then the page hosts and the native
node joins. Each time the two must stay one node each to the other, with
both channels between them open - the reliable one and the lossy state
channel - state flowing both ways over the state channel, reliable
messages arriving in order, and the page's peerStats carrying every field
the native node's does.

Usage:
    python3 run_net_gym_mixed.py --loader <clayliveloader> <starter-dir>
        [--timeout 180] [--headed]

Requires: pip install playwright wsproto
"""

import argparse
import functools
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time

import netgym
from netgym import check, wait_for, probes, in_order, sync_of, peer_stats
from run_net_gym import Inspect
from run_net_gym_web import (Bridge, GymHandler, WebInstance, CHROME_ARGS, CONSOLE,
                             launch_browser, on_console, on_page_error)

HERE = os.path.dirname(os.path.abspath(__file__))
PASSWORD = "stone"


def pairing(H, J, label, page):
    """J joins H's network; the two keep one connection with both channels.
    page is whichever of the two is the browser."""
    for i in (H, J):
        i.eval(["netRef.leave()", f"roomPassword = '{PASSWORD}'"])
    time.sleep(1.0)
    H.eval(["hostUp()"])
    got_code = wait_for(lambda: H.eval1("netId") not in (None, "")
                        and H.eval1("connected") is True, 30)
    code = H.eval1("netId")
    if not check(f"{label}: the host has a network code", got_code and bool(code), str(code)):
        return
    J.eval([f"joinNet('{code}')"])
    if not check(f"{label}: the joiner gets in",
                 wait_for(lambda: J.eval1("connected") is True, 45),
                 f"status={J.eval1('status')} lastError={J.eval1('lastError')!r}"):
        return
    host_id = H.eval1("netRef.nodeId")
    joiner_id = J.eval1("netRef.nodeId")

    # Both state channels open, or as far as they get in the time
    def both_lossy():
        hs = peer_stats(H).get(joiner_id, {})
        js = peer_stats(J).get(host_id, {})
        return hs.get("stateChannel") == "unreliable" and js.get("stateChannel") == "unreliable"
    lossy = wait_for(both_lossy, 15)

    # The page's RTCDataChannel says what it is: unordered, no
    # retransmits - opened by the page, or by the native node and taken
    other = joiner_id if page is H else host_id
    line = f"State channel open with {other} - ordered: false, maxRetransmits: 0"
    def logged():
        page.page.wait_for_timeout(200)  # Playwright hands console events over only here
        return any(line in m for m in CONSOLE[page.role])
    check(f"{label}: the page's state channel is unordered and never retransmits",
          wait_for(logged, 10, 0.05),
          next((m for m in CONSOLE[page.role] if f"State channel open with {other}" in m),
               "no state channel opened"))

    # A second connection taken as a replacement of the first ends the
    # first one: give it time to show
    time.sleep(5.0)

    # Network.peerStats and syncStats change with the pongs, every 2 s, so
    # the window is long enough for a count that is two pongs short
    def snapshot(inst, peer):
        got = json.loads(inst.eval1("JSON.stringify({peers: netRef.peerStats, "
                                    "sync: netRef.syncStats})") or "{}")
        ps = got.get("peers", {})
        return ps, ps.get(peer, {}), got.get("sync", {}).get(peer, {})
    window = 8.0
    h0, j0 = snapshot(H, joiner_id), snapshot(J, host_id)
    time.sleep(window)
    h1, j1 = snapshot(H, joiner_id), snapshot(J, host_id)

    joined = json.loads(H.eval1("JSON.stringify(joinedLog)") or "[]")
    left = json.loads(H.eval1("JSON.stringify(leftLog)") or "[]")
    check(f"{label}: one node each to the other, nobody left",
          H.eval1("JSON.stringify(nodeList)") == json.dumps([joiner_id])
          and J.eval1("JSON.stringify(nodeList)") == json.dumps([host_id])
          and J.eval1("connected") is True and joined == [joiner_id] and not left,
          f"host nodes={H.eval1('JSON.stringify(nodeList)')} "
          f"joiner nodes={J.eval1('JSON.stringify(nodeList)')} joined={joined} left={left}")
    check(f"{label}: the host keeps one peer connection for the joiner",
          list(h1[0].keys()) == [joiner_id], f"host peerStats keys={list(h1[0].keys())}")
    check(f"{label}: both ends have the lossy state channel open",
          lossy and h1[1].get("stateChannel") == "unreliable"
          and j1[1].get("stateChannel") == "unreliable",
          f"host's={h1[1].get('stateChannel')} joiner's={j1[1].get('stateChannel')}")

    # 20 a second each way: 160 in the window, at worst two pongs short
    def delta(a, b, part, field):
        return b[part].get(field, 0) - a[part].get(field, 0)
    h_sent, j_sent = delta(h0, h1, 1, "stateSent"), delta(j0, j1, 1, "stateSent")
    h_recv, j_recv = delta(h0, h1, 2, "recv"), delta(j0, j1, 2, "recv")
    check(f"{label}: state goes both ways over the state channel",
          min(h_sent, j_sent, h_recv, j_recv) >= 80,
          f"in {window:.0f} s: host sent {h_sent} on it, joiner received {j_recv}; "
          f"joiner sent {j_sent}, host received {h_recv}")

    H.eval(["sendProbes('fromHost', 10)"])
    J.eval(["sendProbes('fromJoiner', 10)"])
    wait_for(lambda: len(probes(J, "fromHost")) >= 10 and len(probes(H, "fromJoiner")) >= 10, 10)
    to_j, to_h = probes(J, "fromHost"), probes(H, "fromJoiner")
    check(f"{label}: reliable messages arrive both ways, in order",
          in_order(to_j, 10) and in_order(to_h, 10),
          f"joiner got {[m.get('i') for m in to_j]}, host got {[m.get('i') for m in to_h]}")
    return h1[1], j1[1]


def run(native, page):
    native_side, browser_side = {}, {}
    got = pairing(native, page, "native host, browser joiner", page)
    if got:
        native_side, browser_side = got
    got = pairing(page, native, "browser host, native joiner", page)
    if got and not native_side:
        browser_side, native_side = got
    missing = sorted(set(native_side) - set(browser_side))
    check("peerStats: the browser's has every field the native one has",
          bool(native_side) and not missing,
          f"missing={missing} native={sorted(native_side)} browser={sorted(browser_side)}")
    for i in (native, page):
        i.eval(["netRef.leave()"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", required=True, help="path to clayliveloader")
    ap.add_argument("starter_dir", help="the Clayground Web Runtime starter bundle")
    ap.add_argument("--timeout", type=int, default=180,
                    help="seconds for the loader and the page to boot")
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()

    log_root = os.environ.get("CLAY_NET_GYM_LOG_ROOT") or None
    if log_root:
        os.makedirs(log_root, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="clay_net_gym_mixed_", dir=log_root)
    sandbox_dir = os.path.join(tmp, "gym")
    shutil.copytree(HERE, sandbox_dir,
                    ignore=shutil.ignore_patterns(".clay", "__pycache__", "*.py", "web"))
    serve = os.path.join(tmp, "site")
    shutil.copytree(args.starter_dir, serve)
    shutil.copy2(os.path.join(HERE, "Sandbox.qml"), serve)
    shutil.copy2(os.path.join(HERE, "web", "Main.qml"), serve)

    env = dict(os.environ)
    env.setdefault("QT_QPA_PLATFORM", "offscreen")
    loader = os.path.abspath(args.loader)

    ok = False
    procs = []
    server = None
    try:
        dev, signaling_url = netgym.start_dev_server(tmp, os.path.join(tmp, "dev-server.log"))
        if not check("cloud: clay-dev-server signaling is up", dev is not None, signaling_url):
            return 1
        procs.append(dev)

        logf = open(os.path.join(tmp, "native.log"), "w")
        procs.append(subprocess.Popen(
            [loader, "--sbx", os.path.join(sandbox_dir, "Sandbox.qml"), "--instance", "native"],
            cwd=os.path.dirname(loader), env=env, stdout=logf, stderr=subprocess.STDOUT))
        native = Inspect(sandbox_dir, "native")

        bridge = Bridge()
        handler = functools.partial(GymHandler, directory=serve, bridge=bridge)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_address[1]}"

        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser = launch_browser(p, headless=not args.headed, args=CHROME_ARGS)
            if browser is None:
                check("browser: Chromium available", False,
                      "try: python -m playwright install chromium")
                return 1
            page = browser.new_context().new_page()
            log = open(os.path.join(tmp, "page.console.log"), "w")
            page.on("console", functools.partial(on_console, "joiner", log))
            page.on("pageerror", functools.partial(on_page_error, "joiner", log))
            page.goto(f"{base}/joiner/index.html")
            web = WebInstance(bridge, "joiner", page)

            up = native.wait_phase("ready", args.timeout) and wait_for(web.ready, args.timeout, 0.5)
            if check("gym: the loader and the page loaded the gym", up,
                     f"loader phase={native.state().get('phase')} page polling={web.ready()}"):
                for i in (native, web):
                    i.eval([f"signalingUrl = '{signaling_url}'"])
                run(native, web)
            browser.close()
        ok = True
    except Exception as e:  # a harness failure is a failed run, said as such
        check("harness: ran to the end", False, repr(e))
    finally:
        if server:
            server.shutdown()
        for p in procs:
            try:
                p.terminate()
            except Exception:
                pass
        time.sleep(1)
        for p in procs:
            try:
                p.kill()
            except Exception:
                pass
        ok = netgym.summary() and ok
        if ok:
            shutil.rmtree(tmp, ignore_errors=True)
        else:
            print("Logs kept at:", tmp)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
