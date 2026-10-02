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
    \li \b Cloud - Uses a PeerJS signaling server for peer discovery: the public
        one by default, or your own via \l signalingUrl (clay-dev-server ships one).
        Enables Browser <-> Desktop <-> Mobile connectivity.
    \li \b Local - Embedded signaling server; the code carries the host's IP, port
        and a join secret. Works on a local network without internet. Desktop/Mobile only.
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

        onStateReceived: (from, data, sentAt) => {
            entities[from].sync.push(data, sentAt)   // a StateInterpolator
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

        \value Network.SignalingMode.Cloud Uses a PeerJS server for peer discovery (default): the
               public one, or a self-hosted relay via \l signalingUrl. Enables cross-platform
               Browser <-> Desktop <-> Mobile connectivity.
        \value Network.SignalingMode.Local Host runs an embedded signaling server; the network code
               carries its IP, port and a join secret. No internet needed, local network only.
               Not available on WASM (browser).
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

    /*!
        \qmlproperty var Network::iceServers
        \brief Custom ICE server configuration for NAT traversal.

        Override the default STUN servers. Accepts a list of URL strings
        and/or objects with credentials for TURN servers.

        Default: uses Google's public STUN servers.

        Example with TURN server:
        \qml
        iceServers: [
            "stun:stun.l.google.com:19302",
            { urls: "turn:relay.example.com", username: "user", credential: "pass" }
        ]
        \endqml
    */
    property var iceServers: []

    /*!
        \qmlproperty string Network::signalingUrl
        \brief Custom signaling server URL for offline/LAN operation.

        When set, overrides the default PeerJS cloud signaling server.
        Use this to point at a local PeerJS-compatible relay (e.g. clay-dev-server).

        Example: "wss://myhost:8090/peerjs"

        A \c wss server must present a certificate this machine trusts for
        its host name, or connecting ends in errorOccurred(); see
        \l verifySignalingCertificate.
    */
    property string signalingUrl: ""

    /*!
        \qmlproperty bool Network::verifySignalingCertificate
        \brief Whether a native node checks the signaling server's certificate.

        Default: true. A \c wss signaling server whose certificate does not
        verify - self-signed, expired, or issued for another host name - ends
        the connection attempt in errorOccurred() and status Error.

        Set to false only for a server you control whose certificate cannot
        verify, such as clay-dev-server's self-signed one. Without the check,
        anyone on the path to the server can swap the session descriptions,
        and with them the keys the data channels are encrypted with.

        Applies to desktop and mobile. The browser checks the certificate
        itself and ignores this property. On Windows the certificate is not
        checked yet, whatever this says (a libdatachannel limitation).
        Must be set before calling host() or join().
    */
    property bool verifySignalingCertificate: true

    /*!
        \qmlproperty bool Network::verbose
        \brief Enable diagnostic output via diagnosticMessage.

        Statistics (latency, peerStats, syncStats) are always maintained;
        verbose additionally enables connection phase reporting and ICE
        candidate details through the diagnosticMessage signal.
    */
    property bool verbose: false

    /*!
        \qmlproperty int Network::connectionTimeout
        \brief Timeout in milliseconds for connection attempts. 0 to disable.

        When a connection attempt exceeds this duration, connectionTimedOut()
        is emitted and the connection is terminated. Default: 15000 (15 seconds).
    */
    property int connectionTimeout: 15000

    /*!
        \qmlproperty int Network::gracePeriod
        \brief How long, in milliseconds, a node may go unheard before it counts as gone.

        Every node pings its peers every 2 seconds, and a peer it has heard
        nothing from for half a second right away; every peer answers. A
        peer that leaves a ping unanswered for this long, sending nothing at
        all - not even a pong - has crashed or lost its link: it is reported
        in nodeLeft(). On a joiner that peer is the host, and the network
        ends as when the host leaves (see leave()). A crashed peer is
        noticed within the grace period plus about a second.

        A link that drops out for less than this and comes back loses no
        node. Default: 5000. 0 turns the check off; a node then leaves only
        by saying so or when its connection fails.
    */
    property int gracePeriod: 5000

    /*!
        \qmlproperty var Network::linkConditions
        \brief Simulated network conditions for this node, for testing.

        Default: empty, which changes nothing. Set it to make this node sit
        behind a bad link, on one machine, without touching the operating
        system: everything the node sends and everything it receives over
        its data channels is conditioned, each direction on its own.

        \list
        \li \c loss (0..1) - share of state updates (broadcastState()) that
            are lost. Reliable messages are never lost; a lost one would be
            retransmitted, so they arrive late instead.
        \li \c latencyMs - added to every packet, each way.
        \li \c jitterMs - a random 0..jitterMs added on top. State updates
            may overtake each other this way, reliable messages stay in
            order.
        \li \c bandwidthKbps - packets leave one after another at this
            rate (kbit/s, 0 = no cap); a full link delays everything behind.
        \li \c blackout - while true, state updates are lost and reliable
            messages are held; when it ends, they arrive in order.
        \li \c dropSignaling - while true, the signaling server cannot be
            reached: host() and join() end in errorOccurred(), and a live
            Cloud signaling connection is cut as if the server had dropped
            it (what follows is that of a real drop, see signalingLost()).
            A Local host is its own signaling server and hosts regardless.
        \endlist

        Takes effect immediately, also while connected; assign a whole new
        object to change it. Packets already under way keep their schedule.

        \qml
        network.linkConditions = { loss: 0.1, latencyMs: 80, jitterMs: 20 }
        network.linkConditions = { blackout: true }   // the link goes dark
        network.linkConditions = {}                    // a clean link again
        \endqml

        Works the same on desktop, mobile and in the browser.
    */
    property var linkConditions: ({})

    /*!
        \qmlproperty string Network::password
        \brief The room password a host demands, or the one a joiner gives.

        Default: empty. A host with a password refuses every joiner that
        does not give the same one: the joiner gets joinRefused() with
        \c "wrong-password" and errorOccurred("Wrong password"), and never
        appears in \l nodes. A host without a password takes any joiner.

        The joiner sends it in its handshake over the data channel, which is
        encrypted, so it never passes the signaling server: knowing the
        network code is no longer enough to get in. Works the same for Cloud
        and Local signaling, on desktop, mobile and in the browser.
        Must be set before calling host() or join().
    */
    property string password: ""

    /*!
        \qmlproperty string Network::appId
        \brief Names the app or game, so only builds of the same one connect.

        Default: empty. A joiner whose appId differs from the host's is
        refused with \c "incompatible-app". Set it to the same string in
        every build of a game when other Clayground apps could be handed
        its code. Must be set before calling host() or join().
    */
    property string appId: ""

    /*!
        \qmlproperty string Network::clientToken
        \brief What this node identifies itself with when it joins.

        A random token unless set. A joiner sends it in its handshake, and
        the host keeps it in \l clientTokens next to the joiner's node ID -
        a node ID changes with every join, the token need not. Store it and
        set it again on the next start so a host can recognise a joiner
        that comes back. Must be set before calling join().
    */
    property alias clientToken: _backend.clientToken

    // ========== Read-only State ==========

    /*!
        \qmlproperty string Network::networkId
        \brief The current network code.

        Empty string if not connected. For hosts, this is the code to share.
        Works identically for cloud (e.g., "ABC123") and local
        (e.g., "L1HGF041-6Y4-K7QP2MXA": encoded IP, port and join secret) modes.
    */
    readonly property string networkId: _backend ? _backend.roomId : ""

    /*!
        \qmlproperty string Network::nodeId
        \brief This node's unique identifier.

        For hosts, this equals networkId. For clients, assigned when connecting.
    */
    readonly property string nodeId: _backend ? _backend.playerId : ""

    /*!
        \qmlproperty string Network::hostId
        \brief The node ID of the network's host, the same on every node.

        On the host it equals \l nodeId; on a joiner it is the host's entry
        in \l nodes, and messages and states the host sends itself arrive
        with it as their sender. It names the host in both signaling modes
        and on every platform, so a game decides "is this the host's word?"
        by comparing against it instead of guessing the host's ID format.
        Empty string while not in a network; a joiner knows it from the
        moment it starts connecting to the host.
    */
    readonly property string hostId: _backend ? _backend.hostId : ""

    /*!
        \qmlproperty bool Network::isHost
        \brief True if this node is the network host.
    */
    readonly property bool isHost: _backend ? _backend.isHost : false

    /*!
        \qmlproperty bool Network::acceptingJoins
        \brief True while new nodes can join this node's network.

        True on a host whose signaling connection is up. While the Cloud
        signaling connection is lost (signalingLost()) it is false - the
        network goes on, but nobody new can find the host - and it turns
        true again once the host is back on the server. Always false on a
        joiner.
    */
    readonly property bool acceptingJoins: _backend ? _backend.acceptingJoins : false

    /*!
        \qmlproperty var Network::clientTokens
        \brief On the host, each joiner's \l clientToken, keyed by its node ID.

        A joiner is in it from the moment it is in \l nodes until it leaves.
        Empty on a joiner: a token is between a joiner and its host.
    */
    readonly property var clientTokens: _backend ? _backend.clientTokens : ({})

    /*!
        \qmlproperty int Network::wireVersion
        \brief The version of the message format this build speaks.

        Two builds with different wire versions cannot play together: a
        joiner is refused with \c "incompatible-version", and so is one that
        meets a host from before the handshake. Clayground raises it when
        what goes over the data channels changes.
    */
    readonly property int wireVersion: _backend ? _backend.wireVersion : 0

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

    /*!
        \qmlproperty string Network::connectionPhase
        \brief Current connection phase when status is Connecting.

        Possible values: "signaling", "ice", "handshake" (a joiner waiting
        for the host to take it), or "" when not connecting.
    */
    readonly property string connectionPhase: _backend ? _backend.connectionPhase : ""

    /*!
        \qmlproperty var Network::phaseTiming
        \brief Timing breakdown of the connection phases in milliseconds.

        After connection: { signaling: 230, ice: 1200, datachannel: 0, handshake: 15, total: 1445 }
    */
    readonly property var phaseTiming: _backend ? _backend.phaseTiming : ({})

    /*!
        \qmlproperty int Network::latency
        \brief Best RTT across all connected peers in milliseconds. -1 if unknown.

        Updated every 2 seconds while connected.
    */
    readonly property int latency: _backend ? _backend.latency : -1

    /*!
        \qmlproperty var Network::peerStats
        \brief Per-peer transport statistics, always on.

        Format: { nodeId: { latency, msgSent, msgRecv, bytesSent, bytesRecv,
        stateSent, stateRecv, stateChannel, stateBacklog } }.
        \c stateChannel is \c "unreliable" once the lossy state channel is
        negotiated and \c "fallback" while state still travels over the
        reliable channel.
    */
    readonly property var peerStats: _backend ? _backend.peerStats : ({})

    /*!
        \qmlproperty var Network::syncStats
        \brief Per-node state-sync statistics, keyed by ORIGIN node id.

        Unlike \l peerStats this also covers nodes whose state arrives
        relayed through the host. Format:
        { nodeId: { seq, recv, dropped, ageMs } } - \c dropped counts stale
        updates discarded by sequence checks, \c ageMs is the time since the
        newest accepted state.

        A node that sent keyed states (broadcastState() with a key) also has
        \c keys, { key: { seq, recv, dropped, ageMs } } per key, \c batches,
        the datagrams they came in, and \c maxBatchBytes, the largest of
        them; its \c recv and \c dropped include the keyed states.
    */
    readonly property var syncStats: _backend ? _backend.syncStats : ({})

    /*!
        \qmlproperty real Network::sessionTime
        \brief The session clock: milliseconds since the host created the
               network, the same on every node. -1 while not in a network.

        It is the host's monotonic clock, so no NTP adjustment of a wall
        clock moves it. The host reads it directly; a joiner syncs to it
        with the pings it sends the host anyway, a burst of them right after
        joining and one every 2 seconds after that, and lands within a few
        milliseconds of it - also over a link with 100 ms of latency and
        jitter. Until \l sessionTimeSynced is true it may step; after that
        it only runs, never back.

        Every message and state carries the session time it was sent at
        (\c sentAt in \l messageReceived and \l stateReceived), so a node
        can tell how long ago something happened on another node, or agree
        with all of them on a moment to come ("this lands at t").

        Read it when you need it: it changes every millisecond, but a
        binding to it is only re-evaluated when the clock is set, synced or
        reset.
    */
    readonly property alias sessionTime: _backend.sessionTime

    /*!
        \qmlproperty bool Network::sessionTimeSynced
        \brief True on the host, and on a joiner once its pings have synced
               \l sessionTime to the host's (about 2 seconds after joining).
    */
    readonly property bool sessionTimeSynced: _backend ? _backend.sessionTimeSynced : false

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
        \qmlsignal Network::messageReceived(string fromId, var data, real sentAt)
        \brief Emitted when a reliable message is received.

        Messages sent via broadcast() and sendTo() arrive here. \a sentAt is
        the \l sessionTime the sender sent it at, or -1 when the sender did
        not include one; \c{sessionTime - sentAt} is how long it took.
        Handlers that only take \c (fromId, data) keep working.
    */
    signal messageReceived(string fromId, var data, real sentAt)

    /*!
        \qmlsignal Network::stateReceived(string fromId, var data, real sentAt, string key)
        \brief Emitted when a state update is received.

        Updates sent via broadcastState() arrive here. \a sentAt is the
        \l sessionTime when the sender called broadcastState(), or -1 when
        the sender did not include one; hand it to \l StateInterpolator::push
        so the snapshot lands on the sender's timeline instead of its
        arrival time. \a key is the key the update
        was sent with, or an empty string for one sent without. Handlers
        that only take \c (fromId, data) or \c (fromId, data, sentAt) keep
        working.
    */
    signal stateReceived(string fromId, var data, real sentAt, string key)

    /*!
        \qmlsignal Network::errorOccurred(string message)
        \brief Emitted when a connection error occurs.

        Also emitted on a joiner whose network ended because the host left,
        crashed or lost its connection; \l status is Disconnected then.
    */
    signal errorOccurred(string message)

    /*!
        \qmlsignal Network::joinRefused(string reason, string message)
        \brief Emitted on a joiner the host did not take.

        Joining starts with a handshake: the joiner's wire version, \l appId,
        \l password and \l clientToken go to the host, which takes the
        joiner or refuses it. \a reason says why, for the game to act on:

        \value "incompatible-version" The two builds speak different wire
               versions (\l wireVersion), or one of them predates the handshake.
        \value "incompatible-app" The host's \l appId is another one.
        \value "wrong-password" The \l password is not the host's.
        \value "handshake-failed" The host's answer made no sense.
        \value "refused" The host refused without a reason, e.g. a full network.

        \a message says it in words; errorOccurred(message) follows, and
        \l status is Error. The node is not in a network any more, so it can
        join again - with the right password, for one.
    */
    signal joinRefused(string reason, string message)

    /*!
        \qmlsignal Network::signalingLost()
        \brief Emitted when the Cloud signaling connection drops after it was up.

        Nodes already connected keep their data channels; \l status, \l connected
        and \l nodes stay as they are and messages keep flowing. The node
        reconnects to the server under the same ID, retrying every few
        seconds - the server may hold on to the old connection for a while.
        Meanwhile a host takes no new joiners: \l acceptingJoins is false
        until it is back. A joiner still connecting gets no further help from
        the server and may run into \l connectionTimeout.

        While connected, a node keeps the connection alive with the PeerJS
        heartbeat, so this means the server or the network dropped it. The
        same on desktop, mobile and in the browser.
    */
    signal signalingLost()

    /*!
        \qmlsignal Network::diagnosticMessage(string phase, string detail)
        \brief Emitted with diagnostic info when verbose is true.

        Provides visibility into connection phases, ICE candidates,
        and state transitions.
    */
    signal diagnosticMessage(string phase, string detail)

    /*!
        \qmlsignal Network::connectionTimedOut()
        \brief Emitted when a connection attempt exceeds connectionTimeout.
    */
    signal connectionTimedOut()

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
            _backend.signalingUrl = root.signalingUrl
            _backend.verifySignalingCertificate = root.verifySignalingCertificate
            _backend.iceServers = root.iceServers
            _backend.verbose = root.verbose
            _backend.password = root.password
            _backend.appId = root.appId
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
            _backend.signalingMode = root.signalingMode
            _backend.signalingUrl = root.signalingUrl
            _backend.verifySignalingCertificate = root.verifySignalingCertificate
            _backend.iceServers = root.iceServers
            _backend.verbose = root.verbose
            _backend.password = root.password
            _backend.appId = root.appId
            _backend.joinRoom(networkId)
        }
    }

    /*!
        \qmlmethod void Network::leave()
        \brief Leave the current network.

        Says goodbye to every peer first, so they report this node in
        nodeLeft() at once instead of after the grace period. If you're the
        host, this closes the network for all nodes: each joiner's \l status
        turns Disconnected and it gets errorOccurred().
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
        \qmlmethod void Network::broadcastState(var data, string key)
        \brief Send a state update to all connected nodes.

        Optimized for high-frequency updates like positions: travels over an
        unordered channel without retransmissions (lost packets are simply
        skipped) and carries a sequence number so receivers drop stale
        updates instead of applying them late. Use \l broadcast for anything
        that must arrive (events like attacks, level changes, chat).

        Without \a key the update goes out at once, and the sequence is the
        sender's: an update is stale behind any newer one from that node.
        Send one snapshot of everything this way.

        With \a key - one per object, say - an update is stale only behind a
        newer one from that node for the same key, so a late update for one
        object is never dropped for another's. Keyed updates leave together
        when control returns to the event loop (once per frame for updates
        sent from one frame's handlers) or at \l flushState(), packed into
        datagrams of about 1200 bytes at most; a second update for a key
        before then replaces the first. They arrive in \l stateReceived
        with their \c key. Keys are strings; numbers are converted.
    */
    function broadcastState(data, key) {
        if (!_backend || !connected)
            return
        if (key === undefined || key === null || key === "")
            _backend.broadcastState(data)
        else
            _backend.broadcastKeyedState(data, String(key))
    }

    /*!
        \qmlmethod void Network::flushState()
        \brief Send the keyed state updates queued so far now.

        broadcastState() with a key queues the update until control returns
        to the event loop; call this to send the queue earlier, e.g. right
        after the updates of one tick.
    */
    function flushState() {
        if (_backend)
            _backend.flushState()
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

    /*!
        \qmlmethod int Network::stateAgeMs(string nodeId, string key)
        \brief Milliseconds since the newest accepted state from \a nodeId,
               or -1 if none was received yet.

        With \a key, the newest accepted state \a nodeId sent with that key.
    */
    function stateAgeMs(nodeId, key) {
        if (!_backend)
            return -1
        if (key === undefined || key === null || key === "")
            return _backend.stateAgeMs(nodeId)
        return _backend.keyedStateAgeMs(nodeId, String(key))
    }

    /*!
        \qmlmethod real Network::transitMs(string nodeId)
        \brief How long the fastest state from \a nodeId of the last 3
               seconds took to arrive, in milliseconds of \l sessionTime,
               or NaN before one arrived.

        It is the offset between \a nodeId's timeline and arrival here,
        estimated once per sender: a \l StateInterpolator given this
        network and \a nodeId places its snapshots with it instead of
        estimating the offset on its own. A state relayed by the host
        counts both hops.
    */
    function transitMs(nodeId) {
        return _backend ? _backend.transitMs(nodeId) : NaN
    }

    // Test hook, not API: sends json to nodeId exactly as given, so a test
    // can put a forged "from" on the wire (net gym, #298)
    function _sendRaw(nodeId, json) {
        if (_backend && connected && nodeId)
            _backend.sendRaw(nodeId, json)
    }

    // Test hook, not API: makes this node speak another wire version, so a
    // test can be the joiner from another build (net gym, #323)
    function _setWireVersion(version) {
        if (_backend)
            _backend.wireVersion = version
    }

    // ========== Connection Timeout ==========

    Timer {
        id: _timeoutTimer
        interval: root.connectionTimeout
        running: root.connectionTimeout > 0 && root.status === Network.Status.Connecting
        onTriggered: {
            root.connectionTimedOut()
            root.errorOccurred("Connection timed out (" + root.connectionPhase + " phase)")
            root.leave()
        }
    }

    // ========== Ping Timer ==========

    // Always on while connected - keeps latency and the per-node stats
    // fresh at negligible cost (one tiny message per peer every 2s), and the
    // pongs are how the backend tells a silent peer from a live one.
    Timer {
        id: _pingTimer
        interval: 2000
        repeat: true
        running: root.connected && _backend
        onTriggered: _backend.ping()
    }

    // ========== Backend ==========

    ClayNetworkBackend {
        id: _backend
        verbose: root.verbose
        linkConditions: root.linkConditions
        gracePeriod: root.gracePeriod

        onRoomCreated: (roomId) => root.networkCreated(roomId)
        onPlayerJoined: (playerId) => root.nodeJoined(playerId)
        onPlayerLeft: (playerId) => root.nodeLeft(playerId)
        onMessageReceived: (fromId, data, sentAt) => root.messageReceived(fromId, data, sentAt)
        onStateReceived: (fromId, data, sentAt, key) => root.stateReceived(fromId, data, sentAt, key)
        onErrorOccurred: (message) => root.errorOccurred(message)
        onJoinRefused: (reason, message) => root.joinRefused(reason, message)
        onSignalingLost: () => root.signalingLost()
        onDiagnosticMessage: (phase, detail) => root.diagnosticMessage(phase, detail)
    }
}
