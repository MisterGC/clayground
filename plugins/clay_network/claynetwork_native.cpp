// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claynetwork_native.h"
#include "signaling_peerjs.h"
#include "signaling_local.h"
#include <rtc/rtc.hpp>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>
#include <QDebug>
#include <QRandomGenerator>
#include <QNetworkInterface>
#include <cstring>

ClayNetwork::ClayNetwork(QObject *parent)
    : QObject(parent)
    , signaling_(std::make_unique<PeerJSSignaling>(this))
{
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

void ClayNetwork::createRoom()
{
    if (connected_) {
        leave();
    }

    isHost_ = true;
    status_ = Connecting;
    emit statusChanged();
    emit isHostChanged();

    if (signalingMode_ == Local) {
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

    emit networkIdChanged();
    emit nodeIdChanged();
    emit isHostChanged();
    emit connectedChanged();
    emit statusChanged();
    emit nodeCountChanged();
    emit nodesChanged();
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
    msg["d"] = QJsonObject::fromVariantMap(data.toMap());
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    for (const QString &peerId : peers_.keys()) {
        sendToPeer(peerId, json);
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

    if (isHost_) {
        // Host is ready, announce network
        connected_ = true;
        status_ = Connected;
        emit connectedChanged();
        emit statusChanged();
        emit roomCreated(networkId_);
        qDebug() << "ClayNetwork: Hosting network" << networkId_;
    } else {
        // Client: initiate connection to host
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
        return;
    }

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
    config.iceServers.emplace_back("stun:stun.l.google.com:19302");
    qDebug() << "ClayNetwork: Creating PeerConnection with STUN server";

    auto pc = std::make_shared<rtc::PeerConnection>(config);
    qDebug() << "ClayNetwork: PeerConnection created";

    PeerConnection &peer = peers_[peerId];
    peer.pc = pc;
    peer.ready = false;

    pc->onStateChange([this, peerId](rtc::PeerConnection::State state) {
        qDebug() << "ClayNetwork: Peer" << peerId << "state:" << static_cast<int>(state);
        if (state == rtc::PeerConnection::State::Failed ||
            state == rtc::PeerConnection::State::Disconnected ||
            state == rtc::PeerConnection::State::Closed) {
            QMetaObject::invokeMethod(this, [this, peerId]() {
                if (peers_.contains(peerId) && peers_[peerId].ready) {
                    cleanupPeer(peerId);
                    nodes_.removeAll(peerId);
                    emit nodeCountChanged();
                    emit nodesChanged();
                    emit playerLeft(peerId);
                }
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
        if (signalingMode_ == Local && localClient_) {
            localClient_->sendCandidate(peerId, QString::fromStdString(candidate.candidate()),
                                        QString::fromStdString(candidate.mid()));
        } else {
            signaling_->sendCandidate(peerId, QString::fromStdString(candidate.candidate()),
                                      QString::fromStdString(candidate.mid()));
        }
    });

    pc->onDataChannel([this, peerId](std::shared_ptr<rtc::DataChannel> dc) {
        qDebug() << "ClayNetwork: Data channel received from" << peerId;
        setupDataChannel(peerId, dc);
    });

    if (isOfferer) {
        qDebug() << "ClayNetwork: Creating data channel as offerer";
        auto dc = pc->createDataChannel("data");
        setupDataChannel(peerId, dc);
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

                if (!isHost_ && !connected_) {
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

void ClayNetwork::sendToPeer(const QString &peerId, const QString &message)
{
    if (peers_.contains(peerId) && peers_[peerId].dc && peers_[peerId].dc->isOpen()) {
        // Send as binary (bytes) for PeerJS JSON mode compatibility
        QByteArray utf8 = message.toUtf8();
        std::vector<std::byte> bytes(utf8.size());
        std::memcpy(bytes.data(), utf8.constData(), utf8.size());
        peers_[peerId].dc->send(bytes);
    }
}

void ClayNetwork::handleDataChannelMessage(const QString &fromId, const std::string &message)
{
    QMetaObject::invokeMethod(this, [this, fromId, message]() {
        QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(message));
        if (!doc.isObject()) {
            return;
        }

        QJsonObject obj = doc.object();
        QString type = obj["t"].toString();
        QJsonObject dataObj = obj["d"].toObject();
        QVariant data = dataObj.toVariantMap();

        // Determine actual sender: use "from" field if present (relayed), else connection peer
        QString actualFromId = obj.contains("from") ? obj["from"].toString() : fromId;

        // Host in Star topology: relay to other peers
        if (isHost_ && autoRelay_ && topology_ == Star) {
            // Add "from" field and relay to all OTHER peers
            obj["from"] = fromId;
            QString relayJson = QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
            for (const QString &peerId : peers_.keys()) {
                if (peerId != fromId) {
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

void ClayNetwork::cleanupPeer(const QString &peerId)
{
    if (peers_.contains(peerId)) {
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
