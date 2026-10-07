// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QRandomGenerator>
#include <cmath>
#include "sessionclock.h"

namespace sc = clay::network::sessionclock;

// The session clock (#304) on simulated links: each node has its own
// local clock (another origin), a ping's legs take latencyMs plus a random
// 0..jitterMs like the link conditioner's, and the host answers at once.
class TestSessionClock : public QObject
{
    Q_OBJECT

private slots:
    void testHostClockStartsAtZero();
    void testNoSessionTimeBeforeStartOrSeed();
    void testSeedIsOffByTheWelcomesTransit();
    void testSyncedOnceEnoughSamplesAreIn();
    void testJoinersAgreeWithin10msUnder100pm20Jitter();
    void testSlowLegDoesNotBiasTheEstimate();
    void testSyncedClockSlewsAndNeverStepsBack();
    void testHostIgnoresSamples();
    void testTransitIsTheFastestOfTheWindow();
    void testTransitFollowsTheClockOffset();
    void testTransitOfUnknownSenderIsNaN();
    void testTransitMatchesAScanOfTheWindow();
};

namespace {

struct Leg { double latency; double jitter; };

// One joiner's clock run through a burst of pings to the host. hostAt(t)
// is the host's session time at true time t, the joiner's local clock is
// t + localOrigin. Returns the joiner's error (its session time minus the
// host's) right after the burst.
double syncError(QRandomGenerator &rng, double localOrigin, Leg leg, int pings = sc::kBurstPings)
{
    sc::Clock clock;
    const double hostStart = 1000.0;  // true time the host created the network
    auto hostAt = [&](double t) { return t - hostStart; };
    double t = 5000.0;
    for (int i = 0; i < pings; ++i) {
        const double up = leg.latency + std::floor(rng.generateDouble() * (leg.jitter + 1));
        const double down = leg.latency + std::floor(rng.generateDouble() * (leg.jitter + 1));
        const double sent = t + localOrigin;
        const double st = hostAt(t + up);
        clock.sample(sent, st, t + up + down + localOrigin);
        t += sc::kBurstIntervalMs;
    }
    t += 300;
    return clock.time(t + localOrigin) - hostAt(t);
}

} // namespace

void TestSessionClock::testHostClockStartsAtZero()
{
    sc::Clock host;
    host.start(12345.0);
    QVERIFY(host.valid());
    QVERIFY(host.synced());
    QCOMPARE(host.time(12345.0), 0.0);
    QCOMPARE(host.time(13345.5), 1000.5);
}

void TestSessionClock::testNoSessionTimeBeforeStartOrSeed()
{
    sc::Clock clock;
    QVERIFY(!clock.valid());
    QCOMPARE(clock.time(500.0), -1.0);
    clock.start(100.0);
    clock.reset();
    QCOMPARE(clock.time(500.0), -1.0);
}

void TestSessionClock::testSeedIsOffByTheWelcomesTransit()
{
    // The welcome left the host at session 2000 and took 90 ms
    sc::Clock clock;
    clock.seed(2000.0, 70000.0 + 90.0);
    QVERIFY(clock.valid());
    QVERIFY(!clock.synced());
    QCOMPARE(clock.time(70090.0), 2000.0);  // the host is at 2090 by then
}

void TestSessionClock::testSyncedOnceEnoughSamplesAreIn()
{
    sc::Clock clock;
    clock.seed(0.0, 0.0);
    int becameSynced = 0;
    double sent = 0;
    for (int i = 0; i < sc::kWindow; ++i, sent += 50.0) {
        QCOMPARE(clock.synced(), i >= sc::kSyncedAfter);
        if (clock.sample(sent, sent + 100.0, sent + 200.0))
            ++becameSynced;
    }
    QVERIFY(clock.synced());
    QCOMPARE(becameSynced, 1);
    QCOMPARE(clock.sampleCount(), sc::kWindow);
    // More samples keep the window at its size
    clock.sample(sent, sent + 100.0, sent + 200.0);
    QCOMPARE(clock.sampleCount(), sc::kWindow);
    // A minute later the old ones are gone, down to the fewest kept
    sent += sc::kMaxSampleAgeMs + 1000.0;
    clock.sample(sent, sent + 100.0, sent + 200.0);
    QCOMPARE(clock.sampleCount(), sc::kMinKept);
    QVERIFY(clock.synced());
}

void TestSessionClock::testJoinersAgreeWithin10msUnder100pm20Jitter()
{
    // 100 +- 20 ms each way, as the net gym's link conditioner sets it:
    // 80 ms plus a random 0..40. Two joiners with their own clocks sync
    // to the host; their session times may differ by 10 ms at most.
    QRandomGenerator rng(304);
    const Leg leg{80.0, 40.0};
    double worstPair = 0;
    double worstOne = 0;
    double sumAbs = 0;
    const int trials = 500;
    for (int i = 0; i < trials; ++i) {
        const double a = syncError(rng, 123456.7, leg);
        const double b = syncError(rng, -98765.4, leg);
        worstPair = std::max(worstPair, std::abs(a - b));
        worstOne = std::max({worstOne, std::abs(a), std::abs(b)});
        sumAbs += std::abs(a) + std::abs(b);
    }
    qInfo("over %d pairs: worst pair %.2f ms, worst joiner %.2f ms, mean |error| %.2f ms",
          trials, worstPair, worstOne, sumAbs / (2 * trials));
    QVERIFY2(worstPair <= 10.0, qPrintable(QString::number(worstPair)));
}

void TestSessionClock::testSlowLegDoesNotBiasTheEstimate()
{
    // Every third pong is held back 150 ms (a leg queued behind something
    // on the ordered channel): only slow round trips, the fast half decides
    sc::Clock clock;
    const double origin = 4242.0;  // joiner local = true time + origin
    for (int i = 0; i < sc::kWindow; ++i) {
        const double t = i * 50.0;
        const double down = (i % 3 == 0) ? 250.0 : 100.0;
        clock.sample(t + origin, t + 100.0, t + 100.0 + down + origin);
    }
    QVERIFY(clock.synced());
    const double t = 3000.0;
    QCOMPARE(clock.time(t + origin), t);
}

void TestSessionClock::testSyncedClockSlewsAndNeverStepsBack()
{
    // Samples are taken when the pong arrives, at the clock's now
    sc::Clock clock;
    double t = 100.0;
    for (int i = 0; i < sc::kWindow; ++i, t += 50.0)
        clock.sample(t - 100.0, t - 50.0, t);  // offset exactly 0
    QVERIFY(clock.synced());
    QCOMPARE(clock.time(t), t);

    // The host's clock is now 40 ms behind: the window turns over to the
    // new offset, and the clock follows it without stepping back
    double last = clock.time(t);
    double worstStep = 1e9;
    for (int i = 0; i < 2 * sc::kWindow; ++i) {
        clock.sample(t - 100.0, t - 50.0 - 40.0, t);
        for (int k = 0; k < 10; ++k) {
            t += 10.0;
            const double now = clock.time(t);
            worstStep = std::min(worstStep, now - last);
            last = now;
        }
    }
    QVERIFY2(worstStep >= 10.0 * (1.0 - sc::kSlewRate) - 1e-9,
             qPrintable(QString("a 10 ms step moved the clock by %1 ms").arg(worstStep)));
    QCOMPARE(clock.time(t), t - 40.0);
}

void TestSessionClock::testHostIgnoresSamples()
{
    sc::Clock host;
    host.start(0.0);
    QVERIFY(!host.sample(100.0, 9999.0, 200.0));
    host.seed(9999.0, 300.0);
    QCOMPARE(host.time(300.0), 300.0);
}

void TestSessionClock::testTransitIsTheFastestOfTheWindow()
{
    sc::TransitTracker tr;
    // local == session here (offset 0)
    tr.note("a", 1000.0, 1090.0);
    tr.note("a", 1050.0, 1130.0);  // 80 ms, the fastest
    tr.note("a", 1100.0, 1210.0);
    QCOMPARE(tr.transit("a", 0.0), 80.0);
    // The 80 ms arrival leaves the 3 s window, the newest stays
    tr.note("a", 4200.0, 4300.0);
    QCOMPARE(tr.transit("a", 0.0), 100.0);
    // A send time below zero (none given) is not a transit
    tr.note("a", -1.0, 4400.0);
    QCOMPARE(tr.transit("a", 0.0), 100.0);
}

void TestSessionClock::testTransitFollowsTheClockOffset()
{
    // Stored against the local clock: an offset learnt after the arrival
    // still applies to it
    sc::TransitTracker tr;
    tr.note("a", 500.0, 10600.0);  // local 10600 = session 600 at offset -10000
    QCOMPARE(tr.transit("a", -10000.0), 100.0);
    QCOMPARE(tr.transit("a", -10010.0), 90.0);
}

void TestSessionClock::testTransitOfUnknownSenderIsNaN()
{
    sc::TransitTracker tr;
    QVERIFY(std::isnan(tr.transit("x", 0.0)));
    tr.note("x", 0.0, 50.0);
    tr.forget("x");
    QVERIFY(std::isnan(tr.transit("x", 0.0)));
}

void TestSessionClock::testTransitMatchesAScanOfTheWindow()
{
    // The sliding minimum (#305) against the fastest arrival of the last
    // 3 s found by scanning them all, after every arrival of a stream at
    // 20 Hz with 0..150 ms jitter, a stall now and then, and two senders
    sc::TransitTracker tr;
    QRandomGenerator rng(305);
    struct A { double at; double raw; };
    std::deque<A> all[2];
    const QString ids[2] = {"a", "b"};
    double now = 1000.0;
    for (int n = 0; n < 5000; ++n) {
        now += rng.bounded(100) < 2 ? 3500.0 : 25.0;
        const int s = rng.bounded(2);
        const double sentAt = now - 40.0 - rng.bounded(150.0);
        tr.note(ids[s], sentAt, now);
        all[s].push_back({now, now - sentAt});
        while (all[s].size() > 1 && all[s].front().at < now - sc::kTransitWindowMs)
            all[s].pop_front();
        double best = all[s].front().raw;
        for (const A &a : all[s])
            best = std::min(best, a.raw);
        QCOMPARE(tr.transit(ids[s], 7.0), best + 7.0);
    }
}

QTEST_GUILESS_MAIN(TestSessionClock)
#include "tst_session_clock.moc"
