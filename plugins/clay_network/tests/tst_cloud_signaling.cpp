// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Native Cloud signaling against an in-process PeerJS server (#320): the
// server's certificate is checked unless the opt-out is set, a host keeps its
// signaling connection past the server's idle timeout, and a dropped
// connection reaches the backend as signalingLost. The network goes on
// meanwhile, and the node gets back on the server under the same id, also
// while the server still refuses it as taken (#299).
//
// The server speaks the PeerJS subset the native client uses: OPEN on
// connect, routing by "dst" with "src" stamped by the server, and - like the
// PeerJS server's alive timeout - it closes a client it has not had a
// HEARTBEAT from for idleTimeoutMs. An id it kicked it can hold on to for a
// while and refuse with ID-TAKEN, as a server does that has not noticed yet
// that the old connection is gone.

#include "claynetwork_native.h"

#include <rtc/rtc.hpp>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

#include <QElapsedTimer>
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
    int idTakenReplies() const { return idTaken_; }

    // How often the server registered id and said OPEN
    int opens(const QString &id)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = opens_.find(id.toStdString());
        return it == opens_.end() ? 0 : it->second;
    }

    bool registered(const QString &id)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return clients_.count(id.toStdString()) > 0;
    }

    // The server drops one client, as a restart or a network fault would,
    // and refuses its id as taken for holdIdMs after
    bool kick(const QString &id, int holdIdMs = 0)
    {
        std::shared_ptr<rtc::WebSocket> ws;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = clients_.find(id.toStdString());
            if (it == clients_.end())
                return false;
            ws = it->second.ws;
            clients_.erase(it);
            held_[id.toStdString()] = std::chrono::steady_clock::now()
                                      + std::chrono::milliseconds(holdIdMs);
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
                auto held = held_.find(id);
                if (held != held_.end() && std::chrono::steady_clock::now() < held->second) {
                    ++idTaken_;
                    ws->send(std::string("{\"type\":\"ID-TAKEN\",\"payload\":"
                                         "{\"msg\":\"ID is taken\"}}"));
                    ws->close();
                    return;
                }
                clients_[id] = {ws, std::chrono::steady_clock::now(), 0};
                ++opens_[id];
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
    std::map<std::string, std::chrono::steady_clock::time_point> held_;
    std::map<std::string, int> opens_;
    std::vector<std::shared_ptr<rtc::WebSocket>> sockets_;
    std::thread reaper_;
    std::atomic<bool> stopping_{false};
    std::atomic<int> idleCloses_{0};
    std::atomic<int> idTaken_{0};
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

    // The hold spans two of the server's idle timeouts, so a host that
    // stopped beating (every 5 s) would be closed at least once. 20 s does
    // that against a 10 s timeout; the 120 s it used to hold proved nothing
    // more and was most of the suite's time (#384). CLAY_NET_HOLD_MS sets a
    // longer hold - the PeerJS server's own 60 s timeout is 120000.
    void hostJoinableAfterServerIdleTimeout()
    {
        const int holdMs = envInt("CLAY_NET_HOLD_MS", 20000);
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

    // The host's signaling drops while a joiner is in (#299): the network
    // goes on, the host takes no joiners meanwhile, and it gets back on the
    // server under its code - after ID-TAKEN refusals for the id the server
    // still holds - where the next joiner finds it
    void signalingDropKeepsTheNetwork()
    {
        FakePeerJSServer server(FakePeerJSServer::Options{});
        ClayNetwork host;
        host.setSignalingUrl(server.url());
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        host.createRoom();
        QVERIFY(created.wait(10000));
        const QString code = host.networkId();
        QVERIFY(host.acceptingJoins());

        ClayNetwork joiner;
        joiner.setSignalingUrl(server.url());
        QSignalSpy got(&joiner, &ClayNetwork::messageReceived);
        joiner.joinRoom(code);
        QTRY_VERIFY_WITH_TIMEOUT(joiner.connected() && host.nodes().size() == 1, 20000);
        QVERIFY(!joiner.acceptingJoins());

        QSignalSpy lost(&host, &ClayNetwork::signalingLost);
        QSignalSpy errors(&host, &ClayNetwork::errorOccurred);
        QSignalSpy left(&host, &ClayNetwork::playerLeft);
        QSignalSpy roomCreatedAgain(&host, &ClayNetwork::roomCreated);
        QVERIFY(server.kick(code, 2500));

        QVERIFY(lost.wait(5000));
        QVERIFY(!host.acceptingJoins());
        QCOMPARE(host.status(), ClayNetwork::Connected);
        QVERIFY(host.connected());
        QCOMPARE(host.nodes().size(), 1);

        host.broadcast(QVariantMap{{"probe", "while the server is gone"}});
        QVERIFY(got.wait(5000));

        QElapsedTimer t;
        t.start();
        QTRY_VERIFY_WITH_TIMEOUT(host.acceptingJoins(), 15000);
        qInfo() << "host back on the server" << t.elapsed() << "ms after the drop was seen,"
                << server.idTakenReplies() << "ID-TAKEN refusals on the way";
        QVERIFY(server.idTakenReplies() >= 1);
        QVERIFY(server.registered(code));
        QCOMPARE(host.networkId(), code);
        QCOMPARE(lost.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(left.count(), 0);
        QCOMPARE(roomCreatedAgain.count(), 0);
        QCOMPARE(host.status(), ClayNetwork::Connected);

        ClayNetwork late;
        late.setSignalingUrl(server.url());
        late.joinRoom(code);
        QTRY_VERIFY_WITH_TIMEOUT(late.connected() && host.nodes().size() == 2, 20000);
    }

    // A joiner's signaling drops: it stays in the network and gets back on
    // the server under its own id
    void joinerSignalingDropKeepsTheNetwork()
    {
        FakePeerJSServer server(FakePeerJSServer::Options{});
        ClayNetwork host;
        host.setSignalingUrl(server.url());
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        host.createRoom();
        QVERIFY(created.wait(10000));

        ClayNetwork joiner;
        joiner.setSignalingUrl(server.url());
        joiner.joinRoom(host.networkId());
        QTRY_VERIFY_WITH_TIMEOUT(joiner.connected(), 20000);
        const QString id = joiner.nodeId();

        QSignalSpy lost(&joiner, &ClayNetwork::signalingLost);
        QSignalSpy errors(&joiner, &ClayNetwork::errorOccurred);
        QVERIFY(server.kick(id));
        QVERIFY(lost.wait(5000));
        QTRY_VERIFY_WITH_TIMEOUT(server.registered(id), 10000);
        QCOMPARE(joiner.nodeId(), id);
        QCOMPARE(joiner.status(), ClayNetwork::Connected);
        QCOMPARE(errors.count(), 0);
        QVERIFY(!joiner.acceptingJoins());
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
        QVERIFY(!host.acceptingJoins());

        // No reconnect gets through while the server is unreachable (#299)
        QTest::qWait(3000);
        QVERIFY(!host.acceptingJoins());
        QCOMPARE(server.opens(host.networkId()), 1);

        ClayNetwork joiner;
        joiner.setSignalingUrl(server.url());
        joiner.setLinkConditions({{"dropSignaling", true}});
        QSignalSpy joinErrors(&joiner, &ClayNetwork::errorOccurred);
        joiner.joinRoom(host.networkId());
        QCOMPARE(joinErrors.count(), 1);
        QVERIFY(joinErrors.first().first().toString().contains("unreachable"));
        QCOMPARE(joiner.status(), ClayNetwork::Error);

        // Once it can be reached again, the host is back on it
        host.setLinkConditions({});
        QTRY_VERIFY_WITH_TIMEOUT(host.acceptingJoins(), 10000);
        QCOMPARE(server.opens(host.networkId()), 2);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(lost.count(), 1);
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
