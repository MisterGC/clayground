// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claynetwork_wasm.h"
#include "sender.h"
#include "handshake.h"
#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRandomGenerator>
#include <QUuid>

namespace hs = clay::network::handshake;

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/val.h>
#include <map>
#include "link_conditioner_js.h"  // generated from link_conditioner.js

// Global registry for callback routing
static std::map<int, ClayNetwork*> g_networkRegistry;
int ClayNetwork::nextInstanceId_ = 0;

// JavaScript: Load PeerJS library dynamically (CDN with local fallback)
EM_JS(void, js_load_peerjs, (), {
    if (Module.clayPeerJSLoaded) return;
    if (Module.clayPeerJSLoading) return;

    Module.clayPeerJSLoading = true;
    Module.clayPeerJSReady = new Promise((resolve, reject) => {
        // Already loaded externally (e.g. via <script> tag)?
        if (typeof Peer !== 'undefined') {
            Module.clayPeerJSLoaded = true;
            Module.clayPeerJSLoading = false;
            console.log('[ClayNetwork] PeerJS already available');
            resolve();
            return;
        }

        var onLoaded = function(src) {
            Module.clayPeerJSLoaded = true;
            Module.clayPeerJSLoading = false;
            console.log('[ClayNetwork] PeerJS loaded from ' + src);
            resolve();
        };

        var script = document.createElement('script');
        script.src = 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
        script.onload = function() { onLoaded('CDN'); };
        script.onerror = function() {
            // Fallback: load vendored local copy
            console.warn('[ClayNetwork] CDN unavailable, trying local fallback');
            var local = document.createElement('script');
            local.src = '/demo/webdojo/peerjs.min.js';
            local.onload = function() { onLoaded('local'); };
            local.onerror = function(e) {
                Module.clayPeerJSLoading = false;
                console.error('[ClayNetwork] Failed to load PeerJS', e);
                reject(e);
            };
            document.head.appendChild(local);
        };
        document.head.appendChild(script);
    });
});

// JavaScript: Evaluate the link conditioner (link_conditioner.js) once per page
EM_JS(void, js_install_conditioner, (const char* source), {
    if (Module.clayLinkConditioner) return;
    const module = { exports: {} };
    (new Function('module', UTF8ToString(source)))(module);
    Module.clayLinkConditioner = module.exports;
});

// JavaScript: Initialize network instance
EM_JS(void, js_init_network, (int instanceId), {
    if (!Module.clayNetwork) {
        Module.clayNetwork = {};
    }

    Module.clayNetwork[instanceId] = {
        peer: null,
        connections: new Map(),
        // Unordered/lossy companion connections (label 'clay_state') used
        // for high-frequency state updates
        stateConns: new Map(),
        networkId: null,
        nodeId: null,
        isHost: false,
        topology: 0, // 0 = Star, 1 = Mesh
        maxNodes: 8,
        autoRelay: true,
        verbose: false,
        iceServers: null,
        pingTimers: new Map(),
        // The signaling connection of a live network dropped and is being
        // re-established under the same id (#299)
        sessionUp: false,
        signalingDown: false,
        retryTimer: null,
        retryDelay: 0,
        // Simulated link (#301): every send() and every 'data' event of the
        // node's connections passes through it
        conditioner: Module.clayLinkConditioner.create()
    };
});

// JavaScript: Set the simulated link's conditions (normalized by C++)
EM_JS(void, js_set_link_conditions, (int instanceId, const char* json), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;
    const wasDropped = state.conditioner.dropSignaling();
    state.conditioner.setConditions(JSON.parse(UTF8ToString(json)));
    // Cut the signaling connection the way a server or network drop would;
    // the data connections stay, like they do on a real drop
    if (!wasDropped && state.conditioner.dropSignaling() && state.peer
        && !state.peer.disconnected && !state.peer.destroyed) {
        state.peer.disconnect();
    }
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
    if (!state) return;

    const now = Date.now();
    const msg = JSON.stringify({t: 'p', ts: now});
    state.connections.forEach((conn, peerId) => {
        if (Module.clayIsNode(conn)) {
            conn.send(JSON.parse(msg));
        }
    });
});

// JavaScript: Ping one peer (a quiet one, #299)
EM_JS(void, js_ping_peer, (int instanceId, const char* peerId), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;
    const conn = state.connections.get(UTF8ToString(peerId));
    if (conn && Module.clayIsNode(conn)) {
        conn.send({t: 'p', ts: Date.now()});
    }
});

// JavaScript: Initialize helper functions on Module (called once)
EM_JS(void, js_init_helpers, (), {
    if (Module.clayHelpers) return;
    Module.clayHelpers = true;

    // A connection that carries traffic: open, and past the handshake
    // (#323) - a joiner the host has not taken gets nothing but its answer
    Module.clayIsNode = function(conn) {
        return conn.open && !conn.__clayPending;
    };

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

    // Route a connection's send() through the node's link conditioner. The
    // size is only worked out when a bandwidth cap asks for it.
    Module.clayConditionSend = function(state, conn, stateChannel) {
        if (conn.__clayRawSend) return;
        const raw = conn.send.bind(conn);
        conn.__clayRawSend = raw;
        conn.send = function(obj) {
            state.conditioner.offer('out', stateChannel,
                function() { return JSON.stringify(obj).length; },
                function() { if (conn.open) raw(obj); });
        };
    };

    // Wrap a 'data' handler so what arrives passes the link conditioner first
    Module.clayConditionData = function(state, stateChannel, handler) {
        return function(data) {
            state.conditioner.offer('in', stateChannel,
                function() { return (typeof data === 'string' ? data : JSON.stringify(data)).length; },
                function() { handler(data); });
        };
    };

    // Signaling errors that mean the server connection is gone, not that a
    // request failed: once the session is up they start a reconnect (#299)
    Module.claySignalingErrors = ['network', 'socket-error', 'socket-closed',
                                  'server-error', 'unavailable-id', 'disconnected'];

    // The signaling connection of a live peer dropped: C++ hears of it once
    // per outage, and PeerJS reconnects under the same id until it is back
    Module.clayOnSignalingDown = function(instanceId, peer) {
        var state = Module.clayNetwork[instanceId];
        if (!state || state.peer !== peer || peer.destroyed) return;
        if (!state.signalingDown) {
            state.signalingDown = true;
            state.retryDelay = 0;
            Module._clay_net_signaling_lost(instanceId);
        }
        Module.clayRetrySignaling(instanceId, peer);
    };

    Module.clayRetrySignaling = function(instanceId, peer) {
        var state = Module.clayNetwork[instanceId];
        if (!state || state.retryTimer) return;
        state.retryDelay = state.retryDelay ? Math.min(state.retryDelay * 2, 4000) : 1000;
        state.retryTimer = setTimeout(function() {
            state.retryTimer = null;
            if (state.peer !== peer || peer.destroyed || !state.signalingDown) return;
            // Still dropped by the link conditioner, or a reconnect under way
            if (state.conditioner.dropSignaling() || !peer.disconnected) {
                Module.clayRetrySignaling(instanceId, peer);
                return;
            }
            Module.clayDiag(instanceId, 'signaling', 'Reconnecting to signaling as ' + state.nodeId);
            try {
                peer.reconnect();
            } catch (e) {
                Module.clayRetrySignaling(instanceId, peer);
            }
        }, state.retryDelay);
    };

    // A peer's 'open': true when it is a reconnect, which sets nothing up again
    Module.clayOnSignalingOpen = function(instanceId, peer) {
        var state = Module.clayNetwork[instanceId];
        if (!state || state.peer !== peer || !state.signalingDown) return false;
        state.signalingDown = false;
        state.retryDelay = 0;
        if (state.retryTimer) { clearTimeout(state.retryTimer); state.retryTimer = null; }
        Module._clay_net_signaling_restored(instanceId);
        return true;
    };

    // True when a peer error was a signaling drop and is handled as one
    Module.clayOnPeerError = function(instanceId, peer, err) {
        var state = Module.clayNetwork[instanceId];
        if (!state || state.peer !== peer) return true;
        if (state.sessionUp && Module.claySignalingErrors.indexOf(err.type) >= 0) {
            Module.clayDiag(instanceId, 'signaling', 'Signaling: ' + (err.message || err.type));
            Module.clayOnSignalingDown(instanceId, peer);
            return true;
        }
        return false;
    };

    // The host drops a joiner that said goodbye or went silent (#299): its
    // connection closes, C++ and the other joiners hear it left
    Module.clayDropPeer = function(instanceId, peerId) {
        var state = Module.clayNetwork[instanceId];
        if (!state) return;
        var conn = state.connections.get(peerId);
        if (!conn) return;
        state.connections.delete(peerId);
        var sc = state.stateConns.get(peerId);
        state.stateConns.delete(peerId);
        if (sc) { try { sc.close(); } catch (e) {} }
        try { conn.close(); } catch (e) {}
        Module._clay_net_node_left(instanceId, stringToNewUTF8(peerId));
        state.connections.forEach(function(c) {
            if (Module.clayIsNode(c)) c.send({ t: 'y', sys: 'node_left', nodeId: peerId });
        });
    };

    // The host takes a joiner that passed the handshake: the welcome first,
    // then its roster, then everyone else hears of it. False when the
    // joiner left while C++ was judging its hello - there is nobody to take.
    Module.clayAdmit = function(instanceId, peerId, welcome) {
        var state = Module.clayNetwork[instanceId];
        if (!state) return false;
        var conn = state.connections.get(peerId);
        if (!conn || !conn.__clayPending || !conn.open) return false;
        conn.__clayPending = false;
        conn.send(welcome);
        var others = [];
        state.connections.forEach(function(c, id) {
            if (id !== peerId && Module.clayIsNode(c)) others.push(id);
        });
        conn.send({ t: 'y', sys: 'roster', nodes: others });
        state.connections.forEach(function(c, id) {
            if (id !== peerId && Module.clayIsNode(c))
                c.send({ t: 'y', sys: 'node_joined', nodeId: peerId });
        });
        return true;
    };

    // The host refuses a joiner: it reads why, then its connection closes
    Module.clayRefuse = function(instanceId, peerId, refusal) {
        var state = Module.clayNetwork[instanceId];
        if (!state) return;
        var conn = state.connections.get(peerId);
        if (!conn || !conn.__clayPending) return;
        state.connections.delete(peerId);
        var sc = state.stateConns.get(peerId);
        state.stateConns.delete(peerId);
        if (sc) { try { sc.close(); } catch (e) {} }
        conn.send(refusal);
        setTimeout(function() { try { conn.close(); } catch (e) {} }, 200);
    };

    // Emit diagnostic from JS
    Module.clayDiag = function(instanceId, phase, detail) {
        var state = Module.clayNetwork ? Module.clayNetwork[instanceId] : null;
        if (state && state.verbose) {
            Module._clay_net_diag(instanceId, stringToNewUTF8(phase), stringToNewUTF8(detail));
        }
    };

    // Relay a state update to all other peers, preferring the lossy state
    // connection and falling back to the reliable one.
    Module.clayRelayState = function(state, parsed, exceptPeer) {
        state.connections.forEach(function(c, pid) {
            if (pid === exceptPeer || c.__clayPending) return;
            var sc = state.stateConns.get(pid);
            if (sc && sc.open) sc.send(parsed);
            else if (c.open) c.send(parsed);
        });
    };

    // Shared handler for data arriving on a state connection. Like every
    // message it goes to C++ with the peer at the other end of the link;
    // C++ decides whether a "from" in it counts (attributeSender, #298).
    Module.clayOnStateData = function(instanceId, peerId, data) {
        var state = Module.clayNetwork[instanceId];
        if (!state) return;
        // Only a node's state counts, and only a node's is relayed (#323)
        var link = state.connections.get(peerId);
        if (!link || link.__clayPending) return;
        var msg = typeof data === 'string' ? data : JSON.stringify(data);
        var parsed = JSON.parse(msg);
        if (state.isHost && state.autoRelay && state.topology === 0) {
            parsed.from = peerId;
            Module.clayRelayState(state, parsed, peerId);
            msg = JSON.stringify(parsed);
        }
        Module._clay_net_message(instanceId,
            stringToNewUTF8(peerId), stringToNewUTF8(msg), 1);
    };

    // Attach handlers to an incoming state connection
    Module.claySetupStateConn = function(instanceId, peerId, conn) {
        var state = Module.clayNetwork[instanceId];
        if (!state) return;
        state.stateConns.set(peerId, conn);
        Module.clayConditionSend(state, conn, true);
        conn.on('data', Module.clayConditionData(state, true, function(d) {
            Module.clayOnStateData(instanceId, peerId, d);
        }));
        conn.on('close', function() {
            if (state.stateConns.get(peerId) === conn)
                state.stateConns.delete(peerId);
        });
        conn.on('error', function() {});
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
EM_JS(void, js_create_network, (int instanceId, const char* networkCode, int topology, int maxNodes,
                                int handshakeTimeoutMs), {
    const networkId = UTF8ToString(networkCode);
    const state = Module.clayNetwork[instanceId];
    state.topology = topology;
    state.maxNodes = maxNodes;
    state._startTime = Date.now();

    Module.clayDiag(instanceId, 'signaling', 'Connecting to signaling...');

    Module.clayPeerJSReady.then(() => {
        const cfg = Module.clayBuildPeerConfig(state);
        // Host uses network code as peer ID for easy discovery
        const peer = new Peer(networkId, cfg);
        state.peer = peer;

        peer.on('open', (id) => {
            if (Module.clayOnSignalingOpen(instanceId, peer)) return;
            if (state.peer !== peer) return;
            state.sessionUp = true;
            console.log('[ClayNetwork] Network created:', id);
            state.networkId = id;
            state.nodeId = id;
            state.isHost = true;
            const sigMs = Date.now() - state._startTime;
            Module.clayDiag(instanceId, 'signaling', 'Signaling ready (' + sigMs + 'ms)');
            Module._clay_net_created(instanceId, stringToNewUTF8(id));
        });

        peer.on('connection', (conn) => {
            if (state.peer !== peer) return;
            // Companion state connection of an already-known node - not of
            // a peer still in the handshake, refused or never seen (#323)
            if (conn.label === 'clay_state') {
                const link = state.connections.get(conn.peer);
                if (!link || link.__clayPending) {
                    Module.clayDiag(instanceId, 'datachannel',
                        'Closed a state connection from ' + conn.peer.substring(0, 8) + ', no node');
                    try { conn.close(); } catch (e) {}
                    return;
                }
                Module.claySetupStateConn(instanceId, conn.peer, conn);
                return;
            }

            if (state.connections.size >= state.maxNodes - 1) {
                console.log('[ClayNetwork] Network full, rejecting:', conn.peer);
                Module.clayDiag(instanceId, 'signaling', 'Rejected ' + conn.peer.substring(0, 8) + ' (network full)');
                // Send rejection before closing
                conn.on('open', () => {
                    conn.send({ t: 'R', r: 'Network full' });
                    setTimeout(() => conn.close(), 100);
                });
                return;
            }

            console.log('[ClayNetwork] Node connecting:', conn.peer);
            state.connections.set(conn.peer, conn);
            Module.clayConditionSend(state, conn, false);
            Module.clayTrackIce(instanceId, conn, conn.peer);

            // No node until it passed the handshake (#323): its first
            // message goes to C++, which admits or refuses it - and so
            // does silence (Module.clayAdmit, Module.clayRefuse)
            conn.__clayPending = true;
            const judge = (msg) => {
                if (conn.__clayJudging) return;
                conn.__clayJudging = true;
                Module._clay_net_hello(instanceId, stringToNewUTF8(conn.peer), stringToNewUTF8(msg));
            };
            conn.on('open', () => {
                console.log('[ClayNetwork] Node connected, awaiting its hello:', conn.peer);
                setTimeout(() => {
                    if (conn.__clayPending && state.connections.get(conn.peer) === conn) judge('{}');
                }, handshakeTimeoutMs);
            });

            conn.on('data', Module.clayConditionData(state, false, (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                if (conn.__clayPending) {
                    judge(msg);
                    return;
                }
                const parsed = JSON.parse(msg);

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
                if (parsed.t === 'y') {
                    // A joiner that leaves says so (#299)
                    if (parsed.sys === 'bye') Module.clayDropPeer(instanceId, conn.peer);
                    return;
                }

                // Host in Star topology: relay to other peers if autoRelay is on
                let outMsg = msg;
                if (state.isHost && state.autoRelay && state.topology === 0) {
                    // Add "from" field for receivers to know original sender
                    parsed.from = conn.peer;
                    outMsg = JSON.stringify(parsed);
                    if (parsed.t === 's') {
                        Module.clayRelayState(state, parsed, conn.peer);
                    } else {
                        state.connections.forEach((c, peerId) => {
                            if (peerId !== conn.peer && Module.clayIsNode(c)) {
                                c.send(parsed);
                            }
                        });
                    }
                }

                const isState = parsed.t === 's';
                Module._clay_net_message(instanceId,
                    stringToNewUTF8(conn.peer),
                    stringToNewUTF8(outMsg),
                    isState ? 1 : 0);
            }));

            conn.on('close', () => {
                // Not ours any more: dropped already, or the network was left
                if (state.connections.get(conn.peer) !== conn) return;
                console.log('[ClayNetwork] Node left:', conn.peer);
                state.connections.delete(conn.peer);
                const sc = state.stateConns.get(conn.peer);
                if (sc) { try { sc.close(); } catch (e) {} }
                state.stateConns.delete(conn.peer);
                // Gone in the handshake: it never was a node
                if (conn.__clayPending) return;
                Module._clay_net_node_left(instanceId, stringToNewUTF8(conn.peer));

                // Notify other nodes
                state.connections.forEach((c) => {
                    if (Module.clayIsNode(c)) c.send({ t: 'y', sys: 'node_left', nodeId: conn.peer });
                });
            });

            conn.on('error', (err) => {
                console.error('[ClayNetwork] Connection error:', err);
            });
        });

        peer.on('error', (err) => {
            if (Module.clayOnPeerError(instanceId, peer, err)) return;
            console.error('[ClayNetwork] Peer error:', err);
            Module._clay_net_error(instanceId, stringToNewUTF8(err.message || err.type));
        });

        // Only the server connection: the joiners' data connections stay
        peer.on('disconnected', () => {
            console.log('[ClayNetwork] Disconnected from signaling');
            Module.clayOnSignalingDown(instanceId, peer);
        });
    }).catch((err) => {
        Module._clay_net_error(instanceId, stringToNewUTF8('Failed to load PeerJS'));
    });
});

// JavaScript: Join an existing network
EM_JS(void, js_join_network, (int instanceId, const char* networkCode, int topology,
                              const char* helloJson), {
    const networkId = UTF8ToString(networkCode);
    const hello = JSON.parse(UTF8ToString(helloJson));
    const state = Module.clayNetwork[instanceId];
    state.topology = topology;
    state._startTime = Date.now();

    Module.clayDiag(instanceId, 'signaling', 'Connecting to signaling...');

    Module.clayPeerJSReady.then(() => {
        const cfg = Module.clayBuildPeerConfig(state);
        // Generate random peer ID client-side (avoids HTTP /id request
        // which fails with custom signaling servers)
        const clientId = 'c' + Math.random().toString(36).substring(2, 16);
        const peer = new Peer(clientId, cfg);
        state.peer = peer;

        peer.on('open', (id) => {
            if (Module.clayOnSignalingOpen(instanceId, peer)) return;
            if (state.peer !== peer) return;
            state.sessionUp = true;
            console.log('[ClayNetwork] Client node ready:', id);
            state.nodeId = id;
            state.networkId = networkId;
            state.isHost = false;

            const sigMs = Date.now() - state._startTime;
            state._iceStart = Date.now();
            Module.clayDiag(instanceId, 'signaling', 'Signaling ready (' + sigMs + 'ms)');
            Module._clay_net_phase(instanceId, stringToNewUTF8('ice'), sigMs);
            Module.clayDiag(instanceId, 'ice', 'Connecting to host...');

            // Connect to host - use 'json' serialization for string transfer
            const conn = state.peer.connect(networkId, { reliable: true, serialization: 'json' });
            state.connections.set(networkId, conn);
            Module.clayConditionSend(state, conn, false);
            Module.clayTrackIce(instanceId, conn, networkId);

            // The joiner speaks first, and the host's first answer - its
            // welcome or a refusal - goes to C++ to judge (#323)
            let welcomed = false;
            conn.on('open', () => {
                const totalMs = Date.now() - state._startTime;
                Module.clayDiag(instanceId, 'datachannel', 'Data channel open (' + totalMs + 'ms), saying hello');
                Module._clay_net_phase(instanceId, stringToNewUTF8('handshake'),
                                       Date.now() - state._iceStart);
                conn.send(hello);
            });

            conn.on('data', Module.clayConditionData(state, false, (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                const parsed = JSON.parse(msg);

                if (!welcomed) {
                    if (parsed.t === 'H') {
                        welcomed = true;
                        console.log('[ClayNetwork] Connected to network:', networkId);
                        // Companion lossy connection for state updates
                        const sconn = state.peer.connect(networkId,
                            { label: 'clay_state', reliable: false, serialization: 'json' });
                        Module.claySetupStateConn(instanceId, networkId, sconn);
                    }
                    Module._clay_net_handshake_reply(instanceId, stringToNewUTF8(id), stringToNewUTF8(msg));
                    return;
                }

                // Handle rejection
                if (parsed.t === 'R') {
                    Module._clay_net_error(instanceId, stringToNewUTF8(parsed.r || 'Connection rejected'));
                    return;
                }

                // Roster and mesh bootstrap from the host
                if (parsed.t === 'y') {
                    if (parsed.sys === 'mesh_nodes' && state.topology === 1) {
                        parsed.nodes.forEach((nodeId) => {
                            if (!state.connections.has(nodeId)) {
                                const nodeConn = state.peer.connect(nodeId, { reliable: true, serialization: 'json' });
                                state.connections.set(nodeId, nodeConn);
                                setupNodeConnection(instanceId, nodeId, nodeConn);
                            }
                        });
                        return;
                    }
                    if (parsed.sys === 'node_joined' && state.topology === 1
                        && !state.connections.has(parsed.nodeId)) {
                        const nodeConn = state.peer.connect(parsed.nodeId, { reliable: true, serialization: 'json' });
                        state.connections.set(parsed.nodeId, nodeConn);
                        setupNodeConnection(instanceId, parsed.nodeId, nodeConn);
                    }
                    if (parsed.sys === 'node_left') {
                        state.connections.delete(parsed.nodeId);
                    }
                    Module._clay_net_system(instanceId, stringToNewUTF8(msg));
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

                // The link peer is the host; C++ takes a relayed "from" from it
                const isState = parsed.t === 's';
                Module._clay_net_message(instanceId,
                    stringToNewUTF8(networkId),
                    stringToNewUTF8(msg),
                    isState ? 1 : 0);
            }));

            conn.on('close', () => {
                if (state.connections.get(networkId) !== conn) return;
                console.log('[ClayNetwork] Disconnected from network');
                state.connections.delete(networkId);
                Module._clay_net_disconnected(instanceId);
            });

            conn.on('error', (err) => {
                console.error('[ClayNetwork] Connection error:', err);
                Module._clay_net_error(instanceId, stringToNewUTF8(err.message || 'Connection failed'));
            });
        });

        peer.on('connection', (conn) => {
            if (state.peer !== peer) return;
            if (conn.label === 'clay_state') {
                Module.claySetupStateConn(instanceId, conn.peer, conn);
                return;
            }
            // Accept incoming connections (mesh topology)
            console.log('[ClayNetwork] Incoming mesh connection:', conn.peer);
            state.connections.set(conn.peer, conn);
            setupNodeConnection(instanceId, conn.peer, conn);
        });

        peer.on('error', (err) => {
            if (Module.clayOnPeerError(instanceId, peer, err)) return;
            console.error('[ClayNetwork] Peer error:', err);
            Module._clay_net_error(instanceId, stringToNewUTF8(err.message || err.type));
        });

        peer.on('disconnected', () => {
            console.log('[ClayNetwork] Disconnected from signaling');
            Module.clayOnSignalingDown(instanceId, peer);
        });
    }).catch((err) => {
        Module._clay_net_error(instanceId, stringToNewUTF8('Failed to load PeerJS'));
    });

    // Helper to setup node connection handlers
    function setupNodeConnection(instanceId, nodeId, conn) {
        Module.clayConditionSend(state, conn, false);
        Module.clayTrackIce(instanceId, conn, nodeId);

        conn.on('open', () => {
            console.log('[ClayNetwork] Mesh connected to:', nodeId);
        });

        conn.on('data', Module.clayConditionData(state, false, (data) => {
            const msg = typeof data === 'string' ? data : JSON.stringify(data);
            const parsed = JSON.parse(msg);
            if (parsed.t === 'y') return;

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

            // A Mesh link speaks for its own peer only: C++ ignores any
            // "from" in it, the message belongs to nodeId
            const isState = parsed.t === 's';
            Module._clay_net_message(instanceId,
                stringToNewUTF8(nodeId),
                stringToNewUTF8(msg),
                isState ? 1 : 0);
        }));

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
        if (Module.clayIsNode(conn)) {
            conn.send(obj);
        }
    });
});

// JavaScript: Broadcast a state update - lossy channel where available
EM_JS(void, js_broadcast_state, (int instanceId, const char* data), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;

    const msg = UTF8ToString(data);
    const obj = JSON.parse(msg);
    state.connections.forEach((conn, peerId) => {
        if (conn.__clayPending) return;
        const sc = state.stateConns.get(peerId);
        if (sc && sc.open) {
            sc.send(obj);
        } else if (conn.open) {
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
    if (conn && Module.clayIsNode(conn)) {
        conn.send(obj);
    }
});

// JavaScript: Leave network and cleanup. The state is reset at once; with
// goodbye, every open connection is told first and closed a moment later.
EM_JS(void, js_leave, (int instanceId, int goodbye), {
    const state = Module.clayNetwork[instanceId];
    if (!state) return;

    // Nothing still on the simulated link outlives the network it was for
    state.conditioner.clear();
    if (state.retryTimer) { clearTimeout(state.retryTimer); state.retryTimer = null; }
    state.sessionUp = false;
    state.signalingDown = false;
    state.retryDelay = 0;

    // Handlers check that their peer and connections are still the
    // state's, so what closes below reports nothing back
    const peer = state.peer;
    const conns = Array.from(state.connections.values());
    const stateConns = Array.from(state.stateConns.values());
    state.peer = null;
    state.connections.clear();
    state.stateConns.clear();
    state.networkId = null;
    state.nodeId = null;
    state.isHost = false;

    // Past the link conditioner, which was just cleared (#299)
    let said = false;
    if (goodbye) {
        conns.forEach((conn) => {
            if (!conn.open) return;
            try {
                (conn.__clayRawSend || conn.send.bind(conn))({ t: 'y', sys: 'bye' });
                said = true;
            } catch (e) {}
        });
    }
    const closeAll = () => {
        stateConns.forEach((conn) => { try { conn.close(); } catch (e) {} });
        conns.forEach((conn) => { try { conn.close(); } catch (e) {} });
        if (peer) { try { peer.destroy(); } catch (e) {} }
    };
    // Closing tears the peer connection down, the goodbye has to be out first
    if (said) setTimeout(closeAll, 200);
    else closeAll();
});

// JavaScript: Drop one peer (host side, #299)
EM_JS(void, js_drop_peer, (int instanceId, const char* peerId), {
    Module.clayDropPeer(instanceId, UTF8ToString(peerId));
});

// JavaScript: Take or refuse a joiner after its handshake (host side, #323)
EM_JS(int, js_admit, (int instanceId, const char* peerId, const char* welcomeJson), {
    return Module.clayAdmit(instanceId, UTF8ToString(peerId),
                            JSON.parse(UTF8ToString(welcomeJson))) ? 1 : 0;
});

EM_JS(void, js_refuse, (int instanceId, const char* peerId, const char* refusalJson), {
    Module.clayRefuse(instanceId, UTF8ToString(peerId), JSON.parse(UTF8ToString(refusalJson)));
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
void clay_net_system(int instanceId, const char* json)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, json]() {
            net->onSystem(json);
            free((void*)json);
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
void clay_net_signaling_lost(int instanceId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second]() {
            net->onSignalingLost();
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_signaling_restored(int instanceId)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second]() {
            net->onSignalingRestored();
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
void clay_net_hello(int instanceId, const char* peerId, const char* json)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, peerId, json]() {
            net->onHello(peerId, json);
            free((void*)peerId);
            free((void*)json);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_handshake_reply(int instanceId, const char* nodeId, const char* json)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, nodeId, json]() {
            net->onHandshakeReply(nodeId, json);
            free((void*)nodeId);
            free((void*)json);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_net_phase(int instanceId, const char* phase, int ms)
{
    auto it = g_networkRegistry.find(instanceId);
    if (it != g_networkRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [net = it->second, phase, ms]() {
            net->onPhase(phase, ms);
            free((void*)phase);
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
    , clientToken_(QUuid::createUuid().toString(QUuid::WithoutBraces))
    , wireVersion_(hs::kWireVersion)
{
    clock_.start();
    livenessCheck_.setSingleShot(true);
    livenessCheck_.setTimerType(Qt::PreciseTimer);
    QObject::connect(&livenessCheck_, &QTimer::timeout, this, &ClayNetwork::checkLiveness);
    // A link peer quiet for 0.5 s gets a ping of its own, checked every 250 ms
    quietProbe_.setInterval(250);
    quietProbe_.setTimerType(Qt::PreciseTimer);
    QObject::connect(&quietProbe_, &QTimer::timeout, this, &ClayNetwork::probeQuietPeers);
#ifdef __EMSCRIPTEN__
    instanceId_ = nextInstanceId_++;
    g_networkRegistry[instanceId_] = this;
    js_load_peerjs();
    js_init_helpers();
    js_install_conditioner(kLinkConditionerJs);
    js_init_network(instanceId_);
#endif
}

ClayNetwork::~ClayNetwork()
{
#ifdef __EMSCRIPTEN__
    js_leave(instanceId_, 1);
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

QString ClayNetwork::hostId() const
{
    return hostId_;
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
    // nodes_ holds all OTHER nodes; self counts on top (matches native)
    return connected_ ? nodes_.size() + 1 : 0;
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

bool ClayNetwork::verifySignalingCertificate() const { return verifySignalingCertificate_; }
void ClayNetwork::setVerifySignalingCertificate(bool verify) {
    if (verifySignalingCertificate_ != verify) {
        verifySignalingCertificate_ = verify;
        emit verifySignalingCertificateChanged();
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

QVariantMap ClayNetwork::peerStats() const {
    QVariantMap stats;
    for (auto it = peerLatencies_.constBegin(); it != peerLatencies_.constEnd(); ++it) {
        QVariantMap ps;
        ps["latency"] = it.value();
        stats[it.key()] = ps;
    }
    return stats;
}

QVariantMap ClayNetwork::syncStats() const {
    QVariantMap stats;
    qint64 now = clock_.elapsed();
    for (auto it = stateLastMs_.constBegin(); it != stateLastMs_.constEnd(); ++it) {
        QVariantMap ss;
        ss["seq"] = stateSeqIn_.value(it.key(), 0);
        ss["recv"] = stateRecvCount_.value(it.key(), 0);
        ss["dropped"] = stateDropCount_.value(it.key(), 0);
        ss["ageMs"] = static_cast<qint64>(now - it.value());
        stats[it.key()] = ss;
    }
    return stats;
}

QVariantMap ClayNetwork::linkConditions() const { return conditions_.conditions(); }

void ClayNetwork::setLinkConditions(const QVariantMap &conditions)
{
    conditions_.setConditions(conditions);
#ifdef __EMSCRIPTEN__
    const QByteArray json = QJsonDocument(QJsonObject::fromVariantMap(conditions_.conditions()))
                                .toJson(QJsonDocument::Compact);
    js_set_link_conditions(instanceId_, json.constData());
#endif
    emit linkConditionsChanged();
}

int ClayNetwork::gracePeriod() const { return gracePeriod_; }
void ClayNetwork::setGracePeriod(int ms) {
    if (gracePeriod_ != ms) {
        gracePeriod_ = ms;
        armLivenessCheck();
        emit gracePeriodChanged();
    }
}

bool ClayNetwork::acceptingJoins() const { return acceptingJoins_; }
void ClayNetwork::setAcceptingJoins(bool accepting) {
    if (acceptingJoins_ != accepting) {
        acceptingJoins_ = accepting;
        emit acceptingJoinsChanged();
    }
}

QString ClayNetwork::password() const { return password_; }
void ClayNetwork::setPassword(const QString &password) {
    if (password_ != password) {
        password_ = password;
        emit passwordChanged();
    }
}

QString ClayNetwork::appId() const { return appId_; }
void ClayNetwork::setAppId(const QString &appId) {
    if (appId_ != appId) {
        appId_ = appId;
        emit appIdChanged();
    }
}

QString ClayNetwork::clientToken() const { return clientToken_; }
void ClayNetwork::setClientToken(const QString &token) {
    if (clientToken_ != token) {
        clientToken_ = token;
        emit clientTokenChanged();
    }
}

QVariantMap ClayNetwork::clientTokens() const { return clientTokens_; }

int ClayNetwork::wireVersion() const { return wireVersion_; }
void ClayNetwork::setWireVersion(int version) {
    if (wireVersion_ != version) {
        wireVersion_ = version;
        emit wireVersionChanged();
    }
}

void ClayNetwork::heard(const QString &linkPeer) {
    unansweredSinceMs_.remove(linkPeer);
    lastHeardMs_[linkPeer] = clock_.elapsed();
    // From the first link on, not only from the first 2 s ping
    if (gracePeriod_ > 0 && !quietProbe_.isActive())
        quietProbe_.start();
}

bool ClayNetwork::refuseWhileSignalingDropped()
{
    if (!conditions_.dropSignaling())
        return false;
    status_ = Error;
    emit statusChanged();
    emit errorOccurred("Signaling server unreachable (link conditioner)");
    return true;
}

int ClayNetwork::stateAgeMs(const QString &nodeId) const {
    if (!stateLastMs_.contains(nodeId))
        return -1;
    return static_cast<int>(clock_.elapsed() - stateLastMs_.value(nodeId));
}

void ClayNetwork::forgetSender(const QString &nodeId) {
    stateSeqIn_.remove(nodeId);
    stateLastMs_.remove(nodeId);
    stateRecvCount_.remove(nodeId);
    stateDropCount_.remove(nodeId);
}

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
    if (refuseWhileSignalingDropped())
        return;

    status_ = Connecting;
    connectStartMs_ = clock_.elapsed();
    handshakeStartMs_ = -1;
    phaseTiming_.clear();
    setConnectionPhase("signaling");
    emit statusChanged();

    QString networkCode = generateNetworkCode();
    QByteArray codeBytes = networkCode.toUtf8();
    js_create_network(instanceId_, codeBytes.constData(), static_cast<int>(topology_), maxNodes_,
                      hs::kTimeoutMs);
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
    if (refuseWhileSignalingDropped())
        return;

    // Kept here as well as in JS: the code is the host's PeerJS id
    // (js_create_network), so a joiner's hostId and roster entry come from it
    networkId_ = networkId.toUpper();
    hostId_ = networkId_;
    emit networkIdChanged();
    emit hostIdChanged();

    status_ = Connecting;
    connectStartMs_ = clock_.elapsed();
    handshakeStartMs_ = -1;
    phaseTiming_.clear();
    setConnectionPhase("signaling");
    emit statusChanged();

    QByteArray codeBytes = networkId_.toUtf8();
    const QByteArray hello = QJsonDocument(
        hs::hello(wireVersion_, appId_, password_, clientToken_)).toJson(QJsonDocument::Compact);
    js_join_network(instanceId_, codeBytes.constData(), static_cast<int>(topology_),
                    hello.constData());
#else
    Q_UNUSED(networkId)
    qWarning() << "[ClayNetwork] WASM backend not available on this platform";
#endif
}

void ClayNetwork::leave()
{
    tearDown(true);
}

void ClayNetwork::tearDown(bool goodbye)
{
#ifdef __EMSCRIPTEN__
    js_leave(instanceId_, goodbye ? 1 : 0);
    unansweredSinceMs_.clear();
    lastHeardMs_.clear();
    livenessCheck_.stop();
    quietProbe_.stop();
    signalingDown_ = false;
    setAcceptingJoins(false);

    networkId_.clear();
    nodeId_.clear();
    hostId_.clear();
    isHost_ = false;
    connected_ = false;
    nodes_.clear();
    status_ = Disconnected;
    connectionPhase_.clear();
    phaseTiming_.clear();
    latency_ = -1;
    peerLatencies_.clear();
    stateSeqOut_ = 0;
    stateSeqIn_.clear();
    stateLastMs_.clear();
    stateRecvCount_.clear();
    stateDropCount_.clear();
    clientTokens_.clear();

    emit networkIdChanged();
    emit nodeIdChanged();
    emit hostIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
    emit connectionPhaseChanged();
    emit phaseTimingChanged();
    emit latencyChanged();
    emit peerStatsChanged();
    emit clientTokensChanged();
#else
    Q_UNUSED(goodbye)
#endif
}

void ClayNetwork::loseHost(const QString &reason)
{
    // Every other node was reached through the host: the network is gone
    qWarning() << "[ClayNetwork]" << reason;
    const QStringList gone = nodes_;
    tearDown(false);
    for (const QString &id : gone)
        emit playerLeft(id);
    emit errorOccurred(reason);
}

void ClayNetwork::removeNode(const QString &nodeId)
{
    unansweredSinceMs_.remove(nodeId);
    lastHeardMs_.remove(nodeId);
    forgetSender(nodeId);
    if (clientTokens_.remove(nodeId) > 0)
        emit clientTokensChanged();
    if (nodes_.removeOne(nodeId)) {
        emit nodesChanged();
        emit nodeCountChanged();
        emit playerLeft(nodeId);
    }
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
    // Same wire format as Desktop: {"t": "s", "q": seq, "ts": sender ms, "d": {...}}
    QJsonObject msg;
    msg["t"] = "s";
    msg["q"] = static_cast<qint64>(++stateSeqOut_);
    msg["ts"] = static_cast<double>(QDateTime::currentMSecsSinceEpoch());
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QByteArray json = QJsonDocument(msg).toJson(QJsonDocument::Compact);
    js_broadcast_state(instanceId_, json.constData());
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

void ClayNetwork::sendRaw(const QString &nodeId, const QString &json)
{
#ifdef __EMSCRIPTEN__
    QByteArray nodeBytes = nodeId.toUtf8();
    QByteArray jsonBytes = json.toUtf8();
    js_send_to(instanceId_, nodeBytes.constData(), jsonBytes.constData());
#else
    Q_UNUSED(nodeId)
    Q_UNUSED(json)
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
    // The host's PeerJS id is the network code (js_create_network)
    hostId_ = networkId_;
    isHost_ = true;
    connected_ = true;
    status_ = Connected;
    // As on native: a host's connecting is its signaling
    const qint64 totalMs = clock_.elapsed() - connectStartMs_;
    phaseTiming_["signaling"] = totalMs;
    phaseTiming_["total"] = totalMs;
    emit phaseTimingChanged();
    setConnectionPhase("");
    nodes_.clear();
    setAcceptingJoins(true);

    emit networkIdChanged();
    emit nodeIdChanged();
    emit hostIdChanged();
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
    const qint64 now = clock_.elapsed();
    if (handshakeStartMs_ >= 0)
        phaseTiming_["handshake"] = now - handshakeStartMs_;
    phaseTiming_["total"] = now - connectStartMs_;
    emit phaseTimingChanged();
    setConnectionPhase("");
    nodes_.clear();
    nodes_.append(hostId_); // Add host; other joiners arrive via roster
    heard(hostId_);

    emit nodeIdChanged();
    emit connectedChanged();
    emit nodesChanged();
    emit nodeCountChanged();
    emit statusChanged();
}

void ClayNetwork::onNodeJoined(const char* nodeId)
{
    QString id = QString::fromUtf8(nodeId);
    heard(id);
    if (!nodes_.contains(id)) {
        nodes_.append(id);
        emit nodesChanged();
        emit nodeCountChanged();
    }
    emit playerJoined(id);
}

void ClayNetwork::onNodeLeft(const char* nodeId)
{
    // Once per node: a dropped peer's close may report it again
    removeNode(QString::fromUtf8(nodeId));
}

void ClayNetwork::onSystem(const char* json)
{
    QJsonDocument doc = QJsonDocument::fromJson(QByteArray(json));
    if (!doc.isObject()) return;
    QJsonObject obj = doc.object();
    QString sys = obj["sys"].toString();
    // Only the host sends system messages, over the joiner's one link
    heard(hostId_);

    if (sys == "bye") {
        loseHost(QStringLiteral("The host left the network"));
    } else if (sys == "roster") {
        QStringList added;
        for (const auto &v : obj["nodes"].toArray()) {
            QString id = v.toString();
            if (id != nodeId_ && !nodes_.contains(id)) {
                nodes_.append(id);
                added.append(id);
            }
        }
        if (!added.isEmpty()) {
            emit nodesChanged();
            emit nodeCountChanged();
            for (const QString &id : added)
                emit playerJoined(id);
        }
    } else if (sys == "node_joined") {
        QString id = obj["nodeId"].toString();
        if (!id.isEmpty() && id != nodeId_ && !nodes_.contains(id)) {
            nodes_.append(id);
            emit nodesChanged();
            emit nodeCountChanged();
            emit playerJoined(id);
        }
    } else if (sys == "node_left") {
        removeNode(obj["nodeId"].toString());
    }
}

void ClayNetwork::onMessage(const char* linkPeerId, const char* data, bool isState)
{
    QString linkPeer = QString::fromUtf8(linkPeerId);
    QString jsonStr = QString::fromUtf8(data);
    heard(linkPeer);

    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (!doc.isObject()) return;

    QJsonObject obj = doc.object();

    // The link vouches for the sender, not the message: only the host's
    // relay may name another node, and that node must be in the roster
    QString from = clay::network::attributeSender(
        linkPeer, obj["from"].toString(), isHost_, hostId_, nodes_);
    if (from.isEmpty()) {
        emitDiag("datachannel", QString("Dropped message over %1 from unknown node %2")
                 .arg(linkPeer.left(8), obj["from"].toString().left(8)));
        return;
    }

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
        // Unordered channel: drop anything at or behind the newest seq
        if (obj.contains("q")) {
            auto seq = static_cast<quint32>(obj["q"].toDouble());
            if (stateSeqIn_.contains(from) && seq <= stateSeqIn_.value(from)) {
                stateDropCount_[from]++;
                return;
            }
            stateSeqIn_[from] = seq;
        }
        stateRecvCount_[from]++;
        stateLastMs_[from] = clock_.elapsed();
        double sentAt = obj.contains("ts") ? obj["ts"].toDouble() : -1.0;
        emit stateReceived(from, msgData, sentAt);
    } else {
        emit messageReceived(from, msgData);
    }
}

void ClayNetwork::onHello(const char* peerId, const char* json)
{
#ifdef __EMSCRIPTEN__
    const QString peer = QString::fromUtf8(peerId);
    const QByteArray peerBytes = peer.toUtf8();
    const QJsonObject obj = QJsonDocument::fromJson(QByteArray(json)).object();
    const auto v = hs::judgeHello(obj, wireVersion_, appId_, password_);
    if (!v.ok()) {
        qWarning() << "[ClayNetwork] Refused" << peer << "-" << v.message;
        emitDiag("datachannel", QString("Refused %1: %2").arg(peer.left(8), v.message));
        const QByteArray refusal = QJsonDocument(hs::refusal(v)).toJson(QJsonDocument::Compact);
        js_refuse(instanceId_, peerBytes.constData(), refusal.constData());
        return;
    }
    const QByteArray welcome = QJsonDocument(hs::welcome(nodeId_, wireVersion_))
                                   .toJson(QJsonDocument::Compact);
    // The hello was judged a queued call after it arrived: a joiner that
    // closed in between is gone, and no close will ever report it as left
    if (!js_admit(instanceId_, peerBytes.constData(), welcome.constData())) {
        emitDiag("datachannel", QString("%1 left during the handshake").arg(peer.left(8)));
        return;
    }
    clientTokens_[peer] = obj["tok"].toString();
    emit clientTokensChanged();
    emitDiag("datachannel", QString("Admitted %1").arg(peer.left(8)));
    onNodeJoined(peerBytes.constData());
#else
    Q_UNUSED(peerId)
    Q_UNUSED(json)
#endif
}

void ClayNetwork::onPhase(const char* phase, int ms)
{
    if (status_ != Connecting)
        return;
    const QString p = QString::fromUtf8(phase);
    if (p == QLatin1String("ice")) {
        phaseTiming_["signaling"] = ms;
    } else if (p == QLatin1String("handshake")) {
        phaseTiming_["ice"] = ms;
        phaseTiming_["datachannel"] = 0;
        handshakeStartMs_ = clock_.elapsed();
    } else {
        return;
    }
    emit phaseTimingChanged();
    setConnectionPhase(p);
}

void ClayNetwork::onHandshakeReply(const char* nodeId, const char* json)
{
    if (status_ != Connecting)
        return;
    const QJsonObject obj = QJsonDocument::fromJson(QByteArray(json)).object();
    const auto v = hs::judgeReply(obj, hostId_, wireVersion_);
    if (v.ok()) {
        onConnectedToNetwork(nodeId);
        return;
    }
    qWarning() << "[ClayNetwork] The host refused this node -" << v.message;
    tearDown(false);
    status_ = Error;
    emit statusChanged();
    emit joinRefused(v.reason, v.message);
    emit errorOccurred(v.message);
}

void ClayNetwork::onError(const char* message)
{
    status_ = Error;
    emit statusChanged();
    emit errorOccurred(QString::fromUtf8(message));
}

void ClayNetwork::onDisconnected()
{
    // A joiner's link to the host closed, and with it every node it knew.
    // A host's signaling drop does not come here (onSignalingLost, #299).
    if (status_ == Disconnected)
        return;
    loseHost(QStringLiteral("Lost the connection to the host"));
}

void ClayNetwork::onSignalingLost()
{
    if (signalingDown_ || status_ == Disconnected)
        return;
    signalingDown_ = true;
    setAcceptingJoins(false);
    emitDiag("signaling", "Signaling connection lost, reconnecting");
    emit signalingLost();
}

void ClayNetwork::onSignalingRestored()
{
    if (!signalingDown_)
        return;
    signalingDown_ = false;
    setAcceptingJoins(isHost_);
    emitDiag("signaling", "Signaling restored");
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
    heard(id);
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
    emit syncStatsChanged();
}

// A crashed host never says goodbye (#299). Every peer answers a ping
// within a round trip, so one that leaves a ping unanswered and sends nothing
// else for gracePeriod is gone - counted from the ping, as on native, so a
// link out for less than gracePeriod comes back; with quiet peers probed
// after 0.5 s a crash is noticed within gracePeriod plus about 0.75 s. In a
// Star the links are the host's to each joiner and a joiner's one to the host.
void ClayNetwork::checkLiveness()
{
#ifdef __EMSCRIPTEN__
    if (gracePeriod_ <= 0 || !connected_)
        return;
    const qint64 now = clock_.elapsed();
    const QStringList links = isHost_ ? nodes_ : QStringList{hostId_};
    for (const QString &id : links) {
        const qint64 since = unansweredSinceMs_.value(id, -1);
        if (since < 0 || now - since < gracePeriod_)
            continue;
        emitDiag("datachannel", QString("No answer from %1 for %2 ms, dropping it")
                 .arg(id.left(8)).arg(now - since));
        if (!isHost_) {
            loseHost(QString("The host did not answer for %1 ms").arg(gracePeriod_));
            return;
        }
        QByteArray idBytes = id.toUtf8();
        js_drop_peer(instanceId_, idBytes.constData());
        removeNode(id);
    }
    armLivenessCheck();
#endif
}

void ClayNetwork::armLivenessCheck()
{
    qint64 next = -1;
    if (gracePeriod_ > 0) {
        for (auto it = unansweredSinceMs_.constBegin(); it != unansweredSinceMs_.constEnd(); ++it)
            if (next < 0 || it.value() + gracePeriod_ < next)
                next = it.value() + gracePeriod_;
    }
    if (next < 0) {
        livenessCheck_.stop();
        return;
    }
    livenessCheck_.start(int(qMax<qint64>(0, next - clock_.elapsed())));
}

void ClayNetwork::ping()
{
#ifdef __EMSCRIPTEN__
    if (!connected_)
        return;

    const qint64 sentAt = clock_.elapsed();
    const QStringList links = isHost_ ? nodes_ : QStringList{hostId_};
    for (const QString &id : links)
        if (!unansweredSinceMs_.contains(id))
            unansweredSinceMs_.insert(id, sentAt);
    armLivenessCheck();
    if (gracePeriod_ > 0 && !quietProbe_.isActive())
        quietProbe_.start();

    js_ping(instanceId_);
#endif
}

void ClayNetwork::probeQuietPeers()
{
#ifdef __EMSCRIPTEN__
    if (!connected_ || gracePeriod_ <= 0) {
        quietProbe_.stop();
        return;
    }
    const qint64 now = clock_.elapsed();
    const QStringList links = isHost_ ? nodes_ : QStringList{hostId_};
    bool probed = false;
    for (const QString &id : links) {
        if (unansweredSinceMs_.contains(id) || now - lastHeardMs_.value(id, now) < 500)
            continue;
        unansweredSinceMs_.insert(id, now);
        QByteArray idBytes = id.toUtf8();
        js_ping_peer(instanceId_, idBytes.constData());
        probed = true;
    }
    if (probed)
        armLivenessCheck();
#endif
}
