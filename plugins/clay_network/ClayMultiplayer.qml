// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import Clayground.Network

/*!
    \qmltype ClayMultiplayer
    \inqmlmodule Clayground.Network
    \brief P2P multiplayer networking for browser-based games.

    ClayMultiplayer provides peer-to-peer multiplayer functionality using
    WebRTC Data Channels. One player hosts a game room, others join using
    a simple room code. No dedicated server infrastructure required.

    \section1 Network Topologies

    Two network topologies are supported:

    \list
    \li \b Star - All players connect to the host only. The host acts as
        the authoritative server, relaying messages between players.
        Best for competitive games requiring fair arbitration.
    \li \b Mesh - All players connect to each other directly. Lower latency
        for player-to-player communication. Best for cooperative games.
    \endlist

    \section1 Message Types

    Two message delivery modes are available:

    \list
    \li \b broadcast() / \b messageReceived - Reliable, ordered delivery.
        Use for chat, game events, important state changes.
    \li \b broadcastState() / \b stateReceived - Optimized for frequent updates.
        Use for entity positions, real-time stats.
    \endlist

    \section1 Example Usage

    \qml
    import Clayground.Network

    ClayMultiplayer {
        id: network
        maxPlayers: 4
        topology: ClayMultiplayer.Star

        onRoomCreated: (code) => {
            console.log("Share this code:", code)
        }

        onPlayerJoined: (playerId) => {
            console.log("Player joined:", playerId)
        }

        onMessageReceived: (from, data) => {
            if (data.type === "chat")
                chatLog.append(data.text)
        }

        onStateReceived: (from, data) => {
            // Update entity positions
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
        text: "Join Game"
        onClicked: network.joinRoom(roomCodeInput.text)
    }

    // Send chat message
    function sendChat(text) {
        network.broadcast({ type: "chat", text: text })
    }

    // Send position update
    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: network.broadcastState({ x: player.x, y: player.y })
    }
    \endqml

    \section1 Platform Support

    \table
    \header
        \li Platform
        \li Status
        \li Transport
    \row
        \li WebAssembly (Browser)
        \li Supported
        \li WebRTC via PeerJS
    \row
        \li Desktop (Linux, macOS, Windows)
        \li Planned
        \li libdatachannel / TCP fallback
    \row
        \li Mobile (iOS, Android)
        \li Planned
        \li WebRTC + BLE for local play
    \endtable

    \sa ClayHttpClient
*/
Item {
    id: root

    /*!
        \qmlproperty enumeration ClayMultiplayer::topology
        \brief The network topology to use.

        \value ClayMultiplayer.Star Clients connect only to host (default).
               Host relays all messages. Best for authoritative game logic.
        \value ClayMultiplayer.Mesh All players connect to each other.
               Direct peer-to-peer messaging. Best for cooperative games.

        Must be set before calling createRoom() or joinRoom().
    */
    property int topology: ClayMultiplayer.Star

    /*!
        \qmlproperty int ClayMultiplayer::maxPlayers
        \brief Maximum number of players allowed in a room.

        Valid range: 2-8. Default: 8.
        Must be set before calling createRoom().
    */
    property int maxPlayers: 8

    /*!
        \qmlproperty string ClayMultiplayer::roomId
        \brief The current room code.

        Empty string if not connected to a room.
        For hosts, this is the code to share with other players.
    */
    readonly property string roomId: _backend.roomId

    /*!
        \qmlproperty string ClayMultiplayer::playerId
        \brief This player's unique identifier.

        For hosts, this equals roomId. For clients, this is a unique ID
        assigned when connecting.
    */
    readonly property string playerId: _backend.playerId

    /*!
        \qmlproperty bool ClayMultiplayer::isHost
        \brief True if this player is the room host.
    */
    readonly property bool isHost: _backend.isHost

    /*!
        \qmlproperty bool ClayMultiplayer::connected
        \brief True if connected to a room.
    */
    readonly property bool connected: _backend.connected

    /*!
        \qmlproperty int ClayMultiplayer::playerCount
        \brief Number of players currently in the room.
    */
    readonly property int playerCount: _backend.playerCount

    /*!
        \qmlproperty list<string> ClayMultiplayer::players
        \brief List of player IDs currently in the room.
    */
    readonly property var players: _backend.players

    /*!
        \qmlproperty enumeration ClayMultiplayer::status
        \brief Current connection status.

        \value ClayMultiplayer.Disconnected Not connected to any room.
        \value ClayMultiplayer.Connecting Connection in progress.
        \value ClayMultiplayer.Connected Successfully connected to a room.
        \value ClayMultiplayer.Error Connection failed or lost.
    */
    readonly property int status: _backend.status

    // Enum re-exports for QML access
    readonly property int Star: 0
    readonly property int Mesh: 1
    readonly property int Disconnected: 0
    readonly property int Connecting: 1
    readonly property int Connected: 2
    readonly property int Error: 3

    /*!
        \qmlsignal ClayMultiplayer::roomCreated(string roomId)
        \brief Emitted when a room is successfully created.

        The \a roomId is a short code (e.g., "X7K2M9") that other
        players can use to join the game.
    */
    signal roomCreated(string roomId)

    /*!
        \qmlsignal ClayMultiplayer::playerJoined(string playerId)
        \brief Emitted when a player joins the room.
    */
    signal playerJoined(string playerId)

    /*!
        \qmlsignal ClayMultiplayer::playerLeft(string playerId)
        \brief Emitted when a player leaves the room.
    */
    signal playerLeft(string playerId)

    /*!
        \qmlsignal ClayMultiplayer::messageReceived(string fromId, var data)
        \brief Emitted when a reliable message is received.

        Messages sent via broadcast() arrive here.
        \a fromId is the sender's player ID.
        \a data is the message payload (typically a JavaScript object).
    */
    signal messageReceived(string fromId, var data)

    /*!
        \qmlsignal ClayMultiplayer::stateReceived(string fromId, var data)
        \brief Emitted when a state update is received.

        Updates sent via broadcastState() arrive here.
        Use for high-frequency data like entity positions.
    */
    signal stateReceived(string fromId, var data)

    /*!
        \qmlsignal ClayMultiplayer::errorOccurred(string message)
        \brief Emitted when a connection error occurs.
    */
    signal errorOccurred(string message)

    /*!
        \qmlmethod void ClayMultiplayer::createRoom()
        \brief Create a new game room and become the host.

        On success, emits roomCreated() with a room code that
        can be shared with other players.
    */
    function createRoom() {
        _backend.maxPlayers = root.maxPlayers
        _backend.topology = root.topology
        _backend.createRoom()
    }

    /*!
        \qmlmethod void ClayMultiplayer::joinRoom(string roomId)
        \brief Join an existing room using its code.

        The \a roomId should be the code provided by the host.
        Case-insensitive (automatically converted to uppercase).
    */
    function joinRoom(roomId) {
        _backend.topology = root.topology
        _backend.joinRoom(roomId)
    }

    /*!
        \qmlmethod void ClayMultiplayer::leave()
        \brief Leave the current room.

        If you're the host, this closes the room for all players.
    */
    function leave() {
        _backend.leave()
    }

    /*!
        \qmlmethod void ClayMultiplayer::broadcast(var data)
        \brief Send a reliable message to all connected players.

        Messages are delivered reliably and in order.
        Use for chat, game events, and important state changes.

        \a data should be a JavaScript object that will be serialized to JSON.
    */
    function broadcast(data) {
        _backend.broadcast(data)
    }

    /*!
        \qmlmethod void ClayMultiplayer::broadcastState(var data)
        \brief Send a state update to all connected players.

        Optimized for high-frequency updates like positions.
        \a data should be a JavaScript object.
    */
    function broadcastState(data) {
        _backend.broadcastState(data)
    }

    /*!
        \qmlmethod void ClayMultiplayer::sendTo(string playerId, var data)
        \brief Send a message to a specific player.

        \a playerId must be a valid player ID from the players list.
        \a data should be a JavaScript object.
    */
    function sendTo(playerId, data) {
        _backend.sendTo(playerId, data)
    }

    ClayMultiplayerBackend {
        id: _backend

        onRoomCreated: (roomId) => root.roomCreated(roomId)
        onPlayerJoined: (playerId) => root.playerJoined(playerId)
        onPlayerLeft: (playerId) => root.playerLeft(playerId)
        onMessageReceived: (fromId, data) => root.messageReceived(fromId, data)
        onStateReceived: (fromId, data) => root.stateReceived(fromId, data)
        onErrorOccurred: (message) => root.errorOccurred(message)
    }
}
