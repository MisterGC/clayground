#!/usr/bin/env python3
"""Smoke test for the Clayground Web Runtime starter bundle.

Serves the starter directory with COOP/COEP headers, loads it in headless
Chrome and asserts that the runtime boots (version banner) and Main.qml
loads without QML errors.

Usage:
    python3 wasm_smoke_test.py <starter-dir> [--screenshot out.png] [--timeout 180]

Requires: pip install playwright
Uses the system Chrome when available, otherwise a Playwright-managed
Chromium (python -m playwright install chromium).
"""
import argparse
import functools
import http.server
import sys
import threading

BOOT_MARKER = "Clayground Web Runtime"
QML_OK_MARKER = "QML loaded successfully"
ERROR_MARKERS = ("QML Error", "Failed to create QML object")


class IsolatedHandler(http.server.SimpleHTTPRequestHandler):
    """Static file server with the COOP/COEP headers multithreaded WASM needs."""

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


def launch_browser(p):
    for channel in ("chrome", None):
        try:
            if channel:
                return p.chromium.launch(channel=channel)
            return p.chromium.launch()
        except Exception as e:
            print(f"chromium launch (channel={channel}) failed: {e}")
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("starter_dir")
    ap.add_argument("--screenshot", default="")
    ap.add_argument("--timeout", type=int, default=180)
    args = ap.parse_args()

    handler = functools.partial(IsolatedHandler, directory=args.starter_dir)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{port}/"
    print(f"Serving {args.starter_dir} at {url}")

    from playwright.sync_api import sync_playwright

    booted = qml_loaded = False
    errors = []

    with sync_playwright() as p:
        browser = launch_browser(p)
        if browser is None:
            print("FAIL: no Chromium available (try: python -m playwright install chromium)")
            return 2

        page = browser.new_page()

        def on_console(msg):
            nonlocal booted, qml_loaded
            text = msg.text
            print(f"[console] {text}")
            if BOOT_MARKER in text:
                booted = True
            if QML_OK_MARKER in text:
                qml_loaded = True
            if any(marker in text for marker in ERROR_MARKERS):
                errors.append(text)

        page.on("console", on_console)
        page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
        page.goto(url)
        # Poll via a Playwright call so the sync event loop is pumped and console
        # events actually fire; a bare threading.Event.wait() would stall dispatch
        # and always burn the full timeout even when the app boots in seconds.
        waited = 0
        deadline_ms = args.timeout * 1000
        while waited < deadline_ms and not (qml_loaded or errors):
            page.wait_for_timeout(250)
            waited += 250
        page.wait_for_timeout(1500)  # let trailing errors and rendering arrive
        if args.screenshot:
            page.screenshot(path=args.screenshot)
            print(f"Screenshot written to {args.screenshot}")
        browser.close()
    server.shutdown()

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
    print("PASS: runtime booted and Main.qml loaded without errors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
