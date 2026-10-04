// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// How nodes notice each other leaving (#299): a clean leave() says goodbye
// and reaches the other side at once, a host that goes silent is dropped
// from missing pongs within the grace period plus one ping interval, and a
// link that is out for less than the grace period loses nobody. Two
// backends in one process over Local signaling; a timer pings every 2 s,
// as Network.qml does. Each way of losing the host names its reason (#376)
// before connected turns false.

#include "claynetwork_native.h"

#include <QElapsedTimer>
#include <QSignalSpy>
#include <QTest>
#include <QTimer>

namespace {

constexpr int kPingMs = 2000;  // Network.qml's ping timer

struct Pair
{
    Pair()
    {
        QObject::connect(&pinger, &QTimer::timeout, [this]() {
            host.ping();
            joiner.ping();
        });
        pinger.setTimerType(Qt::PreciseTimer);
        pinger.start(kPingMs);
    }

    bool connect()
    {
        host.setSignalingMode(ClayNetwork::Local);
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        host.createRoom();
        if (!created.wait(10000))
            return false;
        joiner.joinRoom(host.networkId());
        return QTest::qWaitFor([this]() {
            return joiner.connected() && host.nodes().size() == 1;
        }, 20000);
    }

    ClayNetwork host;
    ClayNetwork joiner;
    QTimer pinger;
};

// What a handler on connected sees when it turns false, and in which order
// the joiner's signals came (#376)
struct HostLossLog
{
    explicit HostLossLog(ClayNetwork &net)
    {
        QObject::connect(&net, &ClayNetwork::connectedChanged, &net, [this, &net]() {
            if (!net.connected() && reasonAtDisconnect.isNull()) {
                reasonAtDisconnect = net.hostLostReason();
                order.append("connected=false");
            }
        });
        QObject::connect(&net, &ClayNetwork::hostLost, &net,
                         [this](const QString &reason, const QString &message) {
            reason_ = reason;
            message_ = message;
            order.append("hostLost");
        });
        QObject::connect(&net, &ClayNetwork::errorOccurred, &net, [this](const QString &) {
            order.append("errorOccurred");
        });
    }

    QString reasonAtDisconnect;  // null until connected turned false
    QString reason_;
    QString message_;
    QStringList order;
};

const QStringList kLossOrder{"connected=false", "hostLost", "errorOccurred"};

} // namespace

class TestPeerLiveness : public QObject
{
    Q_OBJECT

private slots:
    void cleanHostLeaveReachesJoiner()
    {
        Pair p;
        QVERIFY(p.connect());
        const QString hostId = p.joiner.hostId();
        // Only the goodbye can be this fast: no check for silence runs
        p.joiner.setGracePeriod(0);
        QSignalSpy errors(&p.joiner, &ClayNetwork::errorOccurred);
        QSignalSpy left(&p.joiner, &ClayNetwork::playerLeft);
        HostLossLog loss(p.joiner);

        QElapsedTimer t;
        t.start();
        p.host.leave();
        QVERIFY(QTest::qWaitFor([&]() {
            return p.joiner.status() == ClayNetwork::Disconnected && errors.count() == 1;
        }, 3000));
        const qint64 ms = t.elapsed();
        qInfo() << "joiner Disconnected with errorOccurred after" << ms << "ms:"
                << errors.first().first().toString();

        QVERIFY(ms < 1000);
        QCOMPARE(errors.first().first().toString(), QString("The host left the network"));
        QVERIFY(!p.joiner.connected());
        QVERIFY(p.joiner.nodes().isEmpty());
        QCOMPARE(left.count(), 1);
        QCOMPARE(left.first().first().toString(), hostId);
        QCOMPARE(loss.reasonAtDisconnect, QString("host-left"));
        QCOMPARE(loss.reason_, QString("host-left"));
        QCOMPARE(loss.message_, QString("The host left the network"));
        QCOMPARE(loss.order, kLossOrder);
        QCOMPARE(p.joiner.hostLostReason(), QString("host-left"));
    }

    void cleanJoinerLeaveReachesHost()
    {
        Pair p;
        QVERIFY(p.connect());
        const QString joinerId = p.joiner.nodeId();
        p.host.setGracePeriod(0);
        QSignalSpy left(&p.host, &ClayNetwork::playerLeft);

        QElapsedTimer t;
        t.start();
        p.joiner.leave();
        QVERIFY(left.wait(3000));
        qInfo() << "host reported the joiner left after" << t.elapsed() << "ms";

        QVERIFY(t.elapsed() < 1000);
        QCOMPARE(left.first().first().toString(), joinerId);
        QCOMPARE(p.host.status(), ClayNetwork::Connected);
    }

    // The host stops answering: everything it sends and receives is held
    // by its link conditioner, as if it had crashed - its connection to the
    // joiner stays up, so the missing pongs are all there is to notice
    void silentHostIsDropped()
    {
        Pair p;
        QVERIFY(p.connect());
        const int grace = p.joiner.gracePeriod();
        QSignalSpy errors(&p.joiner, &ClayNetwork::errorOccurred);
        HostLossLog loss(p.joiner);
        // A crashed host judges nobody: this one would drop the joiner it no
        // longer hears, and the joiner would see the connection close first
        p.host.setGracePeriod(0);

        QElapsedTimer t;
        t.start();
        p.host.setLinkConditions({{"blackout", true}});
        QVERIFY(QTest::qWaitFor([&]() {
            return p.joiner.status() == ClayNetwork::Disconnected;
        }, grace + kPingMs + 3000));
        const qint64 ms = t.elapsed();
        qInfo() << "joiner dropped the silent host after" << ms << "ms, grace" << grace
                << "ms + ping" << kPingMs << "ms =" << grace + kPingMs << "ms:"
                << (errors.isEmpty() ? QString() : errors.first().first().toString());

        // A few ms on top for the event loop that runs both nodes
        QVERIFY(ms <= grace + kPingMs + 50);
        QCOMPARE(errors.count(), 1);
        QVERIFY(errors.first().first().toString().contains("did not answer"));
        QCOMPARE(loss.reasonAtDisconnect, QString("host-timeout"));
        QCOMPARE(loss.reason_, QString("host-timeout"));
        QCOMPARE(loss.order, kLossOrder);
    }

    // The host drops the joiner it no longer hears and closes the
    // connection, with no goodbye: the joiner, whose own grace period is
    // far off, sees the connection close
    void closedConnectionIsLost()
    {
        Pair p;
        QVERIFY(p.connect());
        p.host.setGracePeriod(1000);
        p.joiner.setGracePeriod(60000);
        HostLossLog loss(p.joiner);

        p.joiner.setLinkConditions({{"blackout", true}});
        QVERIFY(QTest::qWaitFor([&]() {
            return p.joiner.status() == ClayNetwork::Disconnected;
        }, 30000));

        qInfo() << "joiner lost the host:" << loss.reason_ << "-" << loss.message_;
        QCOMPARE(loss.reasonAtDisconnect, QString("connection-lost"));
        QCOMPARE(loss.reason_, QString("connection-lost"));
        QCOMPARE(loss.order, kLossOrder);
    }

    // A node that leaves by itself lost no host, and joining again clears
    // the last reason
    void reasonIsClearedAndNotSetByOwnLeave()
    {
        Pair p;
        QVERIFY(p.connect());
        p.joiner.setGracePeriod(0);
        QSignalSpy lost(&p.joiner, &ClayNetwork::hostLost);
        p.joiner.leave();
        QVERIFY(p.joiner.hostLostReason().isEmpty());
        QCOMPARE(lost.count(), 0);

        p.joiner.joinRoom(p.host.networkId());
        QVERIFY(QTest::qWaitFor([&]() { return p.joiner.connected(); }, 20000));
        p.host.leave();
        QVERIFY(QTest::qWaitFor([&]() { return lost.count() == 1; }, 3000));
        QCOMPARE(p.joiner.hostLostReason(), QString("host-left"));

        QSignalSpy created(&p.host, &ClayNetwork::roomCreated);
        p.host.createRoom();
        QVERIFY(created.wait(10000));
        p.joiner.joinRoom(p.host.networkId());
        QVERIFY(p.joiner.hostLostReason().isEmpty());
    }

    // Out for 1.5 s less than the grace period, then back: nobody leaves
    void shortOutageLosesNobody()
    {
        Pair p;
        QVERIFY(p.connect());
        const int grace = p.host.gracePeriod();
        QSignalSpy hostLeft(&p.host, &ClayNetwork::playerLeft);
        QSignalSpy joinerLeft(&p.joiner, &ClayNetwork::playerLeft);
        QSignalSpy errors(&p.joiner, &ClayNetwork::errorOccurred);

        p.host.setLinkConditions({{"blackout", true}});
        QTest::qWait(grace - 1500);
        p.host.setLinkConditions({});
        // Long enough for every check that was due to have run
        QTest::qWait(grace + kPingMs);

        QCOMPARE(hostLeft.count(), 0);
        QCOMPARE(joinerLeft.count(), 0);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(p.joiner.status(), ClayNetwork::Connected);
        QCOMPARE(p.host.nodes().size(), 1);
        QCOMPARE(p.joiner.nodes().size(), 1);
    }

    // A silent joiner is dropped by the host, and the host goes on
    void silentJoinerIsDropped()
    {
        Pair p;
        QVERIFY(p.connect());
        const QString joinerId = p.joiner.nodeId();
        QSignalSpy left(&p.host, &ClayNetwork::playerLeft);
        QSignalSpy hostErrors(&p.host, &ClayNetwork::errorOccurred);
        p.joiner.setGracePeriod(0);  // likewise, the silent one judges nobody

        p.joiner.setLinkConditions({{"blackout", true}});
        QVERIFY(left.wait(p.host.gracePeriod() + kPingMs + 3000));

        QCOMPARE(left.first().first().toString(), joinerId);
        QCOMPARE(hostErrors.count(), 0);
        QCOMPARE(p.host.status(), ClayNetwork::Connected);
        QVERIFY(p.host.nodes().isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestPeerLiveness)
#include "tst_peer_liveness.moc"
