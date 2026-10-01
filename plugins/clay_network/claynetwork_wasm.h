// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QStringList>
#include <QHash>
#include <QElapsedTimer>
#include <QTimer>
#include <qqmlregistration.h>
#include "link_conditioner.h"

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
    Q_PROPERTY(QString hostId READ hostId NOTIFY hostIdChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int playerCount READ nodeCount NOTIFY nodeCountChanged)
    Q_PROPERTY(QStringList players READ nodes NOTIFY nodesChanged)
    Q_PROPERTY(int maxPlayers READ maxNodes WRITE setMaxNodes NOTIFY maxNodesChanged)
    Q_PROPERTY(Topology topology READ topology WRITE setTopology NOTIFY topologyChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool autoRelay READ autoRelay WRITE setAutoRelay NOTIFY autoRelayChanged)
    Q_PROPERTY(SignalingMode signalingMode READ signalingMode WRITE setSignalingMode NOTIFY signalingModeChanged)
    Q_PROPERTY(QVariantList iceServers READ iceServers WRITE setIceServers NOTIFY iceServersChanged)
    Q_PROPERTY(QString signalingUrl READ signalingUrl WRITE setSignalingUrl NOTIFY signalingUrlChanged)
    // Kept so Network.qml can set it on every platform; the browser checks
    // the signaling server's certificate itself and offers no opt-out
    Q_PROPERTY(bool verifySignalingCertificate READ verifySignalingCertificate WRITE setVerifySignalingCertificate NOTIFY verifySignalingCertificateChanged)
    Q_PROPERTY(bool verbose READ verbose WRITE setVerbose NOTIFY verboseChanged)
    Q_PROPERTY(QString connectionPhase READ connectionPhase NOTIFY connectionPhaseChanged)
    Q_PROPERTY(QVariantMap phaseTiming READ phaseTiming NOTIFY phaseTimingChanged)
    Q_PROPERTY(int latency READ latency NOTIFY latencyChanged)
    Q_PROPERTY(QVariantMap peerStats READ peerStats NOTIFY peerStatsChanged)
    Q_PROPERTY(QVariantMap syncStats READ syncStats NOTIFY syncStatsChanged)
    Q_PROPERTY(QVariantMap linkConditions READ linkConditions WRITE setLinkConditions NOTIFY linkConditionsChanged)
    Q_PROPERTY(int gracePeriod READ gracePeriod WRITE setGracePeriod NOTIFY gracePeriodChanged)
    Q_PROPERTY(bool acceptingJoins READ acceptingJoins NOTIFY acceptingJoinsChanged)

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
    QString hostId() const;
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
    QVariantList iceServers() const;
    void setIceServers(const QVariantList &servers);
    QString signalingUrl() const;
    void setSignalingUrl(const QString &url);
    bool verifySignalingCertificate() const;
    void setVerifySignalingCertificate(bool verify);
    bool verbose() const;
    void setVerbose(bool v);
    QString connectionPhase() const;
    QVariantMap phaseTiming() const;
    int latency() const;
    QVariantMap peerStats() const;
    QVariantMap syncStats() const;
    QVariantMap linkConditions() const;
    void setLinkConditions(const QVariantMap &conditions);
    int gracePeriod() const;
    void setGracePeriod(int ms);
    bool acceptingJoins() const;

public slots:
    void createRoom();
    void joinRoom(const QString &networkId);
    void leave();
    void broadcast(const QVariant &data);
    void broadcastState(const QVariant &data);
    void sendTo(const QString &nodeId, const QVariant &data);
    // Test hook: puts json on the wire to nodeId as it is, bypassing the
    // message envelope - the net gym forges a sender id with it (#298)
    void sendRaw(const QString &nodeId, const QString &json);
    // Sends a ping to every peer. A peer that leaves one unanswered, and
    // sends nothing else either, for gracePeriod ms is dropped (#299)
    void ping();
    int stateAgeMs(const QString &nodeId) const;

signals:
    void roomCreated(const QString &networkId);
    void playerJoined(const QString &nodeId);
    void playerLeft(const QString &nodeId);
    void messageReceived(const QString &fromId, const QVariant &data);
    // sentAt: the sender's clock (ms since epoch) when the update was
    // broadcast, or -1 when the sender did not include one.
    void stateReceived(const QString &fromId, const QVariant &data, double sentAt);
    void errorOccurred(const QString &message);
    void diagnosticMessage(const QString &phase, const QString &detail);

    void networkIdChanged();
    void nodeIdChanged();
    void hostIdChanged();
    void isHostChanged();
    void connectedChanged();
    void nodeCountChanged();
    void nodesChanged();
    void maxNodesChanged();
    void topologyChanged();
    void statusChanged();
    void autoRelayChanged();
    void signalingModeChanged();
    void iceServersChanged();
    void signalingUrlChanged();
    void verifySignalingCertificateChanged();
    // The PeerJS server connection dropped after it was up; the data
    // connections stay and PeerJS reconnects under the same id (#299)
    void signalingLost();
    void verboseChanged();
    void connectionPhaseChanged();
    void phaseTimingChanged();
    void latencyChanged();
    void peerStatsChanged();
    void syncStatsChanged();
    void linkConditionsChanged();
    void gracePeriodChanged();
    void acceptingJoinsChanged();

public:
    // Callbacks from JavaScript (via Emscripten)
    void onNetworkCreated(const char* networkId);
    void onConnectedToNetwork(const char* nodeId);
    void onNodeJoined(const char* nodeId);
    void onNodeLeft(const char* nodeId);
    void onMessage(const char* linkPeerId, const char* data, bool isState);
    void onSystem(const char* json);
    void onError(const char* errorMsg);
    void onDisconnected();
    void onSignalingLost();
    void onSignalingRestored();
    void onDiagnostic(const char* phase, const char* detail);
    void onPong(const char* peerId, int rtt);

private:
    void initPeerJS();
    QString generateNetworkCode() const;
    void setConnectionPhase(const QString &phase);
    void emitDiag(const QString &phase, const QString &detail);
    // True (after reporting the error) when linkConditions.dropSignaling
    // makes the signaling server unreachable
    bool refuseWhileSignalingDropped();
    void heard(const QString &linkPeer);
    void checkLiveness();
    void armLivenessCheck();
    // Pings a link peer that has gone quiet, so its deadline starts right
    // after the silence does and not at the next 2 s ping
    void probeQuietPeers();
    // A joiner's host left, went silent or its link closed: the network
    // is over, every node it knew is reported gone
    void loseHost(const QString &reason);
    void removeNode(const QString &nodeId);
    // leave() without the goodbye: everything back to Disconnected
    void tearDown(bool goodbye);
    void setAcceptingJoins(bool accepting);

    QString networkId_;
    QString nodeId_;
    QString hostId_;  // node id of the host, the same on every node
    bool isHost_ = false;
    bool connected_ = false;
    int maxNodes_ = 8;
    Topology topology_ = Star;
    Status status_ = Disconnected;
    bool autoRelay_ = true;
    SignalingMode signalingMode_ = Cloud;  // WASM only supports Cloud
    QStringList nodes_;

    // Custom signaling
    QString signalingUrl_;
    bool verifySignalingCertificate_ = true;

    // ICE configuration
    QVariantList iceServers_;

    // Diagnostics
    bool verbose_ = false;
    QString connectionPhase_;
    QVariantMap phaseTiming_;
    int latency_ = -1;
    QVariantMap peerLatencies_;

    // State sync bookkeeping - keyed by ORIGIN node id
    void forgetSender(const QString &nodeId);
    quint32 stateSeqOut_ = 0;
    QHash<QString, quint32> stateSeqIn_;
    QHash<QString, qint64> stateLastMs_;
    QHash<QString, qint64> stateRecvCount_;
    QHash<QString, qint64> stateDropCount_;
    QElapsedTimer clock_;

    // Holds the simulated link's conditions (#301). The traffic itself is
    // conditioned in JS by link_conditioner.js, which sees every packet -
    // relays and pongs never pass through C++ here.
    clay::network::LinkConditioner conditions_;

    // A peer that leaves a ping unanswered this long counts as gone (#299).
    // Keyed by the peer at the other end of a link: the clock_ time of the
    // first ping sent since it was last heard from.
    int gracePeriod_ = 5000;
    QHash<QString, qint64> unansweredSinceMs_;
    QHash<QString, qint64> lastHeardMs_;
    QTimer livenessCheck_;
    QTimer quietProbe_;
    bool acceptingJoins_ = false;
    bool signalingDown_ = false;

    int instanceId_ = -1;
    static int nextInstanceId_;
};
