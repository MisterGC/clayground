// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Replicated objects (#306) between real nodes: a host and two joiners,
// three backends in one process over Local signaling, a timer pinging every
// 2 s as Network.qml does. What tst_replica checks on the table alone is
// checked here over data channels: a node that joins late sees every live
// object with its last state and the session properties - an object or an
// array among them, already in the map when its signal fires - state from any
// node but the owner is dropped, a despawn is not undone by state that
// arrives after it and frees its sequence entries, an owner that leaves
// takes its objects along or leaves them to the host, ownership can be
// handed over, and a spawn the host drops comes back to its spawner.

#include "claynetwork_native.h"
#include "testhooks.h"

#include <QJSEngine>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTest>
#include <QTimer>

#include <memory>

namespace {

constexpr int kPingMs = 2000;  // Network.qml's ping timer
constexpr int kJoinMs = 20000;

struct Net
{
    Net()
    {
        QObject::connect(&pinger, &QTimer::timeout, [this]() {
            host.ping();
            for (auto &j : joiners)
                j->ping();
        });
        pinger.start(kPingMs);
    }

    bool hostUp()
    {
        host.setSignalingMode(ClayNetwork::Local);
        QSignalSpy created(&host, &ClayNetwork::roomCreated);
        host.createRoom();
        return created.wait(10000);
    }

    ClayNetwork *join()
    {
        auto j = std::make_unique<ClayNetwork>();
        ClayNetwork *raw = j.get();
        const auto before = host.nodes().size();
        raw->joinRoom(host.networkId());
        joiners.push_back(std::move(j));
        const bool ok = QTest::qWaitFor([this, raw, before]() {
            return raw->connected() && host.nodes().size() == before + 1;
        }, kJoinMs);
        return ok ? raw : nullptr;
    }

    ClayNetwork host;
    std::vector<std::unique_ptr<ClayNetwork>> joiners;
    QTimer pinger;
};

QVariantMap state(double x, const QString &mood = QStringLiteral("idle"))
{
    return {{"x", x}, {"mood", mood}};
}

bool waitFor(const std::function<bool()> &cond, int ms = 5000)
{
    return QTest::qWaitFor(cond, ms);
}

} // namespace

class TestReplicatedObjects : public QObject
{
    Q_OBJECT

private slots:
    void cleanup() { clay::network::testhooks::objectOp = nullptr; }

    void aLateJoinerSeesEveryObjectWithItsLastStateAndTheSession()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        QVERIFY(a);

        // The host runs 30 enemies at 20 Hz, A its avatar
        QStringList enemies;
        for (int i = 0; i < 30; ++i)
            enemies.append(net.host.spawnObject("enemy", {{"spawnIndex", i}}, {}, "despawn"));
        const QString avatar = a->spawnObject("avatar", {{"token", "tok-a"}}, {}, "host");
        const QString spark = a->spawnObject("spark", {}, {}, "despawn");
        QVERIFY(!avatar.isEmpty() && !spark.isEmpty());
        QVERIFY(net.host.setSessionProperty("seed", 42));
        QVERIFY(net.host.setSessionProperty("level", "crypt"));
        QVERIFY(!a->setSessionProperty("seed", 7));
        for (int tick = 1; tick <= 10; ++tick) {
            for (int i = 0; i < enemies.size(); ++i)
                net.host.sendObjectState(enemies[i], state(i * 100 + tick,
                                                           tick == 10 ? "hunting" : "idle"));
            a->sendObjectState(avatar, state(tick));
            QTest::qWait(50);
        }
        QVERIFY(a->despawnObject(spark));
        QVERIFY(waitFor([&]() {
            return net.host.objectInfo(avatar).value("state").toMap().value("x").toDouble() == 10.0
                && net.host.objectInfo(spark).isEmpty()
                && a->objectInfo(enemies.last()).value("state").toMap().value("mood") == "hunting";
        }));
        // The keyed batching carries 30 objects a frame: every batch one
        // datagram, two at most per frame
        const QVariantMap fromHost = a->syncStats().value(net.host.nodeId()).toMap();
        QVERIFY2(fromHost.value("maxBatchBytes").toInt() <= 1200,
                 qPrintable(fromHost.value("maxBatchBytes").toString()));
        qInfo() << "30 objects x 10 frames reached A in" << fromHost.value("batches").toInt()
                << "batches of at most" << fromHost.value("maxBatchBytes").toInt() << "bytes";

        ClayNetwork *b = nullptr;
        {
            auto late = std::make_unique<ClayNetwork>();
            QSignalSpy spawned(late.get(), &ClayNetwork::objectSpawned);
            QSignalSpy session(late.get(), &ClayNetwork::sessionPropertyChanged);
            late->joinRoom(net.host.networkId());
            b = late.get();
            net.joiners.push_back(std::move(late));
            QVERIFY(waitFor([&]() { return spawned.count() == 31 && session.count() == 2; },
                            kJoinMs));
        }
        QCOMPARE(b->objects().size(), 31);
        QVERIFY(b->objectInfo(spark).isEmpty());
        for (int i = 0; i < enemies.size(); ++i) {
            const QVariantMap e = b->objectInfo(enemies[i]);
            QCOMPARE(e.value("owner").toString(), net.host.nodeId());
            QCOMPARE(e.value("type").toString(), QString("enemy"));
            QCOMPARE(e.value("onOwnerLeft").toString(), QString("despawn"));
            QCOMPARE(e.value("props").toMap().value("spawnIndex").toInt(), i);
            QCOMPARE(e.value("state").toMap().value("x").toDouble(), i * 100 + 10.0);
            QCOMPARE(e.value("state").toMap().value("mood").toString(), QString("hunting"));
        }
        const QVariantMap av = b->objectInfo(avatar);
        QCOMPARE(av.value("owner").toString(), a->nodeId());
        QCOMPARE(av.value("onOwnerLeft").toString(), QString("host"));
        QCOMPARE(av.value("props").toMap().value("token").toString(), QString("tok-a"));
        QCOMPARE(av.value("state").toMap().value("x").toDouble(), 10.0);
        QCOMPARE(b->sessionProperties().value("seed").toInt(), 42);
        QCOMPARE(b->sessionProperties().value("level").toString(), QString("crypt"));

        // From now on B follows like everybody else
        QSignalSpy states(b, &ClayNetwork::objectStateReceived);
        a->sendObjectState(avatar, state(11));
        QVERIFY(waitFor([&]() {
            return b->objectInfo(avatar).value("state").toMap().value("x").toDouble() == 11.0;
        }));
    }

    void aSessionPropertyHoldingAnObjectOrArrayArrivesWhole()
    {
        // As QML hands them over: a JS object and a JS array, as QJSValue
        // in a QVariant, which JSON used to turn into null (#375)
        QJSEngine js;
        const QVariant loot = QVariant::fromValue(
            js.evaluate("({gold: 3, items: ['sword', {name: 'key', uses: 2}]})"));
        const QVariant path = QVariant::fromValue(js.evaluate("[[0, 1], [2, 3.5], 'exit']"));
        const QByteArray lootJson = R"({"gold":3,"items":["sword",{"name":"key","uses":2}]})";
        const QByteArray pathJson = R"([[0,1],[2,3.5],"exit"])";
        auto json = [](const QVariant &v) {
            return QJsonDocument::fromVariant(QVariantList{v}).toJson(QJsonDocument::Compact)
                .mid(1).chopped(1);
        };
        // Inside sessionPropertyChanged, sessionProperties already holds
        // the value the signal carries
        auto watch = [&](ClayNetwork *n, QStringList *stale, QStringList *seen) {
            QObject::connect(n, &ClayNetwork::sessionPropertyChanged, n,
                             [n, stale, seen, json](const QString &name, const QVariant &value) {
                seen->append(name);
                if (json(n->sessionProperties().value(name)) != json(value))
                    stale->append(name);
            });
        };

        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        QVERIFY(a);
        QStringList staleHost, seenHost, staleA, seenA;
        watch(&net.host, &staleHost, &seenHost);
        watch(a, &staleA, &seenA);
        QVERIFY(net.host.setSessionProperty("seed", 42));
        QVERIFY(net.host.setSessionProperty("loot", loot));
        QVERIFY(net.host.setSessionProperty("path", path));
        QVERIFY(waitFor([&]() { return seenA.size() == 3; }));

        ClayNetwork *b = nullptr;
        QStringList staleB, seenB;
        {
            auto late = std::make_unique<ClayNetwork>();
            b = late.get();
            watch(b, &staleB, &seenB);
            late->joinRoom(net.host.networkId());
            net.joiners.push_back(std::move(late));
            QVERIFY(waitFor([&]() { return seenB.size() == 3; }, kJoinMs));
        }
        for (ClayNetwork *n : {&net.host, a, b}) {
            const QVariantMap p = n->sessionProperties();
            QCOMPARE(p.value("seed").toInt(), 42);
            QCOMPARE(json(p.value("loot")), lootJson);
            QCOMPARE(json(p.value("path")), pathJson);
        }
        QCOMPARE(seenHost, QStringList({"seed", "loot", "path"}));
        QCOMPARE(staleHost, QStringList());
        QCOMPARE(staleA, QStringList());
        QCOMPARE(staleB, QStringList());
    }

    void stateFromAnyNodeButTheOwnerIsDropped()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        ClayNetwork *b = net.join();
        QVERIFY(a && b);
        const QString id = net.host.spawnObject("enemy", {}, {}, "despawn");
        net.host.sendObjectState(id, state(1));
        QVERIFY(waitFor([&]() {
            return a->objectInfo(id).value("state").toMap().value("x").toDouble() == 1.0
                && b->objectInfo(id).value("state").toMap().value("x").toDouble() == 1.0;
        }));
        QSignalSpy hostStates(&net.host, &ClayNetwork::objectStateReceived);
        QSignalSpy aStates(a, &ClayNetwork::objectStateReceived);
        QSignalSpy aDespawns(a, &ClayNetwork::objectDespawned);

        // B claims a state of the host's enemy, plainly and in the host's
        // name, and despawns it - none of it counts anywhere
        const QString hostId = net.host.nodeId();
        b->sendRaw(hostId, QString(R"({"t":"b","q":999999,"ts":0,"e":[{"o":"%1","d":{"x":-1}}]})").arg(id));
        b->sendRaw(hostId, QString(R"({"t":"b","q":999999,"ts":0,"from":"%2","e":[{"o":"%1","d":{"x":-2}}]})")
                               .arg(id, hostId));
        b->sendRaw(hostId, QString(R"({"t":"o","op":"despawn","id":"%1"})").arg(id));
        b->sendRaw(hostId, QString(R"({"t":"o","op":"state","id":"%1","q":999999,"ts":0,"d":{"x":-3}})").arg(id));
        // ... and B's own settle for it, which B refuses to send at all
        b->settleObjectState(id, state(-4));
        // A marker behind them on the same reliable channel: once it is
        // through, so is everything B sent
        const QString marker = b->spawnObject("marker", {}, {}, "despawn");
        QVERIFY(waitFor([&]() { return !a->objectInfo(marker).isEmpty(); }));
        QTest::qWait(200);
        QCOMPARE(hostStates.count(), 0);
        QCOMPARE(aStates.count(), 0);
        QCOMPARE(aDespawns.count(), 0);
        QCOMPARE(net.host.objectInfo(id).value("state").toMap().value("x").toDouble(), 1.0);
        QCOMPARE(a->objectInfo(id).value("state").toMap().value("x").toDouble(), 1.0);
    }

    void aDespawnIsNotUndoneByStateThatArrivesAfterIt()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        QVERIFY(a);
        // Jitter lets lossy states overtake each other and the despawn
        a->setLinkConditions({{"latencyMs", 40}, {"jitterMs", 60}});
        const int before = a->objectSequenceEntries();
        QStringList events;
        QObject::connect(a, &ClayNetwork::objectStateReceived,
                         [&](const QString &id) { events.append("state " + id); });
        QObject::connect(a, &ClayNetwork::objectDespawned,
                         [&](const QString &id) { events.append("despawn " + id); });
        QStringList ids;
        for (int round = 0; round < 10; ++round) {
            const QString id = net.host.spawnObject("spark", {}, {}, "despawn");
            ids.append(id);
            for (int i = 0; i < 5; ++i) {
                net.host.sendObjectState(id, state(i));
                net.host.flushState();
                QTest::qWait(5);
            }
            QVERIFY(net.host.despawnObject(id));
        }
        QVERIFY(waitFor([&]() { return events.count(QStringLiteral("despawn ") + ids.last()) == 1; }));
        QTest::qWait(400);  // whatever was still under way
        for (const QString &id : ids) {
            const qsizetype gone = events.indexOf("despawn " + id);
            QVERIFY2(gone >= 0, qPrintable(id));
            QCOMPARE(events.count("despawn " + id), 1);
            for (qsizetype i = gone + 1; i < events.size(); ++i)
                QVERIFY2(events[i] != "state " + id, qPrintable(events.join(", ")));
            QVERIFY(a->objectInfo(id).isEmpty());
        }
        QCOMPARE(a->objectSequenceEntries(), before);
    }

    // The review of #355: a sequence entry per sender and key, and objects
    // that come and go all the time
    void spawnsAndDespawnsDoNotGrowTheSequenceTables()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        ClayNetwork *b = net.join();
        QVERIFY(a && b);
        const int hostBefore = net.host.objectSequenceEntries();
        const int aBefore = a->objectSequenceEntries();
        const int bBefore = b->objectSequenceEntries();
        for (int i = 0; i < 300; ++i) {
            ClayNetwork *owner = (i % 2) ? a : &net.host;
            const QString id = owner->spawnObject("spark", {}, {}, "despawn");
            QVERIFY(!id.isEmpty());
            owner->sendObjectState(id, state(i));
            owner->flushState();
            if (i % 10 == 9)
                QTest::qWait(20);
            QVERIFY(owner->despawnObject(id));
        }
        QVERIFY(waitFor([&]() {
            return net.host.objects().isEmpty() && a->objects().isEmpty() && b->objects().isEmpty();
        }));
        QTest::qWait(300);
        QCOMPARE(net.host.objectSequenceEntries(), hostBefore);
        QCOMPARE(a->objectSequenceEntries(), aBefore);
        QCOMPARE(b->objectSequenceEntries(), bBefore);
    }

    void whenTheOwnerLeavesItsObjectsDespawnOrPassToTheHost()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        ClayNetwork *b = net.join();
        QVERIFY(a && b);
        const QString avatar = a->spawnObject("avatar", {}, {}, "despawn");
        const QString item = a->spawnObject("item", {}, {}, "host");
        a->sendObjectState(item, state(7));
        QVERIFY(waitFor([&]() {
            return b->objectInfo(item).value("state").toMap().value("x").toDouble() == 7.0
                && !b->objectInfo(avatar).isEmpty();
        }));
        QSignalSpy despawned(b, &ClayNetwork::objectDespawned);
        QSignalSpy owners(b, &ClayNetwork::objectOwnerChanged);
        a->leave();
        QVERIFY(waitFor([&]() { return despawned.count() == 1 && owners.count() == 1; }));
        const QString hostId = net.host.nodeId();
        for (ClayNetwork *n : {&net.host, b}) {
            QVERIFY(n->objectInfo(avatar).isEmpty());
            QCOMPARE(n->objectInfo(item).value("owner").toString(), hostId);
            QCOMPARE(n->objectInfo(item).value("state").toMap().value("x").toDouble(), 7.0);
        }
        QCOMPARE(despawned.first().first().toString(), avatar);
        QCOMPARE(owners.first().at(1).toString(), hostId);
        // The host speaks for it now
        net.host.sendObjectState(item, state(8));
        QVERIFY(waitFor([&]() {
            return b->objectInfo(item).value("state").toMap().value("x").toDouble() == 8.0;
        }));
    }

    void ownershipCanBeHandedOver()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        ClayNetwork *b = net.join();
        QVERIFY(a && b);
        const QString id = a->spawnObject("ball", {}, {}, "despawn");
        a->sendObjectState(id, state(1));
        QVERIFY(waitFor([&]() { return !b->objectInfo(id).isEmpty(); }));
        QVERIFY(!b->setObjectOwner(id, b->nodeId()));
        QVERIFY(a->setObjectOwner(id, b->nodeId()));
        QVERIFY(waitFor([&]() {
            for (ClayNetwork *n : {&net.host, a, b})
                if (n->objectInfo(id).value("owner").toString() != b->nodeId())
                    return false;
            return true;
        }));
        a->sendObjectState(id, state(-1));
        b->sendObjectState(id, state(2));
        QVERIFY(waitFor([&]() {
            return net.host.objectInfo(id).value("state").toMap().value("x").toDouble() == 2.0
                && a->objectInfo(id).value("state").toMap().value("x").toDouble() == 2.0;
        }));
        // The host hands it on too
        QVERIFY(net.host.setObjectOwner(id, a->nodeId()));
        QVERIFY(waitFor([&]() {
            return b->objectInfo(id).value("owner").toString() == a->nodeId();
        }));
    }

    void aSpawnTheHostDropsComesBackToItsSpawnerAsADespawn()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        ClayNetwork *b = net.join();
        QVERIFY(a && b);
        const QString bId = b->nodeId();
        // On its way, A's spawn names B as the owner: the host drops it
        clay::network::testhooks::objectOp = [bId](QJsonObject &op) {
            if (op["op"].toString() == "spawn")
                op["owner"] = bId;
        };
        QSignalSpy aDespawned(a, &ClayNetwork::objectDespawned);
        QSignalSpy bSpawned(b, &ClayNetwork::objectSpawned);
        const QString id = a->spawnObject("ball", {}, {}, "despawn");
        QVERIFY(!a->objectInfo(id).isEmpty());
        QVERIFY(waitFor([&]() { return aDespawned.count() == 1; }));
        QCOMPARE(aDespawned.first().first().toString(), id);
        QVERIFY(a->objectInfo(id).isEmpty());
        QVERIFY(net.host.objectInfo(id).isEmpty());
        QTest::qWait(200);
        QCOMPARE(bSpawned.count(), 0);
    }

    void aSettledStateArrivesAndTheEndOfTheNetworkDespawnsEverything()
    {
        Net net;
        QVERIFY(net.hostUp());
        ClayNetwork *a = net.join();
        QVERIFY(a);
        // Every lossy state is lost; the settled one still arrives
        net.host.setLinkConditions({{"loss", 1.0}});
        const QString id = net.host.spawnObject("ball", {}, {}, "despawn");
        net.host.sendObjectState(id, state(5));
        net.host.flushState();
        net.host.settleObjectState(id, state(6, "resting"));
        QVERIFY(waitFor([&]() {
            return a->objectInfo(id).value("state").toMap().value("mood").toString() == "resting";
        }));
        QSignalSpy despawned(a, &ClayNetwork::objectDespawned);
        net.host.leave();
        QVERIFY(waitFor([&]() { return despawned.count() == 1; }));
        QCOMPARE(despawned.first().first().toString(), id);
        QVERIFY(a->objects().isEmpty());
        QVERIFY(a->sessionProperties().isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestReplicatedObjects)
#include "tst_replicated_objects.moc"
