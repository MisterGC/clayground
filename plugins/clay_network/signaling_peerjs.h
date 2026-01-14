// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <memory>

namespace rtc {
    class WebSocket;
}

class PeerJSSignaling : public QObject
{
    Q_OBJECT

public:
    explicit PeerJSSignaling(QObject *parent = nullptr);
    ~PeerJSSignaling() override;

    void connect(const QString &peerId = QString());
    void disconnect();
    bool isConnected() const;
    QString peerId() const;

    void sendOffer(const QString &targetId, const QString &sdp);
    void sendAnswer(const QString &targetId, const QString &sdp, const QString &connectionId);
    void sendCandidate(const QString &targetId, const QString &candidate, const QString &mid);

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
    QString serverUrl_;
    bool connected_ = false;
};
