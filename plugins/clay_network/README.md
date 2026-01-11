# Clay Network Plugin

The Clay Network plugin provides networking capabilities for Clayground applications, including P2P multiplayer for games and HTTP client functionality for web API integration.

## Getting Started

```qml
import Clayground.Network
```

## Core Components

### P2P Multiplayer

- **ClayMultiplayer** (WASM) - WebRTC-based P2P multiplayer using PeerJS for signaling. No dedicated server required.
- **ClayNetworkUser** (Desktop) - TCP/UDP-based local network P2P with automatic peer discovery.

### HTTP Client

- **ClayHttpClient** - Configurable HTTP client that generates API methods from endpoint definitions.
- **ClayWebAccess** - Low-level HTTP request handler supporting GET and POST with authentication.

## ClayMultiplayer (WebAssembly)

Browser-based P2P multiplayer using WebRTC Data Channels. One player hosts, others join via a simple room code.

### Quick Start

```qml
import Clayground.Network

ClayMultiplayer {
    id: network
    maxPlayers: 4
    topology: ClayMultiplayer.Star

    onRoomCreated: (code) => {
        // Share this code with friends
        console.log("Room code:", code)
    }

    onPlayerJoined: (playerId) => {
        console.log("Player joined:", playerId)
    }

    onMessageReceived: (from, data) => {
        // Handle chat, game events, etc.
        if (data.type === "chat")
            chatLog.append(data.text)
    }

    onStateReceived: (from, data) => {
        // Handle position updates, etc.
        entities[from].x = data.x
        entities[from].y = data.y
    }
}

// Host a game
Button {
    text: "Host Game"
    onClicked: network.createRoom()
}

// Join a game
Button {
    text: "Join"
    onClicked: network.joinRoom(roomCodeInput.text)
}
```

### Network Topologies

| Topology | Description | Best For |
|----------|-------------|----------|
| **Star** | All players connect to host only. Host relays messages. | Competitive games, authoritative server logic |
| **Mesh** | All players connect to each other directly. | Cooperative games, lower latency |

```qml
ClayMultiplayer {
    topology: ClayMultiplayer.Star  // or ClayMultiplayer.Mesh
}
```

### Message Types

| Method | Signal | Delivery | Use Case |
|--------|--------|----------|----------|
| `broadcast(data)` | `messageReceived` | Reliable, ordered | Chat, game events, important state |
| `broadcastState(data)` | `stateReceived` | Optimized for frequency | Entity positions, real-time stats |
| `sendTo(playerId, data)` | `messageReceived` | Reliable, ordered | Direct player messages |

### Multiplayer Game Example

```qml
Item {
    property var players: ({})

    ClayMultiplayer {
        id: network
        maxPlayers: 8

        onPlayerJoined: (playerId) => {
            players[playerId] = createPlayer(playerId)
        }

        onPlayerLeft: (playerId) => {
            if (players[playerId]) {
                players[playerId].destroy()
                delete players[playerId]
            }
        }

        onStateReceived: (from, data) => {
            if (players[from]) {
                players[from].x = data.x
                players[from].y = data.y
            }
        }
    }

    // Broadcast local player position
    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: {
            network.broadcastState({
                x: localPlayer.x,
                y: localPlayer.y
            })
        }
    }
}
```

## ClayNetworkUser (Desktop/Native)

Local network P2P using TCP/UDP with automatic peer discovery. Available on non-WASM platforms.

```qml
ClayNetworkUser {
    id: player
    name: "Player1"

    Component.onCompleted: joinGroup("game-room-1")

    onNewMessage: (from, message) => {
        console.log(nameForId(from) + " says: " + message)
    }

    onNewParticipant: (userId) => {
        sendDirectMessage(userId, "Welcome!")
    }
}
```

## ClayHttpClient

Declarative HTTP API client with auto-generated methods.

```qml
ClayHttpClient {
    id: api

    baseUrl: "https://api.example.com"
    endpoints: {
        "getUser": "GET users/{userId}",
        "createPost": "POST posts {postData}",
        "updateUser": "POST users/{userId} {userData}"
    }

    bearerToken: "your-api-token"

    onReply: (requestId, code, response) => {
        const data = JSON.parse(response)
        console.log("Success:", data)
    }

    onError: (requestId, code, error) => {
        console.error("API Error:", error)
    }

    Component.onCompleted: {
        api.getUser(123)
        api.createPost({ title: "Hello", content: "World" })
    }
}
```

### Authentication Options

```qml
// Direct token
bearerToken: "your-token-here"

// From environment variable
bearerToken: "env:API_TOKEN"

// From file
bearerToken: "file:///path/to/token.txt"
```

## Platform Support

| Platform | P2P Multiplayer | HTTP Client | Status |
|----------|-----------------|-------------|--------|
| WebAssembly (Browser) | ClayMultiplayer (WebRTC) | ClayHttpClient | **Supported** |
| Desktop (Linux, macOS, Windows) | ClayNetworkUser (TCP/UDP) | ClayHttpClient | **Supported** |
| Mobile (iOS, Android) | - | ClayHttpClient | Partial |

## Future Roadmap

### Desktop WebRTC Support (Planned)

Use libdatachannel to enable the same ClayMultiplayer API on desktop platforms, allowing cross-platform play between browser and native apps.

```
Browser Player <--WebRTC--> Desktop Player
```

### Unified API Across Platforms (Planned)

A single ClayMultiplayer API that automatically selects the best transport:

| Platform | Internet Play | LAN Play |
|----------|---------------|----------|
| WASM | WebRTC + PeerJS | WebRTC + PeerJS |
| Desktop | WebRTC + PeerJS | WebRTC + UDP discovery |
| Mobile | WebRTC + PeerJS | BLE / Wi-Fi Direct |

### Mobile Local Play (Planned)

Support for local multiplayer on mobile devices without internet:

- **Bluetooth Low Energy (BLE)** - Low power, works on iOS + Android
- **Wi-Fi Direct** - Higher bandwidth for real-time games
- **Nearby discovery** - Automatic room discovery for local games

```qml
ClayMultiplayer {
    // Future API extension
    function discoverNearby() { }
    signal nearbyRoomFound(string roomId, string hostName)
}
```

## Best Practices

1. **Message Format**: Use JSON objects for structured data exchange.

2. **State Updates**: Use `broadcastState()` for high-frequency updates (positions) and `broadcast()` for important events.

3. **Error Handling**: Always implement `onErrorOccurred` to handle connection issues.

4. **Topology Choice**: Use Star for games needing authoritative host logic, Mesh for cooperative games with direct player interaction.

5. **Room Codes**: Room codes are 6 alphanumeric characters, case-insensitive.

## Technical Details

### WASM Implementation

- **Signaling**: PeerJS public cloud server (free, no setup required)
- **Transport**: WebRTC Data Channels
- **Reliability**: Supports both reliable (TCP-like) and unreliable (UDP-like) modes

### Native Implementation

- **Discovery**: UDP broadcast on local network
- **Transport**: TCP for reliable messaging
- **Groups**: Logical grouping for targeted messaging
