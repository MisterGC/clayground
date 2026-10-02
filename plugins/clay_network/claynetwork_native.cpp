// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claynetwork_native.h"
#include "signaling_peerjs.h"
#include "signaling_local.h"
#include "sender.h"
#include "handshake.h"
#include <rtc/rtc.hpp>
#include <QThread>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QDebug>
#include <QRandomGenerator>
#include <QNetworkInterface>
#include <QDateTime>
#include <cstring>

namespace {
// Network codes and LAN secrets use letters and digits that cannot be
// mistaken for each other (no 0/O, 1/I)
const QString kCodeChars = QStringLiteral("ABCDEFGHJKLMNPQRSTUVWXYZ23456789");
constexpr int kLanSecretLength = 8;
// A peer quiet for this long gets a ping of its own (#299)
constexpr int kQuietProbeMs = 500;
constexpr int kQuietProbeTickMs = 250;
// Signaling reconnects back off from the first to the last delay
constexpr int kSignalingRetryFirstMs = 1000;
constexpr int kSignalingRetryMaxMs = 4000;
namespace hs = clay::network::handshake;
}

ClayNetwork::ClayNetwork(QObject *parent)
    : QObject(parent)
    , signaling_(std::make_unique<PeerJSSignaling>(this))
    , clientToken_(QUuid::createUuid().toString(QUuid::WithoutBraces))
    , wireVersion_(hs::kWireVersion)
{
    clock_.start();
    QObject::connect(signaling_.get(), &PeerJSSignaling::connected,
                     this, &ClayNetwork::onSignalingConnected);
    QObject::connect(signaling_.get(), &PeerJSSignaling::offerReceived,
                     this, &ClayNetwork::onSignalingOffer);
    QObject::connect(signaling_.get(), &PeerJSSignaling::answerReceived,
                     this, &ClayNetwork::onSignalingAnswer);
    QObject::connect(signaling_.get(), &PeerJSSignaling::candidateReceived,
                     this, &ClayNetwork::onSignalingCandidate);
    QObject::connect(signaling_.get(), &PeerJSSignaling::errorOccurred,
                     this, &ClayNetwork::onSignalingError);
    QObject::connect(signaling_.get(), &PeerJSSignaling::rejected,
                     this, &ClayNetwork::onSignalingRejected);
    QObject::connect(signaling_.get(), &PeerJSSignaling::disconnected,
                     this, &ClayNetwork::onSignalingDisconnected);
    signalingRetry_.setSingleShot(true);
    QObject::connect(&signalingRetry_, &QTimer::timeout, this, &ClayNetwork::retrySignaling);
    livenessCheck_.setSingleShot(true);
    livenessCheck_.setTimerType(Qt::PreciseTimer);
    QObject::connect(&livenessCheck_, &QTimer::timeout, this, &ClayNetwork::checkLiveness);
    quietProbe_.setInterval(kQuietProbeTickMs);
    quietProbe_.setTimerType(Qt::PreciseTimer);
    QObject::connect(&quietProbe_, &QTimer::timeout, this, &ClayNetwork::probeQuietPeers);
}

ClayNetwork::~ClayNetwork()
{
    leave();
}

QString ClayNetwork::networkId() const { return networkId_; }
QString ClayNetwork::nodeId() const { return nodeId_; }
QString ClayNetwork::hostId() const { return hostId_; }
bool ClayNetwork::isHost() const { return isHost_; }
bool ClayNetwork::connected() const { return connected_; }
int ClayNetwork::nodeCount() const { return nodes_.size() + 1; }
QStringList ClayNetwork::nodes() const { return nodes_; }
int ClayNetwork::maxNodes() const { return maxNodes_; }
void ClayNetwork::setMaxNodes(int max) {
    if (maxNodes_ != max) {
        maxNodes_ = max;
        emit maxNodesChanged();
    }
}
ClayNetwork::Topology ClayNetwork::topology() const { return topology_; }
void ClayNetwork::setTopology(Topology t) {
    if (topology_ != t) {
        topology_ = t;
        emit topologyChanged();
    }
}
ClayNetwork::Status ClayNetwork::status() const { return status_; }
bool ClayNetwork::autoRelay() const { return autoRelay_; }
void ClayNetwork::setAutoRelay(bool relay) {
    if (autoRelay_ != relay) {
        autoRelay_ = relay;
        emit autoRelayChanged();
    }
}

ClayNetwork::SignalingMode ClayNetwork::signalingMode() const { return signalingMode_; }
void ClayNetwork::setSignalingMode(SignalingMode mode) {
    if (signalingMode_ != mode) {
        signalingMode_ = mode;
        emit signalingModeChanged();
    }
}

QVariantList ClayNetwork::iceServers() const { return iceServers_; }
void ClayNetwork::setIceServers(const QVariantList &servers) {
    if (iceServers_ != servers) {
        iceServers_ = servers;
        emit iceServersChanged();
    }
}

QString ClayNetwork::signalingUrl() const { return signalingUrl_; }
void ClayNetwork::setSignalingUrl(const QString &url) {
    if (signalingUrl_ != url) {
        signalingUrl_ = url;
        emit signalingUrlChanged();
    }
}

bool ClayNetwork::verifySignalingCertificate() const { return verifySignalingCertificate_; }
void ClayNetwork::setVerifySignalingCertificate(bool verify) {
    if (verifySignalingCertificate_ != verify) {
        verifySignalingCertificate_ = verify;
        signaling_->setVerifyCertificate(verify);
        emit verifySignalingCertificateChanged();
    }
}

bool ClayNetwork::verbose() const { return verbose_; }
void ClayNetwork::setVerbose(bool v) {
    if (verbose_ != v) {
        verbose_ = v;
        emit verboseChanged();
    }
}

QString ClayNetwork::connectionPhase() const { return connectionPhase_; }
QVariantMap ClayNetwork::phaseTiming() const { return phaseTiming_; }
int ClayNetwork::latency() const { return latency_; }

QVariantMap ClayNetwork::peerStats() const {
    QVariantMap stats;
    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it) {
        QVariantMap ps;
        ps["latency"] = it->latency;
        ps["msgSent"] = it->msgSent;
        ps["msgRecv"] = it->msgRecv;
        ps["bytesSent"] = it->bytesSent;
        ps["bytesRecv"] = it->bytesRecv;
        ps["stateSent"] = it->stateSent;
        ps["stateRecv"] = it->stateRecv;
        ps["stateChannel"] = it->stateReady ? "unreliable" : "fallback";
        ps["stateBacklog"] = it->dcState && it->dcState->isOpen()
            ? static_cast<qint64>(it->dcState->bufferedAmount()) : 0;
        stats[it.key()] = ps;
    }
    return stats;
}

QVariantMap ClayNetwork::syncStats() const {
    // Per ORIGIN node (covers relayed senders, not just direct peers)
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

QVariantMap ClayNetwork::linkConditions() const { return conditioner_.conditions(); }

void ClayNetwork::setLinkConditions(const QVariantMap &conditions)
{
    const bool wasDropped = conditioner_.dropSignaling();
    conditioner_.setConditions(conditions);
    // Cut a live Cloud signaling connection the way a server or network
    // drop would, so it ends in signalingLost like the real thing (#320)
    if (!wasDropped && conditioner_.dropSignaling() && signaling_->isConnected())
        signaling_->drop();
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

bool ClayNetwork::refuseWhileSignalingDropped()
{
    if (!conditioner_.dropSignaling())
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
    if (connected_) {
        leave();
    }

    // A Local host is its own signaling server, there is nothing to reach
    const bool ownServer = signalingMode_ == Local && signalingUrl_.isEmpty();
    if (!ownServer && refuseWhileSignalingDropped())
        return;

    isHost_ = true;
    status_ = Connecting;
    emit statusChanged();
    emit isHostChanged();

    // Start phase timing
    phaseTimer_.start();
    totalStartMs_ = 0;
    signalingStartMs_ = 0;
    phaseTiming_.clear();
    setConnectionPhase("signaling");
    emitDiag("signaling", "Connecting to signaling...");

    if (!signalingUrl_.isEmpty()) {
        // Custom signaling server: use Cloud mode via custom URL
        signaling_->setServerUrl(signalingUrl_);
        networkId_ = generateNetworkCode();
        emit networkIdChanged();
        signaling_->connect(networkId_);
    } else if (signalingMode_ == Local) {
        // Start local signaling server
        localServer_ = std::make_unique<LocalSignalingServer>(this);
        lanSecret_ = generateLanSecret();
        localServer_->setSecret(lanSecret_);
        if (!localServer_->start(0)) {  // 0 = auto-select port
            status_ = Error;
            emit statusChanged();
            emit errorOccurred("Failed to start local signaling server");
            return;
        }

        // Generate LAN code from local IP, port and a random secret that
        // the signaling server demands from every joiner (#293)
        QString localIp = getLocalIpAddress();
        networkId_ = encodeLanCode(localIp, localServer_->port(), lanSecret_);
        emit networkIdChanged();

        // Connect local client to own server for signaling
        connectLocalSignaling();
    } else {
        // Cloud mode: use PeerJS signaling
        networkId_ = generateNetworkCode();
        emit networkIdChanged();

        // Connect to signaling server with networkId as peerId (host uses networkId)
        signaling_->connect(networkId_);
    }
}

void ClayNetwork::joinRoom(const QString &networkId)
{
    qDebug() << "ClayNetwork: joinRoom called with networkId:" << networkId;

    if (networkId.isEmpty()) {
        qWarning() << "ClayNetwork: Cannot join with empty networkId";
        return;
    }

    if (connected_) {
        qDebug() << "ClayNetwork: Already connected, leaving first";
        leave();
    }

    if (refuseWhileSignalingDropped())
        return;

    isHost_ = false;
    networkId_ = networkId;
    status_ = Connecting;

    emit statusChanged();
    emit isHostChanged();
    emit networkIdChanged();

    // Start phase timing
    phaseTimer_.start();
    totalStartMs_ = 0;
    signalingStartMs_ = 0;
    phaseTiming_.clear();
    setConnectionPhase("signaling");
    emitDiag("signaling", "Connecting to signaling...");

    if (!signalingUrl_.isEmpty()) {
        // Custom signaling server: use Cloud mode via custom URL
        qDebug() << "ClayNetwork: Using custom signaling:" << signalingUrl_;
        signaling_->setServerUrl(signalingUrl_);
        signaling_->connect();
    } else {
        // Check if this is a LAN code
        QString host;
        uint16_t port;
        QString secret;
        if (isLanCode(networkId)) {
            // A mistyped LAN code fails here, not as a connect to a wrong
            // address or a cloud lookup of a code nobody hosts
            if (!decodeLanCode(networkId, host, port, secret)) {
                qWarning() << "ClayNetwork: Malformed LAN code" << networkId;
                status_ = Error;
                emit statusChanged();
                emit errorOccurred("Invalid LAN code");
                return;
            }
            // Local mode: connect to local signaling server
            qDebug() << "ClayNetwork: Decoded LAN code - connecting to" << host << ":" << port;
            signalingMode_ = Local;
            emit signalingModeChanged();
            connectLocalSignaling();
        } else {
            // Cloud mode: use PeerJS signaling
            qDebug() << "ClayNetwork: Connecting to signaling server as client...";
            signalingMode_ = Cloud;
            emit signalingModeChanged();
            signaling_->connect();
        }
    }
}

void ClayNetwork::leave()
{
    sendGoodbye();
    tearDown();
}

void ClayNetwork::sendGoodbye()
{
    // Without it a peer learns of a clean leave only when its connection
    // times out (#299). Written past the link conditioner, which leave()
    // clears: a goodbye still waiting there would never be sent.
    QJsonObject bye;
    bye["t"] = "y";
    bye["sys"] = "bye";
    const QByteArray utf8 = QJsonDocument(bye).toJson(QJsonDocument::Compact);
    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
        if (it->admitted)
            writeToPeer(it.key(), utf8, false);
}

void ClayNetwork::tearDown()
{
    // Nothing still on the simulated link outlives the network it was for
    conditioner_.clear();
    signalingRetry_.stop();
    livenessCheck_.stop();
    quietProbe_.stop();
    signalingDown_ = false;
    signalingRetryMs_ = 0;

    // Close all peer connections
    for (const QString &peerId : peers_.keys()) {
        cleanupPeer(peerId);
    }
    peers_.clear();
    nodes_.clear();

    // Clean up signaling
    if (localClient_) {
        localClient_->disconnect();
        localClient_.reset();
    }
    if (localServer_) {
        localServer_->stop();
        localServer_.reset();
    }
    signaling_->disconnect();

    networkId_.clear();
    nodeId_.clear();
    hostId_.clear();
    isHost_ = false;
    connected_ = false;
    status_ = Disconnected;
    connectionPhase_.clear();
    phaseTiming_.clear();
    latency_ = -1;
    stateSeqOut_ = 0;
    stateSeqIn_.clear();
    stateLastMs_.clear();
    stateRecvCount_.clear();
    stateDropCount_.clear();
    clientTokens_.clear();
    setAcceptingJoins(false);

    emit networkIdChanged();
    emit nodeIdChanged();
    emit hostIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit statusChanged();
    emit nodeCountChanged();
    emit nodesChanged();
    emit connectionPhaseChanged();
    emit phaseTimingChanged();
    emit latencyChanged();
    emit peerStatsChanged();
    emit clientTokensChanged();
}

void ClayNetwork::broadcast(const QVariant &data)
{
    QJsonObject msg;
    msg["t"] = "m";  // message
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
        if (it->admitted)
            sendToPeer(it.key(), json);
}

void ClayNetwork::broadcastState(const QVariant &data)
{
    QJsonObject msg;
    msg["t"] = "s";  // state
    msg["q"] = static_cast<qint64>(++stateSeqOut_);
    // Sender clock, so receivers can place the snapshot on the sender's
    // timeline instead of its arrival time (StateInterpolator, #290)
    msg["ts"] = static_cast<double>(QDateTime::currentMSecsSinceEpoch());
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
        if (it->admitted)
            sendStateToPeer(it.key(), json);
}

void ClayNetwork::sendTo(const QString &nodeId, const QVariant &data)
{
    if (!peers_.contains(nodeId) || !peers_[nodeId].admitted) {
        qWarning() << "ClayNetwork: Unknown peer" << nodeId;
        return;
    }

    QJsonObject msg;
    msg["t"] = "m";
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));
    sendToPeer(nodeId, json);
}

void ClayNetwork::sendRaw(const QString &nodeId, const QString &json)
{
    sendToPeer(nodeId, json);
}

void ClayNetwork::onSignalingConnected(const QString &peerId)
{
    qDebug() << "ClayNetwork: Signaling connected, peerId:" << peerId << "isHost:" << isHost_;

    if (signalingDown_) {
        // Back under the id the network knows us by: nothing to set up again
        signalingDown_ = false;
        signalingRetryMs_ = 0;
        signalingRetry_.stop();
        emitDiag("signaling", "Signaling restored");
        setAcceptingJoins(isHost_);
        return;
    }

    nodeId_ = peerId;
    emit nodeIdChanged();

    qint64 signalingMs = phaseTimer_.elapsed();
    phaseTiming_["signaling"] = signalingMs;
    emit phaseTimingChanged();
    emitDiag("signaling", QString("Signaling ready (%1ms)").arg(signalingMs));

    if (isHost_) {
        // Host is ready, announce network
        hostId_ = nodeId_;
        emit hostIdChanged();
        connected_ = true;
        status_ = Connected;
        setAcceptingJoins(true);
        setConnectionPhase("");
        phaseTiming_["total"] = signalingMs;
        emit phaseTimingChanged();
        emit connectedChanged();
        emit statusChanged();
        emit roomCreated(networkId_);
        qDebug() << "ClayNetwork: Hosting network" << networkId_;
    } else {
        // Client: initiate connection to host
        setConnectionPhase("ice");
        iceStartMs_ = phaseTimer_.elapsed();
        // Over the embedded LAN signaling the host registers as "HOST"; over a
        // PeerJS server (the public one or a custom signalingUrl) it registers
        // with the network code - the same id the host reports as its nodeId
        hostId_ = localClient_ ? QStringLiteral("HOST") : networkId_;
        emit hostIdChanged();
        qDebug() << "ClayNetwork: Client connected to signaling, now connecting to host:" << hostId_;
        setupPeerConnection(hostId_, true);
    }
}

void ClayNetwork::onSignalingOffer(const QString &fromId, const QString &sdp, const QString &connectionId)
{
    qDebug() << "ClayNetwork: Received offer from" << fromId << "connectionId:" << connectionId;

    if (!isHost_) {
        qWarning() << "ClayNetwork: Non-host received offer, ignoring";
        return;
    }

    // Joiners still in the handshake hold a place too
    if (peers_.size() + 1 >= maxNodes_ && !peers_.contains(fromId)) {
        qWarning() << "ClayNetwork: Max nodes reached, rejecting" << fromId;
        emitDiag("signaling", QString("Rejected %1 (network full)").arg(fromId.left(8)));
        // Send rejection
        if (signalingMode_ == Local && localClient_) {
            localClient_->sendReject(fromId, connectionId);
        } else {
            signaling_->sendReject(fromId, connectionId);
        }
        return;
    }

    emitDiag("ice", QString("Offer from %1, negotiating...").arg(fromId.left(8)));
    setupPeerConnection(fromId, false);

    if (peers_.contains(fromId) && peers_[fromId].pc) {
        // Store the connectionId for use in ANSWER
        peers_[fromId].connectionId = connectionId;
        peers_[fromId].pc->setRemoteDescription(rtc::Description(sdp.toStdString(), rtc::Description::Type::Offer));
    }
}

void ClayNetwork::onSignalingAnswer(const QString &fromId, const QString &sdp)
{
    qDebug() << "ClayNetwork: Received answer from" << fromId;

    if (peers_.contains(fromId) && peers_[fromId].pc) {
        peers_[fromId].pc->setRemoteDescription(rtc::Description(sdp.toStdString(), rtc::Description::Type::Answer));
    }
}

void ClayNetwork::onSignalingCandidate(const QString &fromId, const QString &candidate, const QString &mid)
{
    if (peers_.contains(fromId) && peers_[fromId].pc) {
        peers_[fromId].pc->addRemoteCandidate(rtc::Candidate(candidate.toStdString(), mid.toStdString()));
    }
}

void ClayNetwork::onSignalingError(const QString &error)
{
    if (signalingDown_) {
        // A reconnect that did not get through - the server may still hold
        // our old id for a while (ID-TAKEN) or be unreachable: try again
        emitDiag("signaling", QString("Reconnect failed: %1").arg(error));
        scheduleSignalingRetry();
        return;
    }
    qWarning() << "ClayNetwork: Signaling error:" << error;
    status_ = Error;
    emit statusChanged();
    emit errorOccurred(error);
}

void ClayNetwork::onSignalingRejected(const QString &reason)
{
    // A full native host refuses at signaling, a full browser host on the
    // data channel: either way the joiner hears joinRefused("refused")
    if (isHost_ || status_ != Connecting)
        return;
    refusedByHost(hs::refused(), reason);
}

void ClayNetwork::onSignalingDisconnected()
{
    qWarning() << "ClayNetwork: Signaling connection lost";
    emitDiag("signaling", "Signaling connection lost");
    if (signalingDown_) {
        // A reconnect got as far as OPEN and dropped again
        scheduleSignalingRetry();
        return;
    }
    // The network goes on over the data channels; only a joiner that is
    // still to come needs the server, so get back to it under the same id
    const bool inNetwork = connected_ || status_ == Connecting;
    if (inNetwork && !nodeId_.isEmpty()) {
        signalingDown_ = true;
        setAcceptingJoins(false);
        scheduleSignalingRetry();
    }
    emit signalingLost();
}

void ClayNetwork::scheduleSignalingRetry()
{
    if (!signalingDown_ || signalingRetry_.isActive())
        return;
    signalingRetryMs_ = signalingRetryMs_ == 0
        ? kSignalingRetryFirstMs : qMin(signalingRetryMs_ * 2, kSignalingRetryMaxMs);
    signalingRetry_.start(signalingRetryMs_);
}

void ClayNetwork::retrySignaling()
{
    if (!signalingDown_)
        return;
    if (conditioner_.dropSignaling()) {
        emitDiag("signaling", "Signaling server unreachable (link conditioner)");
        scheduleSignalingRetry();
        return;
    }
    emitDiag("signaling", QString("Reconnecting to signaling as %1").arg(nodeId_));
    signaling_->connect(nodeId_);
}

void ClayNetwork::setupPeerConnection(const QString &peerId, bool isOfferer)
{
    qDebug() << "ClayNetwork: Setting up peer connection to" << peerId << (isOfferer ? "(offerer)" : "(answerer)");

    rtc::Configuration config;

    // Configure ICE servers
    if (iceServers_.isEmpty()) {
        // Default: two STUN servers for fallback
        config.iceServers.emplace_back("stun:stun.l.google.com:19302");
        config.iceServers.emplace_back("stun:stun1.l.google.com:19302");
    } else {
        for (const QVariant &entry : iceServers_) {
            if (entry.typeId() == QMetaType::QString) {
                config.iceServers.emplace_back(entry.toString().toStdString());
            } else if (entry.typeId() == QMetaType::QVariantMap) {
                QVariantMap obj = entry.toMap();
                QString urls = obj["urls"].toString();
                QString username = obj.value("username").toString();
                QString credential = obj.value("credential").toString();
                if (!urls.isEmpty()) {
                    rtc::IceServer server(urls.toStdString());
                    if (!username.isEmpty()) {
                        server.username = username.toStdString();
                        server.password = credential.toStdString();
                    }
                    config.iceServers.emplace_back(std::move(server));
                }
            }
        }
    }

    emitDiag("ice", QString("ICE config: %1 server(s)").arg(config.iceServers.size()));

    auto pc = std::make_shared<rtc::PeerConnection>(config);
    qDebug() << "ClayNetwork: PeerConnection created";

    PeerConn &peer = peers_[peerId];
    peer.pc = pc;
    peer.ready = false;
    peer.admitted = false;
    peer.refused = false;

    pc->onStateChange([this, peerId](rtc::PeerConnection::State state) {
        qDebug() << "ClayNetwork: Peer" << peerId << "state:" << static_cast<int>(state);

        static const char* stateNames[] = {
            "New", "Connecting", "Connected", "Disconnected", "Failed", "Closed"
        };
        int idx = static_cast<int>(state);
        const char* name = (idx >= 0 && idx <= 5) ? stateNames[idx] : "Unknown";

        QMetaObject::invokeMethod(this, [this, peerId, state, name]() {
            emitDiag("ice", QString("Peer %1: %2").arg(peerId.left(8), name));

            // Disconnected can recover, so it is not a leave: a peer that
            // stays unreachable leaves its pings unanswered and is dropped
            // after the grace period (#299)
            if (state == rtc::PeerConnection::State::Failed ||
                state == rtc::PeerConnection::State::Closed) {
                peerGone(peerId, QStringLiteral("The connection to the host failed"));
            }
        }, Qt::QueuedConnection);
    });

    pc->onGatheringStateChange([this, peerId](rtc::PeerConnection::GatheringState state) {
        if (state == rtc::PeerConnection::GatheringState::Complete) {
            QMetaObject::invokeMethod(this, [this, peerId]() {
                emitDiag("ice", QString("ICE gathering complete for %1").arg(peerId.left(8)));
            }, Qt::QueuedConnection);
        }
    });

    pc->onLocalDescription([this, peerId, isOfferer](rtc::Description desc) {
        QString sdp = QString::fromStdString(std::string(desc));
        qDebug() << "ClayNetwork: Local description generated, type:" << (isOfferer ? "offer" : "answer") << "for peer:" << peerId;
        if (isOfferer) {
            qDebug() << "ClayNetwork: Sending offer to" << peerId;
            if (signalingMode_ == Local && localClient_) {
                localClient_->sendOffer(peerId, sdp);
            } else {
                signaling_->sendOffer(peerId, sdp);
            }
        } else {
            QString connectionId = peers_.contains(peerId) ? peers_[peerId].connectionId : QString();
            qDebug() << "ClayNetwork: Sending answer to" << peerId << "with connectionId:" << connectionId;
            if (signalingMode_ == Local && localClient_) {
                localClient_->sendAnswer(peerId, sdp, connectionId);
            } else {
                signaling_->sendAnswer(peerId, sdp, connectionId);
            }
        }
    });

    pc->onLocalCandidate([this, peerId](rtc::Candidate candidate) {
        QString candidateStr = QString::fromStdString(candidate.candidate());
        // Parse candidate type for diagnostics
        QString candidateType = "unknown";
        if (candidateStr.contains("typ host")) candidateType = "host";
        else if (candidateStr.contains("typ srflx")) candidateType = "srflx";
        else if (candidateStr.contains("typ relay")) candidateType = "relay";
        else if (candidateStr.contains("typ prflx")) candidateType = "prflx";

        QMetaObject::invokeMethod(this, [this, peerId, candidateType]() {
            emitDiag("ice", QString("Candidate: %1 (%2)").arg(candidateType, peerId.left(8)));
        }, Qt::QueuedConnection);

        if (signalingMode_ == Local && localClient_) {
            localClient_->sendCandidate(peerId, candidateStr,
                                        QString::fromStdString(candidate.mid()));
        } else {
            signaling_->sendCandidate(peerId, candidateStr,
                                      QString::fromStdString(candidate.mid()));
        }
    });

    pc->onDataChannel([this, peerId](std::shared_ptr<rtc::DataChannel> dc) {
        qDebug() << "ClayNetwork: Data channel received from" << peerId
                 << QString::fromStdString(dc->label());
        if (dc->label() == "state")
            setupStateChannel(peerId, dc);
        else
            setupDataChannel(peerId, dc);
    });

    if (isOfferer) {
        qDebug() << "ClayNetwork: Creating data channels as offerer";
        auto dc = pc->createDataChannel("data");
        setupDataChannel(peerId, dc);
        // State channel: unordered, no retransmits - stale positions are
        // dropped by the network instead of delaying fresh ones.
        rtc::DataChannelInit stateInit;
        stateInit.reliability.unordered = true;
        stateInit.reliability.maxRetransmits = 0;
        auto dcState = pc->createDataChannel("state", stateInit);
        setupStateChannel(peerId, dcState);
    }

    qDebug() << "ClayNetwork: Peer connection setup complete for" << peerId;
}

// The offerer calls setupDataChannel/setupStateChannel on the Qt thread; the
// answerer gets them from pc->onDataChannel on libdatachannel's thread. The
// callbacks have to be registered right there (libdatachannel fires onOpen
// synchronously after onDataChannel returns), but peers_ belongs to the Qt
// thread, so the bookkeeping hops over like every other callback (#292).
void ClayNetwork::assignChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc, bool isState)
{
    auto assign = [this, peerId, dc, isState]() {
        if (isState)
            peers_[peerId].dcState = dc;
        else
            peers_[peerId].dc = dc;
    };
    if (QThread::currentThread() == thread())
        assign();
    else
        QMetaObject::invokeMethod(this, assign, Qt::QueuedConnection);
}

void ClayNetwork::setupDataChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc)
{
    assignChannel(peerId, dc, false);

    dc->onOpen([this, peerId]() {
        QMetaObject::invokeMethod(this, [this, peerId]() {
            qDebug() << "ClayNetwork: Data channel open with" << peerId;
            if (!peers_.contains(peerId))
                return;
            PeerConn &peer = peers_[peerId];
            peer.ready = true;
            peer.lastHeardMs = clock_.elapsed();

            // The peer is no node yet: the joiner says hello, the host
            // waits for it (#323) - and refuses a joiner that never does
            if (isHost_) {
                auto pc = peer.pc;
                QTimer::singleShot(hs::kTimeoutMs, this, [this, peerId, pc]() {
                    if (!peers_.contains(peerId) || peers_[peerId].pc != pc
                        || peers_[peerId].admitted || peers_[peerId].refused)
                        return;
                    const auto v = hs::judgeHello(QJsonObject(), wireVersion_, appId_, password_);
                    refuseJoiner(peerId, v.reason, v.message);
                });
            } else if (!connected_) {
                phaseTiming_["ice"] = phaseTimer_.elapsed() - iceStartMs_;
                phaseTiming_["datachannel"] = 0;
                emit phaseTimingChanged();
                emitDiag("datachannel", QString("Data channel open (%1ms), saying hello")
                         .arg(phaseTimer_.elapsed()));
                setConnectionPhase("handshake");
                handshakeStartMs_ = phaseTimer_.elapsed();
                sendJson(peerId, hs::hello(wireVersion_, appId_, password_, clientToken_));
            }
        }, Qt::QueuedConnection);
    });

    dc->onMessage([this, peerId](auto message) {
        if (std::holds_alternative<std::string>(message)) {
            handleDataChannelMessage(peerId, std::get<std::string>(message), false);
        } else if (std::holds_alternative<rtc::binary>(message)) {
            // Handle binary messages (from PeerJS JSON mode)
            const auto& bytes = std::get<rtc::binary>(message);
            std::string str(reinterpret_cast<const char*>(bytes.data()), bytes.size());
            handleDataChannelMessage(peerId, str, false);
        }
    });

    dc->onClosed([this, peerId]() {
        QMetaObject::invokeMethod(this, [this, peerId]() {
            qDebug() << "ClayNetwork: Data channel closed with" << peerId;
        }, Qt::QueuedConnection);
    });
}

void ClayNetwork::setupStateChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc)
{
    assignChannel(peerId, dc, true);

    dc->onOpen([this, peerId]() {
        QMetaObject::invokeMethod(this, [this, peerId]() {
            if (peers_.contains(peerId)) {
                peers_[peerId].stateReady = true;
                emitDiag("datachannel", QString("State channel open (%1)").arg(peerId.left(8)));
            }
        }, Qt::QueuedConnection);
    });

    dc->onMessage([this, peerId](auto message) {
        if (std::holds_alternative<std::string>(message)) {
            handleDataChannelMessage(peerId, std::get<std::string>(message), true);
        } else if (std::holds_alternative<rtc::binary>(message)) {
            const auto& bytes = std::get<rtc::binary>(message);
            std::string str(reinterpret_cast<const char*>(bytes.data()), bytes.size());
            handleDataChannelMessage(peerId, str, true);
        }
    });

    dc->onClosed([this, peerId]() {
        QMetaObject::invokeMethod(this, [this, peerId]() {
            if (peers_.contains(peerId))
                peers_[peerId].stateReady = false;
        }, Qt::QueuedConnection);
    });
}

void ClayNetwork::sendToPeer(const QString &peerId, const QString &message)
{
    const QByteArray utf8 = message.toUtf8();
    conditioner_.offer(clay::network::LinkConditioner::Outgoing, false, utf8.size(),
                       [this, peerId, utf8]() { writeToPeer(peerId, utf8, false); });
}

void ClayNetwork::sendStateToPeer(const QString &peerId, const QString &message)
{
    if (!peers_.contains(peerId))
        return;
    const PeerConn &peer = peers_[peerId];
    // Prefer the lossy state channel; fall back to the reliable one while the
    // state channel is still negotiating (or when a peer doesn't offer one).
    const bool lossy = peer.stateReady && peer.dcState && peer.dcState->isOpen();
    const QByteArray utf8 = message.toUtf8();
    conditioner_.offer(clay::network::LinkConditioner::Outgoing, lossy, utf8.size(),
                       [this, peerId, utf8, lossy]() { writeToPeer(peerId, utf8, lossy); });
}

void ClayNetwork::writeToPeer(const QString &peerId, const QByteArray &utf8, bool stateChannel)
{
    if (!peers_.contains(peerId))
        return;
    PeerConn &peer = peers_[peerId];
    const auto &dc = stateChannel ? peer.dcState : peer.dc;
    if (!dc || !dc->isOpen())
        return;
    // Send as binary (bytes) for PeerJS JSON mode compatibility
    std::vector<std::byte> bytes(utf8.size());
    std::memcpy(bytes.data(), utf8.constData(), utf8.size());
    dc->send(bytes);
    if (stateChannel)
        peer.stateSent++;
    else
        peer.msgSent++;
    peer.bytesSent += utf8.size();
}

void ClayNetwork::handleDataChannelMessage(const QString &fromId, const std::string &message,
                                           bool stateChannel)
{
    QMetaObject::invokeMethod(this, [this, fromId, message, stateChannel]() {
        conditioner_.offer(clay::network::LinkConditioner::Incoming, stateChannel,
                           qsizetype(message.size()),
                           [this, fromId, message, stateChannel]() {
                               processMessage(fromId, message, stateChannel);
                           });
    }, Qt::QueuedConnection);
}

void ClayNetwork::processMessage(const QString &fromId, const std::string &message,
                                 bool stateChannel)
{
    if (peers_.contains(fromId)) {
        peers_[fromId].msgRecv++;
        peers_[fromId].bytesRecv += message.size();
        peers_[fromId].unansweredSinceMs = -1;
        peers_[fromId].lastHeardMs = clock_.elapsed();
    }

    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(message));
    if (!doc.isObject()) {
        return;
    }

    QJsonObject obj = doc.object();
    QString type = obj["t"].toString();

    // Nothing but the handshake passes before it is done (#323). A state
    // that overtook the host's welcome on the unordered channel is no
    // answer to the hello: it is dropped, not judged.
    if (peers_.contains(fromId) && !peers_[fromId].admitted) {
        if (!stateChannel)
            handshakeMessage(fromId, obj);
        return;
    }

    // Handle ping/pong (not relayed)
    if (type == "p") {
        // Respond with pong, echo timestamp
        QJsonObject pong;
        pong["t"] = "P";
        pong["ts"] = obj["ts"];
        QString json = QString::fromUtf8(QJsonDocument(pong).toJson(QJsonDocument::Compact));
        sendToPeer(fromId, json);
        return;
    }
    if (type == "P") {
        // Pong received, calculate RTT
        qint64 sentTs = obj["ts"].toDouble();
        qint64 now = QDateTime::currentMSecsSinceEpoch();
        int rtt = static_cast<int>(now - sentTs);
        if (peers_.contains(fromId)) {
            int prev = peers_[fromId].latency;
            // Exponential moving average (70/30)
            peers_[fromId].latency = (prev < 0) ? rtt : static_cast<int>(prev * 0.7 + rtt * 0.3);

            // Update best latency across all peers
            int best = -1;
            for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it) {
                if (it->latency >= 0 && (best < 0 || it->latency < best))
                    best = it->latency;
            }
            if (latency_ != best) {
                latency_ = best;
                emit latencyChanged();
            }
            emit peerStatsChanged();
            emit syncStatsChanged();
        }
        return;
    }

    // Handle rejection from host
    if (type == "R") {
        QString reason = obj["r"].toString();
        emit errorOccurred(reason.isEmpty() ? "Connection rejected" : reason);
        return;
    }

    // A peer that leaves says so (#299)
    if (type == "y" && obj["sys"].toString() == "bye") {
        peerGone(fromId, QStringLiteral("The host left the network"));
        return;
    }

    // Roster updates from the host (Star topology)
    if (type == "y") {
        handleSystemMessage(obj);
        return;
    }

    QJsonObject dataObj = obj["d"].toObject();
    QVariant data = dataObj.toVariantMap();

    // The link vouches for the sender, not the message: only the host's
    // relay may name another node, and that node must be in the roster
    QString actualFromId = clay::network::attributeSender(
        fromId, obj["from"].toString(), isHost_, hostId_, nodes_);
    if (actualFromId.isEmpty()) {
        emitDiag("datachannel", QString("Dropped message over %1 from unknown node %2")
                 .arg(fromId.left(8), obj["from"].toString().left(8)));
        return;
    }

    // State updates carry a per-sender sequence number; the state channel
    // is unordered, so anything at or behind the newest accepted seq is
    // stale and gets dropped instead of rewinding the entity.
    if (type == "s" && obj.contains("q")) {
        auto seq = static_cast<quint32>(obj["q"].toDouble());
        if (stateSeqIn_.contains(actualFromId)
            && seq <= stateSeqIn_.value(actualFromId)) {
            stateDropCount_[actualFromId]++;
            return;
        }
        stateSeqIn_[actualFromId] = seq;
    }
    if (type == "s") {
        stateRecvCount_[actualFromId]++;
        stateLastMs_[actualFromId] = clock_.elapsed();
        if (peers_.contains(fromId))
            peers_[fromId].stateRecv++;
    }

    // Host in Star topology: relay to other peers
    if (isHost_ && autoRelay_ && topology_ == Star) {
        // Add "from" field and relay to all OTHER peers; state goes over
        // the lossy channel, messages stay reliable
        obj["from"] = fromId;
        QString relayJson = QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it) {
            if (it.key() == fromId || !it->admitted)
                continue;
            if (type == "s")
                sendStateToPeer(it.key(), relayJson);
            else
                sendToPeer(it.key(), relayJson);
        }
    }

    // Emit signal to application
    if (type == "m") {
        emit messageReceived(actualFromId, data);
    } else if (type == "s") {
        double sentAt = obj.contains("ts") ? obj["ts"].toDouble() : -1.0;
        emit stateReceived(actualFromId, data, sentAt);
    }
}

void ClayNetwork::sendJson(const QString &peerId, const QJsonObject &msg)
{
    sendToPeer(peerId, QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void ClayNetwork::handshakeMessage(const QString &fromId, const QJsonObject &obj)
{
    if (isHost_) {
        if (peers_[fromId].refused)
            return;
        const auto v = hs::judgeHello(obj, wireVersion_, appId_, password_);
        if (v.ok())
            admitJoiner(fromId, obj["tok"].toString());
        else
            refuseJoiner(fromId, v.reason, v.message);
        return;
    }
    // A joiner has one link, the one to the host
    if (fromId != hostId_)
        return;
    const auto v = hs::judgeReply(obj, hostId_, wireVersion_);
    if (v.ok())
        joinedHost();
    else
        refusedByHost(v.reason, v.message);
}

void ClayNetwork::admitJoiner(const QString &peerId, const QString &clientToken)
{
    PeerConn &peer = peers_[peerId];
    peer.admitted = true;
    peer.lastHeardMs = clock_.elapsed();
    clientTokens_[peerId] = clientToken;
    emit clientTokensChanged();
    emitDiag("datachannel", QString("Admitted %1").arg(peerId.left(8)));
    // The welcome goes first: the joiner takes nothing else before it
    sendJson(peerId, hs::welcome(nodeId_, wireVersion_));
    if (gracePeriod_ > 0 && !quietProbe_.isActive())
        quietProbe_.start();

    nodes_.append(peerId);
    emit nodeCountChanged();
    emit nodesChanged();
    emit playerJoined(peerId);

    // Star topology: the host owns the roster - tell the new node about
    // everyone and everyone about the new node, so joiners can see each
    // other despite only connecting to us.
    if (topology_ == Star) {
        sendRosterTo(peerId);
        QJsonObject joined;
        joined["t"] = "y";
        joined["sys"] = "node_joined";
        joined["nodeId"] = peerId;
        hostBroadcastSystem(joined, peerId);
    }
}

void ClayNetwork::refuseJoiner(const QString &peerId, const QString &reason,
                               const QString &message)
{
    PeerConn &peer = peers_[peerId];
    peer.refused = true;
    qWarning() << "ClayNetwork: Refused" << peerId << "-" << message;
    emitDiag("datachannel", QString("Refused %1: %2").arg(peerId.left(8), message));
    QJsonObject refusal = hs::refusal({reason, message});
    sendJson(peerId, refusal);
    // Closed once the refusal is out; a new connection under the same id
    // is not this one
    auto pc = peer.pc;
    QTimer::singleShot(hs::kCloseDelayMs, this, [this, peerId, pc]() {
        if (peers_.contains(peerId) && peers_[peerId].pc == pc)
            cleanupPeer(peerId);
    });
}

void ClayNetwork::joinedHost()
{
    PeerConn &peer = peers_[hostId_];
    peer.admitted = true;
    peer.lastHeardMs = clock_.elapsed();
    if (gracePeriod_ > 0 && !quietProbe_.isActive())
        quietProbe_.start();
    nodes_.append(hostId_);
    emit nodeCountChanged();
    emit nodesChanged();
    emit playerJoined(hostId_);

    const qint64 totalMs = phaseTimer_.elapsed();
    phaseTiming_["handshake"] = totalMs - handshakeStartMs_;
    phaseTiming_["total"] = totalMs;
    emit phaseTimingChanged();
    setConnectionPhase("");
    emitDiag("datachannel", QString("Welcomed by the host (total: %1ms)").arg(totalMs));

    connected_ = true;
    status_ = Connected;
    emit connectedChanged();
    emit statusChanged();
}

void ClayNetwork::refusedByHost(const QString &reason, const QString &message)
{
    qWarning() << "ClayNetwork: The host refused this node -" << message;
    tearDown();
    status_ = Error;
    emit statusChanged();
    emit joinRefused(reason, message);
    emit errorOccurred(message);
}

void ClayNetwork::handleSystemMessage(const QJsonObject &obj)
{
    if (isHost_)
        return;  // The host is the roster authority; nothing to apply

    QString sys = obj["sys"].toString();
    if (sys == "roster") {
        // Authoritative list of all OTHER joiners (the host is already
        // in nodes_ since its welcome)
        QStringList updated = nodes_;
        for (const auto &v : obj["nodes"].toArray()) {
            QString id = v.toString();
            if (id != nodeId_ && !updated.contains(id))
                updated.append(id);
        }
        if (updated != nodes_) {
            QStringList added;
            for (const QString &id : updated)
                if (!nodes_.contains(id))
                    added.append(id);
            nodes_ = updated;
            emit nodeCountChanged();
            emit nodesChanged();
            for (const QString &id : added)
                emit playerJoined(id);
        }
    } else if (sys == "node_joined") {
        QString id = obj["nodeId"].toString();
        if (!id.isEmpty() && id != nodeId_ && !nodes_.contains(id)) {
            nodes_.append(id);
            emit nodeCountChanged();
            emit nodesChanged();
            emit playerJoined(id);
        }
    } else if (sys == "node_left") {
        QString id = obj["nodeId"].toString();
        if (nodes_.removeAll(id) > 0) {
            forgetSender(id);
            emit nodeCountChanged();
            emit nodesChanged();
            emit playerLeft(id);
        }
    }
}

void ClayNetwork::sendRosterTo(const QString &peerId)
{
    QJsonObject msg;
    msg["t"] = "y";
    msg["sys"] = "roster";
    QJsonArray arr;
    for (const QString &id : nodes_)
        if (id != peerId)
            arr.append(id);
    msg["nodes"] = arr;
    sendToPeer(peerId, QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void ClayNetwork::hostBroadcastSystem(const QJsonObject &msg, const QString &exceptPeer)
{
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));
    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
        if (it.key() != exceptPeer && it->admitted)
            sendToPeer(it.key(), json);
}

void ClayNetwork::forgetSender(const QString &nodeId)
{
    stateSeqIn_.remove(nodeId);
    stateLastMs_.remove(nodeId);
    stateRecvCount_.remove(nodeId);
    stateDropCount_.remove(nodeId);
}

void ClayNetwork::peerGone(const QString &peerId, const QString &reason)
{
    if (!peers_.contains(peerId) || !peers_[peerId].ready)
        return;
    if (!peers_[peerId].admitted) {
        // Gone in the handshake: no node to report. A joiner has nothing
        // without its host.
        if (!isHost_ && peerId == hostId_)
            loseHost(reason);
        else
            cleanupPeer(peerId);
        return;
    }
    if (!isHost_ && topology_ == Star && peerId == hostId_)
        loseHost(reason);
    else
        dropPeer(peerId);
}

void ClayNetwork::dropPeer(const QString &peerId)
{
    cleanupPeer(peerId);
    nodes_.removeAll(peerId);
    forgetSender(peerId);
    if (clientTokens_.remove(peerId) > 0)
        emit clientTokensChanged();
    emit nodeCountChanged();
    emit nodesChanged();
    emit peerStatsChanged();
    emit playerLeft(peerId);
    if (isHost_ && topology_ == Star) {
        QJsonObject left;
        left["t"] = "y";
        left["sys"] = "node_left";
        left["nodeId"] = peerId;
        hostBroadcastSystem(left);
    }
}

void ClayNetwork::loseHost(const QString &reason)
{
    // Every other node was reached through the host: the network is gone
    qWarning() << "ClayNetwork:" << reason;
    const QStringList gone = nodes_;
    tearDown();
    for (const QString &id : gone)
        emit playerLeft(id);
    emit errorOccurred(reason);
}

// A crashed host never says goodbye (#299). Every peer answers a ping
// within a round trip, so one that leaves a ping unanswered and sends nothing
// else for gracePeriod is gone. Counting from the ping, not from the last
// message, lets a link that was out for less than gracePeriod come back
// whatever the ping cadence. A quiet peer is probed after 0.5 s
// (probeQuietPeers), so a crash is noticed within gracePeriod plus about
// 0.75 s.
void ClayNetwork::checkLiveness()
{
    if (gracePeriod_ <= 0)
        return;
    const qint64 now = clock_.elapsed();
    QStringList silent;
    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
        if (it->admitted && it->unansweredSinceMs >= 0
            && now - it->unansweredSinceMs >= gracePeriod_)
            silent.append(it.key());
    for (const QString &peerId : silent) {
        if (!peers_.contains(peerId))
            continue;  // gone with the host
        emitDiag("datachannel", QString("No answer from %1 for %2 ms, dropping it")
                 .arg(peerId.left(8)).arg(now - peers_.value(peerId).unansweredSinceMs));
        peerGone(peerId, QString("The host did not answer for %1 ms").arg(gracePeriod_));
    }
    armLivenessCheck();
}

void ClayNetwork::armLivenessCheck()
{
    qint64 next = -1;
    if (gracePeriod_ > 0) {
        for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
            if (it->admitted && it->unansweredSinceMs >= 0
                && (next < 0 || it->unansweredSinceMs + gracePeriod_ < next))
                next = it->unansweredSinceMs + gracePeriod_;
    }
    if (next < 0) {
        livenessCheck_.stop();
        return;
    }
    livenessCheck_.start(int(qMax<qint64>(0, next - clock_.elapsed())));
}

QString ClayNetwork::pingJson() const
{
    QJsonObject msg;
    msg["t"] = "p";
    msg["ts"] = static_cast<double>(QDateTime::currentMSecsSinceEpoch());
    return QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));
}

void ClayNetwork::ping()
{
    if (!connected_) return;

    const qint64 sentAt = clock_.elapsed();
    for (PeerConn &peer : peers_)
        if (peer.admitted && peer.unansweredSinceMs < 0)
            peer.unansweredSinceMs = sentAt;
    armLivenessCheck();
    if (gracePeriod_ > 0 && !quietProbe_.isActive())
        quietProbe_.start();

    const QString json = pingJson();
    for (auto it = peers_.constBegin(); it != peers_.constEnd(); ++it)
        if (it->admitted)
            sendToPeer(it.key(), json);
}

// Without it a crash right after a ping waits up to the next one, 2 s, for
// its deadline to start. A peer that streams state is never quiet, so in a
// game this sends nothing; in a quiet lobby it pings a peer every ~0.5 s.
void ClayNetwork::probeQuietPeers()
{
    if (!connected_ || gracePeriod_ <= 0) {
        quietProbe_.stop();
        return;
    }
    const qint64 now = clock_.elapsed();
    QStringList quiet;
    for (auto it = peers_.begin(); it != peers_.end(); ++it) {
        if (it->admitted && it->unansweredSinceMs < 0 && now - it->lastHeardMs >= kQuietProbeMs) {
            it->unansweredSinceMs = now;
            quiet.append(it.key());
        }
    }
    if (quiet.isEmpty())
        return;
    armLivenessCheck();
    const QString json = pingJson();
    for (const QString &peerId : quiet)
        sendToPeer(peerId, json);
}

void ClayNetwork::cleanupPeer(const QString &peerId)
{
    if (peers_.contains(peerId)) {
        if (peers_[peerId].dcState) {
            peers_[peerId].dcState->close();
        }
        if (peers_[peerId].dc) {
            peers_[peerId].dc->close();
        }
        if (peers_[peerId].pc) {
            peers_[peerId].pc->close();
        }
        peers_.remove(peerId);
    }
}

QString ClayNetwork::generateNetworkCode() const
{
    const QString chars = kCodeChars;
    QString code;
    for (int i = 0; i < 6; ++i) {
        code += kCodeChars[QRandomGenerator::global()->bounded(int(kCodeChars.size()))];
    }
    return code;
}

QString ClayNetwork::generateLanSecret()
{
    // The secret is all that keeps a stranger on the LAN out: drawn from the
    // system's RNG, 8 of 32 characters = 40 bits
    QString secret;
    for (int i = 0; i < kLanSecretLength; ++i) {
        secret += kCodeChars[QRandomGenerator::system()->bounded(int(kCodeChars.size()))];
    }
    return secret;
}

void ClayNetwork::connectLocalSignaling()
{
    QString host;
    uint16_t port;
    QString secret;

    if (isHost_) {
        // Host connects to its own local server
        host = "127.0.0.1";
        port = localServer_->port();
        secret = lanSecret_;
    } else {
        // Client decodes the LAN code
        if (!decodeLanCode(networkId_, host, port, secret)) {
            status_ = Error;
            emit statusChanged();
            emit errorOccurred("Invalid LAN code");
            return;
        }
    }

    localClient_ = std::make_unique<LocalSignalingClient>(this);
    setupLocalSignalingConnections();

    // Host uses "HOST" as peerId so clients can find it; clients generate unique ID
    QString peerId = isHost_ ? "HOST" : QString();
    localClient_->connect(host, port, peerId, secret);
}

void ClayNetwork::setupLocalSignalingConnections()
{
    QObject::connect(localClient_.get(), &LocalSignalingClient::connected,
                     this, &ClayNetwork::onSignalingConnected);
    QObject::connect(localClient_.get(), &LocalSignalingClient::offerReceived,
                     this, &ClayNetwork::onSignalingOffer);
    QObject::connect(localClient_.get(), &LocalSignalingClient::answerReceived,
                     this, &ClayNetwork::onSignalingAnswer);
    QObject::connect(localClient_.get(), &LocalSignalingClient::candidateReceived,
                     this, &ClayNetwork::onSignalingCandidate);
    QObject::connect(localClient_.get(), &LocalSignalingClient::errorOccurred,
                     this, &ClayNetwork::onSignalingError);
    QObject::connect(localClient_.get(), &LocalSignalingClient::rejected,
                     this, &ClayNetwork::onSignalingRejected);
}

QString ClayNetwork::encodeLanCode(const QString &host, uint16_t port, const QString &secret)
{
    // Encode IP:port plus the join secret as a LAN code
    // Format: "L" + base36(ip_as_uint32) + "-" + base36(port) + "-" + secret
    // Example: 192.168.1.42:9000 -> "L1HGF041-6Y4-K7QP2MXA"

    QStringList parts = host.split('.');
    if (parts.size() != 4) {
        return QString();
    }

    // Convert IP to uint32
    uint32_t ip = 0;
    for (int i = 0; i < 4; ++i) {
        ip = (ip << 8) | (parts[i].toUInt() & 0xFF);
    }

    // Encode as base36
    auto toBase36 = [](uint64_t num) -> QString {
        const QString chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        if (num == 0) return "0";
        QString result;
        while (num > 0) {
            result.prepend(chars[num % 36]);
            num /= 36;
        }
        return result;
    };

    return QString("L%1-%2-%3").arg(toBase36(ip)).arg(toBase36(port)).arg(secret);
}

bool ClayNetwork::isLanCode(const QString &code)
{
    // Cloud codes have no separator, so 'L' plus one marks a LAN code
    const QString c = code.trimmed().toUpper();
    return c.startsWith('L') && c.contains('-');
}

bool ClayNetwork::decodeLanCode(const QString &code, QString &host, uint16_t &port, QString &secret)
{
    // "L<base36 ip>-<base36 port>-<secret>", nothing more or less: a code
    // that does not parse is refused before anything connects (#321)
    if (!isLanCode(code)) {
        return false;
    }
    const QStringList parts = code.trimmed().toUpper().split('-');
    if (parts.size() != 3) {
        return false;
    }

    auto fromBase36 = [](const QString &str, int maxDigits, uint64_t &out) {
        if (str.isEmpty() || str.size() > maxDigits) {
            return false;
        }
        out = 0;
        for (QChar c : str) {
            out *= 36;
            if (c >= '0' && c <= '9') {
                out += c.unicode() - '0';
            } else if (c >= 'A' && c <= 'Z') {
                out += c.unicode() - 'A' + 10;
            } else {
                return false;
            }
        }
        return true;
    };

    uint64_t ip = 0;
    uint64_t portValue = 0;
    // 36^7 > 2^32 and 36^4 > 2^16, so the digit limits keep both in range
    if (!fromBase36(parts[0].mid(1), 7, ip) || ip > 0xFFFFFFFFu) {
        return false;
    }
    if (!fromBase36(parts[1], 4, portValue) || portValue == 0 || portValue > 0xFFFFu) {
        return false;
    }
    const QString s = parts[2];
    if (s.size() != kLanSecretLength) {
        return false;
    }
    for (QChar c : s) {
        if (!kCodeChars.contains(c)) {
            return false;
        }
    }

    port = static_cast<uint16_t>(portValue);
    secret = s;
    host = QString("%1.%2.%3.%4")
        .arg((ip >> 24) & 0xFF)
        .arg((ip >> 16) & 0xFF)
        .arg((ip >> 8) & 0xFF)
        .arg(ip & 0xFF);

    return true;
}

QString ClayNetwork::getLocalIpAddress()
{
    // Check all RFC 1918 private IP ranges
    auto isPrivateIP = [](const QString &ip) {
        if (ip.startsWith("192.168.")) return true;
        if (ip.startsWith("10.")) return true;
        if (ip.startsWith("172.")) {
            QStringList parts = ip.split('.');
            if (parts.size() >= 2) {
                int second = parts[1].toInt();
                return second >= 16 && second <= 31;
            }
        }
        return false;
    };

    // Get the first private IPv4 address (RFC 1918)
    const QList<QHostAddress> addresses = QNetworkInterface::allAddresses();
    for (const QHostAddress &address : addresses) {
        if (address.protocol() == QAbstractSocket::IPv4Protocol &&
            !address.isLoopback() &&
            isPrivateIP(address.toString())) {
            return address.toString();
        }
    }
    // Fallback: any non-loopback IPv4 (will pick up VPN/external, but better than nothing)
    for (const QHostAddress &address : addresses) {
        if (address.protocol() == QAbstractSocket::IPv4Protocol && !address.isLoopback()) {
            return address.toString();
        }
    }
    return "127.0.0.1";
}
