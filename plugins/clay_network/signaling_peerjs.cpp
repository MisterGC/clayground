// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "signaling_peerjs.h"
#include <rtc/rtc.hpp>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QDebug>

PeerJSSignaling::PeerJSSignaling(QObject *parent)
    : QObject(parent)
    , serverUrl_("wss://0.peerjs.com/peerjs?key=peerjs")
{
    // The PeerJS browser client's pingInterval; the server's alive timeout
    // is a multiple of it
    heartbeat_.setInterval(5000);
    QObject::connect(&heartbeat_, &QTimer::timeout, this, [this]() {
        if (ws_ && ws_->isOpen())
            ws_->send(std::string("{\"type\":\"HEARTBEAT\"}"));
    });
}

PeerJSSignaling::~PeerJSSignaling()
{
    disconnect();
}

void PeerJSSignaling::setServerUrl(const QString &url)
{
    // Normalize: ensure URL ends with ?key=peerjs so connect() can append &id=&token=
    if (url.contains('?'))
        serverUrl_ = url;
    else
        serverUrl_ = url + "?key=peerjs";
}

void PeerJSSignaling::setVerifyCertificate(bool verify)
{
    verifyCertificate_ = verify;
}

void PeerJSSignaling::connect(const QString &peerId)
{
    if (ws_) {
        disconnect();
    }

    peerId_ = peerId.isEmpty() ? QUuid::createUuid().toString(QUuid::Id128).left(16) : peerId;
    QString token = QUuid::createUuid().toString(QUuid::Id128).left(8);

    // PeerJS WebSocket URL format: wss://host/peerjs?key=KEY&id=ID&token=TOKEN
    QString url = serverUrl_ + "&id=" + peerId_ + "&token=" + token;
    qDebug() << "PeerJSSignaling: Connecting to" << url;

    rtc::WebSocket::Configuration config;
    config.disableTlsVerification = !verifyCertificate_;
#ifdef Q_OS_WIN
    // libdatachannel (v0.21.2) skips the root CA check on Windows whatever
    // this says - say so rather than pretend the server was checked
    if (verifyCertificate_ && url.startsWith("wss:"))
        qWarning() << "PeerJSSignaling: the server certificate is not checked on Windows";
#endif
    ws_ = std::make_shared<rtc::WebSocket>(config);
    errorReported_ = false;
    const quint64 attempt = ++attempt_;

    ws_->onOpen([this, attempt]() {
        QMetaObject::invokeMethod(this, [this, attempt]() {
            if (attempt == attempt_) onWsOpen();
        }, Qt::QueuedConnection);
    });

    ws_->onMessage([this, attempt](auto message) {
        if (std::holds_alternative<std::string>(message)) {
            std::string msg = std::get<std::string>(message);
            QMetaObject::invokeMethod(this, [this, attempt, msg]() {
                if (attempt == attempt_) onWsMessage(msg);
            }, Qt::QueuedConnection);
        }
    });

    ws_->onError([this, attempt](std::string error) {
        QMetaObject::invokeMethod(this, [this, attempt, error]() {
            if (attempt == attempt_) onWsError(error);
        }, Qt::QueuedConnection);
    });

    ws_->onClosed([this, attempt]() {
        QMetaObject::invokeMethod(this, [this, attempt]() {
            if (attempt == attempt_) onWsClosed();
        }, Qt::QueuedConnection);
    });

    ws_->open(url.toStdString());
}

void PeerJSSignaling::disconnect()
{
    ++attempt_;
    heartbeat_.stop();
    if (ws_) {
        ws_->resetCallbacks();
        ws_->close();
        ws_.reset();
    }
    connected_ = false;
    peerId_.clear();
}

void PeerJSSignaling::drop()
{
    // Callbacks stay attached, so the close arrives in onWsClosed()
    if (ws_)
        ws_->close();
}

bool PeerJSSignaling::isConnected() const
{
    return connected_;
}

QString PeerJSSignaling::peerId() const
{
    return peerId_;
}

void PeerJSSignaling::onWsOpen()
{
    qDebug() << "PeerJSSignaling: WebSocket opened, waiting for OPEN message...";
    // Don't emit connected yet - wait for "OPEN" message from server
}

void PeerJSSignaling::onWsMessage(const std::string &message)
{
    qDebug() << "PeerJSSignaling: Received message:" << QString::fromStdString(message).left(200);

    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(message));
    if (!doc.isObject()) {
        qDebug() << "PeerJSSignaling: Message is not JSON object";
        return;
    }

    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();
    qDebug() << "PeerJSSignaling: Message type:" << type;

    if (type == "OPEN") {
        // Server acknowledged our connection - NOW we're ready
        qDebug() << "PeerJSSignaling: Server acknowledged connection, signaling ready";
        connected_ = true;
        heartbeat_.start();
        emit connected(peerId_);
    }
    else if (type == "OFFER") {
        QString fromId = obj["src"].toString();
        QJsonObject payload = obj["payload"].toObject();
        QString connectionId = payload["connectionId"].toString();
        qDebug() << "PeerJSSignaling: OFFER payload keys:" << payload.keys() << "connectionId:" << connectionId;

        // Try nested format first (what we send): payload.sdp.sdp
        QString sdp = payload["sdp"].toObject()["sdp"].toString();

        // If empty, try direct format (what browser PeerJS might send): payload.sdp as string
        if (sdp.isEmpty() && payload["sdp"].isString()) {
            sdp = payload["sdp"].toString();
            qDebug() << "PeerJSSignaling: Using direct SDP format";
        }

        // Also check if sdp is at payload.sdp.sdp vs payload.offer.sdp
        if (sdp.isEmpty()) {
            qDebug() << "PeerJSSignaling: SDP is empty! payload.sdp type:" << payload["sdp"].type();
            qDebug() << "PeerJSSignaling: Full payload:" << QString::fromUtf8(QJsonDocument(payload).toJson(QJsonDocument::Compact)).left(500);
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
    else if (type == "REJECT") {
        QString reason = obj["payload"].toObject()["reason"].toString();
        emit errorOccurred(reason.isEmpty() ? "Connection rejected" : reason);
    }
    else if (type == "ERROR") {
        QString errorMsg = obj["payload"].toObject()["msg"].toString();
        emit errorOccurred(errorMsg);
    }
    else if (type == "HEARTBEAT") {
        // The client keeps the beat (heartbeat_); answering an echo here
        // would ping-pong with a server that echoes it (clay-dev-server)
    }
}

void PeerJSSignaling::onWsError(const std::string &error)
{
    qWarning() << "PeerJSSignaling: WebSocket error:" << QString::fromStdString(error);
    errorReported_ = true;
    emit errorOccurred(QString::fromStdString(error));
}

void PeerJSSignaling::onWsClosed()
{
    qDebug() << "PeerJSSignaling: WebSocket closed";
    heartbeat_.stop();
    const bool wasOpen = connected_;
    connected_ = false;
    if (wasOpen)
        emit disconnected();
    else if (!errorReported_)
        emit errorOccurred("Signaling server closed the connection");
}

void PeerJSSignaling::sendMessage(const QString &type, const QString &targetId, const QVariantMap &payload)
{
    if (!ws_ || !ws_->isOpen()) {
        qWarning() << "PeerJSSignaling: Cannot send, WebSocket not open";
        return;
    }

    // PeerJS protocol: client sends type, dst, payload
    // Server adds "src" based on connection identity
    QJsonObject msg;
    msg["type"] = type;
    msg["dst"] = targetId;
    msg["payload"] = QJsonObject::fromVariantMap(payload);

    std::string jsonStr = QJsonDocument(msg).toJson(QJsonDocument::Compact).toStdString();
    qDebug() << "PeerJSSignaling: Sending" << type << "to" << targetId << "payload keys:" << QJsonObject::fromVariantMap(payload).keys();
    ws_->send(jsonStr);
}

void PeerJSSignaling::sendOffer(const QString &targetId, const QString &sdp)
{
    // Match PeerJS client payload format exactly
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
    payload["browser"] = "libdatachannel";

    sendMessage("OFFER", targetId, payload);
}

void PeerJSSignaling::sendAnswer(const QString &targetId, const QString &sdp, const QString &connectionId)
{
    QVariantMap payload;
    QVariantMap sdpObj;
    sdpObj["type"] = "answer";
    sdpObj["sdp"] = sdp;
    payload["sdp"] = sdpObj;
    payload["type"] = "data";
    payload["connectionId"] = connectionId;  // Use the original connectionId from OFFER
    payload["browser"] = "libdatachannel";

    sendMessage("ANSWER", targetId, payload);
}

void PeerJSSignaling::sendCandidate(const QString &targetId, const QString &candidate, const QString &mid)
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

void PeerJSSignaling::sendReject(const QString &targetId, const QString &connectionId)
{
    QVariantMap payload;
    payload["type"] = "data";
    payload["connectionId"] = connectionId;
    payload["reason"] = "Network full";

    sendMessage("REJECT", targetId, payload);
}
