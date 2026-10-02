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
| `signalingUrl` | string | "" | Your own PeerJS-compatible server instead of the public one |
| `verifySignalingCertificate` | bool | true | Native: a `wss` server whose certificate does not verify is an error; `false` opts out |
| `verbose` | bool | false | Enable `diagnosticMessage` output (phases, ICE candidates) |
| `connectionTimeout` | int | 15000 | Connection timeout in ms (0 to disable) |
| `gracePeriod` | int | 5000 | A peer that leaves a ping unanswered this long (ms) counts as gone (0 to disable) - see [Leaving](#leaving) |
| `linkConditions` | var | {} | Simulated loss, latency, jitter, bandwidth cap, blackout and dropped signaling, for tests - see [Testing on a Bad Link](#testing-on-a-bad-link) |
| `password` | string | "" | Room password a host demands and a joiner gives; empty: none - see [Joining](#joining) |
| `appId` | string | "" | Names the app; a joiner of another app is refused |
| `clientToken` | string | random | What a joiner identifies itself with; the host keeps it in `clientTokens` |

### Read-only State

| Property | Type | Description |
|----------|------|-------------|
| `networkId` | string | Network code (share with others to join) |
| `nodeId` | string | This node's unique ID |
| `hostId` | string | The host's node ID, the same on every node |
| `isHost` | bool | True if this node is the host |
| `acceptingJoins` | bool | True on a host new nodes can reach; false while its Cloud signaling is lost |
| `clientTokens` | var | Host: each joiner's `clientToken`, by node ID |
| `wireVersion` | int | Version of the message format this build speaks |
| `connected` | bool | True when connected |
| `status` | enum | `Disconnected`, `Connecting`, `Connected`, `Error` |
| `nodeCount` | int | Number of nodes in the network |
| `nodes` | list | List of node IDs |
| `connectionPhase` | string | Current phase: "signaling", "ice", "handshake" |
| `phaseTiming` | var | `{ signaling, ice, datachannel, handshake, total }` in ms |
| `latency` | int | Best RTT across peers in ms (-1 if unknown) |
| `peerStats` | var | Per-peer transport stats (always on) |
| `syncStats` | var | Per-origin state-sync stats: seq, recv, dropped, ageMs (always on) |

### Signals

| Signal | Description |
|--------|-------------|
| `networkCreated(networkId)` | Host created network successfully |
| `nodeJoined(nodeId)` | A node joined the network |
| `nodeLeft(nodeId)` | A node left the network |
| `messageReceived(fromId, data)` | Reliable message received |
| `stateReceived(fromId, data, sentAt)` | State update received; `sentAt` is the sender's clock in ms (-1 if absent) |
| `errorOccurred(message)` | Connection error; also on a joiner whose host left or went silent |
| `joinRefused(reason, message)` | The host refused this joiner: `incompatible-version`, `incompatible-app`, `wrong-password`, `handshake-failed`, or `refused` (e.g. a full network) |
| `signalingLost()` | Cloud: the signaling connection dropped after it was up; peers stay, the node reconnects, a host takes no joiners meanwhile |
| `diagnosticMessage(phase, detail)` | Diagnostic info (when verbose) |
| `connectionTimedOut()` | Connection attempt timed out |

### Methods

| Method | Description |
|--------|-------------|
| `host()` | Create a network and become host |
| `join(networkId)` | Join using a network code |
| `leave()` | Say goodbye and disconnect from the network |
| `broadcast(data)` | Send reliable message to all nodes |
| `broadcastState(data)` | Send state update (high-frequency) |
| `sendTo(nodeId, data)` | Send to a specific node |

## Joining

Joining starts with a handshake over the data channel, the same natively and
in the browser, with Cloud and Local signaling. The joiner's first message
carries its wire version, `appId`, `password` and `clientToken`; the host
answers with a welcome or a refusal. Until it is welcomed a joiner is no
node: it is not in anybody's `nodes`, gets no `nodeJoined`, and nothing but
the handshake passes either way.

- **Another build.** Two builds whose `wireVersion` differs are refused with
  `incompatible-version`, and so is a build from before the handshake, on
  either side: a joiner that sends something else first or nothing for 5 s,
  a host that answers with anything but a welcome.
- **Another app.** A joiner whose `appId` is not the host's is refused with
  `incompatible-app`.
- **A room password.** A host with a `password` refuses every joiner that
  does not give the same one, with `wrong-password`. The data channel is
  encrypted, so the password never passes the signaling server: a code
  that leaks through a chat or a stream is not enough to get in.

A refused joiner gets `joinRefused(reason, message)`, then
`errorOccurred(message)`, and its `status` is `Error`; it can join again.
The host closes the connection after its refusal. A full host refuses with
`refused` and "Network full" - natively at signaling, before any data
channel, in the browser on the data channel; the joiner hears the same on
both. A host's answer that makes no sense - a welcome naming somebody else
than the host at the other end of the link - is `handshake-failed`.

The host keeps each joiner's `clientToken` in `clientTokens`, next to its
node ID. A node ID changes with every join; a token the app stores and sets
again does not, so a host can tell a joiner that comes back.

## Leaving

A node finds out that another one left in one of three ways, the same
natively and in the browser:

- **It says goodbye.** `leave()` tells every peer before it closes, so they
  report it in `nodeLeft` at once. When the host leaves, every joiner's
  network ends: `status` turns `Disconnected` and `errorOccurred("The host
  left the network")` follows the `nodeLeft` of every node it knew.
- **It goes silent.** Every node pings its peers every 2 s, and a peer it
  has not heard from for 0.5 s right away. A peer that leaves a ping
  unanswered, and sends nothing else either, for `gracePeriod` (5 s by
  default) is dropped - a crashed host, a closed laptop. A joiner notices
  such a host within `gracePeriod` plus about 0.75 s and ends as above,
  with "The host did not answer for 5000 ms". A peer that streams state
  is never quiet, so in a game the extra pings do not happen.
- **Its connection fails.** WebRTC reporting the connection failed or
  closed. A connection that is only `Disconnected` can recover and is not a
  leave: a link that comes back within `gracePeriod` loses nobody.

When a Cloud node's signaling connection drops, the network goes on over
the data channels: `signalingLost()` fires, and the node reconnects under
the same id, retrying after 1, 2 and then every 4 s - a server may still
hold the old id for a while and answer `ID-TAKEN`. Until a host is back,
`acceptingJoins` is false: nobody new can find it. A Local host is its own
signaling server and has none to lose.

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

`latency`, `peerStats` and `syncStats` are always maintained (one tiny
ping per peer every 2 s). Enable `verbose: true` for the connection
diagnostics on top:

```qml
Network {
    verbose: true

    onDiagnosticMessage: (phase, detail) => {
        console.log("[" + phase + "] " + detail)
    }
}
```

This adds:
- **Phase reporting**: `diagnosticMessage` announces "signaling", "ice" and "datachannel" as they happen
- **ICE candidate reporting**: Shows which candidate types were discovered (host/srflx/relay)

Always available, verbose or not: `connectionPhase`, `phaseTiming`, `latency`
(updated every 2 s via ping/pong), `peerStats` (latency, message and byte
counts, state channel) and `syncStats` (per-origin sequence, drops, age).

## Testing on a Bad Link

`linkConditions` puts one node behind a simulated bad link, on one machine,
on desktop, mobile and in the browser alike. Everything the node sends and
receives over its data channels is conditioned, each direction on its own:

```qml
network.linkConditions = { loss: 0.1, latencyMs: 80, jitterMs: 20 }
network.linkConditions = { bandwidthKbps: 256 }
network.linkConditions = { blackout: true }   // the link goes dark ...
network.linkConditions = {}                    // ... and comes back
```

| Key | Effect |
|-----|--------|
| `loss` | Share (0..1) of state updates that are lost. Reliable messages are never lost - they stand for a transport that retransmits, so they arrive late instead |
| `latencyMs` | Added to every packet, each way |
| `jitterMs` | A random 0..jitterMs on top; state updates may overtake each other, reliable messages keep their order |
| `bandwidthKbps` | Packets leave one after another at this rate (kbit/s), both channels in one queue |
| `blackout` | While true, state updates are lost and reliable messages are held; when it ends they arrive in order |
| `dropSignaling` | While true, `host()` and `join()` cannot reach the signaling server and fail with `errorOccurred`; a live Cloud signaling connection is cut as if the server dropped it. A Local host is its own signaling server and hosts regardless |

Changes take effect at once; packets already under way keep their schedule.
The native backend conditions in `link_conditioner.cpp`, the browser in
`link_conditioner.js` - the same rules, checked against the same cases by
`tests/tst_link_conditioner.cpp` and `tests/link_conditioner.test.js`.

The net gym (`tests/gym`) runs three nodes and checks state flow, sender
attribution and interpolation, then puts the host behind 10 % loss, 80±20 ms
latency and a blackout, cuts its link for less than the grace period, drops
its Cloud signaling, lets it leave and finally kills it - the process
natively, the page in the browser. It runs natively over
Local signaling (ctest `network_sync_gym`) and over Cloud signaling through
clay-dev-server's relay (`network_sync_gym_cloud`, registered when Python has
`wsproto`), and in the browser with two pages of the WASM runtime against the
same relay:

```bash
python3 plugins/clay_network/tests/gym/run_net_gym_web.py build/clayground-starter
```

## How It Works

### Connection Flow

1. **Signaling** - Peers discover each other via a signaling server (PeerJS cloud or LAN embedded server). Signaling is only for discovery; after connection, all data flows P2P.

2. **ICE Negotiation** - Peers negotiate the best connection path using ICE (Interactive Connectivity Establishment). Three candidate types:
   - **host** - Direct LAN connection (fastest, same network)
   - **srflx** (server reflexive) - Via STUN, discovers public IP/port. Works through most home routers.
   - **relay** - Via TURN, relays traffic through a server. Works through restrictive NATs but adds latency.

3. **Data Channel** - Once ICE completes, a WebRTC data channel opens for reliable, encrypted communication.

4. **Handshake** - The joiner says hello with its wire version, app, password and client token; the host takes it or refuses it (see [Joining](#joining)). Only now is the joiner a node.

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

| Method | Signal | Channel | Use Case |
|--------|--------|---------|----------|
| `broadcast(data)` | `messageReceived` | reliable, ordered | Chat, game events, level changes |
| `broadcastState(data)` | `stateReceived` | unordered, no retransmit, seq-guarded | Entity positions, real-time updates |
| `sendTo(nodeId, data)` | `messageReceived` | reliable, ordered | Direct messages to specific node |

State updates travel over a dedicated lossy data channel: lost packets are
never retransmitted and each update carries a per-sender sequence number, so
receivers drop stale data instead of applying it late. In Star topology the
host relays state between joiners and propagates the roster, so `nodes` and
`nodeJoined`/`nodeLeft` cover all participants on every node.

## Multiplayer Helpers

- **`StateInterpolator`** - snapshot-buffer interpolation for remote
  entities (render `delayMs` in the past, blend between states, bounded
  extrapolation). Feed it `push(data, sentAt)` with the timestamp from
  `stateReceived` so snapshots sit on the sender's timeline, and set
  `autoDelay: true` to let it size the delay from the observed jitter
  instead of guessing one. Use this instead of `Behavior` animations.
- **`NetworkMonitor`** - drop-in overlay showing per-node RTT, incoming
  state rate, state age and stale-drop counts (`network.syncStats` /
  `network.peerStats` / `network.stateAgeMs(id)` for programmatic access).

See the [Multiplayer Games guide](https://misterGC.github.io/clayground/docs/manual/multiplayer/)
for the full set of patterns (channel choice, tick rates, host authority,
shared seeds).

## Signaling Modes

| Mode | Transport | Cross-Platform | Requires Internet |
|------|-----------|----------------|-------------------|
| **Cloud** | PeerJS server | Yes (Browser + Desktop + Mobile) | No, when using clay-dev-server as local signaling relay |
| **Local** | Embedded WS server | Desktop/Mobile only | No |

The modes are `Network.SignalingMode.Cloud` and `Network.SignalingMode.Local`
in code.

`clay-dev-server` includes a built-in PeerJS signaling relay (`wss://<host>:<port>/peerjs`), so Cloud mode works entirely offline on a LAN. The PeerJS library is vendored locally (no CDN needed) and peer IDs are generated client-side (no cloud `/id` endpoint needed). This enables browser-based P2P networking without any internet dependency. Install the signaling extra with: `pip install clay_dev_server[signaling]`

A native node checks the signaling server's certificate, and clay-dev-server's
is self-signed: set `verifySignalingCertificate: false` on a desktop or mobile
`Network` that uses it. Do that only for a server you control - without the
check, anyone on the path to the server can swap the session descriptions,
and with them the keys the data channels are encrypted with. The browser
checks the certificate itself; on Windows the native check is not available
yet (libdatachannel skips it there).

While its signaling connection is up, a native node sends the PeerJS
`HEARTBEAT` every 5 s, so a host stays joinable past the server's idle
timeout. If the connection drops anyway, `signalingLost()` fires and the node
reconnects (see [Leaving](#leaving)).

LAN codes are auto-detected: if a join code starts with 'L' and contains '-', it's treated as a LAN code.
A LAN code is `L<ip>-<port>-<secret>`: the host's embedded signaling server
turns away any joiner whose first message does not carry the secret, so
knowing the host's address alone is not enough to drop into a session. The
secret travels in the code; a room `password` does not, see
[Joining](#joining). The
secret is 8 characters drawn from the system's random number generator. A code
that does not have exactly that shape fails with `Invalid LAN code` before
anything connects.

An id belongs to the first connection that registered it, until that
connection closes: the LAN signaling server and clay-dev-server's relay both
refuse a second one with `ID-TAKEN`, the way the PeerJS server does. Someone
who has the code therefore cannot register as `HOST`, or as a joiner, and
receive the offers meant for them.

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

Three schemes, each configured by its own properties:

```qml
// Bearer token -> "Authorization: Bearer <token>"
bearerToken: "your-token-here"

// HTTP basic -> "Authorization: Basic <base64(user:password)>"
basicAuthUser: "alice"
basicAuthPassword: "s3cret"

// API key -> a header of its own, "X-API-Key" unless renamed
apiKey: "abc123"
apiKeyHeader: "X-API-Key"
```

`bearerToken` takes precedence over `basicAuthUser`/`basicAuthPassword` — a
request carries one `Authorization` header. `apiKey` is independent and can
accompany either.

Every credential value can be given literally or read from somewhere else:

```qml
bearerToken: "your-token-here"           // Direct value
bearerToken: "env.API_TOKEN"             // From environment variable
bearerToken: "file:///path/to/token.txt" // From file (trimmed)
```
