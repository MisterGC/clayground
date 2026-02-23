#!/usr/bin/env python3
"""
Development server for Clayground website with hot-reload support.

Serves from _site/ but overlays docs/ for rapid iteration on source files.
Changes to QML examples, JS, CSS in docs/ are immediately visible without rebuild.

Usage (run from docs/ directory):
    python3 scripts/serve_dev.py

Then open: http://localhost:8000/
"""
import datetime
import email.utils
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from http.server import HTTPServer, ThreadingHTTPServer, SimpleHTTPRequestHandler

PORT = 8000

def kill_existing_server():
    """Kill any existing server on our port."""
    try:
        result = subprocess.run(
            ['lsof', '-ti', f':{PORT}'],
            capture_output=True, text=True
        )
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                if pid:
                    os.kill(int(pid), signal.SIGTERM)
            print(f"Warning: Killed existing server (PID: {', '.join(pids)})")
            time.sleep(0.5)  # Wait for port to be released
    except Exception:
        pass  # No existing server or lsof not available

# Directories to serve from (in priority order)
DOCS_DIR = Path(__file__).parent.parent
SITE_DIR = DOCS_DIR / '_site'

# Paths to serve from docs/ directly (for rapid iteration)
DEV_PATHS = [
    '/webdojo-examples/',
    '/assets/js/',
    '/assets/css/',
    '/demo/',  # WASM builds are copied here
]

class DevHandler(SimpleHTTPRequestHandler):
    """HTTP handler that overlays docs/ on _site/ for development."""

    def send_head(self):
        """Add If-Modified-Since support for 304 responses."""
        path = self.translate_path(self.path)
        if os.path.isfile(path):
            ims_header = self.headers.get('If-Modified-Since')
            if ims_header:
                try:
                    ims_time = email.utils.parsedate_to_datetime(ims_header)
                    file_mtime = os.stat(path).st_mtime
                    file_dt = datetime.datetime.fromtimestamp(
                        file_mtime, tz=datetime.timezone.utc
                    ).replace(microsecond=0)
                    if file_dt <= ims_time:
                        self.send_response(304)
                        self.end_headers()
                        return None
                except (TypeError, ValueError, OSError):
                    pass
        return super().send_head()

    def translate_path(self, path):
        # Strip query string before processing
        if '?' in path:
            path = path.split('?')[0]

        # Check if this path should be served from docs/ for rapid dev
        for dev_path in DEV_PATHS:
            if path.startswith(dev_path):
                docs_file = DOCS_DIR / path.lstrip('/')
                if docs_file.exists():
                    return str(docs_file)

        # Default: serve from _site/
        site_file = SITE_DIR / path.lstrip('/')
        if site_file.exists():
            return str(site_file)

        # Fallback to docs/ for any other files
        docs_file = DOCS_DIR / path.lstrip('/')
        if docs_file.exists():
            return str(docs_file)

        return str(site_file)  # Return site path for 404

    def end_headers(self):
        # Add COOP/COEP headers for SharedArrayBuffer (required for WASM threading)
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        path = self.path.split('?')[0]
        if path.endswith(('.wasm', '.js')):
            # Cache but revalidate: 304 if unchanged, full fetch if rebuilt
            self.send_header('Cache-Control', 'no-cache')
        else:
            # Small files: always fresh
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

if __name__ == '__main__':
    kill_existing_server()
    os.chdir(SITE_DIR)  # Change to _site for default behavior
    print(f"Development server at http://localhost:{PORT}/")
    print(f"  _site/: Built WASM and Jekyll output")
    print(f"  docs/:  Live overlay for {', '.join(DEV_PATHS)}")
    print("Press Ctrl+C to stop.")
    ThreadingHTTPServer(('localhost', PORT), DevHandler).serve_forever()
