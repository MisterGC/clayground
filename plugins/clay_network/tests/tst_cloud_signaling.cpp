// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Native Cloud signaling against an in-process PeerJS server (#320): the
// server's certificate is checked unless the opt-out is set, a host keeps its
// signaling connection past the server's idle timeout, and a dropped
// connection reaches the backend as signalingLost.
//
// The server speaks the PeerJS subset the native client uses: OPEN on
// connect, routing by "dst" with "src" stamped by the server, and - like the
// PeerJS server's alive timeout - it closes a client it has not had a
// HEARTBEAT from for idleTimeoutMs.

#include "claynetwork_native.h"

#include <rtc/rtc.hpp>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTest>
#include <QUrlQuery>

#include <atomic>
#include <chrono>
#include <map>
#include <mutex>
#include <thread>

namespace {

// A self-signed certificate that is otherwise valid for "localhost", so the
// only reason for it to fail verification is that nobody vouches for it
std::pair<std::string, std::string> selfSignedLocalhost()
{
    EVP_PKEY *key = EVP_RSA_gen(2048);
    X509 *cert = X509_new();
    X509_set_version(cert, 2);
    ASN1_INTEGER_set(X509_get_serialNumber(cert), 1);
    X509_gmtime_adj(X509_getm_notBefore(cert), -3600);
    X509_gmtime_adj(X509_getm_notAfter(cert), 3600 * 24);
    X509_set_pubkey(cert, key);
    X509_NAME *name = X509_get_subject_name(cert);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC,
                               reinterpret_cast<const unsigned char *>("localhost"), -1, -1, 0);
    X509_set_issuer_name(cert, name);
    X509V3_CTX ctx;
    X509V3_set_ctx_nodb(&ctx);
    X509V3_set_ctx(&ctx, cert, cert, nullptr, nullptr, 0);
    X509_EXTENSION *san = X509V3_EXT_nconf_nid(nullptr, &ctx, NID_subject_alt_name,
                                              "DNS:localhost,IP:127.0.0.1");
    X509_add_ext(cert, san, -1);
    X509_EXTENSION_free(san);
    X509_sign(cert, key, EVP_sha256());

    auto pem = [](auto write) {
        BIO *bio = BIO_new(BIO_s_mem());
        write(bio);
        char *data = nullptr;
        long len = BIO_get_mem_data(bio, &data);
        std::string out(data, static_cast<size_t>(len));
        BIO_free(bio);
        return out;
    };
    std::string certPem = pem([&](BIO *b) { PEM_write_bio_X509(b, cert); });
    std::string keyPem = pem([&](BIO *b) {
        PEM_write_bio_PrivateKey(b, key, nullptr, nullptr, 0, nullptr, nullptr);
    });
    X509_free(cert);
    EVP_PKEY_free(key);
    return {certPem, keyPem};
}

class FakePeerJSServer
{
public:
    struct Options {
        bool tls = false;
        bool sendOpen = true;
        int idleTimeoutMs = 60000;
    };

    explicit FakePeerJSServer(Options opt) : opt_(opt)
    {
        rtc::WebSocketServer::Configuration config;
        config.port = 0;
        config.bindAddress = "127.0.0.1";
        if (opt.tls) {
            auto [cert, key] = selfSignedLocalhost();
            config.enableTls = true;
            config.certificatePemFile = cert;
            config.keyPemFile = key;
        }
        server_ = std::make_unique<rtc::WebSocketServer>(config);
        server_->onClient([this](std::shared_ptr<rtc::WebSocket> ws) { accept(ws); });
        reaper_ = std::thread([this]() { reap(); });
    }

    ~FakePeerJSServer()
    {
        stopping_ = true;
        reaper_.join();
        server_->stop();
        std::vector<std::shared_ptr<rtc::WebSocket>> sockets;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            sockets.swap(sockets_);
            clients_.clear();
        }
        for (auto &ws : sockets) {
            ws->resetCallbacks();
            ws->close();
        }
    }

    QString url() const
    {
        return QStringLiteral("%1://%2:%3/peerjs")
            .arg(opt_.tls ? "wss" : "ws", opt_.tls ? "localhost" : "127.0.0.1")
            .arg(server_->port());
    }

    int heartbeats(const QString &id)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = clients_.find(id.toStdString());
        return it == clients_.end() ? -1 : it->second.heartbeats;
    }

    int idleCloses() const { return idleCloses_; }

    // The server drops one client, as a restart or a network fault would
    bool kick(const QString &id)
    {
        std::shared_ptr<rtc::WebSocket> ws;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = clients_.find(id.toStdString());
            if (it == clients_.end())
                return false;
            ws = it->second.ws;
            clients_.erase(it);
        }
        ws->close();
        return true;
    }

private:
    struct Client {
        std::shared_ptr<rtc::WebSocket> ws;
        std::chrono::steady_clock::time_point lastBeat;
        int heartbeats = 0;
    };

    void accept(std::shared_ptr<rtc::WebSocket> ws)
    {
        std::weak_ptr<rtc::WebSocket> weak = ws;
        ws->onOpen([this, weak]() {
            auto ws = weak.lock();
            if (!ws)
                return;
            if (!opt_.sendOpen) {
                ws->close();
                return;
            }
            const QUrlQuery query(QUrl(QString::fromStdString(ws->path().value_or(""))).query());
            const std::string id = query.queryItemValue("id").toStdString();
            {
                std::lock_guard<std::mutex> lock(mutex_);
                clients_[id] = {ws, std::chrono::steady_clock::now(), 0};
            }
            ws->onMessage([this, id](auto message) {
                if (std::holds_alternative<std::string>(message))
                    route(id, std::get<std::string>(message));
            });
            ws->send(std::string("{\"type\":\"OPEN\"}"));
        });
        std::lock_guard<std::mutex> lock(mutex_);
        sockets_.push_back(ws);  // every socket lives as long as the server
    }

    void route(const std::string &src, const std::string &text)
    {
        QJsonObject msg = QJsonDocument::fromJson(QByteArray::fromStdString(text)).object();
        std::shared_ptr<rtc::WebSocket> target;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (msg["type"].toString() == "HEARTBEAT") {
                auto it = clients_.find(src);
                if (it != clients_.end()) {
                    it->second.lastBeat = std::chrono::steady_clock::now();
                    ++it->second.heartbeats;
                }
                return;
            }
            auto it = clients_.find(msg["dst"].toString().toStdString());
            if (it == clients_.end())
                return;
            target = it->second.ws;
        }
        msg["src"] = QString::fromStdString(src);
        target->send(QJsonDocument(msg).toJson(QJsonDocument::Compact).toStdString());
    }

    void reap()
    {
        while (!stopping_) {
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
            std::vector<std::shared_ptr<rtc::WebSocket>> idle;
            {
                std::lock_guard<std::mutex> lock(mutex_);
                const auto now = std::chrono::steady_clock::now();
                for (auto it = clients_.begin(); it != clients_.end();) {
                    if (now - it->second.lastBeat > std::chrono::milliseconds(opt_.idleTimeoutMs)) {
                        idle.push_back(it->second.ws);
                        it = clients_.erase(it);
                    } else {
                        ++it;
                    }
                }
            }
            for (auto &ws : idle) {
                ++idleCloses_;
                ws->close();
            }
        }
    }

    Options opt_;
    std::unique_ptr<rtc::WebSocketServer> server_;
    std::mutex mutex_;
    std::map<std::string, Client> clients_;
    std::vector<std::shared_ptr<rtc::WebSocket>> sockets_;
    std::thread reaper_;
    std::atomic<bool> stopping_{false};
    std::atomic<int> idleCloses_{0};
};

FakePeerJSServer::Options tlsServer()
{
    FakePeerJSServer::Options o;
    o.tls = true;
    return o;
}

FakePeerJSServer::Options silentServer()
{
    FakePeerJSServer::Options o;
    o.sendOpen = false;
    return o;
}

FakePeerJSServer::Options idleTimeout(int ms)
{
    FakePeerJSServer::Options o;
    o.idleTimeoutMs = ms;
    return o;
}

int envInt(const char *name, int fallback)
{
    bool ok = false;
    const int v = qEnvironmentVariableIntValue(name, &ok);
    return ok ? v : fallback;
}

} // namespace

class TestCloudSignaling : public QObject
{
    Q_OBJECT

private slots:
    void selfSignedCertificateIsAnError()
    {
#ifdef Q_OS_WIN
        // libdatachannel (v0.21.2) does not check the certificate on Windows,
        // as PeerJSSignaling warns and the docs say - there is no error to see
        QSKIP("the server certificate is not checked on Windows (libdatachannel)");
#endif
        FakePeerJSServer server(tlsServer());
        ClayNetwork net;
        net.setSignalingUrl(server.url());
        QSignalSpy errors(&net, &ClayNetwork::errorOccurred);
        QSignalSpy created(&net, &ClayNetwork::roomCreated);

        net.createRoom();

        QVERIFY(errors.wait(10000));
        QCOMPARE(net.status(), ClayNetwork::Error);
        QCOMPARE(created.count(), 0);
        qInfo() << "error:" << errors.first().first().toString();
    }

    void optOutAcceptsSelfSignedCertificate()
    {
        FakePeerJSServer server(tlsServer());
        ClayNetwork net;
        net.setSignalingUrl(server.url());
        net.setVerifySignalingCertificate(false);
        QSignalSpy errors(&net, &ClayNetwork::errorOccurred);
        QSignalSpy created(&net, &ClayNetwork::roomCreated);

        net.createRoom();

        QVERIFY(created.wait(10000));
        QCOMPARE(net.status(), ClayNetwork::Connected);
        QCOMPARE(errors.count(), 0);
    }

    void closeBeforeOpenIsAnError()
    {
        FakePeerJSServer server(silentServer());
        ClayNetwork net;
        net.setSignalingUrl(server.url());
        QSignalSpy errors(&net, &ClayNetwork::errorOccurred);

        net.createRoom();

        QVERIFY(errors.wait(10000));
        QCOMPARE(errors.count(), 1);
        QCOMPARE(net.status(), ClayNetwork::Error);
    }

    // CLAY_NET_HOLD_MS shortens the 120 s hold for a quick local run; the
    // server's idle timeout stays at half the hold so the hold always spans it
    void hostJoinableAfterServerIdleTimeout()
    {
        const int holdMs = envInt("CLAY_NET_HOLD_MS", 120000);
        FakePeerJSServer server(idleTimeout(holdMs / 2));
        ClayNetwork host;
        host.setSignalingUrl(server.url());
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        QSignalSpy lost(&host, &ClayNetwork::signalingLost);
        QSignalSpy joined(&host, &ClayNetwork::playerJoined);

        host.createRoom();
        QVERIFY(created.wait(10000));
        const QString code = host.networkId();

        QTest::qWait(holdMs);
        QCOMPARE(lost.count(), 0);
        QCOMPARE(server.idleCloses(), 0);
        const int beats = server.heartbeats(code);
        qInfo() << "held" << holdMs << "ms, heartbeats seen by the server:" << beats;
        QVERIFY(beats >= holdMs / 5000 - 2);

        ClayNetwork joiner;
        joiner.setSignalingUrl(server.url());
        joiner.joinRoom(code);

        QTRY_VERIFY_WITH_TIMEOUT(joined.count() == 1, 20000);
        QTRY_VERIFY_WITH_TIMEOUT(joiner.connected(), 20000);
        QCOMPARE(joined.first().first().toString(), joiner.nodeId());
    }

    void droppedSignalingReachesNetwork()
    {
        FakePeerJSServer server(FakePeerJSServer::Options{});
        ClayNetwork host;
        host.setSignalingUrl(server.url());
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        QSignalSpy lost(&host, &ClayNetwork::signalingLost);
        QSignalSpy errors(&host, &ClayNetwork::errorOccurred);

        host.createRoom();
        QVERIFY(created.wait(10000));
        QVERIFY(server.kick(host.networkId()));

        QVERIFY(lost.wait(5000));
        QCOMPARE(lost.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(host.status(), ClayNetwork::Connected);
    }

    // linkConditions.dropSignaling (#301) cuts a live connection the way a
    // server drop does, and an attempt made while it is set does not get out
    void conditionerDropsSignaling()
    {
        FakePeerJSServer server(FakePeerJSServer::Options{});
        ClayNetwork host;
        host.setSignalingUrl(server.url());
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        QSignalSpy lost(&host, &ClayNetwork::signalingLost);
        QSignalSpy errors(&host, &ClayNetwork::errorOccurred);

        host.createRoom();
        QVERIFY(created.wait(10000));
        host.setLinkConditions({{"dropSignaling", true}});

        QVERIFY(lost.wait(5000));
        QCOMPARE(lost.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(host.status(), ClayNetwork::Connected);

        ClayNetwork joiner;
        joiner.setSignalingUrl(server.url());
        joiner.setLinkConditions({{"dropSignaling", true}});
        QSignalSpy joinErrors(&joiner, &ClayNetwork::errorOccurred);
        joiner.joinRoom(host.networkId());
        QCOMPARE(joinErrors.count(), 1);
        QVERIFY(joinErrors.first().first().toString().contains("unreachable"));
        QCOMPARE(joiner.status(), ClayNetwork::Error);
    }

    void leaveIsNotALoss()
    {
        FakePeerJSServer server(FakePeerJSServer::Options{});
        ClayNetwork host;
        host.setSignalingUrl(server.url());
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        QSignalSpy lost(&host, &ClayNetwork::signalingLost);

        host.createRoom();
        QVERIFY(created.wait(10000));
        host.leave();

        QTest::qWait(1000);
        QCOMPARE(lost.count(), 0);
    }
};

QTEST_GUILESS_MAIN(TestCloudSignaling)
#include "tst_cloud_signaling.moc"
