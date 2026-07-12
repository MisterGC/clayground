// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit tests for Speech::timelineForText - the pure text -> viseme
// timeline builder used for lip-sync.

#include <QtTest>
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

QTEST_GUILESS_MAIN(TestSpeechTimeline)
#include "tst_speech_timeline.moc"
