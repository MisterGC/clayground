// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QHash>
#include <memory>

namespace rtc {
    class WebSocket;
    class WebSocketServer;
}

class LocalSignalingServer : public QObject
{
    Q_OBJECT

public:
    explicit LocalSignalingServer(QObject *parent = nullptr);
    ~LocalSignalingServer() override;

    // A non-empty secret makes every client prove it in its first message
    // before it is registered - an unregistered socket gets nothing relayed
    // and can relay nothing (#293).
    bool start(uint16_t port = 0, const QString &secret = QString());
    void stop();
    bool isRunning() const;
    uint16_t port() const;

signals:
    void clientConnected(const QString &peerId);
    void clientDisconnected(const QString &peerId);
    void errorOccurred(const QString &error);

private:
    void onClientMessage(const QString &peerId, const std::string &message);
    void sendToClient(const QString &peerId, const QString &message);

    std::shared_ptr<rtc::WebSocketServer> server_;
    QHash<QString, std::weak_ptr<rtc::WebSocket>> clients_;
    QString secret_;
    uint16_t port_ = 0;
    bool running_ = false;
};

class LocalSignalingClient : public QObject
{
    Q_OBJECT

public:
    explicit LocalSignalingClient(QObject *parent = nullptr);
    ~LocalSignalingClient() override;

    void connect(const QString &host, uint16_t port, const QString &peerId = QString(),
                 const QString &secret = QString());
    void disconnect();
    bool isConnected() const;
    QString peerId() const;

    void sendOffer(const QString &targetId, const QString &sdp);
    void sendAnswer(const QString &targetId, const QString &sdp, const QString &connectionId);
    void sendCandidate(const QString &targetId, const QString &candidate, const QString &mid);
    void sendReject(const QString &targetId, const QString &connectionId);

signals:
    void connected(const QString &peerId);
    void disconnected();
    void offerReceived(const QString &fromId, const QString &sdp, const QString &connectionId);
    void answerReceived(const QString &fromId, const QString &sdp);
    void candidateReceived(const QString &fromId, const QString &candidate, const QString &mid);
    void errorOccurred(const QString &error);

private:
    void onWsOpen();
    void onWsMessage(const std::string &message);
    void onWsError(const std::string &error);
    void onWsClosed();
    void sendMessage(const QString &type, const QString &targetId, const QVariantMap &payload);

    std::shared_ptr<rtc::WebSocket> ws_;
    QString peerId_;
    QString secret_;
    bool connected_ = false;
};
