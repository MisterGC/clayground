#!/usr/bin/env python3
"""
Development server for Clayground website with hot-reload support.

Serves from _site/ but overlays docs/ for rapid iteration on source files.
Changes to QML examples, JS, CSS in docs/ are immediately visible without rebuild.

Usage (run from docs/ directory):
    python3 scripts/serve_dev.py            # HTTPS (default, needed for WebDojo dynamic resource loading)
    python3 scripts/serve_dev.py --http     # Plain HTTP (localhost is a secure context; SharedArrayBuffer works)

Then open: https://localhost:8000/  (or http://localhost:8000/ with --http)
"""
import argparse
import datetime
import email.utils
import os
import signal
import socket
import ssl
import subprocess
import sys
import time
from pathlib import Path
from http.server import HTTPServer, ThreadingHTTPServer, SimpleHTTPRequestHandler

PORT = 8000
CERT_DIR = Path(__file__).parent.parent / '.dev-cert'
CERT_FILE = CERT_DIR / 'cert.pem'
KEY_FILE = CERT_DIR / 'key.pem'

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

def ensure_cert():
    """Generate a self-signed certificate if none exists."""
    if CERT_FILE.exists() and KEY_FILE.exists():
        return
    CERT_DIR.mkdir(parents=True, exist_ok=True)
    hostname = socket.gethostname()
    subprocess.run([
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', str(KEY_FILE), '-out', str(CERT_FILE),
        '-days', '365', '-nodes',
        '-subj', f'/CN={hostname}',
        '-addext', f'subjectAltName=DNS:{hostname},DNS:localhost,IP:127.0.0.1',
    ], check=True, capture_output=True)
    print(f"Generated self-signed cert for {hostname}")

# Directories to serve from (in priority order)
DOCS_DIR = Path(__file__).parent.parent
SITE_DIR = DOCS_DIR / '_site'

# Paths to serve from docs/ directly (for rapid iteration)
DEV_PATHS = [
    '/webdojo-examples/',
    '/assets/js/',
    '/assets/css/',
    '/vendor/',
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
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        self.send_header('Access-Control-Allow-Origin', '*')
        path = self.path.split('?')[0]
        if path.endswith(('.wasm', '.js')):
            # Cache but revalidate: 304 if unchanged, full fetch if rebuilt
            self.send_header('Cache-Control', 'no-cache')
        else:
            # Small files: always fresh
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Clayground docs dev server')
    parser.add_argument('--http', action='store_true',
                        help='Serve over plain HTTP (default is HTTPS with a self-signed cert). '
                             'HTTP is fine for pure-localhost WASM testing; HTTPS is needed '
                             'when other HTTPS origins (e.g. WebDojo dev server) fetch resources '
                             'from this server to avoid mixed-content blocks.')
    parser.add_argument('--port', type=int, default=PORT, help=f'Port (default: {PORT})')
    args = parser.parse_args()

    kill_existing_server()
    os.chdir(SITE_DIR)  # Change to _site for default behavior
    hostname = socket.gethostname()
    server = ThreadingHTTPServer(('', args.port), DevHandler)
    scheme = 'http'
    if not args.http:
        ensure_cert()
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        scheme = 'https'
    print(f"Development server at {scheme}://localhost:{args.port}/")
    print(f"  LAN: {scheme}://{hostname}:{args.port}/")
    print(f"  _site/: Built WASM and Jekyll output")
    print(f"  docs/:  Live overlay for {', '.join(DEV_PATHS)}")
    print("Press Ctrl+C to stop.")
    server.serve_forever()
