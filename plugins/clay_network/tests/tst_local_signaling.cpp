// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The LAN signaling server embedded in a host (#321): an id belongs to the
// first socket that registered it until that socket closes, so whoever has
// the code cannot take over HOST or a joiner; closed sockets are dropped, so
// connect/close cycles do not pile up; a malformed LAN code fails in the
// joiner before anything connects; and a full host's refusal reaches the
// joiner as joinRefused (#323).

#include "claynetwork_native.h"
#include "signaling_local.h"

#include <QSignalSpy>
#include <QTcpServer>
#include <QTest>

namespace {

const QString kSecret = QStringLiteral("ABCDEFGH");

QString base36(quint64 n)
{
    return QString::number(n, 36).toUpper();
}

// A LAN code for 127.0.0.1:port; the parts can be replaced to break it
QString lanCode(quint16 port, const QString &secret = kSecret)
{
    return QString("L%1-%2-%3").arg(base36(0x7F000001)).arg(base36(port)).arg(secret);
}

struct Client
{
    explicit Client(quint16 port, const QString &id = QString(), const QString &secret = kSecret)
    {
        QObject::connect(&ws, &LocalSignalingClient::errorOccurred,
                         [this](const QString &e) { errors << e; });
        QObject::connect(&ws, &LocalSignalingClient::offerReceived,
                         [this](const QString &from) { offersFrom << from; });
        ws.connect("127.0.0.1", port, id, secret);
    }
    LocalSignalingClient ws;
    QStringList errors;
    QStringList offersFrom;
};

} // namespace

class TestLocalSignaling : public QObject
{
    Q_OBJECT

private slots:
    void takenIdIsRefused()
    {
        LocalSignalingServer server;
        server.setSecret(kSecret);
        QVERIFY(server.start(0));

        Client host(server.port(), "HOST");
        QTRY_VERIFY_WITH_TIMEOUT(host.ws.isConnected(), 5000);
        Client joiner(server.port());
        QTRY_VERIFY_WITH_TIMEOUT(joiner.ws.isConnected(), 5000);
        const QString joinerId = joiner.ws.peerId();

        // Knows the code, claims the host's id, then a joiner's
        Client asHost(server.port(), "HOST");
        Client asJoiner(server.port(), joinerId);
        QTRY_VERIFY_WITH_TIMEOUT(!asHost.errors.isEmpty() && !asJoiner.errors.isEmpty(), 5000);
        qInfo() << "refused:" << asHost.errors.first() << "/" << asJoiner.errors.first();
        QVERIFY(asHost.errors.first().contains("taken"));
        QVERIFY(asJoiner.errors.first().contains("taken"));
        QVERIFY(!asHost.ws.isConnected());
        QVERIFY(!asJoiner.ws.isConnected());

        // The real host still gets what is meant for it
        Client late(server.port());
        QTRY_VERIFY_WITH_TIMEOUT(late.ws.isConnected(), 5000);
        late.ws.sendOffer("HOST", "v=0");
        QTRY_COMPARE_WITH_TIMEOUT(host.offersFrom, QStringList{late.ws.peerId()}, 5000);
        QVERIFY(asHost.offersFrom.isEmpty());
        QTRY_COMPARE_WITH_TIMEOUT(server.openSocketCount(), 3, 5000);
    }

    void idIsFreeAfterItsOwnerCloses()
    {
        LocalSignalingServer server;
        server.setSecret(kSecret);
        QVERIFY(server.start(0));

        {
            Client first(server.port(), "HOST");
            QTRY_VERIFY_WITH_TIMEOUT(first.ws.isConnected(), 5000);
            first.ws.disconnect();
            QTRY_VERIFY_WITH_TIMEOUT(server.clientIds().isEmpty(), 5000);
        }
        Client second(server.port(), "HOST");
        QTRY_VERIFY_WITH_TIMEOUT(second.ws.isConnected(), 5000);
        QVERIFY(second.errors.isEmpty());
    }

    // Every fifth cycle is turned away (wrong secret), every seventh claims a
    // taken id: refused sockets must be dropped as well as registered ones
    void connectCloseCyclesLeaveOnlyLiveClients()
    {
        LocalSignalingServer server;
        server.setSecret(kSecret);
        QVERIFY(server.start(0));
        Client host(server.port(), "HOST");
        QTRY_VERIFY_WITH_TIMEOUT(host.ws.isConnected(), 5000);

        int registered = 0;
        int refused = 0;
        for (int i = 0; i < 50; ++i) {
            const bool wrongSecret = i % 5 == 4;
            const bool takenId = !wrongSecret && i % 7 == 6;
            Client c(server.port(), takenId ? "HOST" : QString(),
                     wrongSecret ? QStringLiteral("ZZZZZZZZ") : kSecret);
            if (wrongSecret || takenId) {
                QTRY_VERIFY_WITH_TIMEOUT(!c.errors.isEmpty(), 5000);
                ++refused;
            } else {
                QTRY_VERIFY_WITH_TIMEOUT(c.ws.isConnected(), 5000);
                ++registered;
            }
            c.ws.disconnect();
        }
        qInfo() << "cycles: registered" << registered << "refused" << refused;

        QTRY_COMPARE_WITH_TIMEOUT(server.clientIds(), QStringList{"HOST"}, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(server.openSocketCount(), 1, 5000);
        qInfo() << "after 50 cycles: ids" << server.clientIds()
                << "sockets" << server.openSocketCount();
    }

    void malformedLanCodeNeverConnects_data()
    {
        QTest::addColumn<QString>("code");
        const QString ip = base36(0x7F000001);
        const QString port = "PORT";  // replaced with the probe's port
        QTest::newRow("no secret") << QString("L%1-%2").arg(ip, port);
        QTest::newRow("secret too short") << QString("L%1-%2-ABCDEFG").arg(ip, port);
        QTest::newRow("secret too long") << QString("L%1-%2-ABCDEFGHJ").arg(ip, port);
        QTest::newRow("secret outside alphabet") << QString("L%1-%2-ABCDEFG0").arg(ip, port);
        QTest::newRow("extra part") << QString("L%1-%2-ABCD-EFGH").arg(ip, port);
        QTest::newRow("empty ip") << QString("L-%1-%2").arg(port, kSecret);
        QTest::newRow("ip not base36") << QString("L3V*0001-%1-%2").arg(port, kSecret);
        QTest::newRow("ip out of range") << QString("LZZZZZZZ-%1-%2").arg(port, kSecret);
        QTest::newRow("port zero") << QString("L%1-0-%2").arg(ip, kSecret);
        QTest::newRow("port out of range") << QString("L%1-1EKG-%2").arg(ip, kSecret);
    }

    void malformedLanCodeNeverConnects()
    {
        QFETCH(QString, code);
        QTcpServer probe;
        QVERIFY(probe.listen(QHostAddress::LocalHost));
        code.replace("PORT", base36(probe.serverPort()));

        ClayNetwork net;
        QSignalSpy errors(&net, &ClayNetwork::errorOccurred);
        net.joinRoom(code);

        QTRY_COMPARE_WITH_TIMEOUT(errors.count(), 1, 2000);
        QCOMPARE(errors.first().first().toString(), QString("Invalid LAN code"));
        QCOMPARE(net.status(), ClayNetwork::Error);
        QTest::qWait(500);
        QVERIFY2(!probe.hasPendingConnections(), qPrintable(code + " connected"));
    }

    // The control for the above: the same probe sees a well-formed code
    void wellFormedLanCodeConnects()
    {
        QTcpServer probe;
        QVERIFY(probe.listen(QHostAddress::LocalHost));
        ClayNetwork net;
        net.joinRoom(lanCode(probe.serverPort()).toLower());
        QTRY_VERIFY_WITH_TIMEOUT(probe.hasPendingConnections(), 5000);
        QCOMPARE(net.signalingMode(), ClayNetwork::Local);
    }

    // A full native host turns a joiner away at signaling; the joiner hears
    // it as joinRefused("refused"), as from a full browser host (#323)
    void fullHostRefusesJoiner()
    {
        ClayNetwork host;
        host.setSignalingMode(ClayNetwork::Local);
        host.setMaxNodes(2);
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        host.createRoom();
        QVERIFY(created.wait(10000));

        ClayNetwork first;
        first.joinRoom(host.networkId());
        QTRY_VERIFY_WITH_TIMEOUT(first.connected() && host.nodes().size() == 1, 20000);

        ClayNetwork second;
        QSignalSpy refused(&second, &ClayNetwork::joinRefused);
        QSignalSpy errors(&second, &ClayNetwork::errorOccurred);
        second.joinRoom(host.networkId());
        QVERIFY(refused.wait(10000));
        QCOMPARE(refused.first().at(0).toString(), QString("refused"));
        QCOMPARE(refused.first().at(1).toString(), QString("Network full"));
        QCOMPARE(errors.count(), 1);
        QCOMPARE(errors.first().first().toString(), QString("Network full"));
        QCOMPARE(second.status(), ClayNetwork::Error);
        QVERIFY(!second.connected());
        QCOMPARE(host.nodes().size(), 1);
    }
};

QTEST_GUILESS_MAIN(TestLocalSignaling)
#include "tst_local_signaling.moc"
