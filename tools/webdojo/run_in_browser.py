#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Run a local Clayground game in the browser on a locally built Web Runtime.

    python3 tools/webdojo/run_in_browser.py <game-dir> [--build] [--serve]

<game-dir> holds the game's Main.qml (a Window or an Item) and everything it
refers to. Nothing is copied or written there: one server answers with the
runtime (clayground.js/.wasm, qtloader.js, the app shell's index.html) from
the starter bundle of a WASM build, and with everything else from the game
directory - edit a QML file, reload, done. assets-manifest.json is the game's
own when it has one, otherwise generated like make-assets-manifest.py does
(assets/ plus every *.qsb), so compiled shaders load as they will when the
game is deployed.

Without --serve it loads the page in headless Chromium, runs the --do steps
and writes console.log plus screenshots to --out. Exit 0 = the QML loaded and
no error marker appeared (QML errors, missing modules, shader and WebGL
failures, uncaught page errors), 1 = errors, 2 = setup problem (no runtime,
no Playwright).

Steps (--do, repeatable, run in order after the QML loaded):
    wait:<ms>          wait
    key:<Key>          press a key (Playwright names: Enter, ArrowUp, d, ...)
    hold:<Key>:<ms>    hold a key down
    click:<x>:<y>      click at a position, fractions of the page size (0..1)
    shot:<name>        screenshot to <out>/<name>.png
    expect:<text>      wait (up to --timeout) for a console line containing text
Default: wait:4000 shot:loaded

Prerequisites (not installed by this script):
    - a WASM build of clayground: emsdk (the version Qt's wasm kit names in
      mkspecs/qconfig.pri, QT_EMCC_VERSION) and Qt's wasm_multithread kit,
      configured into --build-dir, see docs/getting-started/wasm-builds.md
    - for the headless run: pip install playwright && python -m playwright install chromium
"""
import argparse
import functools
import http.server
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
CLAYGROUND = os.path.normpath(os.path.join(HERE, "..", ".."))
APPSHELL = os.path.join(HERE, "appshell")
# Served from the starter bundle: the runtime and the page that boots it.
RUNTIME_FILES = {"clayground.js", "clayground.wasm", "qtloader.js", "index.html",
                 "coi-serviceworker.js", "RUNTIME-MANIFEST.json"}
ERROR_MARKERS = ("QML Error", "Failed to create QML object", "is not installed",
                 "[Qt Critical]", "[Qt Fatal]", "shader", "Shader", "GL_INVALID",
                 "WebGL:", "Failed to link", "graphics pipeline")


def load_manifest_module():
    spec = importlib.util.spec_from_file_location(
        "make_assets_manifest", os.path.join(APPSHELL, "make-assets-manifest.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_handler(runtime_dir, game_dir, manifest_bytes):
    class Handler(http.server.SimpleHTTPRequestHandler):
        """Runtime files from the starter bundle, the rest from the game, with
        the COOP/COEP headers the multithreaded runtime needs."""

        def translate_path(self, path):
            rel = path.split("?", 1)[0].split("#", 1)[0].lstrip("/")
            if rel == "":
                rel = "index.html"
            base = runtime_dir if rel in RUNTIME_FILES else game_dir
            return os.path.join(base, *rel.split("/"))

        def do_GET(self):
            if self.path.split("?", 1)[0] == "/assets-manifest.json" and manifest_bytes:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(manifest_bytes)))
                self.end_headers()
                self.wfile.write(manifest_bytes)
                return
            super().do_GET()

        def send_error(self, code, message=None, explain=None):
            print(f"[http] {code} {self.path}", flush=True)
            super().send_error(code, message, explain)

        def end_headers(self):
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def log_message(self, *args):
            pass
    return Handler


def stale_shaders(game_dir):
    """Shader sources without a .qsb, or older than it - baked by the dojo,
    clayrender or qsb; this script does not bake."""
    stale = []
    for dirpath, subdirs, names in os.walk(game_dir):
        subdirs[:] = [s for s in subdirs if not s.startswith(".")]
        for n in names:
            if n.endswith((".frag", ".vert")):
                src = os.path.join(dirpath, n)
                qsb = src + ".qsb"
                if not os.path.exists(qsb) or os.path.getmtime(qsb) < os.path.getmtime(src):
                    stale.append(os.path.relpath(src, game_dir))
    return stale


def build_runtime(build_dir, log_path):
    cmd = ["cmake", "--build", build_dir, "--target", "clayground_starter"]
    print(f"building runtime: {' '.join(cmd)} (log: {log_path})", flush=True)
    with open(log_path, "w") as log:
        rc = subprocess.call(cmd, stdout=log, stderr=subprocess.STDOUT)
    print(f"build exit={rc}")
    return rc


def run_headless(url, args):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("playwright missing: pip install playwright && python -m playwright install chromium")
        return 2

    os.makedirs(args.out, exist_ok=True)
    log_path = os.path.join(args.out, "console.log")
    log = open(log_path, "w")
    t0 = time.time()
    state = {"loaded": False, "errors": []}

    def record(kind, text):
        line = f"[{time.time() - t0:7.2f}s] [{kind}] {text}"
        log.write(line + "\n")
        log.flush()
        if "QML loaded successfully" in text:
            state["loaded"] = True
        if kind == "pageerror" or (kind != "info" and any(m in text for m in ERROR_MARKERS)):
            state["errors"].append(line)

    steps = args.do or ["wait:4000", "shot:loaded"]
    shots = []
    with sync_playwright() as p:
        # Headless Chromium has no GPU: WebGL2 runs on SwiftShader, which these
        # flags keep enabled instead of blocklisted.
        browser = p.chromium.launch(headless=not args.headed, args=[
            "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
            "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"])
        w, h = (int(v) for v in args.size.split("x"))
        page = browser.new_page(viewport={"width": w, "height": h})
        page.on("console", lambda m: record(m.type, m.text))
        page.on("pageerror", lambda e: record("pageerror", str(e)))
        page.goto(url)

        def wait_until(done, ms):
            while ms > 0 and not done():
                page.wait_for_timeout(250)
                ms -= 250
            return done()

        if not wait_until(lambda: state["loaded"] or state["errors"], args.timeout * 1000):
            record("info", f"QML did not load within {args.timeout}s")
        record("info", "WebGL2: " + page.evaluate("""() => {
            const gl = document.createElement('canvas').getContext('webgl2');
            if (!gl) return 'unavailable';
            const d = gl.getExtension('WEBGL_debug_renderer_info');
            return gl.getParameter(gl.VERSION) + ' | ' +
                   (d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : '?');
        }""") + f"; crossOriginIsolated={page.evaluate('window.crossOriginIsolated')}")

        if state["loaded"]:
            for step in steps:
                kind, _, rest = step.partition(":")
                if kind == "wait":
                    page.wait_for_timeout(int(rest))
                elif kind == "key":
                    page.keyboard.press(rest)
                elif kind == "hold":
                    key, _, ms = rest.rpartition(":")
                    page.keyboard.down(key)
                    page.wait_for_timeout(int(ms))
                    page.keyboard.up(key)
                elif kind == "click":
                    fx, _, fy = rest.partition(":")
                    page.mouse.click(float(fx) * w, float(fy) * h)
                elif kind == "shot":
                    path = os.path.join(args.out, f"{rest}.png")
                    page.screenshot(path=path)
                    shots.append(path)
                elif kind == "expect":
                    seen = []
                    page.on("console", lambda m: seen.append(rest in m.text))
                    if not wait_until(lambda: any(seen), args.timeout * 1000):
                        record("info", f"expect failed: no console line with '{rest}'")
                        state["errors"].append(f"expect: '{rest}' never printed")
                else:
                    print(f"unknown step '{step}'")
                    return 2
        else:
            path = os.path.join(args.out, "not-loaded.png")
            page.screenshot(path=path)
            shots.append(path)
        browser.close()
    log.close()

    print(f"console log: {log_path}")
    for s in shots:
        print(f"screenshot: {s}")
    print(f"qml loaded: {state['loaded']}")
    if state["errors"]:
        print(f"{len(state['errors'])} error line(s):")
        for e in state["errors"][:40]:
            print("  " + e)
        if len(state["errors"]) > 40:
            print(f"  ... {len(state['errors']) - 40} more in the log")
    return 0 if state["loaded"] and not state["errors"] else 1


def main():
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n\n", 1)[0],
        epilog="Steps and prerequisites: see the module docstring.")
    ap.add_argument("game_dir", help="directory with the game's Main.qml")
    ap.add_argument("--build-dir", default=os.path.join(CLAYGROUND, "build-wasm"),
                    help="WASM build of clayground (default: <clayground>/build-wasm)")
    ap.add_argument("--build", action="store_true",
                    help="rebuild the runtime first (incremental, target clayground_starter)")
    ap.add_argument("--entry", default="Main.qml", help="entry QML in game-dir")
    ap.add_argument("--serve", action="store_true",
                    help="serve for a browser of your own instead of the headless run")
    ap.add_argument("--port", type=int, default=0, help="port (--serve default: 8080)")
    ap.add_argument("--out", default="", help="output dir (default: <build-dir>/browser-run)")
    ap.add_argument("--do", action="append", default=[], metavar="STEP",
                    help="step after load, repeatable (see docstring)")
    ap.add_argument("--timeout", type=int, default=120, help="seconds to wait for the QML")
    ap.add_argument("--size", default="1280x800", help="viewport WxH")
    ap.add_argument("--headed", action="store_true", help="visible browser (debugging)")
    args = ap.parse_args()

    game_dir = os.path.abspath(args.game_dir)
    build_dir = os.path.abspath(args.build_dir)
    runtime_dir = os.path.join(build_dir, "clayground-starter")
    args.out = os.path.abspath(args.out or os.path.join(build_dir, "browser-run"))
    if not os.path.isfile(os.path.join(game_dir, args.entry)):
        print(f"no {args.entry} in {game_dir}")
        return 2
    if args.build:
        if shutil.which("cmake") is None:
            print("cmake not found")
            return 2
        rc = build_runtime(build_dir, os.path.join(build_dir, "browser-run-build.log"))
        if rc != 0:
            return rc
    if not os.path.isfile(os.path.join(runtime_dir, "clayground.wasm")):
        print(f"no runtime in {runtime_dir} - configure a WASM build there and run with --build")
        return 2

    for src in stale_shaders(game_dir):
        print(f"warning: {src} has no up-to-date .qsb - bake it with the dojo, clayrender "
              f"or qsb, or the browser loads the old one or none")

    manifest = b""
    if not os.path.isfile(os.path.join(game_dir, "assets-manifest.json")):
        files = load_manifest_module().collect(game_dir, ["assets"])
        manifest = json.dumps(files).encode()
        print(f"assets-manifest.json: generated, {len(files)} file(s) (assets/ and *.qsb)")

    runtime_index = os.path.join(runtime_dir, "index.html")
    if args.entry != "Main.qml":
        # The app shell loads ./Main.qml; point a private copy at the entry.
        patched = os.path.join(build_dir, "browser-run-index.html")
        with open(runtime_index) as f:
            html = f.read().replace("new URL('Main.qml'", f"new URL('{args.entry}'")
        with open(patched, "w") as f:
            f.write(html)
        runtime_dir_for_index = patched
    else:
        runtime_dir_for_index = runtime_index

    handler_cls = make_handler(runtime_dir, game_dir, manifest)

    class Handler(handler_cls):
        def translate_path(self, path):
            rel = path.split("?", 1)[0].lstrip("/")
            if rel in ("", "index.html"):
                return runtime_dir_for_index
            return super().translate_path(path)

    port = args.port or (8080 if args.serve else 0)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = f"http://127.0.0.1:{server.server_address[1]}/"
    if args.serve:
        print(f"serving {game_dir} on the runtime from {runtime_dir}")
        print(f"open {url} - edit, save, reload; Ctrl+C stops")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        return 0
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"serving {game_dir} at {url}")
    try:
        return run_headless(url, args)
    finally:
        server.shutdown()


if __name__ == "__main__":
    sys.exit(main())
