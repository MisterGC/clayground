// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claynetwork_native.h"
#include "signaling_peerjs.h"
#include "signaling_local.h"
#include <rtc/rtc.hpp>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QDebug>
#include <QRandomGenerator>
#include <QNetworkInterface>
#include <QDateTime>
#include <cstring>

ClayNetwork::ClayNetwork(QObject *parent)
    : QObject(parent)
    , signaling_(std::make_unique<PeerJSSignaling>(this))
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
}

ClayNetwork::~ClayNetwork()
{
    leave();
}

QString ClayNetwork::networkId() const { return networkId_; }
QString ClayNetwork::nodeId() const { return nodeId_; }
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
        if (!localServer_->start(0)) {  // 0 = auto-select port
            status_ = Error;
            emit statusChanged();
            emit errorOccurred("Failed to start local signaling server");
            return;
        }

        // Generate LAN code from local IP and port
        QString localIp = getLocalIpAddress();
        networkId_ = encodeLanCode(localIp, localServer_->port());
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
        if (decodeLanCode(networkId, host, port)) {
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

    emit networkIdChanged();
    emit nodeIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit statusChanged();
    emit nodeCountChanged();
    emit nodesChanged();
    emit connectionPhaseChanged();
    emit phaseTimingChanged();
    emit latencyChanged();
    emit peerStatsChanged();
}

void ClayNetwork::broadcast(const QVariant &data)
{
    QJsonObject msg;
    msg["t"] = "m";  // message
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    for (const QString &peerId : peers_.keys()) {
        sendToPeer(peerId, json);
    }
}

void ClayNetwork::broadcastState(const QVariant &data)
{
    QJsonObject msg;
    msg["t"] = "s";  // state
    msg["q"] = static_cast<qint64>(++stateSeqOut_);
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    for (const QString &peerId : peers_.keys()) {
        sendStateToPeer(peerId, json);
    }
}

void ClayNetwork::sendTo(const QString &nodeId, const QVariant &data)
{
    if (!peers_.contains(nodeId)) {
        qWarning() << "ClayNetwork: Unknown peer" << nodeId;
        return;
    }

    QJsonObject msg;
    msg["t"] = "m";
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));
    sendToPeer(nodeId, json);
}

void ClayNetwork::onSignalingConnected(const QString &peerId)
{
    qDebug() << "ClayNetwork: Signaling connected, peerId:" << peerId << "isHost:" << isHost_;
    nodeId_ = peerId;
    emit nodeIdChanged();

    qint64 signalingMs = phaseTimer_.elapsed();
    phaseTiming_["signaling"] = signalingMs;
    emit phaseTimingChanged();
    emitDiag("signaling", QString("Signaling ready (%1ms)").arg(signalingMs));

    if (isHost_) {
        // Host is ready, announce network
        connected_ = true;
        status_ = Connected;
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
        // In Local mode, host uses "HOST" as peerId; in Cloud mode, host uses networkId
        QString hostPeerId = (signalingMode_ == Local) ? "HOST" : networkId_;
        qDebug() << "ClayNetwork: Client connected to signaling, now connecting to host:" << hostPeerId;
        setupPeerConnection(hostPeerId, true);
    }
}

void ClayNetwork::onSignalingOffer(const QString &fromId, const QString &sdp, const QString &connectionId)
{
    qDebug() << "ClayNetwork: Received offer from" << fromId << "connectionId:" << connectionId;

    if (!isHost_) {
        qWarning() << "ClayNetwork: Non-host received offer, ignoring";
        return;
    }

    if (nodeCount() >= maxNodes_) {
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
    qWarning() << "ClayNetwork: Signaling error:" << error;
    status_ = Error;
    emit statusChanged();
    emit errorOccurred(error);
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

    pc->onStateChange([this, peerId](rtc::PeerConnection::State state) {
        qDebug() << "ClayNetwork: Peer" << peerId << "state:" << static_cast<int>(state);

        static const char* stateNames[] = {
            "New", "Connecting", "Connected", "Disconnected", "Failed", "Closed"
        };
        int idx = static_cast<int>(state);
        const char* name = (idx >= 0 && idx <= 5) ? stateNames[idx] : "Unknown";

        QMetaObject::invokeMethod(this, [this, peerId, state, name]() {
            emitDiag("ice", QString("Peer %1: %2").arg(peerId.left(8), name));

            if (state == rtc::PeerConnection::State::Failed ||
                state == rtc::PeerConnection::State::Disconnected ||
                state == rtc::PeerConnection::State::Closed) {
                if (peers_.contains(peerId) && peers_[peerId].ready) {
                    cleanupPeer(peerId);
                    nodes_.removeAll(peerId);
                    forgetSender(peerId);
                    emit nodeCountChanged();
                    emit nodesChanged();
                    emit playerLeft(peerId);
                    if (isHost_ && topology_ == Star) {
                        QJsonObject left;
                        left["t"] = "y";
                        left["sys"] = "node_left";
                        left["nodeId"] = peerId;
                        hostBroadcastSystem(left);
                    }
                }
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

void ClayNetwork::setupDataChannel(const QString &peerId, std::shared_ptr<rtc::DataChannel> dc)
{
    peers_[peerId].dc = dc;

    dc->onOpen([this, peerId]() {
        QMetaObject::invokeMethod(this, [this, peerId]() {
            qDebug() << "ClayNetwork: Data channel open with" << peerId;
            if (peers_.contains(peerId)) {
                peers_[peerId].ready = true;
                nodes_.append(peerId);
                emit nodeCountChanged();
                emit nodesChanged();
                emit playerJoined(peerId);

                // Star topology: the host owns the roster - tell the new
                // node about everyone and everyone about the new node, so
                // joiners can see each other despite only connecting to us.
                if (isHost_ && topology_ == Star) {
                    sendRosterTo(peerId);
                    QJsonObject joined;
                    joined["t"] = "y";
                    joined["sys"] = "node_joined";
                    joined["nodeId"] = peerId;
                    hostBroadcastSystem(joined, peerId);
                }

                if (!isHost_ && !connected_) {
                    qint64 iceMs = phaseTimer_.elapsed() - iceStartMs_;
                    qint64 totalMs = phaseTimer_.elapsed();
                    phaseTiming_["ice"] = iceMs;
                    phaseTiming_["datachannel"] = 0;
                    phaseTiming_["total"] = totalMs;
                    emit phaseTimingChanged();
                    setConnectionPhase("");

                    emitDiag("datachannel",
                             QString("Data channel open (total: %1ms)").arg(totalMs));

                    connected_ = true;
                    status_ = Connected;
                    emit connectedChanged();
                    emit statusChanged();
                }
            }
        }, Qt::QueuedConnection);
    });

    dc->onMessage([this, peerId](auto message) {
        if (std::holds_alternative<std::string>(message)) {
            handleDataChannelMessage(peerId, std::get<std::string>(message));
        } else if (std::holds_alternative<rtc::binary>(message)) {
            // Handle binary messages (from PeerJS JSON mode)
            const auto& bytes = std::get<rtc::binary>(message);
            std::string str(reinterpret_cast<const char*>(bytes.data()), bytes.size());
            handleDataChannelMessage(peerId, str);
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
    peers_[peerId].dcState = dc;

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
            handleDataChannelMessage(peerId, std::get<std::string>(message));
        } else if (std::holds_alternative<rtc::binary>(message)) {
            const auto& bytes = std::get<rtc::binary>(message);
            std::string str(reinterpret_cast<const char*>(bytes.data()), bytes.size());
            handleDataChannelMessage(peerId, str);
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
    if (peers_.contains(peerId) && peers_[peerId].dc && peers_[peerId].dc->isOpen()) {
        // Send as binary (bytes) for PeerJS JSON mode compatibility
        QByteArray utf8 = message.toUtf8();
        std::vector<std::byte> bytes(utf8.size());
        std::memcpy(bytes.data(), utf8.constData(), utf8.size());
        peers_[peerId].dc->send(bytes);

        peers_[peerId].msgSent++;
        peers_[peerId].bytesSent += utf8.size();
    }
}

void ClayNetwork::sendStateToPeer(const QString &peerId, const QString &message)
{
    if (!peers_.contains(peerId))
        return;
    PeerConn &peer = peers_[peerId];
    // Prefer the lossy state channel; fall back to the reliable one while the
    // state channel is still negotiating (or when a peer doesn't offer one).
    if (peer.stateReady && peer.dcState && peer.dcState->isOpen()) {
        QByteArray utf8 = message.toUtf8();
        std::vector<std::byte> bytes(utf8.size());
        std::memcpy(bytes.data(), utf8.constData(), utf8.size());
        peer.dcState->send(bytes);
        peer.stateSent++;
        peer.bytesSent += utf8.size();
    } else {
        sendToPeer(peerId, message);
    }
}

void ClayNetwork::handleDataChannelMessage(const QString &fromId, const std::string &message)
{
    QMetaObject::invokeMethod(this, [this, fromId, message]() {
        if (peers_.contains(fromId)) {
            peers_[fromId].msgRecv++;
            peers_[fromId].bytesRecv += message.size();
        }

        QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(message));
        if (!doc.isObject()) {
            return;
        }

        QJsonObject obj = doc.object();
        QString type = obj["t"].toString();

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

        // Roster updates from the host (Star topology)
        if (type == "y") {
            handleSystemMessage(obj);
            return;
        }

        QJsonObject dataObj = obj["d"].toObject();
        QVariant data = dataObj.toVariantMap();

        // Determine actual sender: use "from" field if present (relayed), else connection peer
        QString actualFromId = obj.contains("from") ? obj["from"].toString() : fromId;

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
            for (const QString &peerId : peers_.keys()) {
                if (peerId != fromId) {
                    if (type == "s")
                        sendStateToPeer(peerId, relayJson);
                    else
                        sendToPeer(peerId, relayJson);
                }
            }
        }

        // Emit signal to application
        if (type == "m") {
            emit messageReceived(actualFromId, data);
        } else if (type == "s") {
            emit stateReceived(actualFromId, data);
        }
    }, Qt::QueuedConnection);
}

void ClayNetwork::handleSystemMessage(const QJsonObject &obj)
{
    if (isHost_)
        return;  // The host is the roster authority; nothing to apply

    QString sys = obj["sys"].toString();
    if (sys == "roster") {
        // Authoritative list of all OTHER joiners (host connection is
        // already in nodes_ via the data channel open)
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
    for (const QString &peerId : peers_.keys())
        if (peerId != exceptPeer)
            sendToPeer(peerId, json);
}

void ClayNetwork::forgetSender(const QString &nodeId)
{
    stateSeqIn_.remove(nodeId);
    stateLastMs_.remove(nodeId);
    stateRecvCount_.remove(nodeId);
    stateDropCount_.remove(nodeId);
}

void ClayNetwork::ping()
{
    if (!connected_) return;

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    QJsonObject msg;
    msg["t"] = "p";
    msg["ts"] = static_cast<double>(now);
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    for (const QString &peerId : peers_.keys()) {
        sendToPeer(peerId, json);
    }
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
    const QString chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    QString code;
    for (int i = 0; i < 6; ++i) {
        code += chars[QRandomGenerator::global()->bounded(chars.length())];
    }
    return code;
}

void ClayNetwork::connectLocalSignaling()
{
    QString host;
    uint16_t port;

    if (isHost_) {
        // Host connects to its own local server
        host = "127.0.0.1";
        port = localServer_->port();
    } else {
        // Client decodes the LAN code
        if (!decodeLanCode(networkId_, host, port)) {
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
    localClient_->connect(host, port, peerId);
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
}

QString ClayNetwork::encodeLanCode(const QString &host, uint16_t port)
{
    // Encode IP:port as a LAN code with separator
    // Format: "L" + base36(ip_as_uint32) + "-" + base36(port)
    // Example: 192.168.1.42:9000 -> "L1HGF041-6Y4"

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

    return QString("L%1-%2").arg(toBase36(ip)).arg(toBase36(port));
}

bool ClayNetwork::decodeLanCode(const QString &code, QString &host, uint16_t &port)
{
    // Check if it's a LAN code (starts with 'L' and contains separator)
    if (!code.startsWith('L') || !code.contains('-')) {
        return false;
    }

    auto fromBase36 = [](const QString &str) -> uint64_t {
        uint64_t result = 0;
        for (QChar c : str) {
            result *= 36;
            if (c >= '0' && c <= '9') {
                result += c.unicode() - '0';
            } else if (c >= 'A' && c <= 'Z') {
                result += c.unicode() - 'A' + 10;
            } else if (c >= 'a' && c <= 'z') {
                result += c.unicode() - 'a' + 10;
            }
        }
        return result;
    };

    // Split on separator: "LXXXXXX-YYY" -> ["LXXXXXX", "YYY"]
    int sepIndex = code.indexOf('-');
    QString ipPart = code.mid(1, sepIndex - 1);  // Skip 'L', up to separator
    QString portPart = code.mid(sepIndex + 1);    // After separator

    uint32_t ip = static_cast<uint32_t>(fromBase36(ipPart));
    port = static_cast<uint16_t>(fromBase36(portPart));

    // Convert uint32 to IP string
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
