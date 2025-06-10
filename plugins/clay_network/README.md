# Clay Network Plugin

The Clay Network plugin provides networking capabilities for Clayground
applications, including peer-to-peer communication for multiplayer games and
HTTP client functionality for web API integration. It offers both local network
discovery and direct messaging capabilities, as well as a flexible HTTP client
with authentication support.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [ClayNetworkNode](#claynetworknode)
  - [ClayNetworkUser](#claynetworkuser)
  - [ClayHttpClient](#clayhttpclient)
  - [ClayWebAccess](#claywebaccess)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay Network plugin in your QML files:

```qml
import Clayground.Network
```

## Core Components

### ClayNetworkNode

Low-level networking component for peer-to-peer communication.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `userId` | string (readonly) | Unique identifier for this network node |
| `_appData` | string | Application-specific data shared with peers |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `sendDirectMessage(userId, message)` | userId: string, message: string | Send message to specific user |
| `broadcastMessage(message)` | message: string | Send message to all connected peers |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `newMessage(from, message)` | from: string, message: string | Received a message |
| `appDataUpdate(user, data)` | user: string, data: string | User's app data updated |
| `newParticipant(user)` | user: string | New user joined network |
| `participantLeft(user)` | user: string | User left network |

### ClayNetworkUser

Higher-level component built on ClayNetworkNode that adds group management functionality.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | string | User's display name |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `joinGroup(groupId)` | groupId: string | Join a communication group |
| `leaveGroup(groupId)` | groupId: string | Leave a communication group |
| `sendGroupMessage(groupId, message)` | groupId: string, message: string | Send message to all group members |
| `nameForId(userId)` | userId: string | Get display name for user ID |

### ClayHttpClient

Configurable HTTP client with automatic API method generation.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `baseUrl` | string | Base URL for all API requests |
| `endpoints` | var | Object defining API endpoints |
| `bearerToken` | string | Bearer token for authentication |
| `api` | var (readonly) | Generated API methods object |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `reply(requestId, returnCode, text)` | requestId: int, returnCode: int, text: string | Successful response |
| `error(requestId, returnCode, text)` | requestId: int, returnCode: int, text: string | Error response |

### ClayWebAccess

Low-level HTTP request handler used by ClayHttpClient.

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `get(url, auth)` | url: string, auth: string | int | Perform GET request |
| `post(url, json, auth)` | url: string, json: string, auth: string | int | Perform POST request |

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
