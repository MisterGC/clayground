#!/usr/bin/env python3
"""
Serve Clayground website locally with COOP/COEP headers for SharedArrayBuffer.

Usage (run from docs/_site directory):
    python3 ../serve_website.py

Then open: http://localhost:8000/clayground/
"""
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

class COOPCOEPHandler(SimpleHTTPRequestHandler):
    """HTTP handler that adds Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy headers."""

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

if __name__ == '__main__':
    port = 8000
    # Ensure we're in the right directory
    if not os.path.exists('clayground'):
        print("Warning: 'clayground' directory not found.")
        print("Run this script from docs/_site/ directory.")
        print()

    print(f"Serving at http://localhost:{port}/clayground/")
    print("Press Ctrl+C to stop.")
    HTTPServer(('localhost', port), COOPCOEPHandler).serve_forever()
