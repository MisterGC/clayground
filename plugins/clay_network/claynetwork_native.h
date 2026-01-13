// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QStringList>
#include <QHash>
#include <qqmlregistration.h>
#include <memory>

namespace rtc {
    class PeerConnection;
    class DataChannel;
}

class PeerJSSignaling;

/*!
    \qmltype ClayNetworkBackend
    \nativetype ClayNetwork
    \inqmlmodule Clayground.Network
    \brief C++ backend for WebRTC P2P networking via libdatachannel (Desktop/Mobile).

    This is the native implementation using libdatachannel for WebRTC.
    Uses PeerJS signaling server for peer discovery.

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

public:
    enum Topology {
        Star,
        Mesh
    };
    Q_ENUM(Topology)

    enum Status {
        Disconnected,
        Connecting,
        Connected,
        Error
    };
    Q_ENUM(Status)

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

private slots:
    void onSignalingConnected(const QString &peerId);
    void onSignalingOffer(const QString &fromId, const QString &sdp);
    void onSignalingAnswer(const QString &fromId, const QString &sdp);
    void onSignalingCandidate(const QString &fromId, const QString &candidate, const QString &mid);
    void onSignalingError(const QString &error);

private:
    struct PeerConnection {
        std::shared_ptr<rtc::PeerConnection> pc;
        std::shared_ptr<rtc::DataChannel> dc;
        bool ready = false;
    };

    void setupPeerConnection(const QString &peerId, bool isOfferer);
    void setupDataChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc);
    void sendToPeer(const QString &peerId, const QString &message);
    void handleDataChannelMessage(const QString &fromId, const std::string &message);
    void cleanupPeer(const QString &peerId);
    QString generateNetworkCode() const;

    std::unique_ptr<PeerJSSignaling> signaling_;
    QHash<QString, PeerConnection> peers_;

    QString networkId_;
    QString nodeId_;
    bool isHost_ = false;
    bool connected_ = false;
    int maxNodes_ = 8;
    Topology topology_ = Star;
    Status status_ = Disconnected;
    QStringList nodes_;
};
