// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The replicated-object table (#306) without a network: three tables - a
// host and two joiners - whose operations travel through in-memory queues
// the way they travel over Star links, every joiner's only to the host.
// Lossy object states are handed to receiveState() directly.

#include "replica.h"

#include <QTest>

namespace rp = clay::network::replica;

namespace {

struct Msg {
    QString from;
    QString to;
    QJsonObject op;
};

// One table per node, wired like a Star network: a joiner sends to the
// host only, the host to anyone
struct Net
{
    explicit Net(const QStringList &joiners) : joinerIds(joiners)
    {
        add("H", true);
        for (const QString &j : joiners)
            add(j, false);
    }

    void add(const QString &id, bool isHost)
    {
        Node &n = nodes[id];
        n.id = id;
        rp::Io io;
        io.sendTo = [this, id](const QString &to, const QJsonObject &op) {
            queue.append({id, to, op});
        };
        io.broadcast = [this, id](const QJsonObject &op, const QString &except) {
            for (const QString &to : roster(id))
                if (to != except)
                    queue.append({id, to, op});
        };
        io.isNode = [this, id](const QString &other) { return roster(id).contains(other); };
        io.diag = [this](const QString &d) { diags.append(d); };
        io.spawned = [this, id](const rp::Object &o) { nodes[id].log.append("spawn " + o.id); };
        io.despawned = [this, id](const rp::Object &o) { nodes[id].log.append("despawn " + o.id); };
        io.ownerChanged = [this, id](const QString &oid, const QString &owner) {
            nodes[id].log.append("owner " + oid + " " + owner);
        };
        io.state = [this, id](const QString &oid, const QVariantMap &d, double) {
            nodes[id].log.append("state " + oid + " " + d.value("x").toString());
        };
        io.sessionProperty = [this, id](const QString &name, const QVariant &v) {
            nodes[id].log.append("session " + name + " " + v.toString());
        };
        n.table.setIo(io);
        n.table.start(id, "H", isHost);
    }

    QStringList roster(const QString &id) const
    {
        QStringList all = QStringList{"H"} + joinerIds;
        all.removeAll(id);
        return all;
    }

    // Delivers everything queued, and what that queues in turn
    void deliver(const std::function<void(Msg &)> &tamper = {})
    {
        while (!queue.isEmpty()) {
            Msg m = queue.takeFirst();
            if (tamper)
                tamper(m);
            if (nodes.contains(m.to))
                nodes[m.to].table.receiveOp(m.from, m.op);
        }
    }

    void leave(const QString &id)
    {
        joinerIds.removeAll(id);
        nodes.remove(id);
        for (auto &n : nodes)
            n.table.nodeLeft(id);
    }

    rp::Table &t(const QString &id) { return nodes[id].table; }
    QStringList &log(const QString &id) { return nodes[id].log; }

    struct Node {
        QString id;
        rp::Table table;
        QStringList log;
    };
    QStringList joinerIds;
    QHash<QString, Node> nodes;
    QList<Msg> queue;
    QStringList diags;
};

QVariantMap at(double x)
{
    return {{"x", x}};
}

} // namespace

class TestReplica : public QObject
{
    Q_OBJECT

private slots:
    void idsAreTheSpawnersAndNeverReused()
    {
        Net net({"A"});
        QStringList ids;
        for (int i = 0; i < 5; ++i) {
            const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
            QVERIFY(id.startsWith("A:"));
            QVERIFY(!ids.contains(id));
            ids.append(id);
            net.deliver();
            QVERIFY(net.t("A").despawn(id));
            net.deliver();
        }
        QCOMPARE(net.t("H").size(), 0);
        QCOMPARE(net.t("A").size(), 0);
    }

    void aSpawnReachesEveryNodeThroughTheHost()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {{"tint", "red"}}, {},
                                            rp::OwnerLeft::Despawn);
        // The spawner has it at once
        QVERIFY(net.t("A").find(id));
        QVERIFY(!net.t("B").find(id));
        net.deliver();
        for (const QString n : {"H", "A", "B"}) {
            const rp::Object *o = net.t(n).find(id);
            QVERIFY2(o, qPrintable(n));
            QCOMPARE(o->owner, QString("A"));
            QCOMPARE(o->type, QString("ball"));
            QCOMPARE(o->props.value("tint").toString(), QString("red"));
            QCOMPARE(net.log(n).count("spawn " + id), 1);
        }
    }

    void aSpawnTheHostDropsComesBackAsADespawn()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        QVERIFY(net.t("A").find(id));
        // On the way the spawn claims somebody else as its owner: the host
        // drops it, and the spawner's own copy goes
        net.deliver([](Msg &m) {
            if (m.op["op"].toString() == "spawn")
                m.op["owner"] = "B";
        });
        QVERIFY(!net.t("H").find(id));
        QVERIFY(!net.t("B").find(id));
        QVERIFY(!net.t("A").find(id));
        QCOMPARE(net.log("A"), QStringList({"spawn " + id, "despawn " + id}));
    }

    void aSpawnUnderAnotherNodesIdIsDropped()
    {
        Net net({"A", "B"});
        const QString bid = net.t("B").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        // A sends a spawn under an id of B's that lives: the live one stays
        net.t("H").receiveOp("A", rp::spawnOp({bid, "ball", "A"}, false));
        net.deliver();
        QCOMPARE(net.t("H").find(bid)->owner, QString("B"));
        QCOMPARE(net.t("B").find(bid)->owner, QString("B"));
        // ... and under one that never lived, it comes back as a despawn
        rp::Object forged;
        forged.id = "B:99";
        forged.type = "ball";
        forged.owner = "A";
        net.t("H").receiveOp("A", rp::spawnOp(forged, false));
        QVERIFY(!net.t("H").find("B:99"));
        QCOMPARE(net.queue.size(), 1);
        QCOMPARE(net.queue.first().to, QString("A"));
        QCOMPARE(net.queue.first().op["op"].toString(), QString("despawn"));
    }

    void stateFromAnyoneButTheOwnerIsDropped()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        // The host relays B's state as B's: B does not own it
        QVERIFY(!net.t("H").receiveState("B", "B", id, 5, at(9), 0, 0));
        QVERIFY(!net.t("A").receiveState("H", "B", id, 5, at(9), 0, 0));
        QVERIFY(net.t("B").receiveState("H", "A", id, 5, at(1), 0, 0));
        QCOMPARE(net.t("B").find(id)->state.value("x").toDouble(), 1.0);
        // The owner's own, sent by itself, is never taken back from others
        QVERIFY(!net.t("A").receiveState("H", "A", id, 6, at(2), 0, 0));
        // None of the dropped ones made a sequence entry
        QCOMPARE(net.t("H").trackedKeys(), 0);
        QCOMPARE(net.t("B").trackedKeys(), 1);
    }

    void aJoinerTakesObjectsOnlyFromItsHostLink()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        // Over a link to A itself - not the host's - nothing counts on B
        QVERIFY(!net.t("B").receiveState("A", "A", id, 3, at(1), 0, 0));
        net.t("B").receiveOp("A", rp::despawnOp(id));
        QVERIFY(net.t("B").find(id));
        // An operation relayed in someone else's name does not count either
        QJsonObject relayed = rp::despawnOp(id);
        relayed["from"] = "A";
        net.t("B").receiveOp("H", relayed);
        QVERIFY(net.t("B").find(id));
    }

    void aDespawnIsNeverUndoneByALateState()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        QVERIFY(net.t("B").receiveState("H", "A", id, 1, at(1), 0, 0));
        QVERIFY(net.t("A").despawn(id));
        // Until the host says so, it lives on the owner too
        QVERIFY(net.t("A").find(id));
        net.deliver();
        for (const QString n : {"H", "A", "B"})
            QVERIFY2(!net.t(n).find(id), qPrintable(n));
        // A newer state of it, overtaken by the despawn, arrives
        QVERIFY(!net.t("B").receiveState("H", "A", id, 2, at(2), 0, 0));
        QVERIFY(!net.t("H").receiveState("A", "A", id, 2, at(2), 0, 0));
        QVERIFY(!net.t("B").find(id));
        QCOMPARE(net.log("B").count("despawn " + id), 1);
        QCOMPARE(net.t("B").trackedKeys(), 0);
    }

    // The review of #355: a receiver keeps a sequence entry per sender and
    // key; objects come and go all the time, so a despawn frees its entry
    void spawnsAndDespawnsDoNotGrowTheSequenceTable()
    {
        Net net({"A", "B"});
        const QString keep = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        quint32 seq = 0;
        QVERIFY(net.t("B").receiveState("H", "A", keep, ++seq, at(0), 0, 0));
        QVERIFY(net.t("H").receiveState("A", "A", keep, seq, at(0), 0, 0));
        const int before = net.t("B").trackedKeys();
        QCOMPARE(before, 1);
        for (int i = 0; i < 1000; ++i) {
            const QString owner = (i % 2) ? "A" : "H";
            const QString id = net.t(owner).spawn("spark", {}, {}, rp::OwnerLeft::Despawn);
            net.deliver();
            ++seq;
            QVERIFY(net.t("B").receiveState("H", owner, id, seq, at(i), 0, 0));
            if (owner == "A")
                QVERIFY(net.t("H").receiveState("A", "A", id, seq, at(i), 0, 0));
            QVERIFY(net.t(owner).despawn(id));
            net.deliver();
            // Late states after the despawn make no entry either
            QVERIFY(!net.t("B").receiveState("H", owner, id, seq + 1, at(i), 0, 0));
        }
        QCOMPARE(net.t("B").trackedKeys(), before);
        QCOMPARE(net.t("H").trackedKeys(), 1);
        QCOMPARE(net.t("B").size(), 1);
    }

    void aLateJoinerGetsEveryObjectWithItsLastStateAndTheSession()
    {
        Net net({"A"});
        const QString mine = net.t("H").spawn("enemy", {{"spawnIndex", 3}}, {},
                                              rp::OwnerLeft::Despawn);
        const QString theirs = net.t("A").spawn("avatar", {{"token", "t-a"}}, {},
                                                rp::OwnerLeft::Host);
        const QString gone = net.t("A").spawn("spark", {}, {}, rp::OwnerLeft::Despawn);
        QVERIFY(net.t("H").setSessionProperty("seed", 42));
        QVERIFY(net.t("H").setSessionProperty("level", "crypt"));
        // A joiner's session property counts nowhere
        QVERIFY(!net.t("A").setSessionProperty("seed", 7));
        net.deliver();
        QVERIFY(net.t("H").sending(mine, at(10), 7, 100));
        QVERIFY(net.t("H").receiveState("A", "A", theirs, 4, at(20), 120, 0));
        QVERIFY(net.t("A").despawn(gone));
        net.deliver();

        net.joinerIds.append("C");
        net.add("C", false);
        net.t("H").admitted("C");
        net.deliver();

        rp::Table &c = net.t("C");
        QCOMPARE(c.size(), 2);
        QVERIFY(!c.find(gone));
        const rp::Object *e = c.find(mine);
        QVERIFY(e);
        QCOMPARE(e->owner, QString("H"));
        QCOMPARE(e->props.value("spawnIndex").toInt(), 3);
        QCOMPARE(e->state.value("x").toDouble(), 10.0);
        QCOMPARE(e->stateAt, 100.0);
        const rp::Object *a = c.find(theirs);
        QVERIFY(a);
        QCOMPARE(a->owner, QString("A"));
        QCOMPARE(a->onOwnerLeft, rp::OwnerLeft::Host);
        QCOMPARE(a->state.value("x").toDouble(), 20.0);
        QCOMPARE(c.sessionProperties().value("seed").toInt(), 42);
        QCOMPARE(c.sessionProperties().value("level").toString(), QString("crypt"));
        // An older lossy state still under way does not overwrite it
        QVERIFY(!c.receiveState("H", "A", theirs, 3, at(19), 110, 0));
        QVERIFY(c.receiveState("H", "A", theirs, 5, at(21), 130, 0));
    }

    void whenTheOwnerLeavesItsObjectsDespawnOrPassToTheHost()
    {
        Net net({"A", "B"});
        const QString avatar = net.t("A").spawn("avatar", {}, {}, rp::OwnerLeft::Despawn);
        const QString item = net.t("A").spawn("item", {}, {}, rp::OwnerLeft::Host);
        const QString other = net.t("B").spawn("avatar", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        net.leave("A");
        net.deliver();
        for (const QString n : {"H", "B"}) {
            QVERIFY2(!net.t(n).find(avatar), qPrintable(n));
            QVERIFY2(net.t(n).find(item), qPrintable(n));
            QCOMPARE(net.t(n).find(item)->owner, QString("H"));
            QCOMPARE(net.t(n).find(other)->owner, QString("B"));
        }
        // The host owns it now: its state counts, A's never again
        QVERIFY(net.t("H").sending(item, at(5), 1, 0));
        QVERIFY(net.t("B").receiveState("H", "H", item, 1, at(5), 0, 0));
    }

    void ownershipCanBeHandedOver()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        QVERIFY(net.t("B").receiveState("H", "A", id, 50, at(1), 0, 0));
        // Neither a stranger's request nor one from a non-owner counts
        QVERIFY(!net.t("B").setOwner(id, "B"));
        QVERIFY(!net.t("A").setOwner(id, "Z"));
        // The owner hands it to B; on A it takes effect with the host's word
        QVERIFY(net.t("A").setOwner(id, "B"));
        QCOMPARE(net.t("A").find(id)->owner, QString("A"));
        net.deliver();
        for (const QString n : {"H", "A", "B"})
            QCOMPARE(net.t(n).find(id)->owner, QString("B"));
        QVERIFY(!net.t("A").sending(id, at(2), 51, 0));
        QVERIFY(net.t("B").sending(id, at(2), 3, 0));
        // B counts on its own, lower sequence; A's states are dropped now
        QVERIFY(net.t("H").receiveState("B", "B", id, 3, at(2), 0, 0));
        QVERIFY(!net.t("H").receiveState("A", "A", id, 52, at(9), 0, 0));
        // The host can hand it on too
        QVERIFY(net.t("H").setOwner(id, "A"));
        net.deliver();
        QCOMPARE(net.t("B").find(id)->owner, QString("A"));
        QCOMPARE(net.log("B").count("owner " + id + " A"), 1);
    }

    void aSettledStateArrivesReliablyAndOutranksOlderLossyOnes()
    {
        Net net({"A", "B"});
        const QString id = net.t("A").spawn("ball", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        // A's last lossy state (seq 9) is lost; it settles with seq 10
        QVERIFY(net.t("A").sending(id, at(9), 10, 200));
        net.queue.append({"A", "H", rp::stateOp(id, at(9), 10, 200)});
        net.deliver();
        QCOMPARE(net.t("H").find(id)->state.value("x").toDouble(), 9.0);
        QCOMPARE(net.t("B").find(id)->state.value("x").toDouble(), 9.0);
        QVERIFY(net.log("B").contains("state " + id + " 9"));
        // The lost one turns up after all: too old
        QVERIFY(!net.t("B").receiveState("H", "A", id, 9, at(8), 190, 0));
        // A settled state from a non-owner goes nowhere
        net.queue.append({"B", "H", rp::stateOp(id, at(99), 11, 300)});
        net.deliver();
        QCOMPARE(net.t("H").find(id)->state.value("x").toDouble(), 9.0);
    }

    void theEndOfTheNetworkDespawnsEverything()
    {
        Net net({"A"});
        const QString a = net.t("H").spawn("enemy", {}, {}, rp::OwnerLeft::Despawn);
        const QString b = net.t("A").spawn("avatar", {}, {}, rp::OwnerLeft::Despawn);
        net.deliver();
        net.log("A").clear();
        net.t("A").reset();
        QCOMPARE(net.t("A").size(), 0);
        QVERIFY(!net.t("A").active());
        QCOMPARE(net.log("A").size(), 2);
        QVERIFY(net.log("A").contains("despawn " + a));
        QVERIFY(net.log("A").contains("despawn " + b));
        QVERIFY(net.t("A").spawn("x", {}, {}, rp::OwnerLeft::Despawn).isEmpty());
    }

    void onlyTheHostSpawnsForAnotherNode()
    {
        Net net({"A", "B"});
        QVERIFY(net.t("A").spawn("ball", {}, "B", rp::OwnerLeft::Despawn).isEmpty());
        QVERIFY(net.t("H").spawn("ball", {}, "Z", rp::OwnerLeft::Despawn).isEmpty());
        const QString id = net.t("H").spawn("ball", {}, "B", rp::OwnerLeft::Despawn);
        QVERIFY(id.startsWith("H:"));
        net.deliver();
        QCOMPARE(net.t("B").find(id)->owner, QString("B"));
        QVERIFY(net.t("B").sending(id, at(1), 1, 0));
    }
};

QTEST_GUILESS_MAIN(TestReplica)
#include "tst_replica.moc"
