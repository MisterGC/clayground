#!/usr/bin/env python3
"""Smoke test for the Clayground Web Runtime starter bundle.

Serves the starter directory with COOP/COEP headers, loads it in headless
Chrome and asserts that the runtime boots (version banner) and Main.qml
loads without QML errors.

--overlay swaps in a different page (its files are copied over a temp copy
of the starter bundle), and --expect adds a console marker the page must
print. Together they turn this into a regression harness for anything that
can only fail in the browser - see tests/pages/.

--audio-probe taps the page's Web Audio graph and measures how loud it
actually is, per phase: a page that prints "PHASE:<name>" opens a named
phase, and --require-audible names the phases that must carry sound.

Usage:
    python3 wasm_smoke_test.py <starter-dir> [--screenshot out.png] [--timeout 180]
                               [--overlay dir] [--expect "marker"] [--click]
                               [--audio-probe] [--require-audible p1,p2]

Requires: pip install playwright
Uses the system Chrome when available, otherwise a Playwright-managed
Chromium (python -m playwright install chromium).
"""
import argparse
import functools
import http.server
import shutil
import sys
import tempfile
import threading

BOOT_MARKER = "Clayground Web Runtime"
QML_OK_MARKER = "QML loaded successfully"
ERROR_MARKERS = ("QML Error", "Failed to create QML object")
MODULES_OK_MARKER = "SMOKE MODULES OK"
FS_OK_MARKER = "SMOKE FS OK"
# The app shell preloads asset files into the in-memory FS (/game/) so Qt can QFile-open
# them; loading a QML file from there proves the mechanism end to end.
FS_PROBE_JS = r"""
window.clayground.FS.mkdirTree('/game/probe');
window.clayground.FS.writeFile('/game/probe/Probe.qml',
    'import QtQuick\nItem { Component.onCompleted: console.log("%s") }');
window.clayground.loadQmlFromUrl('file:///game/probe/Probe.qml');
""" % FS_OK_MARKER
# QML modules a deployed game may import - each one is linked into the runtime binary and
# is missing at runtime (not at build time) if a link line or QmlModules.qml is forgotten.
REQUIRED_MODULES = (
    "QtQuick3D", "QtQuick3D.Helpers",
    "QtQuick3D.AssetUtils",   # RuntimeLoader: glTF/GLB from a URL
    "QtQuick.Timeline",       # balsam-exported skeletal animation clips
    "QtMultimedia", "QtQuick.Particles", "QtQuick.LocalStorage",
    "Clayground.Canvas3D", "Clayground.World", "Clayground.Behavior", "Clayground.Storage",
    # what the published labs and the dojo's Character3D entry import (#250)
    "Clayground.Character3D", "Clayground.Lab", "Clayground.Algorithm", "Clayground.Sound",
    "Clayground.Common",
)
MODULE_PROBE_QML = "\n".join(f"import {m}" for m in REQUIRED_MODULES) + f"""
import QtQuick
Item {{ Component.onCompleted: console.log("{MODULES_OK_MARKER}") }}
"""
# A page prints "PHASE:<name>" to open a phase; audio samples are booked on
# the phase that was open when they were taken.
PHASE_MARKER = "PHASE:"
# Peak RMS over a sampling window below this counts as silence. Digital
# silence measures exactly 0.0, a triggered effect at default volume two
# orders of magnitude above this - anything in between is not a real signal.
AUDIBLE_RMS = 0.002
# Inserts an AnalyserNode in front of every connection into the page's audio
# destination, whoever makes it (Qt's WASM audio sink, a media element's
# graph, ...), and exposes the loudest thing seen in the last window.
# fftSize 16384 is ~370 ms at 44.1 kHz, i.e. wider than the poll interval
# below, so nothing that made a sound can slip between two samples.
AUDIO_PROBE_JS = r"""
(() => {
  const analysers = [];
  const origConnect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...rest) {
    try {
      if (dest instanceof AudioDestinationNode && !(this instanceof AnalyserNode)) {
        const tap = dest.context.createAnalyser();
        tap.fftSize = 16384;
        analysers.push(tap);
        origConnect.call(this, tap);
        return origConnect.call(tap, dest, ...rest);
      }
    } catch (e) { /* fall through and connect untapped */ }
    return origConnect.call(this, dest, ...rest);
  };
  const buf = new Float32Array(16384);
  window.__clayAudioProbe = () => {
    let rms = 0;
    for (const a of analysers) {
      a.getFloatTimeDomainData(buf);
      let sum = 0;
      for (let i = 0; i < buf.length; i++) sum += buf[i] * buf[i];
      rms = Math.max(rms, Math.sqrt(sum / buf.length));
    }
    const ctx = analysers.length ? analysers[0].context : null;
    return {
      taps: analysers.length,
      rms: rms,
      state: ctx ? ctx.state : "none",
    };
  };
})();
"""


class IsolatedHandler(http.server.SimpleHTTPRequestHandler):
    """Static file server with the COOP/COEP headers multithreaded WASM needs."""

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


def launch_browser(p, headless=True):
    for channel in ("chrome", None):
        try:
            if channel:
                return p.chromium.launch(channel=channel, headless=headless)
            return p.chromium.launch(headless=headless)
        except Exception as e:
            print(f"chromium launch (channel={channel}) failed: {e}")
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("starter_dir")
    ap.add_argument("--screenshot", default="")
    ap.add_argument("--timeout", type=int, default=180)
    ap.add_argument("--overlay", default="",
                    help="directory copied over a temp copy of the starter bundle")
    ap.add_argument("--expect", default="",
                    help="console marker the page must print, on top of loading")
    ap.add_argument("--click", action="store_true",
                    help="click the page once after loading, so it has the user "
                         "activation browsers require before any audio plays")
    ap.add_argument("--audio-probe", action="store_true",
                    help="measure the page's audio output per PHASE marker")
    ap.add_argument("--require-audible", default="",
                    help="comma-separated phases that must carry sound "
                         "(implies --audio-probe)")
    ap.add_argument("--headed", action="store_true",
                    help="run a visible browser instead of headless - a local "
                         "debugging aid, headless has no real audio device")
    args = ap.parse_args()
    if args.require_audible:
        args.audio_probe = True

    serve_dir = args.starter_dir
    tmp_dir = ""
    if args.overlay:
        tmp_dir = tempfile.mkdtemp(prefix="wasm-smoke-")
        shutil.copytree(args.starter_dir, tmp_dir, dirs_exist_ok=True)
        shutil.copytree(args.overlay, tmp_dir, dirs_exist_ok=True)
        serve_dir = tmp_dir
        print(f"Overlaying {args.overlay}")

    try:
        return run(args, serve_dir)
    finally:
        if tmp_dir:
            shutil.rmtree(tmp_dir, ignore_errors=True)


def run(args, serve_dir):
    handler = functools.partial(IsolatedHandler, directory=serve_dir)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{port}/"
    print(f"Serving {serve_dir} at {url}")

    from playwright.sync_api import sync_playwright

    booted = qml_loaded = modules_ok = fs_ok = False
    # No --expect means nothing extra to wait for.
    marker_seen = not args.expect
    errors = []
    phase = "start"
    # phase name -> {"rms": loudest sample, "samples": n, "state": last
    # AudioContext state, "taps": tapped connections into the destination}
    audio = {}

    with sync_playwright() as p:
        browser = launch_browser(p, headless=not args.headed)
        if browser is None:
            print("FAIL: no Chromium available (try: python -m playwright install chromium)")
            return 2

        page = browser.new_page()
        if args.audio_probe:
            page.add_init_script(AUDIO_PROBE_JS)

        def sample_audio():
            try:
                s = page.evaluate("window.__clayAudioProbe && window.__clayAudioProbe()")
            except Exception as e:  # navigation or a closed page mid-poll
                print(f"[audio] sample failed: {e}")
                return
            if not s:
                return
            slot = audio.setdefault(phase, {"rms": 0.0, "samples": 0})
            slot["rms"] = max(slot["rms"], s["rms"])
            slot["samples"] += 1
            slot["state"] = s["state"]
            slot["taps"] = s["taps"]

        def on_console(msg):
            nonlocal booted, qml_loaded, marker_seen, modules_ok, fs_ok, phase
            text = msg.text
            print(f"[console] {text}")
            if PHASE_MARKER in text:
                phase = text.split(PHASE_MARKER, 1)[1].strip()
            if BOOT_MARKER in text:
                booted = True
            if QML_OK_MARKER in text:
                qml_loaded = True
            if args.expect and args.expect in text:
                marker_seen = True
            if MODULES_OK_MARKER in text:
                modules_ok = True
            if FS_OK_MARKER in text:
                fs_ok = True
            if any(marker in text for marker in ERROR_MARKERS):
                errors.append(text)

        page.on("console", on_console)
        page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
        page.goto(url)
        if args.click:
            # A media element's play() rejects without user activation, and Qt's
            # WASM backend does not catch that rejection - it would reach the
            # page as an error. One real click makes the activation sticky for
            # the rest of the document's life, which is what a player page needs
            # anyway. It lands before the QML has loaded; that is fine, the
            # activation is the document's, not an element's.
            page.mouse.click(10, 10)
        # Poll via a Playwright call so the sync event loop is pumped and console
        # events actually fire; a bare threading.Event.wait() would stall dispatch
        # and always burn the full timeout even when the app boots in seconds.
        waited = 0
        deadline_ms = args.timeout * 1000
        while waited < deadline_ms and not ((qml_loaded and marker_seen) or errors):
            page.wait_for_timeout(250)
            waited += 250
            if args.audio_probe:
                sample_audio()
        page.wait_for_timeout(1500)  # let trailing errors and rendering arrive
        if args.screenshot:
            page.screenshot(path=args.screenshot)
            print(f"Screenshot written to {args.screenshot}")
        if qml_loaded and not errors:
            # Second load: a QML snippet importing every module the runtime promises.
            # A missing module surfaces as "QML Error: ... module is not installed".
            page.evaluate("qml => window.clayground.loadQml(qml)", MODULE_PROBE_QML)
            waited = 0
            while waited < 30000 and not (modules_ok or errors):
                page.wait_for_timeout(250)
                waited += 250
        if modules_ok and not errors:
            # Third load: a QML file written into the preloaded-assets filesystem.
            page.evaluate(FS_PROBE_JS)
            waited = 0
            while waited < 30000 and not (fs_ok or errors):
                page.wait_for_timeout(250)
                waited += 250
        browser.close()
    server.shutdown()

    for name, slot in audio.items():
        print(f"[audio] phase={name} peakRms={slot['rms']:.4f} "
              f"samples={slot['samples']} taps={slot.get('taps', 0)} "
              f"ctx={slot.get('state', '?')}")

    if errors:
        print("FAIL: errors during startup:")
        for e in errors:
            print(f"  - {e}")
        return 1
    if not booted:
        print(f"FAIL: boot banner ('{BOOT_MARKER} ...') not seen")
        return 1
    if not qml_loaded:
        print("FAIL: Main.qml did not finish loading")
        return 1
    if not marker_seen:
        print(f"FAIL: page never printed {args.expect!r}")
        return 1
    for name in (n.strip() for n in args.require_audible.split(",") if n.strip()):
        slot = audio.get(name)
        if not slot or not slot["samples"]:
            print(f"FAIL: phase {name!r} never opened - nothing to listen to")
            return 1
        if slot["rms"] <= AUDIBLE_RMS:
            print(f"FAIL: phase {name!r} was silent "
                  f"(peak RMS {slot['rms']:.4f} <= {AUDIBLE_RMS})")
            return 1
    if not modules_ok:
        print("FAIL: module probe did not load - a module from REQUIRED_MODULES is missing")
        return 1
    if not fs_ok:
        print("FAIL: QML from the preloaded-assets filesystem (/game/) did not load")
        return 1
    print("PASS: runtime booted, Main.qml loaded, all required QML modules available, /game/ FS works")
    return 0


if __name__ == "__main__":
    sys.exit(main())
