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
}

PeerJSSignaling::~PeerJSSignaling()
{
    disconnect();
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
    config.disableTlsVerification = true; // For testing with public servers
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

void PeerJSSignaling::disconnect()
{
    if (ws_) {
        ws_->close();
        ws_.reset();
    }
    connected_ = false;
    peerId_.clear();
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
        emit connected(peerId_);
    }
    else if (type == "OFFER") {
        QString fromId = obj["src"].toString();
        QJsonObject payload = obj["payload"].toObject();
        QString sdp = payload["sdp"].toObject()["sdp"].toString();
        emit offerReceived(fromId, sdp);
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
    else if (type == "HEARTBEAT") {
        // Respond to heartbeat
        if (ws_ && ws_->isOpen()) {
            QJsonObject heartbeat;
            heartbeat["type"] = "HEARTBEAT";
            ws_->send(QJsonDocument(heartbeat).toJson(QJsonDocument::Compact).toStdString());
        }
    }
}

void PeerJSSignaling::onWsError(const std::string &error)
{
    qWarning() << "PeerJSSignaling: WebSocket error:" << QString::fromStdString(error);
    emit errorOccurred(QString::fromStdString(error));
}

void PeerJSSignaling::onWsClosed()
{
    qDebug() << "PeerJSSignaling: WebSocket closed";
    connected_ = false;
    emit disconnected();
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

void PeerJSSignaling::sendAnswer(const QString &targetId, const QString &sdp)
{
    QVariantMap payload;
    QVariantMap sdpObj;
    sdpObj["type"] = "answer";
    sdpObj["sdp"] = sdp;
    payload["sdp"] = sdpObj;
    payload["type"] = "data";
    payload["connectionId"] = targetId + "_" + peerId_;
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
