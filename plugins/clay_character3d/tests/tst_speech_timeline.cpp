// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit tests for Speech::timelineForText - the pure text -> viseme
// timeline builder used for lip-sync - and for the two things a cue
// scheduler needs from the engine around it: an exposed duration, and a
// say() that always reports the end of the line it started.
//
// Built without CLAY_CHARACTER3D_HAS_TTS (see tests/CMakeLists.txt), so the
// engine runs its silent path here: timings come from the timeline, not from
// a speech engine that may or may not exist on the machine.

#include <QtTest>
#include <QSignalSpy>
#include "speech.h"

class TestSpeechTimeline : public QObject
{
    Q_OBJECT

private slots:
    void emptyTextYieldsClosedMouth();
    void keysAreMonotonicAndBounded();
    void vowelsOpenTheMouth();
    void bilabialsCloseTheMouth();
    void digraphsProduceSingleKey();
    void punctuationAddsPauses();
    void wordMarksMatchWordStarts();
    void paceScaleStretchesTimeline();

    void estimateMatchesTheTimeline();
    void estimateFollowsTheRate();
    void emptyLineStillFinishes();
    void emptyLineFinishesLater();
    void lastSayOfATickWins();
};

void TestSpeechTimeline::emptyTextYieldsClosedMouth()
{
    const VisemeTimeline tl = Speech::timelineForText("");
    QCOMPARE(tl.keys.size(), 1);
    QCOMPARE(tl.keys.first().open, 0.f);
    QCOMPARE(tl.durationMs, 0);
}

void TestSpeechTimeline::keysAreMonotonicAndBounded()
{
    const VisemeTimeline tl =
        Speech::timelineForText("Hello world, how are you today?");
    QVERIFY(tl.keys.size() > 10);
    qint64 prev = -1;
    for (const VisemeKey &k : tl.keys) {
        QVERIFY(k.ms >= prev);
        prev = k.ms;
        QVERIFY(k.open >= 0.f && k.open <= 1.f);
        QVERIFY(k.wide >= 0.f && k.wide <= 1.f);
        QVERIFY(k.round >= 0.f && k.round <= 1.f);
    }
    QCOMPARE(tl.keys.last().open, 0.f);
    QVERIFY(tl.durationMs >= tl.keys.last().ms);
}

void TestSpeechTimeline::vowelsOpenTheMouth()
{
    const VisemeTimeline tl = Speech::timelineForText("a");
    QVERIFY(tl.keys.first().open > 0.7f);
}

void TestSpeechTimeline::bilabialsCloseTheMouth()
{
    const VisemeTimeline tl = Speech::timelineForText("m");
    QVERIFY(tl.keys.first().open < 0.1f);
}

void TestSpeechTimeline::digraphsProduceSingleKey()
{
    // "oo" must collapse into one rounded viseme, not two 'o' keys.
    const VisemeTimeline oo = Speech::timelineForText("oo");
    QCOMPARE(oo.keys.size(), 2); // digraph key + final closing key
    QVERIFY(oo.keys.first().round > 0.8f);

    const VisemeTimeline o = Speech::timelineForText("o");
    QCOMPARE(o.keys.size(), 2);
}

void TestSpeechTimeline::punctuationAddsPauses()
{
    const VisemeTimeline plain = Speech::timelineForText("ha ha");
    const VisemeTimeline paused = Speech::timelineForText("ha. ha");
    QVERIFY(paused.durationMs > plain.durationMs + 200);
}

void TestSpeechTimeline::wordMarksMatchWordStarts()
{
    const QString text = "hi there friend";
    const VisemeTimeline tl = Speech::timelineForText(text);
    QCOMPARE(tl.wordMarks.size(), 3);
    QCOMPARE(tl.wordMarks.at(0).first, qsizetype(0));
    QCOMPARE(tl.wordMarks.at(1).first, qsizetype(3));
    QCOMPARE(tl.wordMarks.at(2).first, qsizetype(9));
    // Later words start later on the timeline
    QVERIFY(tl.wordMarks.at(1).second > tl.wordMarks.at(0).second);
    QVERIFY(tl.wordMarks.at(2).second > tl.wordMarks.at(1).second);
}

void TestSpeechTimeline::paceScaleStretchesTimeline()
{
    const VisemeTimeline fast = Speech::timelineForText("hello world", 0.6);
    const VisemeTimeline slow = Speech::timelineForText("hello world", 1.6);
    QVERIFY(slow.durationMs > fast.durationMs);
}

// The number a scheduler asks for must be the number the mouth is driven by.
// Two estimates of one line is the bug this exposure exists to delete.
void TestSpeechTimeline::estimateMatchesTheTimeline()
{
    Speech s;
    const QString text = "Hello world, how are you today?";
    QCOMPARE(qint64(s.estimateDurationMs(text)),
             Speech::timelineForText(text, 1.0).durationMs);
    QCOMPARE(s.estimateDurationMs(QString()), 0);
}

void TestSpeechTimeline::estimateFollowsTheRate()
{
    Speech s;
    const QString text = "Hello world";
    const int normal = s.estimateDurationMs(text);
    s.setRate(1.0);
    const int fast = s.estimateDurationMs(text);
    s.setRate(-1.0);
    const int slow = s.estimateDurationMs(text);
    QVERIFY(fast < normal);
    QVERIFY(slow > normal);
}

// A queue whose only advance trigger is finished() hangs forever on a line
// that never reports one. An empty line is exactly that case, and a directive
// producing a text-less segment makes it reachable.
void TestSpeechTimeline::emptyLineStillFinishes()
{
    Speech s;
    QSignalSpy started(&s, &Speech::started);
    QSignalSpy finished(&s, &Speech::finished);

    s.say(QStringLiteral("   "));
    QCOMPARE(finished.count(), 0); // never re-entrant into the caller

    QVERIFY(finished.wait(2000));
    QCOMPARE(started.count(), 1);
    QCOMPARE(finished.count(), 1);
    QVERIFY(!s.speaking());
}

void TestSpeechTimeline::emptyLineFinishesLater()
{
    Speech s;
    QSignalSpy finished(&s, &Speech::finished);
    s.sayText(QString());
    QVERIFY(finished.wait(2000));
    QCOMPARE(finished.count(), 1);
}

// Two say() calls in one tick: the second line is the one that runs, and it
// is the only one that reports anything. The dropped line must not emit a
// finished() of its own - a scheduler would read that as its new line ending
// and advance a cue too early.
void TestSpeechTimeline::lastSayOfATickWins()
{
    Speech s;
    QSignalSpy started(&s, &Speech::started);
    QSignalSpy finished(&s, &Speech::finished);

    s.sayText(QStringLiteral("one"));
    s.sayText(QStringLiteral("two"));

    QVERIFY(started.wait(2000));
    QCOMPARE(started.count(), 1);
    QCOMPARE(finished.count(), 0);
    QVERIFY(s.speaking());
    // The line that survived decides the duration.
    QCOMPARE(qint64(s.durationMs()), Speech::timelineForText("two", 1.0).durationMs);

    QVERIFY(finished.wait(5000));
    QCOMPARE(finished.count(), 1);
    QCOMPARE(started.count(), 1);
    QVERIFY(!s.speaking());
}

QTEST_GUILESS_MAIN(TestSpeechTimeline)
#include "tst_speech_timeline.moc"
