// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonObject>
#include <QString>

// The join handshake (#323), shared by the native and the WASM backend.
//
// A joiner's first message over the reliable data channel is a hello with
// its wire version, app id, room password and client token. The host judges
// it and answers with a welcome naming itself, or a refusal with a reason,
// and closes. Until then the joiner is no node: it is not in the host's
// roster and nothing but the handshake passes either way. The data channel
// is DTLS-encrypted, so the password never crosses the signaling server.
//
// The hello's "t" and "v" fields never change, whatever a later wire version
// does to the rest: that is how two builds tell they cannot talk.
namespace clay::network::handshake {

// Bump whenever a message on the data channels changes in a way an older
// build would misread
constexpr int kWireVersion = 1;
// A joiner that opened its channel and sent no hello for this long is
// refused: it is a build from before the handshake
constexpr int kTimeoutMs = 5000;
// A refused joiner gets this long to read the refusal before the host
// closes the connection
constexpr int kCloseDelayMs = 200;

inline QString incompatibleVersion() { return QStringLiteral("incompatible-version"); }
inline QString incompatibleApp() { return QStringLiteral("incompatible-app"); }
inline QString wrongPassword() { return QStringLiteral("wrong-password"); }
inline QString handshakeFailed() { return QStringLiteral("handshake-failed"); }
inline QString refused() { return QStringLiteral("refused"); }

// reason is empty when the other side passed
struct Verdict {
    QString reason;
    QString message;
    bool ok() const { return reason.isEmpty(); }
};

inline QJsonObject hello(int version, const QString &appId, const QString &password,
                         const QString &clientToken)
{
    QJsonObject msg;
    msg["t"] = "h";
    msg["v"] = version;
    msg["app"] = appId;
    msg["pw"] = password;
    msg["tok"] = clientToken;
    return msg;
}

inline QJsonObject welcome(const QString &hostId, int version)
{
    QJsonObject msg;
    msg["t"] = "H";
    msg["v"] = version;
    msg["host"] = hostId;
    return msg;
}

inline QJsonObject refusal(const Verdict &verdict)
{
    QJsonObject msg;
    msg["t"] = "R";
    msg["code"] = verdict.reason;
    msg["r"] = verdict.message;
    return msg;
}

// Compares without stopping at the first difference, so how long a refusal
// takes says nothing about how much of a guess was right
inline bool samePassword(const QString &a, const QString &b)
{
    const QByteArray x = a.toUtf8();
    const QByteArray y = b.toUtf8();
    int diff = x.size() ^ y.size();
    for (qsizetype i = 0; i < x.size(); ++i)
        diff |= x[i] ^ (i < y.size() ? y[i] : 0);
    return diff == 0;
}

// The host's judgement of a joiner's first message. A host without a
// password takes any; one with a password takes only the same.
inline Verdict judgeHello(const QJsonObject &msg, int version, const QString &appId,
                          const QString &password)
{
    if (msg["t"].toString() != QLatin1String("h"))
        return {incompatibleVersion(),
                QString("Incompatible version: the joiner sent no handshake, "
                        "the host speaks wire version %1").arg(version)};
    const int theirs = msg["v"].toInt(-1);
    if (theirs != version)
        return {incompatibleVersion(),
                QString("Incompatible version: the joiner speaks wire version %1, "
                        "the host %2").arg(theirs).arg(version)};
    const QString theirApp = msg["app"].toString();
    if (theirApp != appId)
        return {incompatibleApp(),
                QString("Incompatible app: the joiner is \"%1\", the host \"%2\"")
                    .arg(theirApp, appId)};
    if (!password.isEmpty() && !samePassword(msg["pw"].toString(), password))
        return {wrongPassword(), QStringLiteral("Wrong password")};
    return {};
}

// The joiner's judgement of the host's first message, over its link to
// linkPeer. A welcome must name the host at the other end of that link.
inline Verdict judgeReply(const QJsonObject &msg, const QString &linkPeer, int version)
{
    const QString t = msg["t"].toString();
    if (t == QLatin1String("H")) {
        const int theirs = msg["v"].toInt(-1);
        if (theirs != version)
            return {incompatibleVersion(),
                    QString("Incompatible version: the joiner speaks wire version %1, "
                            "the host %2").arg(version).arg(theirs)};
        const QString host = msg["host"].toString();
        if (host.isEmpty() || host != linkPeer)
            return {handshakeFailed(),
                    QString("Handshake failed: the host at %1 named itself \"%2\"")
                        .arg(linkPeer, host)};
        return {};
    }
    if (t == QLatin1String("R")) {
        const QString code = msg["code"].toString();
        const QString message = msg["r"].toString();
        return {code.isEmpty() ? refused() : code,
                message.isEmpty() ? QStringLiteral("Connection rejected") : message};
    }
    // A host from before the handshake greets with its roster
    return {incompatibleVersion(),
            QString("Incompatible version: the host sent no handshake, "
                    "the joiner speaks wire version %1").arg(version)};
}

} // namespace clay::network::handshake
