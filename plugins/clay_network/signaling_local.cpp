// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "signaling_local.h"
#include <rtc/rtc.hpp>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>
#include <QDebug>

// ============================================================================
// LocalSignalingServer - PeerJS-compatible signaling server for LAN
// ============================================================================

LocalSignalingServer::LocalSignalingServer(QObject *parent)
    : QObject(parent)
{
}

LocalSignalingServer::~LocalSignalingServer()
{
    stop();
}

bool LocalSignalingServer::start(uint16_t port)
{
    if (running_) {
        return true;
    }

    try {
        rtc::WebSocketServer::Configuration config;
        config.port = port;
        config.enableTls = false;

        server_ = std::make_shared<rtc::WebSocketServer>(config);

        server_->onClient([this](std::shared_ptr<rtc::WebSocket> ws) {
            QString peerId;

            ws->onOpen([this, ws, &peerId]() {
                // PeerJS sends id in URL query: ws://host:port/peerjs?key=...&id=PEER_ID&token=...
                // For simplicity, we'll extract it from the first message or path
                qDebug() << "LocalSignalingServer: Client WebSocket opened";
            });

            ws->onMessage([this, ws, peerId](auto message) mutable {
                if (std::holds_alternative<std::string>(message)) {
                    std::string msg = std::get<std::string>(message);

                    // First message should identify the peer
                    if (peerId.isEmpty()) {
                        // Parse the path to get peer ID from query params
                        // Or get it from HELLO message
                        QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(msg));
                        if (doc.isObject()) {
                            QJsonObject obj = doc.object();
                            if (obj.contains("id")) {
                                peerId = obj["id"].toString();
                            }
                        }

                        // If still no peer ID, generate one
                        if (peerId.isEmpty()) {
                            peerId = QUuid::createUuid().toString(QUuid::Id128).left(16);
                        }

                        clients_[peerId] = ws;
                        qDebug() << "LocalSignalingServer: Client registered as" << peerId;

                        // Send OPEN message to confirm registration
                        QJsonObject openMsg;
                        openMsg["type"] = "OPEN";
                        openMsg["id"] = peerId;
                        ws->send(QJsonDocument(openMsg).toJson(QJsonDocument::Compact).toStdString());

                        QMetaObject::invokeMethod(this, [this, peerId]() {
                            emit clientConnected(peerId);
                        }, Qt::QueuedConnection);
                    }

                    QMetaObject::invokeMethod(this, [this, peerId, msg]() {
                        onClientMessage(peerId, msg);
                    }, Qt::QueuedConnection);
                }
            });

            ws->onError([this](std::string error) {
                qWarning() << "LocalSignalingServer: Client error:" << QString::fromStdString(error);
            });

            ws->onClosed([this, ws, peerId]() mutable {
                if (!peerId.isEmpty()) {
                    clients_.remove(peerId);
                    QMetaObject::invokeMethod(this, [this, peerId]() {
                        emit clientDisconnected(peerId);
                    }, Qt::QueuedConnection);
                }
            });
        });

        port_ = server_->port();
        running_ = true;
        qDebug() << "LocalSignalingServer: Started on port" << port_;
        return true;

    } catch (const std::exception &e) {
        qWarning() << "LocalSignalingServer: Failed to start:" << e.what();
        emit errorOccurred(QString::fromStdString(e.what()));
        return false;
    }
}

void LocalSignalingServer::stop()
{
    if (server_) {
        server_->stop();
        server_.reset();
    }
    clients_.clear();
    running_ = false;
    port_ = 0;
}

bool LocalSignalingServer::isRunning() const
{
    return running_;
}

uint16_t LocalSignalingServer::port() const
{
    return port_;
}

void LocalSignalingServer::onClientMessage(const QString &peerId, const std::string &message)
{
    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(message));
    if (!doc.isObject()) {
        return;
    }

    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();

    if (type == "HEARTBEAT") {
        // Respond to heartbeat
        sendToClient(peerId, QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
        return;
    }

    // Forward OFFER, ANSWER, CANDIDATE to target peer
    QString dst = obj["dst"].toString();
    if (dst.isEmpty()) {
        return;
    }

    // Add source ID and forward
    obj["src"] = peerId;
    QString forwardMsg = QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
    sendToClient(dst, forwardMsg);
}

void LocalSignalingServer::sendToClient(const QString &peerId, const QString &message)
{
    auto it = clients_.find(peerId);
    if (it == clients_.end()) {
        return;
    }

    auto ws = it.value().lock();
    if (ws && ws->isOpen()) {
        ws->send(message.toStdString());
    }
}

// ============================================================================
// LocalSignalingClient - Connects to LocalSignalingServer
// ============================================================================

LocalSignalingClient::LocalSignalingClient(QObject *parent)
    : QObject(parent)
{
}

LocalSignalingClient::~LocalSignalingClient()
{
    disconnect();
}

void LocalSignalingClient::connect(const QString &host, uint16_t port, const QString &peerId)
{
    if (ws_) {
        disconnect();
    }

    peerId_ = peerId.isEmpty() ? QUuid::createUuid().toString(QUuid::Id128).left(16) : peerId;

    // Connect to local signaling server
    QString url = QString("ws://%1:%2/peerjs?id=%3").arg(host).arg(port).arg(peerId_);
    qDebug() << "LocalSignalingClient: Connecting to" << url;

    rtc::WebSocket::Configuration config;
    ws_ = std::make_shared<rtc::WebSocket>(config);

    ws_->onOpen([this]() {
        QMetaObject::invokeMethod(this, [this]() { onWsOpen(); }, Qt::QueuedConnection);
    });

    ws_->onMessage([this](auto message) {
        if (std::holds_alternative<std::string>(message)) {
            std::string msg = std::get<std::string>(message);
            QMetaObject::invokeMethod(this, [this, msg]() { onWsMessage(msg); }, Qt::QueuedConnection);
        }
    });

    ws_->onError([this](std::string error) {
        QMetaObject::invokeMethod(this, [this, error]() { onWsError(error); }, Qt::QueuedConnection);
    });

    ws_->onClosed([this]() {
        QMetaObject::invokeMethod(this, [this]() { onWsClosed(); }, Qt::QueuedConnection);
    });

    ws_->open(url.toStdString());
}

void LocalSignalingClient::disconnect()
{
    if (ws_) {
        ws_->close();
        ws_.reset();
    }
    connected_ = false;
    peerId_.clear();
}

bool LocalSignalingClient::isConnected() const
{
    return connected_;
}

QString LocalSignalingClient::peerId() const
{
    return peerId_;
}

void LocalSignalingClient::onWsOpen()
{
    qDebug() << "LocalSignalingClient: WebSocket opened, sending ID message";

    // Send identification message
    QJsonObject idMsg;
    idMsg["id"] = peerId_;
    ws_->send(QJsonDocument(idMsg).toJson(QJsonDocument::Compact).toStdString());
}

void LocalSignalingClient::onWsMessage(const std::string &message)
{
    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(message));
    if (!doc.isObject()) {
        return;
    }

    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();

    if (type == "OPEN") {
        connected_ = true;
        QString assignedId = obj["id"].toString();
        if (!assignedId.isEmpty()) {
            peerId_ = assignedId;
        }
        qDebug() << "LocalSignalingClient: Connected as" << peerId_;
        emit connected(peerId_);
    }
    else if (type == "OFFER") {
        QString fromId = obj["src"].toString();
        QJsonObject payload = obj["payload"].toObject();
        QString connectionId = payload["connectionId"].toString();
        QString sdp = payload["sdp"].toObject()["sdp"].toString();
        if (sdp.isEmpty() && payload["sdp"].isString()) {
            sdp = payload["sdp"].toString();
        }
        emit offerReceived(fromId, sdp, connectionId);
    }
    else if (type == "ANSWER") {
        QString fromId = obj["src"].toString();
        QJsonObject payload = obj["payload"].toObject();
        QString sdp = payload["sdp"].toObject()["sdp"].toString();
        emit answerReceived(fromId, sdp);
    }
    else if (type == "CANDIDATE") {
        QString fromId = obj["src"].toString();
        QJsonObject payload = obj["payload"].toObject();
        QJsonObject candidate = payload["candidate"].toObject();
        QString candidateStr = candidate["candidate"].toString();
        QString mid = candidate["sdpMid"].toString();
        emit candidateReceived(fromId, candidateStr, mid);
    }
    else if (type == "ERROR") {
        QString errorMsg = obj["payload"].toObject()["msg"].toString();
        emit errorOccurred(errorMsg);
    }
}

void LocalSignalingClient::onWsError(const std::string &error)
{
    qWarning() << "LocalSignalingClient: WebSocket error:" << QString::fromStdString(error);
    emit errorOccurred(QString::fromStdString(error));
}

void LocalSignalingClient::onWsClosed()
{
    qDebug() << "LocalSignalingClient: WebSocket closed";
    connected_ = false;
    emit disconnected();
}

void LocalSignalingClient::sendMessage(const QString &type, const QString &targetId, const QVariantMap &payload)
{
    if (!ws_ || !ws_->isOpen()) {
        qWarning() << "LocalSignalingClient: Cannot send, WebSocket not open";
        return;
    }

    QJsonObject msg;
    msg["type"] = type;
    msg["dst"] = targetId;
    msg["payload"] = QJsonObject::fromVariantMap(payload);

    std::string jsonStr = QJsonDocument(msg).toJson(QJsonDocument::Compact).toStdString();
    ws_->send(jsonStr);
}

void LocalSignalingClient::sendOffer(const QString &targetId, const QString &sdp)
{
    QVariantMap payload;
    QVariantMap sdpObj;
    sdpObj["type"] = "offer";
    sdpObj["sdp"] = sdp;
    payload["sdp"] = sdpObj;
    payload["type"] = "data";
    payload["connectionId"] = peerId_ + "_" + targetId;
    payload["label"] = peerId_ + "_" + targetId;
    payload["reliable"] = true;
    payload["serialization"] = "json";

    sendMessage("OFFER", targetId, payload);
}

void LocalSignalingClient::sendAnswer(const QString &targetId, const QString &sdp, const QString &connectionId)
{
    QVariantMap payload;
    QVariantMap sdpObj;
    sdpObj["type"] = "answer";
    sdpObj["sdp"] = sdp;
    payload["sdp"] = sdpObj;
    payload["type"] = "data";
    payload["connectionId"] = connectionId;

    sendMessage("ANSWER", targetId, payload);
}

void LocalSignalingClient::sendCandidate(const QString &targetId, const QString &candidate, const QString &mid)
{
    QVariantMap payload;
    QVariantMap candidateObj;
    candidateObj["candidate"] = candidate;
    candidateObj["sdpMid"] = mid;
    candidateObj["sdpMLineIndex"] = 0;
    payload["candidate"] = candidateObj;
    payload["type"] = "data";
    payload["connectionId"] = peerId_ + "_" + targetId;

    sendMessage("CANDIDATE", targetId, payload);
}
