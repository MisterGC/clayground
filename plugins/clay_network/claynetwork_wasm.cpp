// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claynetwork_wasm.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
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
        autoRelay: true,
        verbose: false,
        iceServers: null,
        pingTimers: new Map()
    };
});

// JavaScript: Set autoRelay property
EM_JS(void, js_set_auto_relay, (int instanceId, int autoRelay), {
    const state = Module.clayNetwork[instanceId];
    if (state) {
        state.autoRelay = autoRelay !== 0;
    }
});

// JavaScript: Set verbose mode
EM_JS(void, js_set_verbose, (int instanceId, int verbose), {
    const state = Module.clayNetwork[instanceId];
    if (state) {
        state.verbose = verbose !== 0;
    }
});

// JavaScript: Set ICE servers configuration
EM_JS(void, js_set_ice_servers, (int instanceId, const char* iceJson), {
    const state = Module.clayNetwork[instanceId];
    if (state) {
        const json = UTF8ToString(iceJson);
        state.iceServers = json ? JSON.parse(json) : null;
    }
});

// JavaScript: Set custom signaling URL
EM_JS(void, js_set_signaling_url, (int instanceId, const char* urlStr), {
    const state = Module.clayNetwork[instanceId];
    if (state) {
        state.signalingUrl = UTF8ToString(urlStr) || '';
    }
});

// JavaScript: Send ping to all peers
EM_JS(void, js_ping, (int instanceId), {
    const state = Module.clayNetwork[instanceId];
    if (!state || !state.verbose) return;

    const now = Date.now();
    const msg = JSON.stringify({t: 'p', ts: now});
    state.connections.forEach((conn, peerId) => {
        if (conn.open) {
            conn.send(JSON.parse(msg));
        }
    });
});

// JavaScript: Initialize helper functions on Module (called once)
EM_JS(void, js_init_helpers, (), {
    if (Module.clayHelpers) return;
    Module.clayHelpers = true;

    // Build PeerJS config with ICE servers and optional custom signaling
    Module.clayBuildPeerConfig = function(state) {
        var cfg = { debug: 1 };
        if (state.iceServers && state.iceServers.length > 0) {
            cfg.config = { iceServers: state.iceServers.map(function(s) {
                if (typeof s === 'string') return { urls: s };
                return s;
            })};
        }
        if (state.signalingUrl) {
            var url = new URL(state.signalingUrl);
            cfg.host = url.hostname;
            cfg.port = parseInt(url.port) || (url.protocol === 'wss:' ? 443 : 80);
            cfg.path = url.pathname;
            cfg.secure = url.protocol === 'wss:';
            cfg.key = 'peerjs';
        }
        return cfg;
    };

    // Emit diagnostic from JS
    Module.clayDiag = function(instanceId, phase, detail) {
        var state = Module.clayNetwork ? Module.clayNetwork[instanceId] : null;
        if (state && state.verbose) {
            Module._clay_net_diag(instanceId, stringToNewUTF8(phase), stringToNewUTF8(detail));
        }
    };

    // Setup ICE state tracking on a connection
    Module.clayTrackIce = function(instanceId, conn, peerId) {
        var state = Module.clayNetwork ? Module.clayNetwork[instanceId] : null;
        if (!state) return;
        try {
            var pc = conn.peerConnection;
            if (!pc) return;

            pc.addEventListener('iceconnectionstatechange', function() {
                Module.clayDiag(instanceId, 'ice', 'Peer ' + peerId.substring(0, 8) + ': ' + pc.iceConnectionState);
            });

            pc.addEventListener('icecandidate', function(event) {
                if (event.candidate) {
                    var c = event.candidate.candidate;
                    var type = 'unknown';
                    if (c.indexOf('typ host') >= 0) type = 'host';
                    else if (c.indexOf('typ srflx') >= 0) type = 'srflx';
                    else if (c.indexOf('typ relay') >= 0) type = 'relay';
                    else if (c.indexOf('typ prflx') >= 0) type = 'prflx';
                    Module.clayDiag(instanceId, 'ice', 'Candidate: ' + type + ' (' + peerId.substring(0, 8) + ')');
                }
            });
        } catch (e) {}
    };
});

// JavaScript: Create a network (become host)
EM_JS(void, js_create_network, (int instanceId, const char* networkCode, int topology, int maxNodes), {
    const networkId = UTF8ToString(networkCode);
    const state = Module.clayNetwork[instanceId];
    state.topology = topology;
    state.maxNodes = maxNodes;
    state._startTime = Date.now();

    Module.clayDiag(instanceId, 'signaling', 'Connecting to signaling...');

    Module.clayPeerJSReady.then(() => {
        const cfg = Module.clayBuildPeerConfig(state);
        // Host uses network code as peer ID for easy discovery
        state.peer = new Peer(networkId, cfg);

        state.peer.on('open', (id) => {
            console.log('[ClayNetwork] Network created:', id);
            state.networkId = id;
            state.nodeId = id;
            state.isHost = true;
            const sigMs = Date.now() - state._startTime;
            Module.clayDiag(instanceId, 'signaling', 'Signaling ready (' + sigMs + 'ms)');
            Module._clay_net_created(instanceId, stringToNewUTF8(id));
        });

        state.peer.on('connection', (conn) => {
            if (state.connections.size >= state.maxNodes - 1) {
                console.log('[ClayNetwork] Network full, rejecting:', conn.peer);
                Module.clayDiag(instanceId, 'signaling', 'Rejected ' + conn.peer.substring(0, 8) + ' (network full)');
                // Send rejection before closing
                conn.on('open', () => {
                    conn.send({ _clay_sys: 'rejected', reason: 'Network full' });
                    setTimeout(() => conn.close(), 100);
                });
                return;
            }

            console.log('[ClayNetwork] Node connecting:', conn.peer);
            state.connections.set(conn.peer, conn);
            Module.clayTrackIce(instanceId, conn, conn.peer);

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

                // Handle ping/pong (not relayed)
                if (parsed.t === 'p') {
                    conn.send({ t: 'P', ts: parsed.ts });
                    return;
                }
                if (parsed.t === 'P') {
                    const rtt = Date.now() - parsed.ts;
                    Module._clay_net_pong(instanceId, stringToNewUTF8(conn.peer), rtt);
                    return;
                }

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
    state._startTime = Date.now();

    Module.clayDiag(instanceId, 'signaling', 'Connecting to signaling...');

    Module.clayPeerJSReady.then(() => {
        const cfg = Module.clayBuildPeerConfig(state);
        // Generate random peer ID client-side (avoids HTTP /id request
        // which fails with custom signaling servers)
        const clientId = 'c' + Math.random().toString(36).substring(2, 16);
        state.peer = new Peer(clientId, cfg);

        state.peer.on('open', (id) => {
            console.log('[ClayNetwork] Client node ready:', id);
            state.nodeId = id;
            state.networkId = networkId;
            state.isHost = false;

            const sigMs = Date.now() - state._startTime;
            state._iceStart = Date.now();
            Module.clayDiag(instanceId, 'signaling', 'Signaling ready (' + sigMs + 'ms)');
            Module.clayDiag(instanceId, 'ice', 'Connecting to host...');

            // Connect to host - use 'json' serialization for string transfer
            const conn = state.peer.connect(networkId, { reliable: true, serialization: 'json' });
            state.connections.set(networkId, conn);
            Module.clayTrackIce(instanceId, conn, networkId);

            conn.on('open', () => {
                console.log('[ClayNetwork] Connected to network:', networkId);
                const totalMs = Date.now() - state._startTime;
                const iceMs = Date.now() - state._iceStart;
                Module.clayDiag(instanceId, 'datachannel', 'Data channel open (total: ' + totalMs + 'ms)');
                Module._clay_net_connected(instanceId, stringToNewUTF8(id));
            });

            conn.on('data', (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                const parsed = JSON.parse(msg);

                // Handle rejection
                if (parsed._clay_sys === 'rejected') {
                    Module._clay_net_error(instanceId, stringToNewUTF8(parsed.reason || 'Connection rejected'));
                    return;
                }

                // Handle system messages
                if (parsed._clay_sys === 'mesh_nodes') {
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

                // Handle ping/pong (not relayed)
                if (parsed.t === 'p') {
                    conn.send({ t: 'P', ts: parsed.ts });
                    return;
                }
                if (parsed.t === 'P') {
                    const rtt = Date.now() - parsed.ts;
                    Module._clay_net_pong(instanceId, stringToNewUTF8(networkId), rtt);
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
        Module.clayTrackIce(instanceId, conn, nodeId);

        conn.on('open', () => {
            console.log('[ClayNetwork] Mesh connected to:', nodeId);
        });

        conn.on('data', (data) => {
            const msg = typeof data === 'string' ? data : JSON.stringify(data);
            const parsed = JSON.parse(msg);
            if (parsed._clay_sys) return;

            // Handle ping/pong
            if (parsed.t === 'p') {
                conn.send({ t: 'P', ts: parsed.ts });
                return;
            }
            if (parsed.t === 'P') {
                const rtt = Date.now() - parsed.ts;
                Module._clay_net_pong(instanceId, stringToNewUTF8(nodeId), rtt);
                return;
            }

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

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_diag(int instanceId, const char* phase, const char* detail)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, phase, detail]() {
            net->onDiagnostic(phase, detail);
            free((void*)phase);
            free((void*)detail);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_pong(int instanceId, const char* peerId, int rtt)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, peerId, rtt]() {
            net->onPong(peerId, rtt);
            free((void*)peerId);
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
    js_init_helpers();
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

ClayNetwork::SignalingMode ClayNetwork::signalingMode() const
{
    return signalingMode_;
}

void ClayNetwork::setSignalingMode(SignalingMode mode)
{
    // WASM only supports Cloud mode - ignore attempts to set Local
    if (mode == Local) {
        qWarning() << "[ClayNetwork] LAN mode not supported in browser, using Internet mode";
        return;
    }
    if (signalingMode_ != mode) {
        signalingMode_ = mode;
        emit signalingModeChanged();
    }
}

QVariantList ClayNetwork::iceServers() const { return iceServers_; }
void ClayNetwork::setIceServers(const QVariantList &servers) {
    if (iceServers_ != servers) {
        iceServers_ = servers;
#ifdef __EMSCRIPTEN__
        // Convert to JSON array for JS
        QJsonArray arr;
        for (const QVariant &v : servers) {
            if (v.typeId() == QMetaType::QString) {
                arr.append(v.toString());
            } else if (v.typeId() == QMetaType::QVariantMap) {
                arr.append(QJsonObject::fromVariantMap(v.toMap()));
            }
        }
        QByteArray json = QJsonDocument(arr).toJson(QJsonDocument::Compact);
        js_set_ice_servers(instanceId_, json.constData());
#endif
        emit iceServersChanged();
    }
}

QString ClayNetwork::signalingUrl() const { return signalingUrl_; }
void ClayNetwork::setSignalingUrl(const QString &url) {
    if (signalingUrl_ != url) {
        signalingUrl_ = url;
#ifdef __EMSCRIPTEN__
        js_set_signaling_url(instanceId_, url.toUtf8().constData());
#endif
        emit signalingUrlChanged();
    }
}

bool ClayNetwork::verbose() const { return verbose_; }
void ClayNetwork::setVerbose(bool v) {
    if (verbose_ != v) {
        verbose_ = v;
#ifdef __EMSCRIPTEN__
        js_set_verbose(instanceId_, v ? 1 : 0);
#endif
        emit verboseChanged();
    }
}

QString ClayNetwork::connectionPhase() const { return connectionPhase_; }
QVariantMap ClayNetwork::phaseTiming() const { return phaseTiming_; }
int ClayNetwork::latency() const { return latency_; }
QVariantMap ClayNetwork::peerStats() const { return QVariantMap(); }

void ClayNetwork::setConnectionPhase(const QString &phase) {
    if (connectionPhase_ != phase) {
        connectionPhase_ = phase;
        emit connectionPhaseChanged();
    }
}

void ClayNetwork::emitDiag(const QString &phase, const QString &detail) {
    if (verbose_) {
        emit diagnosticMessage(phase, detail);
    }
}

void ClayNetwork::createRoom()
{
#ifdef __EMSCRIPTEN__
    if (connected_) {
        qWarning() << "[ClayNetwork] Already connected, leave first";
        return;
    }

    status_ = Connecting;
    setConnectionPhase("signaling");
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
    setConnectionPhase("signaling");
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
    connectionPhase_.clear();
    phaseTiming_.clear();
    latency_ = -1;
    peerLatencies_.clear();

    emit networkIdChanged();
    emit nodeIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
    emit connectionPhaseChanged();
    emit phaseTimingChanged();
    emit latencyChanged();
    emit peerStatsChanged();
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
    setConnectionPhase("");
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
    setConnectionPhase("");
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

void ClayNetwork::onDiagnostic(const char* phase, const char* detail)
{
    if (verbose_) {
        emit diagnosticMessage(QString::fromUtf8(phase), QString::fromUtf8(detail));
    }
}

void ClayNetwork::onPong(const char* peerId, int rtt)
{
    QString id = QString::fromUtf8(peerId);
    int prev = peerLatencies_.value(id, -1).toInt();
    int smoothed = (prev < 0) ? rtt : static_cast<int>(prev * 0.7 + rtt * 0.3);
    peerLatencies_[id] = smoothed;

    // Update best latency across all peers
    int best = -1;
    for (auto it = peerLatencies_.constBegin(); it != peerLatencies_.constEnd(); ++it) {
        int lat = it->toInt();
        if (lat >= 0 && (best < 0 || lat < best))
            best = lat;
    }
    if (latency_ != best) {
        latency_ = best;
        emit latencyChanged();
    }
    emit peerStatsChanged();
}

void ClayNetwork::ping()
{
#ifdef __EMSCRIPTEN__
    if (connected_ && verbose_) {
        js_ping(instanceId_);
    }
#endif
}
