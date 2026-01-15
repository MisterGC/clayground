// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import Clayground.Network

/*!
    \qmltype Network
    \inqmlmodule Clayground.Network
    \brief Unified P2P networking for games, apps, and distributed systems.

    Network provides peer-to-peer connectivity using WebRTC Data Channels.
    One node hosts a network, others join using a simple network code.
    No dedicated server infrastructure required.

    Works across platforms: Browser (WASM), Desktop, and Mobile can all
    connect to each other when using Internet signaling mode.

    \section1 Signaling Modes

    \list
    \li \b Internet - Uses PeerJS signaling server for peer discovery. Requires internet.
        Enables Browser <-> Desktop <-> Mobile connectivity.
    \li \b LAN - Embedded signaling server with encoded IP codes.
        Works on local network without internet. Desktop/Mobile only.
    \endlist

    \section1 Network Topologies

    \list
    \li \b Star - All nodes connect to the host only. The host relays
        messages between nodes.
    \li \b Mesh - All nodes connect to each other directly. (Future)
    \endlist

    \section1 Example Usage

    \qml
    import Clayground.Network

    Network {
        id: network
        maxNodes: 4
        topology: Network.Topology.Star
        signalingMode: Network.SignalingMode.Cloud

        onNetworkCreated: (code) => {
            console.log("Share this code:", code)
        }

        onNodeJoined: (nodeId) => {
            console.log("Node joined:", nodeId)
        }

        onMessageReceived: (from, data) => {
            if (data.type === "chat")
                chatLog.append(data.text)
        }

        onStateReceived: (from, data) => {
            entities[from].x = data.x
            entities[from].y = data.y
        }
    }

    // Host a network
    Button {
        text: "Host"
        onClicked: network.host()
    }

    // Join a network
    Button {
        text: "Join"
        onClicked: network.join(codeInput.text)
    }
    \endqml

    \sa ClayHttpClient
*/
Item {
    id: root

    // ========== Enums ==========

    enum Topology { Star, Mesh }
    enum SignalingMode { Cloud, Local }
    enum Status { Disconnected, Connecting, Connected, Error }

    // ========== Configuration ==========

    /*!
        \qmlproperty enumeration Network::topology
        \brief The network topology to use.

        \value Network.Topology.Star Nodes connect only to host (default).
        \value Network.Topology.Mesh All nodes connect to each other. (Future)

        Must be set before calling host() or join().
    */
    property int topology: Network.Topology.Star

    /*!
        \qmlproperty enumeration Network::signalingMode
        \brief How nodes discover and connect to each other.

        Signaling is only used for initial peer discovery. Once connected,
        all data flows directly peer-to-peer via WebRTC data channels.

        \value Network.SignalingMode.Cloud Uses PeerJS server for peer discovery (default). Requires internet.
               Enables cross-platform Browser <-> Desktop <-> Mobile connectivity.
        \value Network.SignalingMode.Local Host runs embedded signaling server. No internet needed.
               Works on local network only. Not available on WASM (browser).
    */
    property int signalingMode: Network.SignalingMode.Cloud

    /*!
        \qmlproperty int Network::maxNodes
        \brief Maximum number of nodes allowed in the network.

        Valid range: 2-8. Default: 8.
        Must be set before calling host().
    */
    property int maxNodes: 8

    /*!
        \qmlproperty bool Network::autoRelay
        \brief Whether the host automatically relays messages between joiners in Star topology.

        Default: true. When enabled, messages sent by one joiner are automatically
        forwarded to all other joiners through the host.

        Set to false if the host wants full control over message relay (e.g., for
        server-authoritative validation, anti-cheat, or custom game logic).
        When false, the host must manually forward messages using broadcast().
    */
    property bool autoRelay: true

    // ========== Read-only State ==========

    /*!
        \qmlproperty string Network::networkId
        \brief The current network code.

        Empty string if not connected. For hosts, this is the code to share.
        Works identically for cloud (e.g., "ABC123") and local (encoded IP) modes.
    */
    readonly property string networkId: _backend ? _backend.roomId : ""

    /*!
        \qmlproperty string Network::nodeId
        \brief This node's unique identifier.

        For hosts, this equals networkId. For clients, assigned when connecting.
    */
    readonly property string nodeId: _backend ? _backend.playerId : ""

    /*!
        \qmlproperty bool Network::isHost
        \brief True if this node is the network host.
    */
    readonly property bool isHost: _backend ? _backend.isHost : false

    /*!
        \qmlproperty bool Network::connected
        \brief True if connected to a network.
    */
    readonly property bool connected: _backend ? _backend.connected : false

    /*!
        \qmlproperty int Network::nodeCount
        \brief Number of nodes currently in the network.
    */
    readonly property int nodeCount: _backend ? _backend.playerCount : 0

    /*!
        \qmlproperty list<string> Network::nodes
        \brief List of node IDs currently in the network.
    */
    readonly property var nodes: _backend ? _backend.players : []

    /*!
        \qmlproperty enumeration Network::status
        \brief Current connection status.

        \value Network.Status.Disconnected Not connected to any network.
        \value Network.Status.Connecting Connection in progress.
        \value Network.Status.Connected Successfully connected.
        \value Network.Status.Error Connection failed or lost.
    */
    readonly property int status: _backend ? _backend.status : Network.Status.Disconnected

    // ========== Signals ==========

    /*!
        \qmlsignal Network::networkCreated(string networkId)
        \brief Emitted when a network is successfully created.

        The \a networkId is a short code that other nodes can use to join.
    */
    signal networkCreated(string networkId)

    /*!
        \qmlsignal Network::nodeJoined(string nodeId)
        \brief Emitted when a node joins the network.
    */
    signal nodeJoined(string nodeId)

    /*!
        \qmlsignal Network::nodeLeft(string nodeId)
        \brief Emitted when a node leaves the network.
    */
    signal nodeLeft(string nodeId)

    /*!
        \qmlsignal Network::messageReceived(string fromId, var data)
        \brief Emitted when a reliable message is received.

        Messages sent via broadcast() arrive here.
    */
    signal messageReceived(string fromId, var data)

    /*!
        \qmlsignal Network::stateReceived(string fromId, var data)
        \brief Emitted when a state update is received.

        Updates sent via broadcastState() arrive here.
    */
    signal stateReceived(string fromId, var data)

    /*!
        \qmlsignal Network::errorOccurred(string message)
        \brief Emitted when a connection error occurs.
    */
    signal errorOccurred(string message)

    // ========== Methods ==========

    /*!
        \qmlmethod void Network::host()
        \brief Create a new network and become the host.

        On success, emits networkCreated() with a code that can be shared.
        Does nothing if already connected.
    */
    function host() {
        if (_backend && !connected) {
            _backend.maxPlayers = root.maxNodes
            _backend.topology = root.topology
            _backend.autoRelay = root.autoRelay
            _backend.signalingMode = root.signalingMode
            _backend.createRoom()
        }
    }

    /*!
        \qmlmethod void Network::join(string networkId)
        \brief Join an existing network using its code.

        The \a networkId should be the code provided by the host.
        Does nothing if networkId is empty or already connected.
    */
    function join(networkId) {
        if (_backend && !connected && networkId && networkId.length > 0) {
            _backend.topology = root.topology
            _backend.autoRelay = root.autoRelay
            _backend.joinRoom(networkId)
        }
    }

    /*!
        \qmlmethod void Network::leave()
        \brief Leave the current network.

        If you're the host, this closes the network for all nodes.
    */
    function leave() {
        if (_backend) {
            _backend.leave()
        }
    }

    /*!
        \qmlmethod void Network::broadcast(var data)
        \brief Send a reliable message to all connected nodes.

        Messages are delivered reliably and in order.
        \a data should be a JavaScript object.
    */
    function broadcast(data) {
        if (_backend && connected) {
            _backend.broadcast(data)
        }
    }

    /*!
        \qmlmethod void Network::broadcastState(var data)
        \brief Send a state update to all connected nodes.

        Optimized for high-frequency updates like positions.
    */
    function broadcastState(data) {
        if (_backend && connected) {
            _backend.broadcastState(data)
        }
    }

    /*!
        \qmlmethod void Network::sendTo(string nodeId, var data)
        \brief Send a message to a specific node.

        \a nodeId must be a valid node ID from the nodes list.
    */
    function sendTo(nodeId, data) {
        if (_backend && connected && nodeId) {
            _backend.sendTo(nodeId, data)
        }
    }

    // ========== Backend ==========

    ClayNetworkBackend {
        id: _backend

        onRoomCreated: (roomId) => root.networkCreated(roomId)
        onPlayerJoined: (playerId) => root.nodeJoined(playerId)
        onPlayerLeft: (playerId) => root.nodeLeft(playerId)
        onMessageReceived: (fromId, data) => root.messageReceived(fromId, data)
        onStateReceived: (fromId, data) => root.stateReceived(fromId, data)
        onErrorOccurred: (message) => root.errorOccurred(message)
    }
}
