# Clay Network Plugin

The Clay Network plugin provides networking capabilities for Clayground
applications, including peer-to-peer communication for multiplayer games and
HTTP client functionality for web API integration. It offers both local network
discovery and direct messaging capabilities, as well as a flexible HTTP client
with authentication support.

## Getting Started

To use the Clay Network plugin in your QML files:

```qml
import Clayground.Network
```

## Core Components

- **ClayNetworkNode** - Low-level P2P networking component for direct messaging and broadcast communication.
- **ClayNetworkUser** - Higher-level component extending ClayNetworkNode with user identity and group messaging.
- **ClayHttpClient** - Configurable HTTP client that generates API methods from endpoint definitions.
- **ClayWebAccess** - Low-level HTTP request handler supporting GET and POST with authentication.

## Usage Examples

### Peer-to-Peer Messaging

```qml
import Clayground.Network

ClayNetworkUser {
    id: player
    name: "Player1"
    
    Component.onCompleted: {
        // Join a game room
        joinGroup("game-room-1")
    }
    
    onNewMessage: (from, message) => {
        console.log(`${nameForId(from)} says: ${message}`)
    }
    
    onNewParticipant: (userId) => {
        console.log(`${nameForId(userId)} joined!`)
        sendDirectMessage(userId, "Welcome!")
    }
    
    // Send to everyone in the group
    function broadcastMove(x, y) {
        sendGroupMessage("game-room-1", JSON.stringify({
            type: "move",
            x: x,
            y: y
        }))
    }
}
```

### HTTP API Integration

```qml
ClayHttpClient {
    id: apiClient
    
    baseUrl: "https://api.example.com"
    endpoints: {
        "getUser": "GET users/{userId}",
        "updateUser": "POST users/{userId} {userData}",
        "listPosts": "GET posts",
        "createPost": "POST posts {postData}"
    }
    
    bearerToken: "your-api-token-here"
    
    onReply: (requestId, code, response) => {
        const data = JSON.parse(response)
        console.log("Success:", data)
    }
    
    onError: (requestId, code, error) => {
        console.error("API Error:", error)
    }
    
    Component.onCompleted: {
        // Methods are automatically generated
        api.getUser(123)
        api.createPost({
            title: "Hello World",
            content: "My first post"
        })
    }
}
```

### Multiplayer Game State

```qml
Item {
    property var players: ({})
    
    ClayNetworkUser {
        id: networkNode
        name: "Player" + Math.floor(Math.random() * 1000)
        
        Component.onCompleted: joinGroup("multiplayer-game")
        
        onNewMessage: (from, message) => {
            const data = JSON.parse(message)
            if (data.type === "position") {
                players[from].x = data.x
                players[from].y = data.y
            }
        }
        
        onNewParticipant: (userId) => {
            players[userId] = playerComponent.createObject(gameArea, {
                playerId: userId,
                playerName: nameForId(userId)
            })
        }
        
        onParticipantLeft: (userId) => {
            if (players[userId]) {
                players[userId].destroy()
                delete players[userId]
            }
        }
    }
    
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            networkNode.sendGroupMessage("multiplayer-game", JSON.stringify({
                type: "position",
                x: localPlayer.x,
                y: localPlayer.y
            }))
        }
    }
}
```

### Dynamic API Configuration

```qml
ClayHttpClient {
    id: configurable
    
    property string environment: "development"
    
    baseUrl: environment === "production" 
        ? "https://api.prod.example.com"
        : "https://api.dev.example.com"
    
    endpoints: ({
        weather: "GET weather/{city}",
        forecast: "GET forecast/{city}/{days}"
    })
    
    // Bearer token from file or environment variable
    bearerToken: "file:///path/to/token.txt"
    // or
    // bearerToken: "env:API_TOKEN"
    
    function getWeatherForecast(city) {
        api.weather(city)
        api.forecast(city, 7)
    }
}
```

## Best Practices

1. **Group Management**: Use groups to organize communication channels and reduce unnecessary messages.

2. **Message Format**: Use JSON for structured data exchange between peers.

3. **Error Handling**: Always implement error handlers for network operations.

4. **Authentication**: Store API tokens securely, preferably in files or environment variables.

5. **Network Discovery**: The peer-to-peer system uses automatic local network discovery - ensure your network allows UDP broadcast.

## Technical Implementation

The Clay Network plugin implements:

- **Peer Discovery**: Automatic discovery of peers on local network using UDP broadcast
- **TCP Communication**: Reliable message delivery between peers
- **Group System**: Logical grouping for targeted messaging
- **HTTP Client**: Flexible API client with automatic method generation
- **Authentication**: Support for Bearer token authentication
- **Request Management**: Tracking of pending requests with unique IDs

The peer-to-peer system automatically handles connection management, peer discovery, and message routing, making it easy to create multiplayer experiences on local networks.
