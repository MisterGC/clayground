// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QStringList>
#include <qqmlregistration.h>

/*!
    \qmltype ClayNetworkBackend
    \nativetype ClayNetwork
    \inqmlmodule Clayground.Network
    \brief C++ backend for WebRTC P2P networking via PeerJS (WASM).

    This is the WASM implementation using browser-native WebRTC.
    Native platforms use a different backend with the same QML API.

    \sa Network
*/
class ClayNetwork : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_NAMED_ELEMENT(ClayNetworkBackend)

    Q_PROPERTY(QString roomId READ networkId NOTIFY networkIdChanged)
    Q_PROPERTY(QString playerId READ nodeId NOTIFY nodeIdChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int playerCount READ nodeCount NOTIFY nodeCountChanged)
    Q_PROPERTY(QStringList players READ nodes NOTIFY nodesChanged)
    Q_PROPERTY(int maxPlayers READ maxNodes WRITE setMaxNodes NOTIFY maxNodesChanged)
    Q_PROPERTY(Topology topology READ topology WRITE setTopology NOTIFY topologyChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool autoRelay READ autoRelay WRITE setAutoRelay NOTIFY autoRelayChanged)
    Q_PROPERTY(SignalingMode signalingMode READ signalingMode WRITE setSignalingMode NOTIFY signalingModeChanged)

public:
    enum Topology {
        Star,   // Nodes connect only to host
        Mesh    // Everyone connects to everyone
    };
    Q_ENUM(Topology)

    enum Status {
        Disconnected,
        Connecting,
        Connected,
        Error
    };
    Q_ENUM(Status)

    enum SignalingMode {
        Cloud,  // Internet: Uses PeerJS server (only mode supported in WASM)
        Local   // LAN: Not supported in WASM
    };
    Q_ENUM(SignalingMode)

    explicit ClayNetwork(QObject *parent = nullptr);
    ~ClayNetwork() override;

    QString networkId() const;
    QString nodeId() const;
    bool isHost() const;
    bool connected() const;
    int nodeCount() const;
    QStringList nodes() const;
    int maxNodes() const;
    void setMaxNodes(int max);
    Topology topology() const;
    void setTopology(Topology t);
    Status status() const;
    bool autoRelay() const;
    void setAutoRelay(bool relay);
    SignalingMode signalingMode() const;
    void setSignalingMode(SignalingMode mode);

public slots:
    void createRoom();
    void joinRoom(const QString &networkId);
    void leave();
    void broadcast(const QVariant &data);
    void broadcastState(const QVariant &data);
    void sendTo(const QString &nodeId, const QVariant &data);

signals:
    void roomCreated(const QString &networkId);
    void playerJoined(const QString &nodeId);
    void playerLeft(const QString &nodeId);
    void messageReceived(const QString &fromId, const QVariant &data);
    void stateReceived(const QString &fromId, const QVariant &data);
    void errorOccurred(const QString &message);

    void networkIdChanged();
    void nodeIdChanged();
    void isHostChanged();
    void connectedChanged();
    void nodeCountChanged();
    void nodesChanged();
    void maxNodesChanged();
    void topologyChanged();
    void statusChanged();
    void autoRelayChanged();
    void signalingModeChanged();

public:
    // Callbacks from JavaScript (via Emscripten)
    void onNetworkCreated(const char* networkId);
    void onConnectedToNetwork(const char* nodeId);
    void onNodeJoined(const char* nodeId);
    void onNodeLeft(const char* nodeId);
    void onMessage(const char* fromId, const char* data, bool isState);
    void onError(const char* errorMsg);
    void onDisconnected();

private:
    void initPeerJS();
    QString generateNetworkCode() const;

    QString networkId_;
    QString nodeId_;
    bool isHost_ = false;
    bool connected_ = false;
    int maxNodes_ = 8;
    Topology topology_ = Star;
    Status status_ = Disconnected;
    bool autoRelay_ = true;
    SignalingMode signalingMode_ = Cloud;  // WASM only supports Cloud
    QStringList nodes_;

    int instanceId_ = -1;
    static int nextInstanceId_;
};
