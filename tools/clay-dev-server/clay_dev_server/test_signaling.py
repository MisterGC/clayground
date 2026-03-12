#!/usr/bin/env python3
"""Test script for the PeerJS signaling relay in clay-dev-server.

Connects two fake peers via WebSocket and verifies the signaling
protocol: OPEN, HEARTBEAT, message routing (OFFER/ANSWER/CANDIDATE),
and error handling.

Usage:
    python3 test_signaling.py [host] [port]

Defaults to localhost:8090. Requires clay-dev-server to be running.
"""

import json
import socket
import ssl
import sys
import hashlib
import base64
import os
import time

from wsproto import WSConnection, ConnectionType
from wsproto.events import (
    Request, AcceptConnection, Message, BytesMessage,
    Ping, Pong, CloseConnection
)

# Defaults
HOST = "localhost"
PORT = 8090
TIMEOUT = 5  # seconds


class PeerJSClient:
    """Minimal PeerJS signaling client using wsproto."""

    def __init__(self, host, port, peer_id, token=None):
        self.host = host
        self.port = port
        self.peer_id = peer_id
        self.token = token or base64.b16encode(os.urandom(4)).decode().lower()
        self.sock = None
        self.ws = None

    def connect(self):
        """Establish WebSocket connection to the signaling relay."""
        raw = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        raw.settimeout(TIMEOUT)

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        self.sock = ctx.wrap_socket(raw, server_hostname=self.host)
        self.sock.connect((self.host, self.port))

        self.ws = WSConnection(ConnectionType.CLIENT)

        path = f"/peerjs?key=peerjs&id={self.peer_id}&token={self.token}"
        data = self.ws.send(Request(host=self.host, target=path))
        self.sock.sendall(data)

        # Read until we get the AcceptConnection event
        while True:
            raw_data = self.sock.recv(4096)
            if not raw_data:
                raise ConnectionError("Server closed connection during handshake")
            self.ws.receive_data(raw_data)
            for event in self.ws.events():
                if isinstance(event, AcceptConnection):
                    return
                if isinstance(event, CloseConnection):
                    raise ConnectionError(f"Server rejected: {event.reason}")

    def send_json(self, obj):
        """Send a JSON message over WebSocket."""
        data = self.ws.send(Message(data=json.dumps(obj)))
        self.sock.sendall(data)

    def recv_json(self, timeout=TIMEOUT):
        """Receive a JSON message from WebSocket. Returns parsed dict."""
        self.sock.settimeout(timeout)
        buf = b""
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("No message received within timeout")
            self.sock.settimeout(remaining)
            try:
                chunk = self.sock.recv(4096)
            except socket.timeout:
                raise TimeoutError("No message received within timeout")
            if not chunk:
                raise ConnectionError("Connection closed")
            buf += chunk
            self.ws.receive_data(chunk)
            for event in self.ws.events():
                if isinstance(event, (Message, BytesMessage)):
                    text = event.data if isinstance(event.data, str) else event.data.decode()
                    return json.loads(text)
                if isinstance(event, Ping):
                    pong = self.ws.send(Pong())
                    self.sock.sendall(pong)
                if isinstance(event, CloseConnection):
                    raise ConnectionError("Server closed connection")

    def recv_all(self, timeout=0.5):
        """Drain all pending messages within a short timeout."""
        messages = []
        try:
            while True:
                messages.append(self.recv_json(timeout=timeout))
        except (TimeoutError, socket.timeout):
            pass
        return messages

    def close(self):
        """Close the WebSocket connection."""
        if self.sock and self.ws:
            try:
                data = self.ws.send(CloseConnection(code=1000, reason="done"))
                self.sock.sendall(data)
            except Exception:
                pass
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass


# --- Test helpers ---

passed = 0
failed = 0


def test(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        msg = f"  FAIL  {name}"
        if detail:
            msg += f"  ({detail})"
        print(msg)


def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


# --- Tests ---

def test_connect_and_open(host, port):
    """Test 1: Connect and receive OPEN message."""
    section("1. Connect + OPEN")

    peer = PeerJSClient(host, port, "TEST_PEER_1")
    try:
        peer.connect()
        test("WebSocket handshake", True)
    except Exception as e:
        test("WebSocket handshake", False, str(e))
        return None

    try:
        msg = peer.recv_json()
        test("Received message after connect", msg is not None)
        test("Message type is OPEN", msg.get("type") == "OPEN", f"got: {msg}")
    except Exception as e:
        test("Receive OPEN", False, str(e))

    peer.close()
    return True


def test_heartbeat(host, port):
    """Test 2: HEARTBEAT echo."""
    section("2. HEARTBEAT")

    peer = PeerJSClient(host, port, "TEST_HB")
    try:
        peer.connect()
        peer.recv_json()  # consume OPEN

        peer.send_json({"type": "HEARTBEAT"})
        msg = peer.recv_json()
        test("HEARTBEAT echoed", msg.get("type") == "HEARTBEAT", f"got: {msg}")
    except Exception as e:
        test("HEARTBEAT", False, str(e))
    finally:
        peer.close()


def test_message_routing(host, port):
    """Test 3: Two peers, route OFFER from peer1 to peer2."""
    section("3. Message routing (OFFER)")

    peer1 = PeerJSClient(host, port, "TEST_SRC")
    peer2 = PeerJSClient(host, port, "TEST_DST")
    try:
        peer1.connect()
        peer1.recv_json()  # OPEN

        peer2.connect()
        peer2.recv_json()  # OPEN

        test("Both peers connected", True)

        # peer1 sends OFFER to peer2
        offer = {
            "type": "OFFER",
            "dst": "TEST_DST",
            "payload": {
                "sdp": {"type": "offer", "sdp": "v=0\r\nfake-sdp"},
                "type": "data",
                "connectionId": "TEST_SRC_TEST_DST",
                "label": "TEST_SRC_TEST_DST",
                "reliable": True,
                "serialization": "json",
                "browser": "test-script"
            }
        }
        peer1.send_json(offer)

        msg = peer2.recv_json()
        test("Peer2 received OFFER", msg.get("type") == "OFFER", f"got type: {msg.get('type')}")
        test("OFFER has src field", msg.get("src") == "TEST_SRC", f"got src: {msg.get('src')}")
        test("OFFER payload intact",
             msg.get("payload", {}).get("sdp", {}).get("sdp") == "v=0\r\nfake-sdp",
             f"got payload: {json.dumps(msg.get('payload', {}))[:200]}")

        # peer1 should NOT have received anything
        leftover = peer1.recv_all(timeout=0.3)
        test("Sender got no echo", len(leftover) == 0, f"got {len(leftover)} messages")

    except Exception as e:
        test("Message routing", False, str(e))
    finally:
        peer1.close()
        peer2.close()


def test_answer_and_candidate(host, port):
    """Test 4: ANSWER and CANDIDATE routing."""
    section("4. ANSWER + CANDIDATE routing")

    peer1 = PeerJSClient(host, port, "TEST_A")
    peer2 = PeerJSClient(host, port, "TEST_B")
    try:
        peer1.connect()
        peer1.recv_json()
        peer2.connect()
        peer2.recv_json()

        # ANSWER from peer2 to peer1
        answer = {
            "type": "ANSWER",
            "dst": "TEST_A",
            "payload": {
                "sdp": {"type": "answer", "sdp": "v=0\r\nfake-answer-sdp"},
                "type": "data",
                "connectionId": "TEST_A_TEST_B",
                "browser": "test-script"
            }
        }
        peer2.send_json(answer)
        msg = peer1.recv_json()
        test("ANSWER routed to peer1", msg.get("type") == "ANSWER")
        test("ANSWER src is peer2", msg.get("src") == "TEST_B")

        # CANDIDATE from peer1 to peer2
        candidate = {
            "type": "CANDIDATE",
            "dst": "TEST_B",
            "payload": {
                "candidate": {
                    "candidate": "candidate:1 1 UDP 2122252543 192.168.0.1 12345 typ host",
                    "sdpMid": "0",
                    "sdpMLineIndex": 0
                },
                "type": "data",
                "connectionId": "TEST_A_TEST_B"
            }
        }
        peer1.send_json(candidate)
        msg = peer2.recv_json()
        test("CANDIDATE routed to peer2", msg.get("type") == "CANDIDATE")
        test("CANDIDATE src is peer1", msg.get("src") == "TEST_A")
        test("CANDIDATE payload intact",
             msg.get("payload", {}).get("candidate", {}).get("candidate", "").startswith("candidate:1"),
             f"got: {json.dumps(msg.get('payload', {}))[:200]}")

    except Exception as e:
        test("ANSWER/CANDIDATE", False, str(e))
    finally:
        peer1.close()
        peer2.close()


def test_unknown_peer(host, port):
    """Test 5: Message to non-existent peer returns ERROR."""
    section("5. Unknown peer -> ERROR")

    peer = PeerJSClient(host, port, "TEST_LONELY")
    try:
        peer.connect()
        peer.recv_json()  # OPEN

        peer.send_json({
            "type": "OFFER",
            "dst": "DOES_NOT_EXIST",
            "payload": {"sdp": {"type": "offer", "sdp": "fake"}}
        })

        msg = peer.recv_json()
        test("Received ERROR", msg.get("type") == "ERROR", f"got: {msg}")
        test("ERROR mentions peer",
             "DOES_NOT_EXIST" in msg.get("payload", {}).get("msg", ""),
             f"got: {msg.get('payload', {}).get('msg', '')}")
    except Exception as e:
        test("Unknown peer error", False, str(e))
    finally:
        peer.close()


def test_duplicate_peer_id(host, port):
    """Test 6: What happens when two peers register with the same ID."""
    section("6. Duplicate peer ID")

    peer1 = PeerJSClient(host, port, "TEST_DUP")
    peer2 = PeerJSClient(host, port, "TEST_DUP")
    try:
        peer1.connect()
        msg1 = peer1.recv_json()
        test("First peer gets OPEN", msg1.get("type") == "OPEN")

        peer2.connect()
        msg2 = peer2.recv_json()
        # Server might reject or overwrite - let's document behavior
        test("Second peer gets response", msg2 is not None, f"type: {msg2.get('type')}")
        if msg2.get("type") == "OPEN":
            print("         -> Server allows duplicate ID (overwrites)")
        elif msg2.get("type") == "ERROR":
            print("         -> Server rejects duplicate ID")
        else:
            print(f"         -> Unexpected: {msg2}")
    except Exception as e:
        test("Duplicate peer ID", False, str(e))
    finally:
        peer1.close()
        peer2.close()


def test_concurrent_peers(host, port):
    """Test 7: Multiple peers registered simultaneously."""
    section("7. Concurrent peers (simulating host + 3 clients)")

    peers = {}
    ids = ["HOST_PEER", "MOD_PEER", "BASTI_PEER", "DACROWD_PEER"]
    try:
        for pid in ids:
            p = PeerJSClient(host, port, pid)
            p.connect()
            msg = p.recv_json()
            test(f"{pid} connected + OPEN", msg.get("type") == "OPEN")
            peers[pid] = p

        # Each client sends OFFER to host
        for client_id in ids[1:]:
            peers[client_id].send_json({
                "type": "OFFER",
                "dst": "HOST_PEER",
                "payload": {
                    "sdp": {"type": "offer", "sdp": f"sdp-from-{client_id}"},
                    "connectionId": f"{client_id}_HOST_PEER"
                }
            })

        # Host should receive all 3 OFFERs
        received = []
        for _ in range(3):
            msg = peers["HOST_PEER"].recv_json()
            received.append(msg)

        sources = [m.get("src") for m in received]
        test("Host received 3 OFFERs", len(received) == 3, f"got {len(received)}")
        for client_id in ids[1:]:
            test(f"OFFER from {client_id} arrived",
                 client_id in sources,
                 f"sources: {sources}")

    except Exception as e:
        test("Concurrent peers", False, str(e))
    finally:
        for p in peers.values():
            p.close()


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else HOST
    port = int(sys.argv[2]) if len(sys.argv) > 2 else PORT

    print(f"Testing PeerJS signaling relay at wss://{host}:{port}/peerjs")
    print(f"Make sure clay-dev-server is running!")

    test_connect_and_open(host, port)
    test_heartbeat(host, port)
    test_message_routing(host, port)
    test_answer_and_candidate(host, port)
    test_unknown_peer(host, port)
    test_duplicate_peer_id(host, port)
    test_concurrent_peers(host, port)

    section("RESULTS")
    total = passed + failed
    print(f"  {passed}/{total} passed, {failed} failed")
    if failed:
        print("  Some tests FAILED - check output above")
    else:
        print("  All tests passed!")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
