"""
QML development server with file watching and SSE live-reload.

Serves QML/JS files from a project directory and pushes reload events
to connected WebDojo clients via Server-Sent Events when files change.

Uses watchdog for native file system events (macOS FSEvents, Linux inotify)
with automatic fallback to polling if watchdog is not installed.

Usage:
    clay-dev-server <project_dir> [port]
    python -m clay_dev_server <project_dir> [port]
"""
import os
import json
import queue
import signal
import socket
import ssl
import subprocess
import sys
import threading
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from socketserver import ThreadingMixIn

DEFAULT_PORT = 8090
WATCH_EXTENSIONS = {'.qml', '.js', '.mjs'}
POLL_INTERVAL = 0.5  # seconds (fallback polling only)
DEBOUNCE_INTERVAL = 0.3  # seconds

try:
    import wsproto
    from wsproto import ConnectionType, WSConnection
    from wsproto.events import (
        AcceptConnection, BytesMessage, CloseConnection,
        Message, Ping, Pong, Request,
    )
    HAS_WSPROTO = True
except ImportError:
    HAS_WSPROTO = False

CERT_DIR = Path.home() / '.clay-dev-cert'
CERT_FILE = CERT_DIR / 'cert.pem'
KEY_FILE = CERT_DIR / 'key.pem'


def _local_hostname():
    """Get the mDNS .local hostname (macOS scutil), if available."""
    try:
        r = subprocess.run(
            ['scutil', '--get', 'LocalHostName'],
            capture_output=True, text=True
        )
        name = r.stdout.strip()
        if name:
            return f'{name}.local'
    except FileNotFoundError:
        pass
    return None


def ensure_cert():
    """Generate a self-signed certificate if none exists."""
    if CERT_FILE.exists() and KEY_FILE.exists():
        return
    CERT_DIR.mkdir(parents=True, exist_ok=True)
    hostname = socket.gethostname()
    san_entries = [f'DNS:{hostname}', 'DNS:localhost', 'IP:127.0.0.1']
    local_name = _local_hostname()
    if local_name:
        san_entries.insert(1, f'DNS:{local_name}')
    subprocess.run([
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', str(KEY_FILE), '-out', str(CERT_FILE),
        '-days', '365', '-nodes',
        '-subj', f'/CN={hostname}',
        '-addext', f'subjectAltName={",".join(san_entries)}',
    ], check=True, capture_output=True)
    print(f"Generated self-signed cert for {hostname}")

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    HAS_WATCHDOG = True
except ImportError:
    HAS_WATCHDOG = False

# ============================================================================
# SSE Client Registry
# ============================================================================

sse_clients = []
sse_clients_lock = threading.Lock()


def register_sse_client():
    q = queue.Queue()
    with sse_clients_lock:
        sse_clients.append(q)
    return q


def unregister_sse_client(q):
    with sse_clients_lock:
        try:
            sse_clients.remove(q)
        except ValueError:
            pass


def broadcast_sse_event(event_type, data):
    msg = f"event: {event_type}\ndata: {json.dumps(data)}\n\n"
    with sse_clients_lock:
        for q in sse_clients:
            q.put(msg)

# ============================================================================
# Debounced Broadcaster
# ============================================================================


class DebouncedBroadcaster:

    def __init__(self, interval=DEBOUNCE_INTERVAL):
        self.interval = interval
        self.lock = threading.Lock()
        self.pending = set()
        self.timer = None

    def add(self, files):
        with self.lock:
            self.pending.update(files)
            if self.timer:
                self.timer.cancel()
            self.timer = threading.Timer(self.interval, self._fire)
            self.timer.daemon = True
            self.timer.start()

    def _fire(self):
        with self.lock:
            if not self.pending:
                return
            files = sorted(self.pending)
            self.pending.clear()
            self.timer = None
        print(f"Changed: {', '.join(files)}")
        broadcast_sse_event('reload', {'files': files})

# ============================================================================
# PeerJS Signaling Relay
# ============================================================================

peerjs_peers = {}       # peer_id -> socket (raw file object)
peerjs_peers_lock = threading.Lock()


def _ws_send(sock, ws_conn, data):
    """Send a WebSocket text frame over a raw socket."""
    ws_conn.send(Message(data=data))
    try:
        sock.sendall(ws_conn.data_to_send())
    except (BrokenPipeError, ConnectionResetError, OSError):
        pass


def _ws_send_json(sock, ws_conn, obj):
    """Send a JSON-encoded WebSocket message."""
    _ws_send(sock, ws_conn, json.dumps(obj))


def handle_peerjs_ws(request_handler):
    """Handle a PeerJS signaling WebSocket connection.

    Runs in the request handler's thread (one per connection via ThreadingMixIn).
    Implements the PeerJS signaling protocol:
      - Register peer on connect (send OPEN)
      - Route OFFER/ANSWER/CANDIDATE/HEARTBEAT between peers
      - Clean up on disconnect
    """
    # Parse peer ID from query string: /peerjs?key=peerjs&id=PEER_ID&token=TOKEN
    from urllib.parse import urlparse, parse_qs
    parsed = urlparse(request_handler.path)
    params = parse_qs(parsed.query)
    peer_id = params.get('id', [None])[0]
    if not peer_id:
        request_handler.send_error(400, 'Missing id parameter')
        return

    # Perform WebSocket upgrade handshake
    sock = request_handler.request  # the raw SSL-wrapped socket
    ws = WSConnection(ConnectionType.SERVER)

    # Build raw HTTP request bytes from what BaseHTTPRequestHandler already parsed
    raw_path = request_handler.path
    raw_request_line = f'GET {raw_path} HTTP/1.1\r\n'
    raw_headers = ''
    for key, val in request_handler.headers.items():
        raw_headers += f'{key}: {val}\r\n'
    raw = (raw_request_line + raw_headers + '\r\n').encode()
    ws.receive_data(raw)

    # Process the Request event and accept
    for event in ws.events():
        if isinstance(event, Request):
            ws.send(AcceptConnection())
            sock.sendall(ws.data_to_send())
            break
    else:
        return

    # Register peer
    with peerjs_peers_lock:
        peerjs_peers[peer_id] = (sock, ws)

    # Send OPEN to confirm registration
    _ws_send_json(sock, ws, {'type': 'OPEN'})
    print(f"[peerjs] Peer registered: {peer_id}")

    try:
        while True:
            data = sock.recv(4096)
            if not data:
                break
            ws.receive_data(data)
            for event in ws.events():
                if isinstance(event, (Message, BytesMessage)):
                    text = event.data if isinstance(event.data, str) else event.data.decode()
                    _handle_peerjs_message(peer_id, sock, ws, text)
                elif isinstance(event, Ping):
                    ws.send(Pong())
                    sock.sendall(ws.data_to_send())
                elif isinstance(event, CloseConnection):
                    ws.send(CloseConnection(code=event.code, reason=event.reason))
                    try:
                        sock.sendall(ws.data_to_send())
                    except (BrokenPipeError, ConnectionResetError, OSError):
                        pass
                    return
    except (BrokenPipeError, ConnectionResetError, OSError):
        pass
    finally:
        with peerjs_peers_lock:
            if peer_id in peerjs_peers and peerjs_peers[peer_id][0] is sock:
                del peerjs_peers[peer_id]
        print(f"[peerjs] Peer disconnected: {peer_id}")


def _handle_peerjs_message(src_id, sock, ws, text):
    """Route a PeerJS signaling message to its destination peer."""
    try:
        msg = json.loads(text)
    except json.JSONDecodeError:
        return

    msg_type = msg.get('type', '')

    if msg_type == 'HEARTBEAT':
        _ws_send_json(sock, ws, {'type': 'HEARTBEAT'})
        return

    dst_id = msg.get('dst')
    if not dst_id:
        return

    # Add source ID (PeerJS protocol: server stamps src)
    msg['src'] = src_id

    with peerjs_peers_lock:
        target = peerjs_peers.get(dst_id)

    if target:
        dst_sock, dst_ws = target
        _ws_send_json(dst_sock, dst_ws, msg)
    else:
        # Target not found — send error back to sender
        _ws_send_json(sock, ws, {
            'type': 'ERROR',
            'payload': {'msg': f'Peer {dst_id} not found'}
        })


# ============================================================================
# HTTP Handler
# ============================================================================


class DevHandler(SimpleHTTPRequestHandler):

    def do_GET(self):
        if self.path.startswith('/peerjs') and HAS_WSPROTO:
            upgrade = self.headers.get('Upgrade', '').lower()
            if upgrade == 'websocket':
                handle_peerjs_ws(self)
                return
        if self.path == '/events' or self.path.startswith('/events?'):
            self.handle_sse()
        else:
            super().do_GET()

    def handle_sse(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'keep-alive')
        self.end_headers()

        client_queue = register_sse_client()
        try:
            while True:
                try:
                    msg = client_queue.get(timeout=15)
                    self.wfile.write(msg.encode())
                    self.wfile.flush()
                except queue.Empty:
                    # Send keepalive comment
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            unregister_sse_client(client_queue)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def guess_type(self, path):
        if path.endswith('.qml'):
            return 'text/plain'
        if path.endswith('.mjs'):
            return 'application/javascript'
        return super().guess_type(path)

    def log_message(self, format, *args):
        pass

# ============================================================================
# File Watcher — watchdog (preferred) or polling (fallback)
# ============================================================================


if HAS_WATCHDOG:

    class QmlEventHandler(FileSystemEventHandler):

        def __init__(self, root_dir, broadcaster):
            self.root = Path(root_dir)
            self.broadcaster = broadcaster

        def _is_watched(self, path):
            return Path(path).suffix in WATCH_EXTENSIONS

        def on_modified(self, event):
            if not event.is_directory and self._is_watched(event.src_path):
                rel = str(Path(event.src_path).relative_to(self.root))
                self.broadcaster.add([rel])

        def on_created(self, event):
            if not event.is_directory and self._is_watched(event.src_path):
                rel = str(Path(event.src_path).relative_to(self.root))
                self.broadcaster.add([rel])

        def on_deleted(self, event):
            if not event.is_directory and self._is_watched(event.src_path):
                rel = str(Path(event.src_path).relative_to(self.root))
                self.broadcaster.add([rel])


class PollingFileWatcher:

    def __init__(self, root_dir):
        self.root = Path(root_dir)
        self.mtimes = {}
        self._build_snapshot()

    def _build_snapshot(self):
        for path in self._scan_files():
            try:
                self.mtimes[path] = path.stat().st_mtime
            except OSError:
                pass

    def _scan_files(self):
        for ext in WATCH_EXTENSIONS:
            yield from self.root.rglob(f'*{ext}')

    def check(self):
        changed = []
        deleted = []
        current_paths = set()

        for path in self._scan_files():
            current_paths.add(path)
            try:
                mtime = path.stat().st_mtime
            except OSError:
                continue

            prev = self.mtimes.get(path)
            if prev is None or mtime > prev:
                self.mtimes[path] = mtime
                if prev is not None:
                    changed.append(str(path.relative_to(self.root)))

        for path in set(self.mtimes.keys()) - current_paths:
            del self.mtimes[path]
            deleted.append(str(path.relative_to(self.root)))

        return changed, deleted

# ============================================================================
# Threaded Server
# ============================================================================


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

# ============================================================================
# Main
# ============================================================================


def kill_existing_server(port):
    try:
        result = subprocess.run(
            ['lsof', '-ti', f':{port}'],
            capture_output=True, text=True
        )
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                if pid:
                    os.kill(int(pid), signal.SIGTERM)
            print(f"Killed existing server on port {port} (PID: {', '.join(pids)})")
    except Exception:
        pass


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <project_dir> [port]")
        sys.exit(1)

    project_dir = Path(sys.argv[1]).resolve()
    port = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_PORT

    if not project_dir.is_dir():
        print(f"Error: {project_dir} is not a directory")
        sys.exit(1)

    kill_existing_server(port)
    os.chdir(project_dir)

    server = ThreadedHTTPServer(('', port), DevHandler)
    ensure_cert()
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    hostname = socket.gethostname()
    print(f"QML dev server at https://localhost:{port}/")
    print(f"  LAN: https://{hostname}:{port}/")
    print(f"Watching: {project_dir}")
    print(f"SSE endpoint: https://localhost:{port}/events")
    if HAS_WSPROTO:
        print(f"PeerJS signaling: wss://localhost:{port}/peerjs")
        local_name = _local_hostname()
        if local_name:
            print(f"  LAN: wss://{local_name}:{port}/peerjs")
    else:
        print("PeerJS signaling: unavailable (install wsproto)")

    broadcaster = DebouncedBroadcaster()

    if HAS_WATCHDOG:
        print("File watching: watchdog (native events)")
        handler = QmlEventHandler(project_dir, broadcaster)
        observer = Observer()
        observer.schedule(handler, str(project_dir), recursive=True)
        observer.start()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nStopping.")
            observer.stop()
            observer.join()
            server.shutdown()
    else:
        print("File watching: polling (install watchdog for native events)")
        watcher = PollingFileWatcher(project_dir)
        try:
            while True:
                changed, deleted = watcher.check()
                all_files = changed + deleted
                if all_files:
                    broadcaster.add(all_files)
                time.sleep(POLL_INTERVAL)
        except KeyboardInterrupt:
            print("\nStopping.")
            server.shutdown()


if __name__ == '__main__':
    main()
