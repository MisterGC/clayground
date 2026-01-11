// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claymultiplayer.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/val.h>
#include <map>

// Global registry for callback routing
static std::map<int, ClayMultiplayer*> g_multiplayerRegistry;
int ClayMultiplayer::nextInstanceId_ = 0;

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
            console.log('[ClayMultiplayer] PeerJS loaded');
            resolve();
        };
        script.onerror = (e) => {
            Module.clayPeerJSLoading = false;
            console.error('[ClayMultiplayer] Failed to load PeerJS', e);
            reject(e);
        };
        document.head.appendChild(script);
    });
});

// JavaScript: Initialize multiplayer instance
EM_JS(void, js_init_multiplayer, (int instanceId), {
    if (!Module.clayMultiplayer) {
        Module.clayMultiplayer = {};
    }

    Module.clayMultiplayer[instanceId] = {
        peer: null,
        connections: new Map(),
        roomId: null,
        playerId: null,
        isHost: false,
        topology: 0, // 0 = Star, 1 = Mesh
        maxPlayers: 8
    };
});

// JavaScript: Create a room (become host)
EM_JS(void, js_create_room, (int instanceId, const char* roomCode, int topology, int maxPlayers), {
    const roomId = UTF8ToString(roomCode);
    const state = Module.clayMultiplayer[instanceId];
    state.topology = topology;
    state.maxPlayers = maxPlayers;

    Module.clayPeerJSReady.then(() => {
        // Host uses room code as peer ID for easy discovery
        state.peer = new Peer(roomId, {
            debug: 1
        });

        state.peer.on('open', (id) => {
            console.log('[ClayMultiplayer] Room created:', id);
            state.roomId = id;
            state.playerId = id;
            state.isHost = true;
            Module._clay_mp_room_created(instanceId, stringToNewUTF8(id));
        });

        state.peer.on('connection', (conn) => {
            if (state.connections.size >= state.maxPlayers - 1) {
                console.log('[ClayMultiplayer] Room full, rejecting:', conn.peer);
                conn.close();
                return;
            }

            console.log('[ClayMultiplayer] Player connecting:', conn.peer);
            state.connections.set(conn.peer, conn);

            conn.on('open', () => {
                console.log('[ClayMultiplayer] Player joined:', conn.peer);
                Module._clay_mp_player_joined(instanceId, stringToNewUTF8(conn.peer));

                // In mesh topology, tell new player about existing players
                if (state.topology === 1) {
                    const existingPeers = Array.from(state.connections.keys()).filter(p => p !== conn.peer);
                    if (existingPeers.length > 0) {
                        conn.send(JSON.stringify({
                            _clay_sys: 'mesh_peers',
                            peers: existingPeers
                        }));
                    }
                }

                // Notify existing players about new player
                state.connections.forEach((c, peerId) => {
                    if (peerId !== conn.peer) {
                        c.send(JSON.stringify({
                            _clay_sys: 'player_joined',
                            playerId: conn.peer
                        }));
                    }
                });
            });

            conn.on('data', (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                const parsed = JSON.parse(msg);

                // Handle system messages
                if (parsed._clay_sys) return;

                const isState = parsed._clay_state === true;
                Module._clay_mp_message(instanceId,
                    stringToNewUTF8(conn.peer),
                    stringToNewUTF8(msg),
                    isState ? 1 : 0);
            });

            conn.on('close', () => {
                console.log('[ClayMultiplayer] Player left:', conn.peer);
                state.connections.delete(conn.peer);
                Module._clay_mp_player_left(instanceId, stringToNewUTF8(conn.peer));

                // Notify other players
                state.connections.forEach((c) => {
                    c.send(JSON.stringify({
                        _clay_sys: 'player_left',
                        playerId: conn.peer
                    }));
                });
            });

            conn.on('error', (err) => {
                console.error('[ClayMultiplayer] Connection error:', err);
            });
        });

        state.peer.on('error', (err) => {
            console.error('[ClayMultiplayer] Peer error:', err);
            Module._clay_mp_error(instanceId, stringToNewUTF8(err.message || err.type));
        });

        state.peer.on('disconnected', () => {
            console.log('[ClayMultiplayer] Disconnected from signaling');
            Module._clay_mp_disconnected(instanceId);
        });
    }).catch((err) => {
        Module._clay_mp_error(instanceId, stringToNewUTF8('Failed to load PeerJS'));
    });
});

// JavaScript: Join an existing room
EM_JS(void, js_join_room, (int instanceId, const char* roomCode, int topology), {
    const roomId = UTF8ToString(roomCode);
    const state = Module.clayMultiplayer[instanceId];
    state.topology = topology;

    Module.clayPeerJSReady.then(() => {
        // Client gets random peer ID
        state.peer = new Peer({
            debug: 1
        });

        state.peer.on('open', (id) => {
            console.log('[ClayMultiplayer] Client peer ready:', id);
            state.playerId = id;
            state.roomId = roomId;
            state.isHost = false;

            // Connect to host
            const conn = state.peer.connect(roomId, { reliable: true });
            state.connections.set(roomId, conn);

            conn.on('open', () => {
                console.log('[ClayMultiplayer] Connected to room:', roomId);
                Module._clay_mp_connected(instanceId, stringToNewUTF8(id));
            });

            conn.on('data', (data) => {
                const msg = typeof data === 'string' ? data : JSON.stringify(data);
                const parsed = JSON.parse(msg);

                // Handle system messages
                if (parsed._clay_sys === 'mesh_peers') {
                    // Connect to other peers for mesh topology
                    parsed.peers.forEach((peerId) => {
                        if (!state.connections.has(peerId)) {
                            const peerConn = state.peer.connect(peerId, { reliable: true });
                            state.connections.set(peerId, peerConn);
                            setupPeerConnection(instanceId, peerId, peerConn);
                        }
                    });
                    return;
                }

                if (parsed._clay_sys === 'player_joined') {
                    Module._clay_mp_player_joined(instanceId, stringToNewUTF8(parsed.playerId));
                    // In mesh topology, connect to new player
                    if (state.topology === 1 && !state.connections.has(parsed.playerId)) {
                        const peerConn = state.peer.connect(parsed.playerId, { reliable: true });
                        state.connections.set(parsed.playerId, peerConn);
                        setupPeerConnection(instanceId, parsed.playerId, peerConn);
                    }
                    return;
                }

                if (parsed._clay_sys === 'player_left') {
                    Module._clay_mp_player_left(instanceId, stringToNewUTF8(parsed.playerId));
                    state.connections.delete(parsed.playerId);
                    return;
                }

                const isState = parsed._clay_state === true;
                Module._clay_mp_message(instanceId,
                    stringToNewUTF8(roomId),
                    stringToNewUTF8(msg),
                    isState ? 1 : 0);
            });

            conn.on('close', () => {
                console.log('[ClayMultiplayer] Disconnected from room');
                state.connections.delete(roomId);
                Module._clay_mp_disconnected(instanceId);
            });

            conn.on('error', (err) => {
                console.error('[ClayMultiplayer] Connection error:', err);
                Module._clay_mp_error(instanceId, stringToNewUTF8(err.message || 'Connection failed'));
            });
        });

        state.peer.on('connection', (conn) => {
            // Accept incoming connections (mesh topology)
            console.log('[ClayMultiplayer] Incoming mesh connection:', conn.peer);
            state.connections.set(conn.peer, conn);
            setupPeerConnection(instanceId, conn.peer, conn);
        });

        state.peer.on('error', (err) => {
            console.error('[ClayMultiplayer] Peer error:', err);
            Module._clay_mp_error(instanceId, stringToNewUTF8(err.message || err.type));
        });
    }).catch((err) => {
        Module._clay_mp_error(instanceId, stringToNewUTF8('Failed to load PeerJS'));
    });

    // Helper to setup peer connection handlers
    function setupPeerConnection(instanceId, peerId, conn) {
        conn.on('open', () => {
            console.log('[ClayMultiplayer] Mesh connected to:', peerId);
        });

        conn.on('data', (data) => {
            const msg = typeof data === 'string' ? data : JSON.stringify(data);
            const parsed = JSON.parse(msg);
            if (parsed._clay_sys) return;

            const isState = parsed._clay_state === true;
            Module._clay_mp_message(instanceId,
                stringToNewUTF8(peerId),
                stringToNewUTF8(msg),
                isState ? 1 : 0);
        });

        conn.on('close', () => {
            state.connections.delete(peerId);
            Module._clay_mp_player_left(instanceId, stringToNewUTF8(peerId));
        });
    }
});

// JavaScript: Broadcast message to all connected peers
EM_JS(void, js_broadcast, (int instanceId, const char* data), {
    const state = Module.clayMultiplayer[instanceId];
    if (!state) return;

    const msg = UTF8ToString(data);
    state.connections.forEach((conn) => {
        if (conn.open) {
            conn.send(msg);
        }
    });
});

// JavaScript: Send message to specific peer
EM_JS(void, js_send_to, (int instanceId, const char* peerId, const char* data), {
    const state = Module.clayMultiplayer[instanceId];
    if (!state) return;

    const targetId = UTF8ToString(peerId);
    const msg = UTF8ToString(data);

    const conn = state.connections.get(targetId);
    if (conn && conn.open) {
        conn.send(msg);
    }
});

// JavaScript: Leave room and cleanup
EM_JS(void, js_leave, (int instanceId), {
    const state = Module.clayMultiplayer[instanceId];
    if (!state) return;

    state.connections.forEach((conn) => {
        try { conn.close(); } catch (e) {}
    });
    state.connections.clear();

    if (state.peer) {
        try { state.peer.destroy(); } catch (e) {}
        state.peer = null;
    }

    state.roomId = null;
    state.playerId = null;
    state.isHost = false;
});

// JavaScript: Get player list
EM_JS(char*, js_get_players, (int instanceId), {
    const state = Module.clayMultiplayer[instanceId];
    if (!state) return stringToNewUTF8('[]');

    const players = Array.from(state.connections.keys());
    if (state.isHost) {
        players.unshift(state.playerId); // Add self for host
    }
    return stringToNewUTF8(JSON.stringify(players));
});

// C callbacks from JavaScript
extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_room_created(int instanceId, const char* roomId)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second, roomId]() {
            mp->onRoomCreated(roomId);
            free((void*)roomId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_connected(int instanceId, const char* odId)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second, odId]() {
            mp->onConnectedToRoom(odId);
            free((void*)odId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_player_joined(int instanceId, const char* odId)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second, odId]() {
            mp->onPlayerJoined(odId);
            free((void*)odId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_player_left(int instanceId, const char* odId)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second, odId]() {
            mp->onPlayerLeft(odId);
            free((void*)odId);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_message(int instanceId, const char* fromId, const char* data, int isState)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second, fromId, data, isState]() {
            mp->onMessage(fromId, data, isState != 0);
            free((void*)fromId);
            free((void*)data);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_error(int instanceId, const char* message)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second, message]() {
            mp->onError(message);
            free((void*)message);
        }, Qt::QueuedConnection);
    }
}

extern "C" EMSCRIPTEN_KEEPALIVE
void clay_mp_disconnected(int instanceId)
{
    auto it = g_multiplayerRegistry.find(instanceId);
    if (it != g_multiplayerRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [mp = it->second]() {
            mp->onDisconnected();
        }, Qt::QueuedConnection);
    }
}

#endif // __EMSCRIPTEN__

ClayMultiplayer::ClayMultiplayer(QObject *parent)
    : QObject(parent)
{
#ifdef __EMSCRIPTEN__
    instanceId_ = nextInstanceId_++;
    g_multiplayerRegistry[instanceId_] = this;
    js_load_peerjs();
    js_init_multiplayer(instanceId_);
#endif
}

ClayMultiplayer::~ClayMultiplayer()
{
#ifdef __EMSCRIPTEN__
    js_leave(instanceId_);
    g_multiplayerRegistry.erase(instanceId_);
#endif
}

QString ClayMultiplayer::roomId() const
{
    return roomId_;
}

QString ClayMultiplayer::playerId() const
{
    return playerId_;
}

bool ClayMultiplayer::isHost() const
{
    return isHost_;
}

bool ClayMultiplayer::connected() const
{
    return connected_;
}

int ClayMultiplayer::playerCount() const
{
    return players_.size();
}

QStringList ClayMultiplayer::players() const
{
    return players_;
}

int ClayMultiplayer::maxPlayers() const
{
    return maxPlayers_;
}

void ClayMultiplayer::setMaxPlayers(int max)
{
    if (max < 2) max = 2;
    if (max > 8) max = 8;
    if (maxPlayers_ == max) return;

    maxPlayers_ = max;
    emit maxPlayersChanged();
}

ClayMultiplayer::Topology ClayMultiplayer::topology() const
{
    return topology_;
}

void ClayMultiplayer::setTopology(Topology t)
{
    if (topology_ == t) return;
    topology_ = t;
    emit topologyChanged();
}

ClayMultiplayer::Status ClayMultiplayer::status() const
{
    return status_;
}

void ClayMultiplayer::createRoom()
{
#ifdef __EMSCRIPTEN__
    if (connected_) {
        qWarning() << "[ClayMultiplayer] Already connected, leave first";
        return;
    }

    status_ = Connecting;
    emit statusChanged();

    QString roomCode = generateRoomCode();
    QByteArray roomBytes = roomCode.toUtf8();
    js_create_room(instanceId_, roomBytes.constData(), static_cast<int>(topology_), maxPlayers_);
#else
    qWarning() << "[ClayMultiplayer] Not available on this platform";
#endif
}

void ClayMultiplayer::joinRoom(const QString &roomId)
{
#ifdef __EMSCRIPTEN__
    if (connected_) {
        qWarning() << "[ClayMultiplayer] Already connected, leave first";
        return;
    }

    status_ = Connecting;
    emit statusChanged();

    QByteArray roomBytes = roomId.toUpper().toUtf8();
    js_join_room(instanceId_, roomBytes.constData(), static_cast<int>(topology_));
#else
    Q_UNUSED(roomId)
    qWarning() << "[ClayMultiplayer] Not available on this platform";
#endif
}

void ClayMultiplayer::leave()
{
#ifdef __EMSCRIPTEN__
    js_leave(instanceId_);

    roomId_.clear();
    playerId_.clear();
    isHost_ = false;
    connected_ = false;
    players_.clear();
    status_ = Disconnected;

    emit roomIdChanged();
    emit playerIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit playersChanged();
    emit playerCountChanged();
    emit statusChanged();
#endif
}

void ClayMultiplayer::broadcast(const QVariant &data)
{
#ifdef __EMSCRIPTEN__
    QJsonObject obj = QJsonObject::fromVariantMap(data.toMap());
    QByteArray json = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    js_broadcast(instanceId_, json.constData());
#else
    Q_UNUSED(data)
#endif
}

void ClayMultiplayer::broadcastState(const QVariant &data)
{
#ifdef __EMSCRIPTEN__
    QJsonObject obj = QJsonObject::fromVariantMap(data.toMap());
    obj["_clay_state"] = true;
    QByteArray json = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    js_broadcast(instanceId_, json.constData());
#else
    Q_UNUSED(data)
#endif
}

void ClayMultiplayer::sendTo(const QString &odId, const QVariant &data)
{
#ifdef __EMSCRIPTEN__
    QJsonObject obj = QJsonObject::fromVariantMap(data.toMap());
    QByteArray json = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    QByteArray peerBytes = odId.toUtf8();
    js_send_to(instanceId_, peerBytes.constData(), json.constData());
#else
    Q_UNUSED(odId)
    Q_UNUSED(data)
#endif
}

QString ClayMultiplayer::generateRoomCode() const
{
    // Generate a 6-character room code (no ambiguous chars)
    const QString chars = QStringLiteral("ABCDEFGHJKLMNPQRSTUVWXYZ23456789");
    QString code;
    for (int i = 0; i < 6; ++i) {
        int idx = QRandomGenerator::global()->bounded(chars.length());
        code += chars.at(idx);
    }
    return code;
}

void ClayMultiplayer::onRoomCreated(const char* roomId)
{
    roomId_ = QString::fromUtf8(roomId);
    playerId_ = roomId_;
    isHost_ = true;
    connected_ = true;
    status_ = Connected;
    players_.clear();
    players_.append(playerId_);

    emit roomIdChanged();
    emit playerIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit playersChanged();
    emit playerCountChanged();
    emit statusChanged();
    emit roomCreated(roomId_);
}

void ClayMultiplayer::onConnectedToRoom(const char* odId)
{
    playerId_ = QString::fromUtf8(odId);
    connected_ = true;
    status_ = Connected;
    players_.clear();
    players_.append(roomId_); // Add host
    players_.append(playerId_);

    emit playerIdChanged();
    emit connectedChanged();
    emit playersChanged();
    emit playerCountChanged();
    emit statusChanged();
}

void ClayMultiplayer::onPlayerJoined(const char* odId)
{
    QString id = QString::fromUtf8(odId);
    if (!players_.contains(id)) {
        players_.append(id);
        emit playersChanged();
        emit playerCountChanged();
    }
    emit playerJoined(id);
}

void ClayMultiplayer::onPlayerLeft(const char* odId)
{
    QString id = QString::fromUtf8(odId);
    if (players_.removeOne(id)) {
        emit playersChanged();
        emit playerCountChanged();
    }
    emit playerLeft(id);
}

void ClayMultiplayer::onMessage(const char* fromId, const char* data, bool isState)
{
    QString from = QString::fromUtf8(fromId);
    QString jsonStr = QString::fromUtf8(data);

    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    QVariant msgData = doc.toVariant();

    // Remove internal markers before passing to user
    if (doc.isObject()) {
        QJsonObject obj = doc.object();
        obj.remove("_clay_state");
        msgData = obj.toVariantMap();
    }

    if (isState) {
        emit stateReceived(from, msgData);
    } else {
        emit messageReceived(from, msgData);
    }
}

void ClayMultiplayer::onError(const char* message)
{
    status_ = Error;
    emit statusChanged();
    emit errorOccurred(QString::fromUtf8(message));
}

void ClayMultiplayer::onDisconnected()
{
    connected_ = false;
    status_ = Disconnected;
    players_.clear();

    emit connectedChanged();
    emit playersChanged();
    emit playerCountChanged();
    emit statusChanged();
}
