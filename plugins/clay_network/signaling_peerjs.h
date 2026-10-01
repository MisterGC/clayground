// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
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
    // Closes the socket as if the server or the network had dropped it:
    // an open session ends in disconnected(), not in silence (#301)
    void drop();
    bool isConnected() const;
    QString peerId() const;

    void setServerUrl(const QString &url);
    // Off only by explicit choice: without the check anyone on the path to
    // the server can swap the SDP and with it the DTLS fingerprints (#320)
    void setVerifyCertificate(bool verify);

    void sendOffer(const QString &targetId, const QString &sdp);
    void sendAnswer(const QString &targetId, const QString &sdp, const QString &connectionId);
    void sendCandidate(const QString &targetId, const QString &candidate, const QString &mid);
    void sendReject(const QString &targetId, const QString &connectionId);

signals:
    void connected(const QString &peerId);
    // An open session ended without disconnect() being called: the server
    // dropped it, or the network did. A connection that never got as far as
    // the server's OPEN ends in errorOccurred instead.
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
    bool verifyCertificate_ = true;
    bool errorReported_ = false;
    // Bumped on every connect() and disconnect(): a callback queued by a
    // socket that is no longer ours is dropped, not mistaken for a drop
    quint64 attempt_ = 0;
    // A PeerJS server closes a socket it has not heard a HEARTBEAT on for
    // its alive timeout, so a host would silently stop being joinable
    QTimer heartbeat_;
};
