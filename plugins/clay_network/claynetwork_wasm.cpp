// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claynetwork_wasm.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/val.h>
#include <map>

// Global registry for callback routing
static std::map<int, ClayNetwork*> g_networkRegistry;
int ClayNetwork::nextInstanceId_ = 0;

// JavaScript: Load PeerJS library dynamically
EM_JS(void, js_load_peerjs, (), {
    if (Module.clayPeerJSLoaded) return;
    if (Module.clayPeerJSLoading) return;

    Module.clayPeerJSLoading = true;
    Module.clayPeerJSReady = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
        script.onload = () => {
            Module.clayPeerJSLoaded = true;
            Module.clayPeerJSLoading = false;
            console.log('[ClayNetwork] PeerJS loaded');
            resolve();
        };
        script.onerror = (e) => {
            Module.clayPeerJSLoading = false;
            console.error('[ClayNetwork] Failed to load PeerJS', e);
            reject(e);
        };
        document.head.appendChild(script);
    });
});

// JavaScript: Initialize network instance
EM_JS(void, js_init_network, (int instanceId), {
    if (!Module.clayNetwork) {
        Module.clayNetwork = {};
    }

    Module.clayNetwork[instanceId] = {
        peer: null,
        connections: new Map(),
        networkId: null,
        nodeId: null,
        isHost: false,
        topology: 0, // 0 = Star, 1 = Mesh
        maxNodes: 8,
        autoRelay: true
    };
});

// JavaScript: Set autoRelay property
EM_JS(void, js_set_auto_relay, (int instanceId, int autoRelay), {
    const state = Module.clayNetwork[instanceId];
    if (state) {
        state.autoRelay = autoRelay !== 0;
    }
});

// JavaScript: Create a network (become host)
EM_JS(void, js_create_network, (int instanceId, const char* networkCode, int topology, int maxNodes), {
    const networkId = UTF8ToString(networkCode);
    const state = Module.clayNetwork[instanceId];
    state.topology = topology;
    state.maxNodes = maxNodes;

    Module.clayPeerJSReady.then(() => {
        // Host uses network code as peer ID for easy discovery
        state.peer = new Peer(networkId, {
            debug: 1
        });

        state.peer.on('open', (id) => {
            console.log('[ClayNetwork] Network created:', id);
            state.networkId = id;
            state.nodeId = id;
            state.isHost = true;
            Module._clay_net_created(instanceId, stringToNewUTF8(id));
        });

        state.peer.on('connection', (conn) => {
            if (state.connections.size >= state.maxNodes - 1) {
                console.log('[ClayNetwork] Network full, rejecting:', conn.peer);
                conn.close();
                return;
            }

            console.log('[ClayNetwork] Node connecting:', conn.peer);
            state.connections.set(conn.peer, conn);

            conn.on('open', () => {
                console.log('[ClayNetwork] Node joined:', conn.peer);
                Module._clay_net_node_joined(instanceId, stringToNewUTF8(conn.peer));

                // In mesh topology, tell new node about existing nodes
                if (state.topology === 1) {
                    const existingNodes = Array.from(state.connections.keys()).filter(p => p !== conn.peer);
                    if (existingNodes.length > 0) {
                        conn.send(JSON.stringify({
                            _clay_sys: 'mesh_nodes',
                            nodes: existingNodes
                        }));
                    }
                }

                // Notify existing nodes about new node
                state.connections.forEach((c, nodeId) => {
                    if (nodeId !== conn.peer) {
                        c.send(JSON.stringify({
                            _clay_sys: 'node_joined',
                            nodeId: conn.peer
                        }));
                    }
                });
            });

            conn.on('data', (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                const parsed = JSON.parse(msg);

                // Handle system messages
                if (parsed._clay_sys) return;

                // Host in Star topology: relay to other peers if autoRelay is on
                if (state.isHost && state.autoRelay && state.topology === 0) {
                    // Add "from" field for receivers to know original sender
                    parsed.from = conn.peer;
                    const relayMsg = JSON.stringify(parsed);
                    state.connections.forEach((c, peerId) => {
                        if (peerId !== conn.peer && c.open) {
                            c.send(parsed);
                        }
                    });
                }

                const isState = parsed._clay_state === true;
                Module._clay_net_message(instanceId,
                    stringToNewUTF8(conn.peer),
                    stringToNewUTF8(msg),
                    isState ? 1 : 0);
            });

            conn.on('close', () => {
                console.log('[ClayNetwork] Node left:', conn.peer);
                state.connections.delete(conn.peer);
                Module._clay_net_node_left(instanceId, stringToNewUTF8(conn.peer));

                // Notify other nodes
                state.connections.forEach((c) => {
                    c.send(JSON.stringify({
                        _clay_sys: 'node_left',
                        nodeId: conn.peer
                    }));
                });
            });

            conn.on('error', (err) => {
                console.error('[ClayNetwork] Connection error:', err);
            });
        });

        state.peer.on('error', (err) => {
            console.error('[ClayNetwork] Peer error:', err);
            Module._clay_net_error(instanceId, stringToNewUTF8(err.message || err.type));
        });

        state.peer.on('disconnected', () => {
            console.log('[ClayNetwork] Disconnected from signaling');
            Module._clay_net_disconnected(instanceId);
        });
    }).catch((err) => {
        Module._clay_net_error(instanceId, stringToNewUTF8('Failed to load PeerJS'));
    });
});

// JavaScript: Join an existing network
EM_JS(void, js_join_network, (int instanceId, const char* networkCode, int topology), {
    const networkId = UTF8ToString(networkCode);
    const state = Module.clayNetwork[instanceId];
    state.topology = topology;

    Module.clayPeerJSReady.then(() => {
        // Client gets random peer ID
        state.peer = new Peer({
            debug: 1
        });

        state.peer.on('open', (id) => {
            console.log('[ClayNetwork] Client node ready:', id);
            state.nodeId = id;
            state.networkId = networkId;
            state.isHost = false;

            // Connect to host - use 'json' serialization for string transfer
            const conn = state.peer.connect(networkId, { reliable: true, serialization: 'json' });
            state.connections.set(networkId, conn);

            conn.on('open', () => {
                console.log('[ClayNetwork] Connected to network:', networkId);
                Module._clay_net_connected(instanceId, stringToNewUTF8(id));
            });

            conn.on('data', (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                const parsed = JSON.parse(msg);

                // Handle system messages
                if (parsed._clay_sys === 'mesh_nodes') {
                    // Connect to other nodes for mesh topology
                    parsed.nodes.forEach((nodeId) => {
                        if (!state.connections.has(nodeId)) {
                            const nodeConn = state.peer.connect(nodeId, { reliable: true, serialization: 'json' });
                            state.connections.set(nodeId, nodeConn);
                            setupNodeConnection(instanceId, nodeId, nodeConn);
                        }
                    });
                    return;
                }

                if (parsed._clay_sys === 'node_joined') {
                    Module._clay_net_node_joined(instanceId, stringToNewUTF8(parsed.nodeId));
                    // In mesh topology, connect to new node
                    if (state.topology === 1 && !state.connections.has(parsed.nodeId)) {
                        const nodeConn = state.peer.connect(parsed.nodeId, { reliable: true, serialization: 'json' });
                        state.connections.set(parsed.nodeId, nodeConn);
                        setupNodeConnection(instanceId, parsed.nodeId, nodeConn);
                    }
                    return;
                }

                if (parsed._clay_sys === 'node_left') {
                    Module._clay_net_node_left(instanceId, stringToNewUTF8(parsed.nodeId));
                    state.connections.delete(parsed.nodeId);
                    return;
                }

                // Use "from" field if present (relayed message), else use host ID
                const actualFromId = parsed.from || networkId;
                const isState = parsed._clay_state === true;
                Module._clay_net_message(instanceId,
                    stringToNewUTF8(actualFromId),
                    stringToNewUTF8(msg),
                    isState ? 1 : 0);
            });

            conn.on('close', () => {
                console.log('[ClayNetwork] Disconnected from network');
                state.connections.delete(networkId);
                Module._clay_net_disconnected(instanceId);
            });

            conn.on('error', (err) => {
                console.error('[ClayNetwork] Connection error:', err);
                Module._clay_net_error(instanceId, stringToNewUTF8(err.message || 'Connection failed'));
            });
        });

        state.peer.on('connection', (conn) => {
            // Accept incoming connections (mesh topology)
            console.log('[ClayNetwork] Incoming mesh connection:', conn.peer);
            state.connections.set(conn.peer, conn);
            setupNodeConnection(instanceId, conn.peer, conn);
        });

        state.peer.on('error', (err) => {
            console.error('[ClayNetwork] Peer error:', err);
            Module._clay_net_error(instanceId, stringToNewUTF8(err.message || err.type));
        });
    }).catch((err) => {
        Module._clay_net_error(instanceId, stringToNewUTF8('Failed to load PeerJS'));
    });

    // Helper to setup node connection handlers
    function setupNodeConnection(instanceId, nodeId, conn) {
        conn.on('open', () => {
            console.log('[ClayNetwork] Mesh connected to:', nodeId);
        });

        conn.on('data', (data) => {
            const msg = typeof data === 'string' ? data : JSON.stringify(data);
            const parsed = JSON.parse(msg);
            if (parsed._clay_sys) return;

            // Use "from" field if present (relayed), else use direct peer ID
            const actualFromId = parsed.from || nodeId;
            const isState = parsed._clay_state === true;
            Module._clay_net_message(instanceId,
                stringToNewUTF8(actualFromId),
                stringToNewUTF8(msg),
                isState ? 1 : 0);
        });

        conn.on('close', () => {
            state.connections.delete(nodeId);
            Module._clay_net_node_left(instanceId, stringToNewUTF8(nodeId));
        });
    }
});

// JavaScript: Broadcast message to all connected nodes
EM_JS(void, js_broadcast, (int instanceId, const char* data), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;

    const msg = UTF8ToString(data);
    // Parse JSON so PeerJS doesn't double-encode when using JSON serialization
    const obj = JSON.parse(msg);
    state.connections.forEach((conn) => {
        if (conn.open) {
            conn.send(obj);
        }
    });
});

// JavaScript: Send message to specific node
EM_JS(void, js_send_to, (int instanceId, const char* nodeId, const char* data), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;

    const targetId = UTF8ToString(nodeId);
    const msg = UTF8ToString(data);
    // Parse JSON so PeerJS doesn't double-encode when using JSON serialization
    const obj = JSON.parse(msg);

    const conn = state.connections.get(targetId);
    if (conn && conn.open) {
        conn.send(obj);
    }
});

// JavaScript: Leave network and cleanup
EM_JS(void, js_leave, (int instanceId), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;

    state.connections.forEach((conn) => {
        try { conn.close(); } catch (e) {}
    });
    state.connections.clear();

    if (state.peer) {
        try { state.peer.destroy(); } catch (e) {}
        state.peer = null;
    }

    state.networkId = null;
    state.nodeId = null;
    state.isHost = false;
});

// JavaScript: Get node list
EM_JS(char*, js_get_nodes, (int instanceId), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return stringToNewUTF8('[]');

    const nodes = Array.from(state.connections.keys());
    if (state.isHost) {
        nodes.unshift(state.nodeId); // Add self for host
    }
    return stringToNewUTF8(JSON.stringify(nodes));
});

// C callbacks from JavaScript
extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_created(int instanceId, const char* networkId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, networkId]() {
            net->onNetworkCreated(networkId);
            free((void*)networkId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_connected(int instanceId, const char* nodeId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, nodeId]() {
            net->onConnectedToNetwork(nodeId);
            free((void*)nodeId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_node_joined(int instanceId, const char* nodeId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, nodeId]() {
            net->onNodeJoined(nodeId);
            free((void*)nodeId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_node_left(int instanceId, const char* nodeId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, nodeId]() {
            net->onNodeLeft(nodeId);
            free((void*)nodeId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_message(int instanceId, const char* fromId, const char* data, int isState)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, fromId, data, isState]() {
            net->onMessage(fromId, data, isState != 0);
            free((void*)fromId);
            free((void*)data);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_error(int instanceId, const char* message)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, message]() {
            net->onError(message);
            free((void*)message);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_disconnected(int instanceId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second]() {
            net->onDisconnected();
        }, Qt::QueuedConnection);
    }
}

#endif // __EMSCRIPTEN__

ClayNetwork::ClayNetwork(QObject *parent)
    : QObject(parent)
{
#ifdef __EMSCRIPTEN__
    instanceId_ = nextInstanceId_++;
    g_networkRegistry[instanceId_] = this;
    js_load_peerjs();
    js_init_network(instanceId_);
#endif
}

ClayNetwork::~ClayNetwork()
{
#ifdef __EMSCRIPTEN__
    js_leave(instanceId_);
    g_networkRegistry.erase(instanceId_);
#endif
}

QString ClayNetwork::networkId() const
{
    return networkId_;
}

QString ClayNetwork::nodeId() const
{
    return nodeId_;
}

bool ClayNetwork::isHost() const
{
    return isHost_;
}

bool ClayNetwork::connected() const
{
    return connected_;
}

int ClayNetwork::nodeCount() const
{
    return nodes_.size();
}

QStringList ClayNetwork::nodes() const
{
    return nodes_;
}

int ClayNetwork::maxNodes() const
{
    return maxNodes_;
}

void ClayNetwork::setMaxNodes(int max)
{
    if (max < 2) max = 2;
    if (max > 8) max = 8;
    if (maxNodes_ == max) return;

    maxNodes_ = max;
    emit maxNodesChanged();
}

ClayNetwork::Topology ClayNetwork::topology() const
{
    return topology_;
}

void ClayNetwork::setTopology(Topology t)
{
    if (topology_ == t) return;
    topology_ = t;
    emit topologyChanged();
}

ClayNetwork::Status ClayNetwork::status() const
{
    return status_;
}

bool ClayNetwork::autoRelay() const
{
    return autoRelay_;
}

void ClayNetwork::setAutoRelay(bool relay)
{
    if (autoRelay_ == relay) return;
    autoRelay_ = relay;
#ifdef __EMSCRIPTEN__
    js_set_auto_relay(instanceId_, relay ? 1 : 0);
#endif
    emit autoRelayChanged();
}

void ClayNetwork::createRoom()
{
#ifdef __EMSCRIPTEN__
    if (connected_) {
        qWarning() << "[ClayNetwork] Already connected, leave first";
        return;
    }

    status_ = Connecting;
    emit statusChanged();

    QString networkCode = generateNetworkCode();
    QByteArray codeBytes = networkCode.toUtf8();
    js_create_network(instanceId_, codeBytes.constData(), static_cast<int>(topology_), maxNodes_);
#else
    qWarning() << "[ClayNetwork] WASM backend not available on this platform";
#endif
}

void ClayNetwork::joinRoom(const QString &networkId)
{
#ifdef __EMSCRIPTEN__
    if (connected_) {
        qWarning() << "[ClayNetwork] Already connected, leave first";
        return;
    }

    status_ = Connecting;
    emit statusChanged();

    QByteArray codeBytes = networkId.toUpper().toUtf8();
    js_join_network(instanceId_, codeBytes.constData(), static_cast<int>(topology_));
#else
    Q_UNUSED(networkId)
    qWarning() << "[ClayNetwork] WASM backend not available on this platform";
#endif
}

void ClayNetwork::leave()
{
#ifdef __EMSCRIPTEN__
    js_leave(instanceId_);

    networkId_.clear();
    nodeId_.clear();
    isHost_ = false;
    connected_ = false;
    nodes_.clear();
    status_ = Disconnected;

    emit networkIdChanged();
    emit nodeIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
#endif
}

void ClayNetwork::broadcast(const QVariant &data)
{
#ifdef __EMSCRIPTEN__
    // Use same wire format as Desktop: {"t": "m", "d": {...}}
    QJsonObject msg;
    msg["t"] = "m";
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QByteArray json = QJsonDocument(msg).toJson(QJsonDocument::Compact);
    js_broadcast(instanceId_, json.constData());
#else
    Q_UNUSED(data)
#endif
}

void ClayNetwork::broadcastState(const QVariant &data)
{
#ifdef __EMSCRIPTEN__
    // Use same wire format as Desktop: {"t": "s", "d": {...}}
    QJsonObject msg;
    msg["t"] = "s";
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QByteArray json = QJsonDocument(msg).toJson(QJsonDocument::Compact);
    js_broadcast(instanceId_, json.constData());
#else
    Q_UNUSED(data)
#endif
}

void ClayNetwork::sendTo(const QString &nodeId, const QVariant &data)
{
#ifdef __EMSCRIPTEN__
    // Use same wire format as Desktop: {"t": "m", "d": {...}}
    QJsonObject msg;
    msg["t"] = "m";
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QByteArray json = QJsonDocument(msg).toJson(QJsonDocument::Compact);
    QByteArray nodeBytes = nodeId.toUtf8();
    js_send_to(instanceId_, nodeBytes.constData(), json.constData());
#else
    Q_UNUSED(nodeId)
    Q_UNUSED(data)
#endif
}

QString ClayNetwork::generateNetworkCode() const
{
    // Generate a 6-character network code (no ambiguous chars)
    const QString chars = QStringLiteral("ABCDEFGHJKLMNPQRSTUVWXYZ23456789");
    QString code;
    for (int i = 0; i < 6; ++i) {
        int idx = QRandomGenerator::global()->bounded(chars.length());
        code += chars.at(idx);
    }
    return code;
}

void ClayNetwork::onNetworkCreated(const char* networkId)
{
    networkId_ = QString::fromUtf8(networkId);
    nodeId_ = networkId_;
    isHost_ = true;
    connected_ = true;
    status_ = Connected;
    nodes_.clear();
    nodes_.append(nodeId_);

    emit networkIdChanged();
    emit nodeIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
    emit roomCreated(networkId_);
}

void ClayNetwork::onConnectedToNetwork(const char* nodeId)
{
    nodeId_ = QString::fromUtf8(nodeId);
    connected_ = true;
    status_ = Connected;
    nodes_.clear();
    nodes_.append(networkId_); // Add host
    nodes_.append(nodeId_);

    emit nodeIdChanged();
    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
}

void ClayNetwork::onNodeJoined(const char* nodeId)
{
    QString id = QString::fromUtf8(nodeId);
    if (!nodes_.contains(id)) {
        nodes_.append(id);
        emit nodesChanged();
        emit nodeCountChanged();
    }
    emit playerJoined(id);
}

void ClayNetwork::onNodeLeft(const char* nodeId)
{
    QString id = QString::fromUtf8(nodeId);
    if (nodes_.removeOne(id)) {
        emit nodesChanged();
        emit nodeCountChanged();
    }
    emit playerLeft(id);
}

void ClayNetwork::onMessage(const char* fromId, const char* data, bool isState)
{
    QString from = QString::fromUtf8(fromId);
    QString jsonStr = QString::fromUtf8(data);

    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (!doc.isObject()) return;

    QJsonObject obj = doc.object();

    // Handle unified wire format: {"t": "m/s", "d": {...}}
    QString type = obj["t"].toString();
    QVariant msgData;

    if (!type.isEmpty()) {
        // New unified format from Desktop or updated WASM
        msgData = obj["d"].toObject().toVariantMap();
        isState = (type == "s");
    } else {
        // Legacy format (old WASM): raw data with optional _clay_state marker
        obj.remove("_clay_state");
        msgData = obj.toVariantMap();
    }

    if (isState) {
        emit stateReceived(from, msgData);
    } else {
        emit messageReceived(from, msgData);
    }
}

void ClayNetwork::onError(const char* message)
{
    status_ = Error;
    emit statusChanged();
    emit errorOccurred(QString::fromUtf8(message));
}

void ClayNetwork::onDisconnected()
{
    connected_ = false;
    status_ = Disconnected;
    nodes_.clear();

    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
}
