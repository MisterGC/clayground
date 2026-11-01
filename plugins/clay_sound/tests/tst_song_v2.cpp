// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Song v2 offline: the adaptive demo song (demo/songs/adaptive.song.json)
// switches state on the next bar and fades a layer in by intensity,
// measured on renderSong() against renders that differ only in that;
// the sequencer's sync points, stingers and end, read off its notes.
// Built against Clayground::SoundEngine alone.

#include "clay_sound_engine.h"
#include "song/song_parser.h"

#include <QtTest/QtTest>

#include <algorithm>
#include <cmath>

namespace cs = clay::sound;

namespace {

constexpr int kRate = cs::kSampleRate;
constexpr int64_t kBeat = kRate / 2;    // the demo plays 120 bpm
constexpr int64_t kBar = 4 * kBeat;

double rms(const std::vector<float> &a, const std::vector<float> *minus, int64_t from, int64_t to)
{
    double sum = 0.0;
    for (int64_t i = from; i < to; ++i) {
        const double d = a[i] - (minus ? (*minus)[i] : 0.0f);
        sum += d * d;
    }
    return std::sqrt(sum / std::max<int64_t>(1, to - from));
}

std::vector<float> render(const cs::SongModel &song, const cs::SongPerformance &perf, double seconds)
{
    return cs::renderSong(song, perf, seconds, 1.0f, false, kRate, /*stereo=*/false);
}

cs::SongCue cue(int64_t frame, cs::SongCue::Kind kind, const QString &name, double value = 0.0)
{
    cs::SongCue c;
    c.frame = frame;
    c.kind = kind;
    c.name = name;
    c.value = value;
    return c;
}

// First frame an instrument's note starts on at or after `from`, -1 if none.
int64_t firstNote(const std::vector<cs::SequencedNote> &notes, const QString &instrument, int64_t from = 0)
{
    for (const auto &n : notes)
        if (n.instrument == instrument && n.frame >= from) return n.frame;
    return -1;
}

} // namespace

class TestSongV2 : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void demoSongSwitchesStateOnTheNextBar();
    void demoSongFadesTheLayerInByIntensity();
    void stateMovesOnTheTransitionsSync();
    void stingerPlaysOnItsSync();
    void songWithoutSegmentsEndsOrLoops();
    void sameCuesRenderTheSameSamples();

private:
    cs::SongModel demo_;
};

void TestSongV2::initTestCase()
{
    std::string error;
    QVERIFY2(cs::loadSong(CLAY_SOUND_DEMO_ADAPTIVE, &demo_, &error), error.c_str());
    QCOMPARE(demo_.version, 2);
    QCOMPARE(demo_.tempo, 120.0);
    QCOMPARE(cs::segmentBeats(demo_, "explore"), 8.0);
    QCOMPARE(cs::segmentBeats(demo_, "combat"), 8.0);
}

// Asked for combat at 1.3 s, mid-way through the first bar, the music
// stays in explore up to the bar line at 2 s and plays combat from its
// start there: before the line every sample is the one the song plays
// without the cue, after it (once explore's last notes have rung out)
// every sample is one of a song started in combat, 2 s later.
void TestSongV2::demoSongSwitchesStateOnTheNextBar()
{
    cs::SongPerformance stay;
    stay.intensity = 1.0;
    cs::SongPerformance moved = stay;
    moved.cues = {cue(std::llround(1.3 * kRate), cs::SongCue::Kind::State, "combat")};
    cs::SongPerformance combat = stay;
    combat.start = "combat";

    const auto a = render(demo_, stay, 6.0);
    const auto b = render(demo_, moved, 6.0);
    const auto c = render(demo_, combat, 6.0);
    QCOMPARE(b.size(), size_t(6 * kRate));

    for (int64_t i = 0; i < kBar; ++i)
        if (b[i] != a[i]) QFAIL(qPrintable(QStringLiteral("differs at frame %1, before the bar line").arg(i)));
    QVERIFY(rms(b, &a, kBar, kBar + 256) > 1e-3);   // combat sounds right on the line

    const int64_t rungOut = kBar + kRate / 2;
    for (int64_t i = rungOut; i < int64_t(b.size()); ++i)
        if (b[i] != c[i - kBar]) QFAIL(qPrintable(QStringLiteral("frame %1 is not combat's frame %2").arg(i).arg(i - kBar)));
    QVERIFY(rms(b, nullptr, rungOut, b.size()) > 0.05);

    // The bar line, not the pattern's end: asked at 2.1 s, at 4 s.
    cs::SongSequencer seq(demo_, kRate);
    std::vector<cs::SequencedNote> notes;
    seq.advance(std::llround(2.1 * kRate), notes);
    QVERIFY(seq.setState("combat"));
    seq.advance(4 * kBar, notes);
    QCOMPARE(firstNote(notes, "horn"), 2 * kBar);
    QCOMPARE(seq.segmentAt(2 * kBar - 1), QStringLiteral("explore"));
    QCOMPARE(seq.segmentAt(2 * kBar), QStringLiteral("combat"));
    QCOMPARE(seq.beatAt(2 * kBar + kBeat), 1.0);

    // Asked on the bar line itself, it moves there.
    cs::SongSequencer onLine(demo_, kRate);
    notes.clear();
    onLine.advance(kBar, notes);
    onLine.setState("combat");
    onLine.advance(2 * kBar, notes);
    QCOMPARE(firstNote(notes, "horn"), kBar);
}

// The drive layer (arp on the beat, hat on the off-beat) is silent at
// intensity 0 and full from 0.75. Raised to 0.75 on beat 4, it fades in
// over 4 beats: each of its notes plays at the level its start falls on,
// so what it adds to the mix is that level times what it adds at full.
void TestSongV2::demoSongFadesTheLayerInByIntensity()
{
    cs::SongPerformance quiet;          // intensity 0
    cs::SongPerformance full;
    full.intensity = 0.75;
    cs::SongPerformance rising = quiet;
    rising.cues = {cue(4 * kBeat, cs::SongCue::Kind::Intensity, {}, 0.75)};

    const auto q = render(demo_, quiet, 6.0);
    const auto f = render(demo_, full, 6.0);
    const auto r = render(demo_, rising, 6.0);

    for (int64_t i = 0; i < 4 * kBeat; ++i)
        if (r[i] != q[i]) QFAIL(qPrintable(QStringLiteral("differs at frame %1, before the cue").arg(i)));

    // Half-beat windows: an arp note, then a hat note, each rung out
    // before the next window starts.
    for (int64_t half = 8; half < 24; ++half) {
        const int64_t from = half * kBeat / 2;
        const int64_t to = from + kBeat / 2;
        const double layer = rms(f, &q, from, to);
        QVERIFY2(layer > 1e-3, qPrintable(QStringLiteral("window %1 has no layer").arg(half)));
        const double level = std::clamp((half / 2.0 - 4.0) / 4.0, 0.0, 1.0);
        const double heard = rms(r, &q, from, to);
        QVERIFY2(std::abs(heard - level * layer) < 1e-3 * layer + 1e-7,
                 qPrintable(QStringLiteral("window %1: %2 of the layer, expected %3")
                                .arg(half).arg(heard / layer).arg(level)));
    }
}

// Combat goes back to explore on its exit cue (beat 4) with the pickup
// stinger there; asked after the cue, at the segment's end.
void TestSongV2::stateMovesOnTheTransitionsSync()
{
    std::vector<cs::SequencedNote> notes;
    cs::SongSequencer seq(demo_, kRate, "combat");
    seq.advance(1 * kBeat, notes);
    seq.setState("explore");
    seq.advance(3 * kBar, notes);
    QCOMPARE(seq.segmentAt(4 * kBeat - 1), QStringLiteral("combat"));
    QCOMPARE(seq.segmentAt(4 * kBeat), QStringLiteral("explore"));
    QCOMPARE(firstNote(notes, "lead"), 4 * kBeat);  // the stinger's first note, then explore's melody
    int leadOnTheCue = 0;
    for (const auto &n : notes)
        if (n.instrument == "lead" && n.frame == 4 * kBeat) ++leadOnTheCue;
    QCOMPARE(leadOnTheCue, 2);
    QCOMPARE(firstNote(notes, "horn", 4 * kBeat), -1);

    cs::SongSequencer late(demo_, kRate, "combat");
    notes.clear();
    late.advance(5 * kBeat, notes);
    late.setState("explore");
    late.advance(3 * kBar, notes);
    QCOMPARE(late.segmentAt(8 * kBeat - 1), QStringLiteral("combat"));
    QCOMPARE(late.segmentAt(8 * kBeat), QStringLiteral("explore"));

    // A later request replaces one not reached yet; asking for the
    // current segment drops it.
    cs::SongSequencer back(demo_, kRate);
    notes.clear();
    back.advance(kBeat, notes);
    back.setState("combat");
    back.advance(2 * kBeat, notes);
    back.setState("explore");
    back.advance(3 * kBar, notes);
    QCOMPARE(firstNote(notes, "horn"), -1);
    QVERIFY(!back.setState("nowhere"));
}

void TestSongV2::stingerPlaysOnItsSync()
{
    std::vector<cs::SequencedNote> notes;
    cs::SongSequencer seq(demo_, kRate);
    seq.advance(std::llround(2.3 * kBeat), notes);
    QVERIFY(seq.playStinger("pickup"));
    QVERIFY(!seq.playStinger("fanfare"));
    notes.clear();
    seq.advance(kBar, notes);
    // Pickup: E6 on the next beat (3), A6 a quarter beat later.
    std::vector<cs::SequencedNote> pickup;
    for (const auto &n : notes)
        if (n.instrument == "lead" && n.midi > 84) pickup.push_back(n);
    QCOMPARE(pickup.size(), size_t(2));
    QCOMPARE(pickup[0].frame, 3 * kBeat);
    QCOMPARE(pickup[0].midi, 88);
    QCOMPARE(pickup[1].frame, std::llround(3.25 * kBeat));
    QCOMPARE(pickup[1].midi, 93);
}

void TestSongV2::songWithoutSegmentsEndsOrLoops()
{
    const auto parsed = cs::SongParser::parse(R"({
        "version": 2, "tempo": 120,
        "instruments": { "i": { "source": "sine" } },
        "tracks": { "t": { "instrument": "i" } },
        "patterns": { "A": { "t": [ { "t": 1, "note": 69, "dur": 0.5 } ] } }
    })");
    QVERIFY2(parsed.ok, qPrintable(parsed.error));

    std::vector<cs::SequencedNote> notes;
    cs::SongSequencer once(parsed.model, kRate);
    once.advance(3 * kBar, notes);
    QCOMPARE(notes.size(), size_t(1));
    QCOMPARE(notes[0].frame, kBeat);
    QVERIFY(once.ended());
    QCOMPARE(once.endFrame(), kBar);    // one bar: the pattern rounds up to it

    cs::SongSequencer looped(parsed.model, kRate);
    looped.setLoop(true);
    notes.clear();
    looped.advance(3 * kBar, notes);
    QCOMPARE(notes.size(), size_t(3));
    QCOMPARE(notes[2].frame, 2 * kBar + kBeat);
    QVERIFY(!looped.ended());

    // renderSong of 0 s renders the one pass.
    const auto pcm = cs::renderSong(parsed.model, cs::SongPerformance{}, 0.0, 1.0f, false, kRate, false);
    QCOMPARE(pcm.size(), size_t(kBar));
}

// Rendered twice, with every kind of cue, the samples are the same, and
// the stereo render folds down to the mono one.
void TestSongV2::sameCuesRenderTheSameSamples()
{
    cs::SongPerformance perf;
    perf.intensity = 0.4;
    perf.cues = {cue(kBeat, cs::SongCue::Kind::Stinger, "pickup"),
                 cue(3 * kBeat, cs::SongCue::Kind::Intensity, {}, 1.0),
                 cue(kBar + 7, cs::SongCue::Kind::State, "combat"),
                 cue(2 * kBar + kBeat, cs::SongCue::Kind::State, "explore")};
    const auto one = cs::renderSong(demo_, perf, 8.0, 0.8f, false, kRate, true);
    const auto two = cs::renderSong(demo_, perf, 8.0, 0.8f, false, kRate, true);
    QCOMPARE(one.size(), size_t(2 * 8 * kRate));
    QVERIFY(one == two);
    const auto mono = cs::renderSong(demo_, perf, 8.0, 0.8f, false, kRate, false);
    for (size_t i = 0; i < mono.size(); ++i)
        QCOMPARE(mono[i], (one[2 * i] + one[2 * i + 1]) * 0.5f);
}

QTEST_GUILESS_MAIN(TestSongV2)
#include "tst_song_v2.moc"
