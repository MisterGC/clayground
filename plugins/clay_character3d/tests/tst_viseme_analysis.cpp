// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Unit tests for the spectral lip-sync analyser.
//
// The point of these is that formant thresholds decay into magic constants
// the moment nobody can say what they were for. So the input here is
// synthesised rather than recorded: a vowel is a pair of formants over a
// glottal buzz, and the test asserts the thing the number was chosen to do -
// a low F1 with a high F2 is "ee" and must come out spread, whatever else
// changes underneath.
//
// Synthesis is deliberately crude - summed harmonics weighted by a resonance
// curve, no vocal tract model. It only has to put energy where a real vowel
// puts energy, because band ratios are all the analyser reads.

#include <QtTest>
#include <QtMath>

#include "visemeanalysis.h"

using namespace ClayViseme;

namespace {

constexpr int RATE = 22050;

// A buzz at f0 with two formant resonances, which is what the band ratios
// are actually looking at.
QVector<float> vowel(float f0, float f1, float f2, int ms, int rate = RATE)
{
    const int n = rate * ms / 1000;
    QVector<float> out(n, 0.f);
    for (int h = 1; h * f0 < rate / 2 - 1; ++h) {
        const float f = h * f0;
        auto reson = [f](float centre, float bw) {
            const float d = (f - centre) / bw;
            return 1.f / (1.f + d * d);
        };
        // 1/h rolloff for the source, shaped by the two resonances.
        const float a = (1.f / h) * (reson(f1, 90.f) + reson(f2, 130.f) + 0.02f);
        const float w = 2.f * float(M_PI) * f / rate;
        for (int i = 0; i < n; ++i)
            out[i] += a * float(qSin(w * i));
    }
    float peak = 0.f;
    for (float s : out)
        peak = qMax(peak, qAbs(s));
    if (peak > 0.f)
        for (float &s : out)
            s /= peak;
    return out;
}

// Deterministic broadband noise - a fricative, as far as a band ratio cares.
QVector<float> hiss(int ms, int rate = RATE)
{
    const int n = rate * ms / 1000;
    QVector<float> out(n);
    quint32 seed = 0x12345678u;
    float prev = 0.f;
    for (int i = 0; i < n; ++i) {
        seed = seed * 1664525u + 1013904223u;
        const float white = float((seed >> 8) % 20001) / 10000.f - 1.f;
        // High-passed: an /s/ is energy above 4 kHz, not everywhere.
        out[i] = white - prev * 0.85f;
        prev = white;
    }
    return out;
}

QVector<float> silence(int ms, int rate = RATE)
{
    return QVector<float>(rate * ms / 1000, 0.f);
}

QVector<float> operator+(QVector<float> a, const QVector<float> &b)
{
    a.append(b);
    return a;
}

// The mean of a field over the loud frames - the quiet ones carry no shape
// and averaging them in only measures the silence.
template <typename F>
float meanLoud(const QVector<Frame> &frames, F field)
{
    float sum = 0.f;
    int n = 0;
    for (const Frame &f : frames) {
        if (f.level > 0.5f) {
            sum += field(f);
            ++n;
        }
    }
    return n ? sum / n : 0.f;
}

// Frames built by hand rather than measured. Alignment does not care where
// the numbers came from, and a test that has to synthesise convincing audio
// to check a dynamic program is testing the wrong thing.
QVector<Frame> flatFrames(int count, float level, float openness,
                          float frontness = 0.5f, int hopMs = 16)
{
    QVector<Frame> out;
    for (int i = 0; i < count; ++i) {
        Frame f;
        f.ms = qint64(i) * hopMs;
        f.level = level;
        f.openness = openness;
        f.frontness = frontness;
        f.fricness = 0.f;
        f.confidence = 1.f;
        out.append(f);
    }
    return out;
}

VisemeTimeline scriptOf(const QVector<VisemeKey> &keys)
{
    VisemeTimeline tl;
    tl.keys = keys;
    tl.durationMs = keys.isEmpty() ? 0 : keys.last().ms;
    return tl;
}

} // namespace

class TestVisemeAnalysis : public QObject
{
    Q_OBJECT

private slots:
    void emptyInputYieldsNothing();
    void tooShortForOneFrameYieldsNothing();
    void framesAreMonotonicAndBounded();

    void openVowelOpensWiderThanClosedVowel();
    void frontVowelSpreads();
    void backVowelRounds();
    void openBackVowelIsOpenNotRounded();
    void wideAndRoundAreNeverBothOn();
    void fricativeIsNarrowNotOpen();
    void silenceClosesTheMouth();

    void resultIsIndependentOfSampleRate();
    void resultIsIndependentOfPitch();
    void resultIsIndependentOfLevel();

    void lowConfidenceFallsBackToTheEnvelope();
    void timelineIsMonotonicAndEndsClosed();

    void alignRejectsATranscriptOfTheWrongLength();
    void alignRejectsInputTooSmallToAlign();
    void alignRejectsATableTooLargeToBeWorthIt();
    void alignKeepsAClosureTheAudioCannotSee();
    void alignTakesItsClockFromTheAudio();
    void alignKeysAreStrictlyMonotonic();
    void alignCarriesWordMarksOntoTheRecording();
    void alignFindsTheSecondSyllableAfterThePause();
    void alignLetsLoudnessSetEmphasis();
};

void TestVisemeAnalysis::emptyInputYieldsNothing()
{
    QVERIFY(analyse(QVector<float>(), RATE).isEmpty());
    QVERIFY(timelineForSamples(QVector<float>(), RATE).keys.isEmpty());
}

void TestVisemeAnalysis::tooShortForOneFrameYieldsNothing()
{
    // Less than one FFT window of audio. An empty result is the contract:
    // the caller falls back to the envelope rather than showing a dead mouth.
    QVERIFY(analyse(vowel(120.f, 700.f, 1200.f, 5), RATE).isEmpty());
}

void TestVisemeAnalysis::framesAreMonotonicAndBounded()
{
    const auto f = analyse(vowel(120.f, 700.f, 1200.f, 400), RATE);
    QVERIFY(f.size() > 10);
    qint64 prev = -1;
    for (const Frame &x : f) {
        QVERIFY(x.ms > prev);
        prev = x.ms;
        QVERIFY(x.level >= 0.f && x.level <= 1.f);
        QVERIFY(x.openness >= 0.f && x.openness <= 1.f);
        QVERIFY(x.frontness >= 0.f && x.frontness <= 1.f);
        QVERIFY(x.fricness >= 0.f && x.fricness <= 1.f);
        QVERIFY(x.confidence >= 0.f && x.confidence <= 1.f);
    }
}

void TestVisemeAnalysis::openVowelOpensWiderThanClosedVowel()
{
    // /a/ has a high F1, /i/ a low one. That difference IS the jaw.
    const auto ah = analyse(vowel(120.f, 750.f, 1150.f, 400), RATE);
    const auto ee = analyse(vowel(120.f, 300.f, 2400.f, 400), RATE);
    const float a = meanLoud(ah, [](const Frame &f) { return f.openness; });
    const float e = meanLoud(ee, [](const Frame &f) { return f.openness; });
    QVERIFY2(a > e + 0.2f, qPrintable(QString("ah=%1 ee=%2").arg(a).arg(e)));

    const auto ahTl = timelineFromFrames(ah);
    const auto eeTl = timelineFromFrames(ee);
    float ao = 0.f, eo = 0.f;
    for (const auto &k : ahTl.keys) ao = qMax(ao, k.open);
    for (const auto &k : eeTl.keys) eo = qMax(eo, k.open);
    QVERIFY2(ao > eo, qPrintable(QString("open ah=%1 ee=%2").arg(ao).arg(eo)));
}

void TestVisemeAnalysis::frontVowelSpreads()
{
    const auto tl = timelineForSamples(vowel(120.f, 300.f, 2400.f, 400), RATE);
    float wide = 0.f, round = 0.f;
    for (const auto &k : tl.keys) {
        wide = qMax(wide, k.wide);
        round = qMax(round, k.round);
    }
    QVERIFY2(wide > 0.3f, qPrintable(QString("wide=%1").arg(wide)));
    QVERIFY2(round < 0.05f, qPrintable(QString("round=%1").arg(round)));
}

void TestVisemeAnalysis::backVowelRounds()
{
    // /u/: low F1, low F2. The shape the mouth could not previously make.
    const auto tl = timelineForSamples(vowel(120.f, 320.f, 800.f, 400), RATE);
    float wide = 0.f, round = 0.f;
    for (const auto &k : tl.keys) {
        wide = qMax(wide, k.wide);
        round = qMax(round, k.round);
    }
    QVERIFY2(round > 0.3f, qPrintable(QString("round=%1").arg(round)));
    QVERIFY2(wide < 0.05f, qPrintable(QString("wide=%1").arg(wide)));
}

void TestVisemeAnalysis::openBackVowelIsOpenNotRounded()
{
    // /a/ is a BACK vowel - its F2 sits about where /u/'s does - but it is
    // the widest-open shape there is, and a mouth that pouts through "ah" is
    // wrong in the most visible way available. Low F2 alone cannot mean
    // rounded; the jaw has to be closed too.
    const auto tl = timelineForSamples(vowel(120.f, 750.f, 1150.f, 400), RATE);
    float open = 0.f, round = 0.f;
    for (const auto &k : tl.keys) {
        open = qMax(open, k.open);
        round = qMax(round, k.round);
    }
    QVERIFY2(open > 0.7f, qPrintable(QString("open=%1").arg(open)));
    QVERIFY2(round < 0.25f, qPrintable(QString("round=%1").arg(round)));

    // And the close back vowel it must still be told apart from.
    const auto oo = timelineForSamples(vowel(120.f, 320.f, 800.f, 400), RATE);
    float ooRound = 0.f;
    for (const auto &k : oo.keys)
        ooRound = qMax(ooRound, k.round);
    QVERIFY2(ooRound > round + 0.3f,
             qPrintable(QString("ah=%1 oo=%2").arg(round).arg(ooRound)));
}

void TestVisemeAnalysis::wideAndRoundAreNeverBothOn()
{
    // They are two ends of one axis. A frame asking for both is a mapping
    // bug, and it looks like a mouth that cannot decide.
    const QVector<QPair<float, float>> vowels = {
        {750.f, 1150.f}, {300.f, 2400.f}, {320.f, 800.f},
        {500.f, 1000.f}, {550.f, 1900.f}
    };
    for (const auto &v : vowels) {
        const auto tl = timelineForSamples(vowel(120.f, v.first, v.second, 300), RATE);
        for (const auto &k : tl.keys)
            QVERIFY2(qMin(k.wide, k.round) < 0.02f,
                     qPrintable(QString("F1=%1 F2=%2 wide=%3 round=%4")
                                .arg(v.first).arg(v.second).arg(k.wide).arg(k.round)));
    }
}

void TestVisemeAnalysis::fricativeIsNarrowNotOpen()
{
    const auto sFrames = analyse(hiss(400), RATE);
    QVERIFY(meanLoud(sFrames, [](const Frame &f) { return f.fricness; }) > 0.5f);

    const auto ah = timelineForSamples(vowel(120.f, 750.f, 1150.f, 400), RATE);
    const auto ss = timelineFromFrames(sFrames);
    float ahOpen = 0.f, ssOpen = 0.f;
    for (const auto &k : ah.keys) ahOpen = qMax(ahOpen, k.open);
    for (const auto &k : ss.keys) ssOpen = qMax(ssOpen, k.open);
    QVERIFY2(ssOpen < ahOpen * 0.75f,
             qPrintable(QString("ah=%1 ss=%2").arg(ahOpen).arg(ssOpen)));
}

void TestVisemeAnalysis::silenceClosesTheMouth()
{
    const auto tl = timelineForSamples(
        vowel(120.f, 750.f, 1150.f, 300) + silence(300) + vowel(120.f, 750.f, 1150.f, 300),
        RATE);
    QVERIFY(!tl.keys.isEmpty());
    // Somewhere in the middle the mouth must actually be shut.
    float minOpen = 1.f;
    for (const auto &k : tl.keys)
        if (k.ms > 400 && k.ms < 550)
            minOpen = qMin(minOpen, k.open);
    QVERIFY2(minOpen < 0.05f, qPrintable(QString("minOpen=%1").arg(minOpen)));
}

void TestVisemeAnalysis::resultIsIndependentOfSampleRate()
{
    // Band edges are in Hz. Computed from a fixed bin width instead and a
    // take at another rate has its formants shifted - quietly, and it reads
    // as "the detection is just bad".
    //
    // Two things this test learned the hard way:
    //
    //  * The rates must DECIMATE DIFFERENTLY. 22050 is within rounding of the
    //    16 kHz target and is kept; 48000 is decimated by three to exactly
    //    16000. Comparing 16 k against 48 k - which is what this did first -
    //    runs both analyses at 16000 and passes whatever the bin width is
    //    computed from. It did, against a deliberately broken one.
    //  * One vowel is not enough. A rounded vowel stays rounded through a
    //    38% shift of the band edges, because the classification is coarse on
    //    purpose. A sweep has to cross a boundary somewhere, and does.
    const QVector<float> f2s = {800.f, 1200.f, 1550.f, 1900.f, 2400.f};
    for (float f2 : f2s) {
        const auto a = analyse(vowel(120.f, 400.f, f2, 350, 22050), 22050);
        const auto b = analyse(vowel(120.f, 400.f, f2, 350, 48000), 48000);
        const float fa = meanLoud(a, [](const Frame &f) { return f.frontness; });
        const float fb = meanLoud(b, [](const Frame &f) { return f.frontness; });
        QVERIFY2(qAbs(fa - fb) < 0.1f,
                 qPrintable(QString("F2=%1: 22k=%2 48k=%3").arg(f2).arg(fa).arg(fb)));
    }

    const QVector<float> f1s = {300.f, 450.f, 600.f, 750.f, 900.f};
    for (float f1 : f1s) {
        const auto a = analyse(vowel(120.f, f1, 1500.f, 350, 22050), 22050);
        const auto b = analyse(vowel(120.f, f1, 1500.f, 350, 48000), 48000);
        const float oa = meanLoud(a, [](const Frame &f) { return f.openness; });
        const float ob = meanLoud(b, [](const Frame &f) { return f.openness; });
        QVERIFY2(qAbs(oa - ob) < 0.1f,
                 qPrintable(QString("F1=%1: 22k=%2 48k=%3").arg(f1).arg(oa).arg(ob)));
    }
}

void TestVisemeAnalysis::resultIsIndependentOfPitch()
{
    // The failure this guards: peak-picking inside the F1 band returns a
    // HARMONIC for a high voice, so the mouth tracks the pitch of the
    // sentence instead of its shape. Band ratios must not care.
    const auto low = analyse(vowel(90.f, 750.f, 1150.f, 400), RATE);
    const auto high = analyse(vowel(260.f, 750.f, 1150.f, 400), RATE);
    const float ol = meanLoud(low, [](const Frame &f) { return f.openness; });
    const float oh = meanLoud(high, [](const Frame &f) { return f.openness; });
    QVERIFY2(qAbs(ol - oh) < 0.2f,
             qPrintable(QString("f0=90 -> %1, f0=260 -> %2").arg(ol).arg(oh)));
}

void TestVisemeAnalysis::resultIsIndependentOfLevel()
{
    // Everything is normalised against the file's own peak, so a quiet take
    // must not be a quiet mouth.
    QVector<float> loud = vowel(120.f, 750.f, 1150.f, 400);
    QVector<float> quiet = loud;
    for (float &s : quiet)
        s *= 0.05f;
    const auto a = timelineForSamples(loud, RATE);
    const auto b = timelineForSamples(quiet, RATE);
    float ao = 0.f, bo = 0.f;
    for (const auto &k : a.keys) ao = qMax(ao, k.open);
    for (const auto &k : b.keys) bo = qMax(bo, k.open);
    QVERIFY2(qAbs(ao - bo) < 0.05f, qPrintable(QString("%1 vs %2").arg(ao).arg(bo)));
}

void TestVisemeAnalysis::lowConfidenceFallsBackToTheEnvelope()
{
    // A frame the analyser cannot read must keep its loudness and give up
    // its shape - degrade to what shipped before, never to a guess.
    Frame f;
    f.ms = 0;
    f.level = 1.f;
    f.confidence = 0.f;
    f.openness = 1.f;   // would ask for a wide-open jaw if believed
    f.frontness = 1.f;  // and a spread mouth
    const auto tl = timelineFromFrames({f});
    QVERIFY(!tl.keys.isEmpty());
    const auto &k = tl.keys.first();
    QCOMPARE(k.wide, 0.f);
    QCOMPARE(k.round, 0.f);
    QVERIFY2(qAbs(k.open - 1.f) < 1e-4f, qPrintable(QString("open=%1").arg(k.open)));
}

void TestVisemeAnalysis::timelineIsMonotonicAndEndsClosed()
{
    const auto tl = timelineForSamples(vowel(120.f, 750.f, 1150.f, 500), RATE);
    QVERIFY(tl.keys.size() > 10);
    qint64 prev = -1;
    for (const auto &k : tl.keys) {
        QVERIFY(k.ms > prev);
        prev = k.ms;
        QVERIFY(k.open >= 0.f && k.open <= 1.f);
        QVERIFY(k.wide >= 0.f && k.wide <= 1.f);
        QVERIFY(k.round >= 0.f && k.round <= 1.f);
    }
    QCOMPARE(tl.keys.last().open, 0.f);
    QCOMPARE(tl.durationMs, tl.keys.last().ms);
}

// A three-syllable script with a bilabial in the middle: "ma-m-ma". The
// middle key is the one no acoustic measurement gets right, because a /m/ is
// voiced and therefore loud.
VisemeTimeline maMmaScript()
{
    return scriptOf({
        {0,   0.90f, 0.25f, 0.f},
        {130, 0.02f, 0.10f, 0.f},   // bilabial closure
        {210, 0.90f, 0.25f, 0.f},
        {340, 0.00f, 0.00f, 0.f}
    });
}

void TestVisemeAnalysis::alignRejectsATranscriptOfTheWrongLength()
{
    // A transcript from another take is worse than none - it would drag the
    // mouth confidently through the wrong syllables for a whole line.
    const auto frames = flatFrames(60, 0.8f, 0.7f);   // ~944 ms
    VisemeTimeline script = maMmaScript();
    script.durationMs = 12000;                        // a different sentence
    QVERIFY(align(script, frames).keys.isEmpty());

    script.durationMs = 50;                           // or a much shorter one
    QVERIFY(align(script, frames).keys.isEmpty());
}

void TestVisemeAnalysis::alignRejectsInputTooSmallToAlign()
{
    QVERIFY(align(maMmaScript(), flatFrames(2, 0.8f, 0.7f)).keys.isEmpty());
    QVERIFY(align(scriptOf({}), flatFrames(60, 0.8f, 0.7f)).keys.isEmpty());
}

void TestVisemeAnalysis::alignRejectsATableTooLargeToBeWorthIt()
{
    // The DTW table is one cell per (script key, audio frame). Long enough
    // inputs make that tens of megabytes allocated in one go on the main
    // thread, for a line nobody will study the alignment of. It has to
    // decline rather than allocate.
    const int frameCount = 4000;                   // a bit over a minute
    QVector<VisemeKey> many;
    for (int i = 0; i < 3000; ++i)
        many.append({qint64(i) * 21, 0.5f, 0.2f, 0.f});  // ~63 s of script
    const auto tl = align(scriptOf(many), flatFrames(frameCount, 0.8f, 0.7f));
    QVERIFY2(tl.keys.isEmpty(),
             qPrintable(QString("built a %1-cell table")
                        .arg(qint64(many.size()) * frameCount)));
}

void TestVisemeAnalysis::alignKeepsAClosureTheAudioCannotSee()
{
    // THE reason a transcript is worth having. The audio is loud and open
    // from end to end, so every acoustic tier says "open" throughout. The
    // script says there is an /m/ in the middle, and a mouth that does not
    // close on it is the single most visible lip-sync error there is.
    const auto frames = flatFrames(25, 1.0f, 0.8f);   // ~384 ms, loud
    const auto tl = align(maMmaScript(), frames);
    QVERIFY(!tl.keys.isEmpty());

    // Less the appended closing key, which is 0 by construction. Counting it
    // made this test pass against an align() that took its shapes from the
    // AUDIO - the one thing it exists to rule out.
    float minOpen = 1.f, maxOpen = 0.f;
    for (int i = 0; i < tl.keys.size() - 1; ++i) {
        minOpen = qMin(minOpen, tl.keys.at(i).open);
        maxOpen = qMax(maxOpen, tl.keys.at(i).open);
    }
    QVERIFY2(minOpen < 0.06f, qPrintable(QString("minOpen=%1").arg(minOpen)));
    QVERIFY2(maxOpen > 0.6f, qPrintable(QString("maxOpen=%1").arg(maxOpen)));

    // And the same frames without a script cannot produce that closure.
    const auto acoustic = timelineFromFrames(frames);
    float acousticMin = 1.f;
    for (int i = 0; i < acoustic.keys.size() - 1; ++i)  // less the closing key
        acousticMin = qMin(acousticMin, acoustic.keys.at(i).open);
    QVERIFY2(acousticMin > 0.5f,
             qPrintable(QString("acousticMin=%1").arg(acousticMin)));
}

void TestVisemeAnalysis::alignTakesItsClockFromTheAudio()
{
    // The script's own timings are an estimate and must be thrown away.
    const auto frames = flatFrames(50, 0.8f, 0.7f);   // 784 ms
    const auto tl = align(maMmaScript(), frames);     // script claims 340 ms
    QVERIFY(!tl.keys.isEmpty());
    QCOMPARE(tl.durationMs, frames.last().ms + 16);
    QVERIFY2(tl.keys.last().ms > 700,
             qPrintable(QString("last=%1").arg(tl.keys.last().ms)));

    // Every shape is timed at the ONSET of the run it was matched to, not at
    // its end. Take the end instead and each shape lands late by half its own
    // length, which reads as a mouth trailing the voice - and the first key,
    // which must start the line, is the clearest place to see it.
    QCOMPARE(tl.keys.first().ms, qint64(0));
}

void TestVisemeAnalysis::alignKeysAreStrictlyMonotonic()
{
    // Two script keys can be assigned the same frame, and then a timeline
    // that stalls or goes backwards samples unpredictably at playback.
    //
    // Forcing that needs MORE script keys than audio frames. An earlier
    // version of this test used four keys against eight frames, where the
    // path is free to give every key its own frame - so it passed against an
    // align() with the monotonic fix removed.
    QVector<VisemeKey> many;
    for (int i = 0; i < 14; ++i)
        many.append({qint64(i) * 8, (i % 2) ? 0.8f : 0.1f, 0.2f, 0.f});
    const VisemeTimeline script = scriptOf(many);     // 104 ms, 14 keys
    const auto frames = flatFrames(5, 0.8f, 0.7f);    // 64 ms, 5 frames
    const auto tl = align(script, frames);
    QVERIFY2(!tl.keys.isEmpty(), "the length guard should accept this pairing");
    QCOMPARE(tl.keys.size(), many.size() + 1);
    qint64 prev = -1;
    for (const auto &k : tl.keys) {
        QVERIFY2(k.ms > prev, qPrintable(QString("ms=%1 after %2").arg(k.ms).arg(prev)));
        prev = k.ms;
    }
}

void TestVisemeAnalysis::alignCarriesWordMarksOntoTheRecording()
{
    // Word callbacks were only ever available for spoken text. Alignment maps
    // them onto a recording for free - which is what a subtitle needs.
    const auto frames = flatFrames(50, 0.8f, 0.7f);
    VisemeTimeline script = maMmaScript();
    script.wordMarks = {{0, 0}, {3, 210}};
    const auto tl = align(script, frames);
    QVERIFY(!tl.keys.isEmpty());
    QCOMPARE(tl.wordMarks.size(), 2);
    QCOMPARE(tl.wordMarks.at(0).first, qsizetype(0));
    QCOMPARE(tl.wordMarks.at(1).first, qsizetype(3));
    QVERIFY(tl.wordMarks.at(0).second <= tl.wordMarks.at(1).second);
    QVERIFY(tl.wordMarks.at(1).second <= tl.durationMs);
    // On the RECORDING's clock, not the script's. Ordered-and-in-bounds was
    // true of untranslated marks too, so it proved nothing: the script ends
    // at 340 ms and the recording runs to 784.
    QVERIFY2(tl.wordMarks.at(1).second > script.durationMs,
             qPrintable(QString("mark=%1 script ends %2")
                        .arg(tl.wordMarks.at(1).second).arg(script.durationMs)));
}

void TestVisemeAnalysis::alignFindsTheSecondSyllableAfterThePause()
{
    // The one that asks whether alignment ALIGNS, rather than whether it
    // produces well-formed output. Two bursts with a silence between them,
    // and a script of two syllables with a pause between them: the second
    // syllable has to land in the second burst. Everything else here is
    // satisfied by a timeline that simply stretches the script to fit.
    QVector<Frame> frames;
    auto push = [&frames](int count, float level) {
        for (int i = 0; i < count; ++i) {
            Frame f;
            f.ms = qint64(frames.size()) * 16;
            f.level = level;
            f.openness = level > 0.1f ? 0.75f : 0.f;
            f.frontness = 0.5f;
            f.confidence = level > 0.1f ? 1.f : 0.f;
            frames.append(f);
        }
    };
    push(20, 0.9f);   // 0    - 304 ms
    push(20, 0.0f);   // 320  - 624 ms
    push(20, 0.9f);   // 640  - 944 ms

    const VisemeTimeline script = scriptOf({
        {0,   0.90f, 0.25f, 0.f},
        {200, 0.00f, 0.00f, 0.f},   // the pause
        {400, 0.90f, 0.25f, 0.f},
        {600, 0.00f, 0.00f, 0.f}
    });

    const auto tl = align(script, frames);
    QVERIFY(!tl.keys.isEmpty());
    QCOMPARE(tl.keys.size(), 5);

    QVERIFY2(tl.keys.at(0).ms < 320,
             qPrintable(QString("first syllable at %1").arg(tl.keys.at(0).ms)));
    QVERIFY2(tl.keys.at(1).ms >= 300 && tl.keys.at(1).ms < 660,
             qPrintable(QString("pause at %1").arg(tl.keys.at(1).ms)));
    QVERIFY2(tl.keys.at(2).ms >= 620,
             qPrintable(QString("second syllable at %1").arg(tl.keys.at(2).ms)));
}

void TestVisemeAnalysis::alignLetsLoudnessSetEmphasis()
{
    // Identity is the script's, but a shouted syllable should still open
    // further than a muttered one - otherwise every line is read flat.
    const auto loud = align(maMmaScript(), flatFrames(30, 1.0f, 0.8f));
    const auto soft = align(maMmaScript(), flatFrames(30, 0.35f, 0.8f));
    QVERIFY(!loud.keys.isEmpty() && !soft.keys.isEmpty());
    float lo = 0.f, so = 0.f;
    for (const auto &k : loud.keys) lo = qMax(lo, k.open);
    for (const auto &k : soft.keys) so = qMax(so, k.open);
    QVERIFY2(lo > so + 0.1f, qPrintable(QString("loud=%1 soft=%2").arg(lo).arg(so)));
}

QTEST_MAIN(TestVisemeAnalysis)
#include "tst_viseme_analysis.moc"
