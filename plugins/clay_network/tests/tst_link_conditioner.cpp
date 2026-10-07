// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The native link conditioner (#301) on a test clock: what each condition
// does to a packet, and that reliable packets are never lost or reordered.
// link_conditioner.test.js checks the browser's twin against the same cases.

#include <QtTest>
#include "link_conditioner.h"

using clay::network::LinkConditioner;

namespace {
constexpr auto Out = LinkConditioner::Outgoing;
constexpr auto In = LinkConditioner::Incoming;
}

class TestLinkConditioner : public QObject
{
    Q_OBJECT

    qint64 t_ = 0;
    QList<double> randoms_;
    int nextRandom_ = 0;

    // A conditioner on the test clock; random() replays randoms_ in a loop
    std::unique_ptr<LinkConditioner> make()
    {
        auto c = std::make_unique<LinkConditioner>();
        c->setClock([this]() { return t_; });
        c->setRandom([this]() {
            if (randoms_.isEmpty()) return 0.5;
            return randoms_.at(nextRandom_++ % randoms_.size());
        });
        return c;
    }

    void advance(LinkConditioner &c, qint64 toMs)
    {
        t_ = toMs;
        c.pump(t_);
    }

private slots:
    void init()
    {
        t_ = 1000;
        randoms_.clear();
        nextRandom_ = 0;
    }

    void cleanLinkDeliversInsideOffer()
    {
        auto c = make();
        QVERIFY(!c->active());
        int got = 0;
        c->offer(Out, true, 100, [&]() { ++got; });
        c->offer(In, false, 100, [&]() { ++got; });
        QCOMPARE(got, 2);
    }

    void conditionsAreClamped()
    {
        auto c = make();
        c->setConditions({{"loss", 3.0}, {"latencyMs", -5}, {"jitterMs", 10},
                          {"bandwidthKbps", -1}, {"blackout", true}, {"bogus", 1}});
        const QVariantMap m = c->conditions();
        QCOMPARE(m.value("loss").toDouble(), 1.0);
        QCOMPARE(m.value("latencyMs").toInt(), 0);
        QCOMPARE(m.value("jitterMs").toInt(), 10);
        QCOMPARE(m.value("bandwidthKbps").toInt(), 0);
        QCOMPARE(m.value("blackout").toBool(), true);
        QCOMPARE(m.value("dropSignaling").toBool(), false);
        QVERIFY(!m.contains("bogus"));
    }

    void latencyDelaysEveryPacket()
    {
        auto c = make();
        c->setConditions({{"latencyMs", 80}});
        QList<qint64> at;
        c->offer(Out, true, 10, [&]() { at << t_; });
        c->offer(In, false, 10, [&]() { at << t_; });
        advance(*c, 1079);
        QVERIFY(at.isEmpty());
        advance(*c, 1080);
        QCOMPARE(at, (QList<qint64>{1080, 1080}));
    }

    void lossDropsStateOnly()
    {
        auto c = make();
        // every 10th draw is below 0.1
        randoms_ = {0.05, 0.5, 0.6, 0.7, 0.8, 0.9, 0.2, 0.3, 0.4, 0.95};
        c->setConditions({{"loss", 0.1}});
        int state = 0, reliable = 0;
        for (int i = 0; i < 1000; ++i) {
            c->offer(Out, true, 10, [&]() { ++state; });
            c->offer(Out, false, 10, [&]() { ++reliable; });
        }
        advance(*c, 1001);
        QCOMPARE(state, 900);
        QCOMPARE(reliable, 1000);
        QCOMPARE(c->droppedCount(), 100);
    }

    void totalLossNeverTouchesReliable()
    {
        auto c = make();
        c->setConditions({{"loss", 1.0}});
        int state = 0, reliable = 0;
        for (int i = 0; i < 50; ++i) {
            c->offer(In, true, 10, [&]() { ++state; });
            c->offer(In, false, 10, [&]() { ++reliable; });
        }
        advance(*c, 1001);
        QCOMPARE(state, 0);
        QCOMPARE(reliable, 50);
    }

    void jitterReordersStateButNotReliable()
    {
        auto c = make();
        // first packet draws the most jitter, the last the least
        randoms_ = {0.99, 0.5, 0.0};
        c->setConditions({{"latencyMs", 50}, {"jitterMs", 100}});
        QList<int> state, reliable;
        for (int i = 0; i < 3; ++i)
            c->offer(Out, true, 10, [&state, i]() { state << i; });
        nextRandom_ = 0;
        for (int i = 0; i < 3; ++i)
            c->offer(Out, false, 10, [&reliable, i]() { reliable << i; });
        advance(*c, 1200);
        QCOMPARE(state, (QList<int>{2, 1, 0}));
        QCOMPARE(reliable, (QList<int>{0, 1, 2}));
    }

    void jitterStaysWithinBounds()
    {
        auto c = make();
        randoms_ = {0.0, 0.999999};
        c->setConditions({{"latencyMs", 100}, {"jitterMs", 20}});
        QList<qint64> at;
        c->offer(Out, true, 10, [&]() { at << t_; });
        c->offer(Out, true, 10, [&]() { at << t_; });
        for (qint64 ms = 1000; ms <= 1200; ++ms)
            advance(*c, ms);
        QCOMPARE(at, (QList<qint64>{1100, 1120}));
    }

    void bandwidthSpacesPacketsPerDirection()
    {
        auto c = make();
        // 1000 bytes at 80 kbit/s = 100 ms on the link each
        c->setConditions({{"bandwidthKbps", 80}, {"latencyMs", 10}});
        QList<qint64> out, in;
        for (int i = 0; i < 3; ++i) {
            c->offer(Out, i % 2 == 0, 1000, [&]() { out << t_; });
            c->offer(In, false, 1000, [&]() { in << t_; });
        }
        for (qint64 ms = 1000; ms <= 1400; ++ms)
            advance(*c, ms);
        QCOMPARE(out, (QList<qint64>{1110, 1210, 1310}));
        QCOMPARE(in, (QList<qint64>{1110, 1210, 1310}));
    }

    void blackoutDropsStateAndHoldsReliable()
    {
        auto c = make();
        c->setConditions({{"latencyMs", 20}, {"blackout", true}});
        QList<int> reliable;
        int state = 0;
        for (int i = 0; i < 5; ++i) {
            c->offer(Out, true, 10, [&]() { ++state; });
            c->offer(Out, false, 10, [&reliable, i]() { reliable << i; });
        }
        advance(*c, 3000);
        QCOMPARE(state, 0);
        QVERIFY(reliable.isEmpty());
        QCOMPARE(c->heldCount(), 5);
        QCOMPARE(c->droppedCount(), 5);

        // the link comes back: held ones go out in order, after the latency
        c->setConditions({{"latencyMs", 20}});
        c->offer(Out, false, 10, [&reliable]() { reliable << 5; });
        advance(*c, 3019);
        QVERIFY(reliable.isEmpty());
        advance(*c, 3020);
        QCOMPARE(reliable, (QList<int>{0, 1, 2, 3, 4, 5}));
    }

    void reliableKeepsOrderWhenConditionsClear()
    {
        auto c = make();
        c->setConditions({{"latencyMs", 100}});
        QList<int> got;
        c->offer(In, false, 10, [&]() { got << 0; });
        c->setConditions({});
        // still behind the first one, although the link is clean now
        c->offer(In, false, 10, [&]() { got << 1; });
        QVERIFY(got.isEmpty());
        advance(*c, 1100);
        QCOMPARE(got, (QList<int>{0, 1}));
        // and with nothing under way, delivery is immediate again
        c->offer(In, false, 10, [&]() { got << 2; });
        QCOMPARE(got, (QList<int>{0, 1, 2}));
    }

    void deliveryMayOfferAgain()
    {
        auto c = make();
        c->setConditions({{"latencyMs", 30}});
        QList<qint64> at;
        // a ping that is answered: the answer takes the link again
        c->offer(In, false, 10, [&]() {
            at << t_;
            c->offer(Out, false, 10, [&]() { at << t_; });
        });
        advance(*c, 1030);
        advance(*c, 1060);
        QCOMPARE(at, (QList<qint64>{1030, 1060}));
    }

    void clearForgetsEverything()
    {
        auto c = make();
        c->setConditions({{"latencyMs", 30}});
        int got = 0;
        c->offer(Out, false, 10, [&]() { ++got; });
        c->setConditions({{"blackout", true}});
        c->offer(Out, false, 10, [&]() { ++got; });
        c->clear();
        c->setConditions({});
        advance(*c, 5000);
        QCOMPARE(got, 0);
    }

    void dropSignalingIsReported()
    {
        auto c = make();
        QVERIFY(!c->dropSignaling());
        c->setConditions({{"dropSignaling", true}});
        QVERIFY(c->dropSignaling());
        // it conditions no data channel traffic by itself
        QVERIFY(!c->active());
    }

    // The real timer, not the test clock: a delayed packet arrives on its own
    void realTimerDelivers()
    {
        LinkConditioner c;
        c.setConditions({{"latencyMs", 40}});
        QElapsedTimer since;
        since.start();
        qint64 tookMs = -1;
        c.offer(Out, true, 10, [&]() { tookMs = since.elapsed(); });
        QTRY_VERIFY_WITH_TIMEOUT(tookMs >= 0, 2000);
        QVERIFY2(tookMs >= 39, qPrintable(QString::number(tookMs)));
    }
};

QTEST_GUILESS_MAIN(TestLinkConditioner)
#include "tst_link_conditioner.moc"
