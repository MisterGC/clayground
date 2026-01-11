// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QStringList>
#include <qqmlregistration.h>

/*!
    \qmltype ClayMultiplayerBackend
    \nativetype ClayMultiplayer
    \inqmlmodule Clayground.Network
    \brief C++ backend for WebRTC P2P multiplayer via PeerJS.

    ClayMultiplayerBackend provides the WebRTC Data Channel implementation
    for browser-based multiplayer games. Uses PeerJS for signaling and
    establishes direct peer-to-peer connections for game data.

    This is the WASM implementation. Native platforms use a different
    backend with the same QML API.

    \sa ClayMultiplayer
*/
class ClayMultiplayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_NAMED_ELEMENT(ClayMultiplayerBackend)

    Q_PROPERTY(QString roomId READ roomId NOTIFY roomIdChanged)
    Q_PROPERTY(QString playerId READ playerId NOTIFY playerIdChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int playerCount READ playerCount NOTIFY playerCountChanged)
    Q_PROPERTY(QStringList players READ players NOTIFY playersChanged)
    Q_PROPERTY(int maxPlayers READ maxPlayers WRITE setMaxPlayers NOTIFY maxPlayersChanged)
    Q_PROPERTY(Topology topology READ topology WRITE setTopology NOTIFY topologyChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)

public:
    enum Topology {
        Star,   // Clients connect only to host
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

    explicit ClayMultiplayer(QObject *parent = nullptr);
    ~ClayMultiplayer() override;

    QString roomId() const;
    QString playerId() const;
    bool isHost() const;
    bool connected() const;
    int playerCount() const;
    QStringList players() const;
    int maxPlayers() const;
    void setMaxPlayers(int max);
    Topology topology() const;
    void setTopology(Topology t);
    Status status() const;

public slots:
    void createRoom();
    void joinRoom(const QString &roomId);
    void leave();
    void broadcast(const QVariant &data);
    void broadcastState(const QVariant &data);
    void sendTo(const QString &odId, const QVariant &data);

signals:
    void roomCreated(const QString &roomId);
    void playerJoined(const QString &odId);
    void playerLeft(const QString &odId);
    void messageReceived(const QString &fromId, const QVariant &data);
    void stateReceived(const QString &fromId, const QVariant &data);
    void errorOccurred(const QString &message);

    void roomIdChanged();
    void playerIdChanged();
    void isHostChanged();
    void connectedChanged();
    void playerCountChanged();
    void playersChanged();
    void maxPlayersChanged();
    void topologyChanged();
    void statusChanged();

public:
    // Callbacks from JavaScript (via Emscripten)
    void onRoomCreated(const char* roomId);
    void onConnectedToRoom(const char* odId);
    void onPlayerJoined(const char* odId);
    void onPlayerLeft(const char* odId);
    void onMessage(const char* fromId, const char* data, bool isState);
    void onError(const char* errorMsg);
    void onDisconnected();

private:
    void initPeerJS();
    QString generateRoomCode() const;

    QString roomId_;
    QString playerId_;
    bool isHost_ = false;
    bool connected_ = false;
    int maxPlayers_ = 8;
    Topology topology_ = Star;
    Status status_ = Disconnected;
    QStringList players_;

    int instanceId_ = -1;
    static int nextInstanceId_;
};
