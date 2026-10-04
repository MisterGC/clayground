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
#include <memory>
#include <mutex>
#include "link_conditioner.h"
#include "statebatch.h"
#include "replica.h"
#include "sessionclock.h"

namespace rtc {
    class PeerConnection;
    class DataChannel;
}

class PeerJSSignaling;
class LocalSignalingServer;
class LocalSignalingClient;

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
    Q_PROPERTY(QString hostId READ hostId NOTIFY hostIdChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString hostLostReason READ hostLostReason NOTIFY hostLostReasonChanged)
    Q_PROPERTY(int playerCount READ nodeCount NOTIFY nodeCountChanged)
    Q_PROPERTY(QStringList players READ nodes NOTIFY nodesChanged)
    Q_PROPERTY(int maxPlayers READ maxNodes WRITE setMaxNodes NOTIFY maxNodesChanged)
    Q_PROPERTY(Topology topology READ topology WRITE setTopology NOTIFY topologyChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool autoRelay READ autoRelay WRITE setAutoRelay NOTIFY autoRelayChanged)
    Q_PROPERTY(SignalingMode signalingMode READ signalingMode WRITE setSignalingMode NOTIFY signalingModeChanged)
    Q_PROPERTY(QVariantList iceServers READ iceServers WRITE setIceServers NOTIFY iceServersChanged)
    Q_PROPERTY(QString signalingUrl READ signalingUrl WRITE setSignalingUrl NOTIFY signalingUrlChanged)
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
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(QString appId READ appId WRITE setAppId NOTIFY appIdChanged)
    Q_PROPERTY(QString clientToken READ clientToken WRITE setClientToken NOTIFY clientTokenChanged)
    Q_PROPERTY(QVariantMap clientTokens READ clientTokens NOTIFY clientTokensChanged)
    // The host's clock, shared by every node (#304). Read live: it changes
    // every ms but notifies only when it is set, synced or reset
    Q_PROPERTY(double sessionTime READ sessionTime NOTIFY sessionClockChanged)
    Q_PROPERTY(bool sessionTimeSynced READ sessionTimeSynced NOTIFY sessionClockChanged)
    // Host-owned session properties, the same on every node (#306)
    Q_PROPERTY(QVariantMap sessionProperties READ sessionProperties NOTIFY sessionPropertiesChanged)
    // Test hook: a joiner that speaks another wire version (#323)
    Q_PROPERTY(int wireVersion READ wireVersion WRITE setWireVersion NOTIFY wireVersionChanged)

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

    enum SignalingMode {
        Cloud,  // Internet: Uses PeerJS server for peer discovery
        Local   // LAN: Host runs embedded signaling server (no internet needed)
    };
    Q_ENUM(SignalingMode)

    explicit ClayNetwork(QObject *parent = nullptr);
    ~ClayNetwork() override;

    QString networkId() const;
    QString nodeId() const;
    QString hostId() const;
    bool isHost() const;
    bool connected() const;
    QString hostLostReason() const { return hostLostReason_; }
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
    QString password() const;
    void setPassword(const QString &password);
    QString appId() const;
    void setAppId(const QString &appId);
    QString clientToken() const;
    void setClientToken(const QString &token);
    QVariantMap clientTokens() const;
    int wireVersion() const;
    void setWireVersion(int version);
    double sessionTime() const;
    bool sessionTimeSynced() const;
    QVariantMap sessionProperties() const;

public slots:
    void createRoom();
    void joinRoom(const QString &networkId);
    void leave();
    void broadcast(const QVariant &data);
    void broadcastState(const QVariant &data);
    // Queues a keyed state (#302); the queue goes out as batches when
    // control is back in the event loop, or at flushState()
    void broadcastKeyedState(const QVariant &data, const QString &key);
    void flushState();
    void sendTo(const QString &nodeId, const QVariant &data);
    // Test hook: puts json on the wire to nodeId as it is, bypassing the
    // message envelope - the net gym forges a sender id with it (#298)
    void sendRaw(const QString &nodeId, const QString &json);
    // Sends a ping to every peer. A peer that leaves one unanswered, and
    // sends nothing else either, for gracePeriod ms is dropped (#299)
    void ping();
    int stateAgeMs(const QString &nodeId) const;
    int keyedStateAgeMs(const QString &nodeId, const QString &key) const;
    // How long the fastest state from nodeId in the last 3 s took, in
    // session ms; NaN before one arrived (#304)
    double transitMs(const QString &nodeId) const;

    // Replicated objects (#306), see replica.h. A spawn returns the new
    // object's id, empty when refused; owner empty means this node, and
    // onOwnerLeft is "despawn" or "host".
    QString spawnObject(const QString &type, const QVariantMap &props, const QString &owner,
                        const QString &onOwnerLeft);
    bool despawnObject(const QString &id);
    bool setObjectOwner(const QString &id, const QString &owner);
    // The owner's state of an object: queued with the keyed states, lossy
    void sendObjectState(const QString &id, const QVariant &data);
    // ... or now and reliably, for a state that must arrive - the last one
    // of an object that came to rest
    void settleObjectState(const QString &id, const QVariant &data);
    bool setSessionProperty(const QString &name, const QVariant &value);
    QVariantList objects() const;
    // {id, type, owner, props, onOwnerLeft[, state]}, empty for no object
    QVariantMap objectInfo(const QString &id) const;
    // Test hook: the sequence entries kept for object states (#306)
    int objectSequenceEntries() const;

signals:
    void roomCreated(const QString &networkId);
    void playerJoined(const QString &nodeId);
    void playerLeft(const QString &nodeId);
    // sentAt: the session time (#304) when the sender sent it, or -1 when
    // the sender did not include one
    void messageReceived(const QString &fromId, const QVariant &data, double sentAt);
    // sentAt: the session time (#304) when the update was broadcast, or -1
    // when the sender did not include one. key is the key it was broadcast
    // with, empty for an unkeyed state (#302).
    void stateReceived(const QString &fromId, const QVariant &data, double sentAt,
                       const QString &key);
    void errorOccurred(const QString &message);
    // The host refused this joiner in the handshake (#323); reason is one
    // of handshake.h's codes, errorOccurred(message) follows
    void joinRefused(const QString &reason, const QString &message);
    // A joiner lost its host (#376); reason is one of hostloss.h's codes,
    // already in hostLostReason when connected turned false.
    // errorOccurred(message) follows
    void hostLost(const QString &reason, const QString &message);
    // The Cloud signaling connection dropped after it was up. Peers already
    // connected stay; the node reconnects under the same id, and a host
    // takes no new joiners until it is back (acceptingJoins, #299)
    void signalingLost();
    void diagnosticMessage(const QString &phase, const QString &detail);
    // Replicated objects (#306)
    void objectSpawned(const QString &id, const QString &type, const QString &owner,
                       const QVariantMap &props);
    void objectDespawned(const QString &id, const QString &type);
    void objectOwnerChanged(const QString &id, const QString &owner);
    void objectStateReceived(const QString &id, const QVariantMap &data, double sentAt);
    void sessionPropertyChanged(const QString &name, const QVariant &value);
    void sessionPropertiesChanged();

    void networkIdChanged();
    void nodeIdChanged();
    void hostIdChanged();
    void isHostChanged();
    void connectedChanged();
    void hostLostReasonChanged();
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
    void verboseChanged();
    void connectionPhaseChanged();
    void phaseTimingChanged();
    void latencyChanged();
    void peerStatsChanged();
    void syncStatsChanged();
    void linkConditionsChanged();
    void gracePeriodChanged();
    void acceptingJoinsChanged();
    void passwordChanged();
    void appIdChanged();
    void clientTokenChanged();
    void clientTokensChanged();
    void wireVersionChanged();
    void sessionClockChanged();

private slots:
    void onSignalingConnected(const QString &peerId);
    void onSignalingOffer(const QString &fromId, const QString &sdp, const QString &connectionId);
    void onSignalingAnswer(const QString &fromId, const QString &sdp);
    void onSignalingCandidate(const QString &fromId, const QString &candidate, const QString &mid);
    void onSignalingError(const QString &error);
    void onSignalingRejected(const QString &reason);
    void onSignalingDisconnected();

private:
    struct PeerConn {
        std::shared_ptr<rtc::PeerConnection> pc;
        std::shared_ptr<rtc::DataChannel> dc;
        // Second, unordered channel with maxRetransmits=0 - carries state
        // updates so a lost packet can never head-of-line-block newer ones.
        std::shared_ptr<rtc::DataChannel> dcState;
        QString connectionId;  // PeerJS connection ID (for ANSWER matching)
        bool ready = false;
        // Passed the handshake (#323): only now is the peer a node, and
        // only now does anything but the handshake go to or come from it
        bool admitted = false;
        // The host refused it and closes the connection in a moment
        bool refused = false;
        bool stateReady = false;
        // Per-peer stats (always on - the counters are cheap)
        int latency = -1;
        qint64 msgSent = 0;
        qint64 msgRecv = 0;
        qint64 bytesSent = 0;
        qint64 bytesRecv = 0;
        qint64 stateSent = 0;
        qint64 stateRecv = 0;
        // clock_ time of the first ping sent since this peer was last
        // heard from, -1 while nothing is outstanding (#299)
        qint64 unansweredSinceMs = -1;
        // clock_ time of the last message from this peer
        qint64 lastHeardMs = 0;
    };

    // libdatachannel calls back on its own threads, and a closed peer
    // connection still reports Closed from there after close() returned -
    // also after this object is gone (#357). Its callbacks reach the object
    // only through this guard, which the destructor disarms first.
    struct CallbackGuard {
        std::recursive_mutex mutex;
        ClayNetwork *owner = nullptr;
    };
    // Queues fn on the object's thread - or drops it, the object being gone
    template <typename F>
    static void post(const std::shared_ptr<CallbackGuard> &guard, F &&fn)
    {
        std::lock_guard<std::recursive_mutex> lock(guard->mutex);
        if (guard->owner)
            QMetaObject::invokeMethod(guard->owner, std::forward<F>(fn), Qt::QueuedConnection);
    }

    void setupPeerConnection(const QString &peerId, bool isOfferer);
    void setupDataChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc);
    void setupStateChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc);
    void assignChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc, bool isState);
    void sendToPeer(const QString &peerId, const QString &message);
    void sendStateToPeer(const QString &peerId, const QString &message);
    void writeToPeer(const QString &peerId, const QByteArray &utf8, bool stateChannel);
    // stateChannel marks the lossy one
    void handleDataChannelMessage(const QString &fromId, const std::string &message,
                                  bool stateChannel);
    void processMessage(const QString &fromId, const std::string &message, bool stateChannel);
    // A message from a peer that has not passed the handshake yet (#323)
    void handshakeMessage(const QString &fromId, const QJsonObject &obj);
    void admitJoiner(const QString &peerId, const QString &clientToken);
    void refuseJoiner(const QString &peerId, const QString &reason, const QString &message);
    void joinedHost();
    void refusedByHost(const QString &reason, const QString &message);
    void sendJson(const QString &peerId, const QJsonObject &msg);
    void handleSystemMessage(const QJsonObject &obj);
    void sendRosterTo(const QString &peerId);
    void hostBroadcastSystem(const QJsonObject &msg, const QString &exceptPeer = QString());
    void forgetSender(const QString &nodeId);
    void cleanupPeer(const QString &peerId);
    // A peer left - said goodbye, went silent or its connection failed. On
    // a Star joiner the host leaving ends the network (loseHost).
    // reason is a hostloss.h code, used when the peer is the host
    void peerGone(const QString &peerId, const QString &reason, const QString &message);
    void dropPeer(const QString &peerId);
    void loseHost(const QString &reason, const QString &message);
    // Empty while the host is not lost, cleared by createRoom()/joinRoom()
    void setHostLostReason(const QString &reason);
    void sendGoodbye();
    void checkLiveness();
    void armLivenessCheck();
    // Pings a peer that has gone quiet, so its deadline starts right after
    // the silence does and not at the next 2 s ping
    void probeQuietPeers();
    QString pingJson() const;
    // The pings that sync a joiner's session clock right after the welcome
    void syncBurst();
    // This node's monotonic clock in ms, what the session clock reads
    double localMs() const;
    // leave() without the goodbye: everything back to Disconnected
    void tearDown();
    void setAcceptingJoins(bool accepting);
    void setupReplicas();
    void scheduleSignalingRetry();
    void retrySignaling();
    QString generateNetworkCode() const;
    static QString generateLanSecret();
    void connectLocalSignaling();
    void setupLocalSignalingConnections();
    void setConnectionPhase(const QString &phase);
    void emitDiag(const QString &phase, const QString &detail);
    // True (after reporting the error) when linkConditions.dropSignaling
    // makes the signaling server unreachable
    bool refuseWhileSignalingDropped();
    static QString encodeLanCode(const QString &host, uint16_t port, const QString &secret);
    static bool isLanCode(const QString &code);
    static bool decodeLanCode(const QString &code, QString &host, uint16_t &port, QString &secret);
    static QString getLocalIpAddress();

    std::shared_ptr<CallbackGuard> guard_;
    std::unique_ptr<PeerJSSignaling> signaling_;
    std::unique_ptr<LocalSignalingServer> localServer_;
    std::unique_ptr<LocalSignalingClient> localClient_;
    QHash<QString, PeerConn> peers_;

    QString networkId_;
    QString nodeId_;
    QString hostId_;  // node id of the host, the same on every node
    QString lanSecret_;  // random part of a LAN code, checked by the host's signaling server
    bool isHost_ = false;
    bool connected_ = false;
    QString hostLostReason_;
    int maxNodes_ = 8;
    Topology topology_ = Star;
    Status status_ = Disconnected;
    bool autoRelay_ = true;
    SignalingMode signalingMode_ = Cloud;
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
    QElapsedTimer phaseTimer_;
    qint64 signalingStartMs_ = 0;
    qint64 iceStartMs_ = 0;
    qint64 handshakeStartMs_ = 0;
    qint64 totalStartMs_ = 0;

    // State sync bookkeeping - keyed by ORIGIN node id (relayed states come
    // in over the host connection but originate from other nodes).
    quint32 stateSeqOut_ = 0;
    QHash<QString, quint32> stateSeqIn_;
    QHash<QString, qint64> stateLastMs_;
    QHash<QString, qint64> stateRecvCount_;
    QHash<QString, qint64> stateDropCount_;
    QElapsedTimer clock_;
    // Keyed states (#302): sent ones wait in the queue for the flush,
    // received ones are sequenced per sender and key
    clay::network::statebatch::Queue keyedOut_;
    clay::network::statebatch::Tracker keyedIn_;
    QTimer keyedFlush_;
    // Replicated objects (#306): the table every node keeps, and the
    // owner's object states waiting for the flush with the keyed ones
    clay::network::replica::Table replicas_;
    clay::network::statebatch::Queue objectsOut_;

    // The session clock (#304): the host's runs from createRoom, a joiner's
    // is synced from its pings to the host
    clay::network::sessionclock::Clock session_;
    clay::network::sessionclock::TransitTracker transit_;
    QTimer syncBurst_;
    int syncBurstLeft_ = 0;

    // Simulated link for tests (#301): everything sent and received over
    // the data channels passes through it
    clay::network::LinkConditioner conditioner_;

    // A peer unheard for this long counts as gone (#299)
    int gracePeriod_ = 5000;
    QTimer livenessCheck_;
    QTimer quietProbe_;
    bool acceptingJoins_ = false;
    // The Cloud signaling connection of a live network dropped; retries
    // re-register under the same id until it is back (#299)
    bool signalingDown_ = false;
    int signalingRetryMs_ = 0;
    QTimer signalingRetry_;

    // The join handshake (#323)
    QString password_;
    QString appId_;
    QString clientToken_;
    int wireVersion_;
    QVariantMap clientTokens_;  // host: each joiner's token, by node id
};
