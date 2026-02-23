# Clay Network Plugin

P2P networking for Clayground applications using WebRTC. One node hosts, others join via a short code. No dedicated server required.

## Getting Started

```qml
import Clayground.Network

Network {
    id: network
    maxNodes: 4

    onNetworkCreated: (code) => console.log("Share this code:", code)
    onNodeJoined: (nodeId) => console.log("Joined:", nodeId)
    onMessageReceived: (from, data) => console.log(data)
    onErrorOccurred: (msg) => console.log("Error:", msg)
}

// Host
Button { text: "Host"; onClicked: network.host() }

// Join
Button { text: "Join"; onClicked: network.join(codeInput.text) }
```

## Network Component

### Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `topology` | enum | `Star` | `Star` (host relays) or `Mesh` (direct) |
| `signalingMode` | enum | `Cloud` | `Cloud` (PeerJS) or `Local` (LAN) |
| `maxNodes` | int | 8 | Max nodes (2-8) |
| `autoRelay` | bool | true | Host auto-relays in Star topology |
| `iceServers` | var | [] | Custom STUN/TURN servers |
| `verbose` | bool | false | Enable diagnostics and latency monitoring |
| `connectionTimeout` | int | 15000 | Connection timeout in ms (0 to disable) |

### Read-only State

| Property | Type | Description |
|----------|------|-------------|
| `networkId` | string | Network code (share with others to join) |
| `nodeId` | string | This node's unique ID |
| `isHost` | bool | True if this node is the host |
| `connected` | bool | True when connected |
| `status` | enum | `Disconnected`, `Connecting`, `Connected`, `Error` |
| `nodeCount` | int | Number of nodes in the network |
| `nodes` | list | List of node IDs |
| `connectionPhase` | string | Current phase: "signaling", "ice", "datachannel" |
| `phaseTiming` | var | `{ signaling, ice, datachannel, total }` in ms |
| `latency` | int | Best RTT across peers in ms (-1 if unknown) |
| `peerStats` | var | Per-peer stats (when verbose) |

### Signals

| Signal | Description |
|--------|-------------|
| `networkCreated(networkId)` | Host created network successfully |
| `nodeJoined(nodeId)` | A node joined the network |
| `nodeLeft(nodeId)` | A node left the network |
| `messageReceived(fromId, data)` | Reliable message received |
| `stateReceived(fromId, data)` | State update received |
| `errorOccurred(message)` | Connection error |
| `diagnosticMessage(phase, detail)` | Diagnostic info (when verbose) |
| `connectionTimedOut()` | Connection attempt timed out |

### Methods

| Method | Description |
|--------|-------------|
| `host()` | Create a network and become host |
| `join(networkId)` | Join using a network code |
| `leave()` | Disconnect from the network |
| `broadcast(data)` | Send reliable message to all nodes |
| `broadcastState(data)` | Send state update (high-frequency) |
| `sendTo(nodeId, data)` | Send to a specific node |

## ICE Server Configuration

By default, Clayground uses Google's public STUN servers. For connections across restrictive NATs (symmetric NAT, carrier-grade NAT), add TURN servers:

```qml
Network {
    iceServers: [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
        { urls: "turn:relay.example.com:3478", username: "user", credential: "pass" }
    ]
}
```

## Verbose Mode & Diagnostics

Enable `verbose: true` to get connection diagnostics and latency monitoring:

```qml
Network {
    verbose: true

    onDiagnosticMessage: (phase, detail) => {
        console.log("[" + phase + "] " + detail)
    }
}
```

This enables:
- **Phase tracking**: `connectionPhase` shows "signaling", "ice", or "datachannel"
- **Phase timing**: `phaseTiming` breaks down time spent in each phase
- **ICE candidate reporting**: Shows which candidate types were discovered (host/srflx/relay)
- **Latency monitoring**: `latency` updated every 2s via ping/pong
- **Per-peer stats**: `peerStats` with latency, message counts, byte counts

## How It Works

### Connection Flow

1. **Signaling** - Peers discover each other via a signaling server (PeerJS cloud or LAN embedded server). Signaling is only for discovery; after connection, all data flows P2P.

2. **ICE Negotiation** - Peers negotiate the best connection path using ICE (Interactive Connectivity Establishment). Three candidate types:
   - **host** - Direct LAN connection (fastest, same network)
   - **srflx** (server reflexive) - Via STUN, discovers public IP/port. Works through most home routers.
   - **relay** - Via TURN, relays traffic through a server. Works through restrictive NATs but adds latency.

3. **Data Channel** - Once ICE completes, a WebRTC data channel opens for reliable, encrypted communication.

### Why Connections Sometimes Fail

When both peers are behind restrictive NATs (symmetric NAT, carrier-grade NAT), STUN alone can't establish a direct connection. STUN only discovers public IP/port, but symmetric NATs assign different ports per destination. A TURN relay server solves this by acting as a middle point.

This also explains asymmetric connectivity: it can work in one direction but not the other, because one peer may have a permissive NAT while the other has a restrictive one.

### External Resources

- [WebRTC overview](https://webrtc.org/)
- [ICE, STUN, TURN explained (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols)
- [NAT traversal deep dive (Tailscale)](https://tailscale.com/blog/how-nat-traversal-works)
- [coturn TURN server](https://github.com/coturn/coturn) - self-hosted TURN
- [Open Relay Project](https://www.metered.ca/tools/openrelay/) - free TURN servers

## Network Topologies

| Topology | Description | Best For |
|----------|-------------|----------|
| **Star** | All nodes connect to host. Host relays messages. | Competitive games, authoritative logic |
| **Mesh** | All nodes connect to each other directly. | Cooperative games, lower latency |

## Message Types

| Method | Signal | Use Case |
|--------|--------|----------|
| `broadcast(data)` | `messageReceived` | Chat, game events, reliable state |
| `broadcastState(data)` | `stateReceived` | Entity positions, real-time updates |
| `sendTo(nodeId, data)` | `messageReceived` | Direct messages to specific node |

## Signaling Modes

| Mode | Transport | Cross-Platform | Requires Internet |
|------|-----------|----------------|-------------------|
| **Cloud** | PeerJS server | Yes (Browser + Desktop + Mobile) | Yes |
| **Local** | Embedded WS server | Desktop/Mobile only | No |

LAN codes are auto-detected: if a join code starts with 'L' and contains '-', it's treated as a LAN code.

## Platform Support

| Platform | P2P (Network) | HTTP Client |
|----------|---------------|-------------|
| Desktop (Linux, macOS, Windows) | WebRTC via libdatachannel | ClayHttpClient |
| WebAssembly (Browser) | WebRTC via PeerJS | ClayHttpClient |
| Mobile (iOS, Android) | WebRTC via libdatachannel | ClayHttpClient |

## ClayHttpClient

Declarative HTTP API client with auto-generated methods.

```qml
ClayHttpClient {
    id: api
    baseUrl: "https://api.example.com"
    endpoints: {
        "getUser": "GET users/{userId}",
        "createPost": "POST posts {postData}"
    }
    bearerToken: "your-api-token"

    onReply: (requestId, code, response) => console.log(JSON.parse(response))
    onError: (requestId, code, error) => console.error(error)

    Component.onCompleted: api.getUser(123)
}
```

### Authentication Options

```qml
bearerToken: "your-token-here"          // Direct token
bearerToken: "env:API_TOKEN"            // From environment variable
bearerToken: "file:///path/to/token.txt" // From file
```
