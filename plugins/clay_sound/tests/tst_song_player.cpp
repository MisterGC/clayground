// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongPlayer tests — drive the player against a fake recording
// instrument and verify correct triggerNote() calls in the correct
// order.

#include "audio_output.h"
#include "clay_sound_engine.h"
#include "song_player.h"
#include "synth_instrument.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QVariantList>

class FakeInstrument : public QObject
{
    Q_OBJECT
public:
    // gainStage: the one the player named around this call.
    struct Call { int midi; qreal vel; qreal durSec; int gainStage; };
    QVector<Call> calls;

    Q_INVOKABLE void triggerNote(int midiNote, qreal velocity, qreal durationSeconds)
    {
        calls.push_back({ midiNote, velocity, durationSeconds,
                          clay::sound::AudioOutput::instance().triggerGainStage() });
    }
};

class TestSongPlayer : public QObject
{
    Q_OBJECT

private slots:
    void playsAllEventsInOrder();
    void loopingRestartsFromBeginning();
    void seekSkipsPastEvents();
    void parseErrorKeepsUnloaded();
    void hotReloadKeepsPositionAndSwapsFutureEvents();
    void hotReloadWithBadSyntaxKeepsPreviousModel();
    void volumeIsTheGainStageItsNotesPlayThrough();
    void renderOfflinePlacesNotesOnTheirFrame();

    void v2LivePlaybackRendersWhatRenderOfflineReturns();
    void v2StateAndIntensityBeforePlayAreWhereItStarts();
    void v2SampleInstrumentsLoadBesideTheSong();
    void v2HotReloadStaysInTheSegment();

private:
    QString writeSong(QTemporaryDir &dir, const QByteArray &content);
};

QString TestSongPlayer::writeSong(QTemporaryDir &dir, const QByteArray &content)
{
    const QString path = dir.filePath("song.song.json");
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return {};
    f.write(content);
    f.close();
    return path;
}

// Poll for a condition with a timeout; spins the event loop so timers fire.
static bool waitUntil(std::function<bool()> cond, int timeoutMs)
{
    QElapsedTimer t;
    t.start();
    while (!cond()) {
        if (t.elapsed() > timeoutMs) return false;
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
    }
    return true;
}

void TestSongPlayer::playsAllEventsInOrder()
{
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({
        "tempo": 240,
        "tracks": { "lead": { "instrument": "leadSynth" } },
        "patterns": {
          "A": { "lead": [
            { "t": 0,   "note": "C4", "dur": 0.25 },
            { "t": 0.5, "note": "E4", "dur": 0.25 },
            { "t": 1.0, "note": "G4", "dur": 0.25 }
          ] }
        },
        "sections": [ { "pattern": "A" } ]
    })");
    QVERIFY(!path.isEmpty());

    FakeInstrument fake;
    fake.setObjectName("leadSynth");

    SongPlayer p;
    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake) });
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY(p.loaded());
    QCOMPARE(p.tempo(), 240.0);

    // Pattern length rounds up to 2 beats (last event ends at 1.25).
    // At 240 BPM that's 0.5s of playback.
    QSignalSpy doneSpy(&p, &SongPlayer::finished);
    p.play();
    QVERIFY(waitUntil([&] { return doneSpy.count() > 0; }, 3000));

    QCOMPARE(fake.calls.size(), 3);
    QCOMPARE(fake.calls[0].midi, 60);
    QCOMPARE(fake.calls[1].midi, 64);
    QCOMPARE(fake.calls[2].midi, 67);
    // dur 0.25 beats @ 240 BPM = 0.0625s
    QVERIFY(qAbs(fake.calls[0].durSec - 0.0625) < 1e-6);
}

void TestSongPlayer::loopingRestartsFromBeginning()
{
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({
        "tempo": 240,
        "tracks": { "l": { "instrument": "inst" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": 60, "dur": 0.25 } ] } },
        "sections": [ { "pattern": "A" } ]
    })");
    FakeInstrument fake;
    fake.setObjectName("inst");

    SongPlayer p;
    p.setLoop(true);
    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake) });
    p.setSource(QUrl::fromLocalFile(path));
    p.play();
    // Wait until we've seen at least 2 triggers (= one loop).
    QVERIFY(waitUntil([&] { return fake.calls.size() >= 2; }, 3000));
    p.stop();
    QVERIFY(fake.calls.size() >= 2);
    QCOMPARE(fake.calls[0].midi, 60);
    QCOMPARE(fake.calls[1].midi, 60);
}

void TestSongPlayer::seekSkipsPastEvents()
{
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({
        "tempo": 240,
        "tracks": { "l": { "instrument": "inst" } },
        "patterns": {
          "A": { "l": [
            { "t": 0,   "note": 60, "dur": 0.25 },
            { "t": 1.0, "note": 62, "dur": 0.25 }
          ] }
        },
        "sections": [ { "pattern": "A" } ]
    })");
    FakeInstrument fake;
    fake.setObjectName("inst");

    SongPlayer p;
    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake) });
    p.setSource(QUrl::fromLocalFile(path));
    p.seek(0.8); // skip past the first event
    QSignalSpy doneSpy(&p, &SongPlayer::finished);
    p.play();
    QVERIFY(waitUntil([&] { return doneSpy.count() > 0; }, 3000));
    QCOMPARE(fake.calls.size(), 1);
    QCOMPARE(fake.calls[0].midi, 62);
}

void TestSongPlayer::parseErrorKeepsUnloaded()
{
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({ "tempo": "bogus" })");
    SongPlayer p;
    QSignalSpy errSpy(&p, &SongPlayer::parseError);
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY(!p.loaded());
    QVERIFY(errSpy.count() >= 1);
    QVERIFY(!p.error().isEmpty());
}

void TestSongPlayer::hotReloadKeepsPositionAndSwapsFutureEvents()
{
#ifdef Q_OS_WIN
    QSKIP("QFileSystemWatcher on Windows NTFS does not reliably fire "
          "fileChanged() for two writes in quick succession; see QTBUG-*");
#endif
    QTemporaryDir dir;
    // First version: three notes across ~2 beats; slow tempo so the
    // test has time to overwrite the file mid-playback.
    const QString path = writeSong(dir, R"({
        "tempo": 60,
        "tracks": { "l": { "instrument": "inst" } },
        "patterns": {
          "A": { "l": [
            { "t": 0,   "note": 60, "dur": 0.25 },
            { "t": 1.0, "note": 62, "dur": 0.25 },
            { "t": 2.0, "note": 64, "dur": 0.25 }
          ] }
        },
        "sections": [ { "pattern": "A" } ]
    })");
    FakeInstrument fake;
    fake.setObjectName("inst");
    SongPlayer p;
    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake) });
    p.setSource(QUrl::fromLocalFile(path));
    QSignalSpy hotSpy(&p, &SongPlayer::hotReloaded);

    p.play();
    // Wait until the first note fires but before the second.
    QVERIFY(waitUntil([&] { return fake.calls.size() >= 1; }, 3000));
    QVERIFY(p.position() < 1.0);

    // Overwrite with a new version — different notes at the same times.
    QFile f(path);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(R"({
        "tempo": 60,
        "tracks": { "l": { "instrument": "inst" } },
        "patterns": {
          "A": { "l": [
            { "t": 0,   "note": 60, "dur": 0.25 },
            { "t": 1.0, "note": 72, "dur": 0.25 },
            { "t": 2.0, "note": 74, "dur": 0.25 }
          ] }
        },
        "sections": [ { "pattern": "A" } ]
    })");
    f.close();

    QVERIFY(waitUntil([&] { return hotSpy.count() >= 1; }, 3000));
    QVERIFY(p.playing());
    // Subsequent notes should be the NEW ones.
    QVERIFY(waitUntil([&] { return fake.calls.size() >= 3; }, 5000));
    p.stop();

    // calls[0] fired before the swap (old note 60)
    QCOMPARE(fake.calls[0].midi, 60);
    // Remaining triggers are from the new file.
    QCOMPARE(fake.calls[1].midi, 72);
    QCOMPARE(fake.calls[2].midi, 74);
}

void TestSongPlayer::hotReloadWithBadSyntaxKeepsPreviousModel()
{
#ifdef Q_OS_WIN
    QSKIP("QFileSystemWatcher on Windows NTFS does not reliably fire "
          "fileChanged() for two writes in quick succession; see QTBUG-*");
#endif
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "inst" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": 60, "dur": 0.25 } ] } }
    })");
    SongPlayer p;
    FakeInstrument fake;
    fake.setObjectName("inst");
    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake) });
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY(p.loaded());
    const double prevTotal = p.totalBeats();

    QSignalSpy errSpy(&p, &SongPlayer::parseError);
    QFile f(path);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write("{ not json");
    f.close();
    QVERIFY(waitUntil([&] { return errSpy.count() >= 1; }, 3000));
    QVERIFY(p.loaded());
    QCOMPARE(p.totalBeats(), prevTotal);
}

void TestSongPlayer::volumeIsTheGainStageItsNotesPlayThrough()
{
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({
        "tempo": 240,
        "tracks": { "l": { "instrument": "inst" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": 60, "dur": 0.25 },
                                    { "t": 0.5, "note": 62, "dur": 0.25 } ] } },
        "sections": [ { "pattern": "A" } ]
    })");
    FakeInstrument fake;
    fake.setObjectName("inst");

    SongPlayer p;
    QCOMPARE(p.volume(), 1.0);
    QSignalSpy volSpy(&p, &SongPlayer::volumeChanged);
    p.setVolume(1.5);
    QCOMPARE(p.volume(), 1.0);          // clamped, so unchanged
    QCOMPARE(volSpy.count(), 0);
    p.setVolume(0.3);
    QCOMPARE(volSpy.count(), 1);

    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake) });
    p.setSource(QUrl::fromLocalFile(path));
    QSignalSpy doneSpy(&p, &SongPlayer::finished);
    p.play();
    QVERIFY(waitUntil([&] { return doneSpy.count() > 0; }, 3000));

    QCOMPARE(fake.calls.size(), 2);
    const int stage = fake.calls[0].gainStage;
    QVERIFY(stage >= 0);
    QCOMPARE(fake.calls[1].gainStage, stage);
    // Velocity is the song's, the volume is the stage's.
    QVERIFY(qAbs(fake.calls[0].vel - 0.8) < 1e-6);
    auto &eng = clay::sound::AudioOutput::instance().engine();
    QCOMPARE(eng.gainStage(stage), 0.3f);
    // Outside the player's calls no stage is named.
    QCOMPARE(clay::sound::AudioOutput::instance().triggerGainStage(), -1);

    // A later volume reaches the same stage, so ringing notes follow it.
    p.setVolume(0.6);
    QCOMPARE(eng.gainStage(stage), 0.6f);

    // Two players never share a stage.
    SongPlayer other;
    FakeInstrument fake2;
    fake2.setObjectName("inst");
    other.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&fake2) });
    other.setSource(QUrl::fromLocalFile(path));
    QSignalSpy doneSpy2(&other, &SongPlayer::finished);
    other.play();
    QVERIFY(waitUntil([&] { return doneSpy2.count() > 0; }, 3000));
    QVERIFY(!fake2.calls.isEmpty());
    QVERIFY(fake2.calls[0].gainStage != stage);
}

// renderOffline() starts every note on its exact frame, scales it by
// the volume and repeats the song while it loops; a track whose
// instrument is not bound stays silent.
void TestSongPlayer::renderOfflinePlacesNotesOnTheirFrame()
{
    QTemporaryDir dir;
    const QString path = writeSong(dir, R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "lead" }, "x": { "instrument": "nobody" } },
        "patterns": { "A": { "l": [ { "t": 1, "note": 69, "dur": 0.5, "vel": 1 } ],
                             "x": [ { "t": 0, "note": 40, "dur": 1 } ] } },
        "sections": [ { "pattern": "A" } ]
    })");
    SynthInstrument lead;
    lead.setObjectName("lead");
    lead.setWaveform("square");
    lead.setAttack(0.0);
    lead.setSustain(1.0);
    lead.setRelease(0.01);
    lead.setVolume(0.5);

    SongPlayer p;
    p.setInstruments(QVariantList{ QVariant::fromValue<QObject *>(&lead) });
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY(p.loaded());

    // The song is 2 beats (1.5 rounded up) = 1 s; beat 1 is frame 22050.
    const QVector<float> full = p.renderOffline();
    QCOMPARE(full.size(), 44100);
    for (int i = 0; i < 22050; ++i) QCOMPARE(full[i], 0.0f);
    float peak = 0.0f;
    for (int i = 22050; i < 22050 + 100; ++i) peak = std::max(peak, std::abs(full[i]));
    QVERIFY(peak > 0.4f);

    p.setVolume(0.5);
    const QVector<float> half = p.renderOffline();
    QCOMPARE(half.size(), full.size());
    for (int i = 0; i < full.size(); ++i)
        QVERIFY(std::abs(half[i] - 0.5f * full[i]) < 1e-6f);
    p.setVolume(1.0);

    // Looping, the second second plays the first one again.
    p.setLoop(true);
    const QVector<float> looped = p.renderOffline(2.0);
    QCOMPARE(looped.size(), 88200);
    for (int i = 0; i < 44100; ++i) QCOMPARE(looped[44100 + i], full[i]);
}

// A v2 song played live on the shared engine - rendered in passes of
// uneven size, ticked between them, steered by state, intensity and a
// stinger while it plays - renders the samples renderSong() renders for
// the same controls: each at the song frame it reached, which is the
// engine's frame then plus the look-ahead.
void TestSongPlayer::v2LivePlaybackRendersWhatRenderOfflineReturns()
{
    namespace cs = clay::sound;
    auto &eng = cs::AudioOutput::instance().engine();
    const int rate = cs::AudioOutput::instance().sampleRate();

    SongPlayer p;
    p.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_ADAPTIVE));
    QVERIFY2(p.loaded(), qPrintable(p.error()));
    QCOMPARE(p.version(), 2);
    QCOMPARE(p.segment(), QStringLiteral("explore"));
    QCOMPARE(p.totalBeats(), 8.0);
    p.setIntensity(0.3);

    // Start far from frame 0 and mid-pass, with nothing else ringing.
    std::vector<float> skip(rate + 12345);
    eng.renderOffline(skip.data(), static_cast<int>(skip.size()));
    QCOMPARE(eng.activeVoices(), size_t(0));
    QCOMPARE(eng.pendingEvents(), size_t(0));

    p.play();
    QVERIFY(p.playing());
    const int64_t start = eng.currentFrame();

    struct Control { double at; std::function<void()> send; cs::SongCue cue; };
    auto cue = [](cs::SongCue::Kind kind, const QString &name, double value = 0.0) {
        cs::SongCue c;
        c.kind = kind;
        c.name = name;
        c.value = value;
        return c;
    };
    QVector<Control> controls = {
        {1.3, [&] { p.setState("combat"); }, cue(cs::SongCue::Kind::State, "combat")},
        {2.9, [&] { p.setIntensity(1.0); }, cue(cs::SongCue::Kind::Intensity, {}, 1.0)},
        {5.1, [&] { QVERIFY(p.playStinger("pickup")); }, cue(cs::SongCue::Kind::Stinger, "pickup")},
        {6.7, [&] { p.setState("explore"); }, cue(cs::SongCue::Kind::State, "explore")},
    };

    const int64_t frames = 10 * rate;
    std::vector<float> live(static_cast<size_t>(frames));
    const int passes[] = {256, 1000, 441, 1777, 882, 613};
    int next = 0;
    QStringList segments;
    for (int64_t at = 0, k = 0; at < frames; ++k) {
        while (next < controls.size() && eng.currentFrame() - start >= controls[next].at * rate) {
            controls[next].cue.frame = eng.currentFrame() - start + SongPlayer::kScheduleAheadFrames;
            controls[next].send();
            ++next;
        }
        const int n = static_cast<int>(std::min<int64_t>(passes[k % 6], frames - at));
        eng.renderOffline(live.data() + at, n);
        at += n;
        QMetaObject::invokeMethod(&p, "tick");
        if (segments.isEmpty() || segments.last() != p.segment()) segments << p.segment();
    }
    for (auto &s : live) s = std::clamp(s, -1.0f, 1.0f);
    QCOMPARE(next, controls.size());
    QCOMPARE(segments, (QStringList{"explore", "combat", "explore"}));

    cs::SongModel model;
    std::string error;
    QVERIFY2(cs::loadSong(CLAY_SOUND_DEMO_ADAPTIVE, &model, &error), error.c_str());
    cs::SongPerformance perf;
    perf.intensity = 0.3;
    for (const Control &c : std::as_const(controls)) perf.cues.append(c.cue);
    const auto offline = cs::renderSong(model, perf, 10.0, 1.0f, false, rate, false);
    QCOMPARE(offline.size(), live.size());
    for (size_t i = 0; i < live.size(); ++i)
        if (live[i] != offline[i])
            QFAIL(qPrintable(QStringLiteral("frame %1: live %2, offline %3").arg(i).arg(live[i]).arg(offline[i])));
    double energy = 0.0;
    for (float s : live) energy += double(s) * s;
    QVERIFY(energy / live.size() > 1e-3);

    // renderOffline() takes the same cues in seconds, from the state
    // and intensity the player has now.
    p.stop();
    p.setState("explore");
    p.setIntensity(0.3);
    QVariantList cues;
    for (const Control &c : std::as_const(controls)) {
        QVariantMap m{{"at", double(c.cue.frame) / rate}};
        if (c.cue.kind == cs::SongCue::Kind::State) m.insert("state", c.cue.name);
        if (c.cue.kind == cs::SongCue::Kind::Intensity) m.insert("intensity", c.cue.value);
        if (c.cue.kind == cs::SongCue::Kind::Stinger) m.insert("stinger", c.cue.name);
        cues << m;
    }
    std::reverse(cues.begin(), cues.end());    // the player orders them
    const QVector<float> fromQml = p.renderOffline(10.0, cues);
    QCOMPARE(fromQml, QVector<float>(offline.begin(), offline.end()));

    // Stopped, the notes handed out ahead are taken back.
    QCOMPARE(eng.pendingEvents(), size_t(0));
}

// Before play() the state is the segment the song starts in and the
// intensity its layers' level; renderOffline() starts there too.
void TestSongPlayer::v2StateAndIntensityBeforePlayAreWhereItStarts()
{
    namespace cs = clay::sound;
    SongPlayer p;
    QSignalSpy segSpy(&p, &SongPlayer::segmentChanged);
    p.setState("combat");
    p.setIntensity(1.0);
    p.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_ADAPTIVE));
    QVERIFY(p.loaded());
    QCOMPARE(p.segment(), QStringLiteral("combat"));
    QVERIFY(segSpy.count() > 0);

    cs::SongModel model;
    QVERIFY(cs::loadSong(CLAY_SOUND_DEMO_ADAPTIVE, &model));
    cs::SongPerformance perf;
    perf.start = "combat";
    perf.intensity = 1.0;
    const auto expected = cs::renderSong(model, perf, 3.0, 1.0f, false,
                                         cs::AudioOutput::instance().sampleRate(), false);
    QCOMPARE(p.renderOffline(3.0), QVector<float>(expected.begin(), expected.end()));

    p.setState("explore");
    QCOMPARE(p.segment(), QStringLiteral("explore"));
    p.setState("nowhere");
    QVERIFY(p.error().contains("nowhere"));
    QCOMPARE(p.segment(), QStringLiteral("explore"));
    QVERIFY(!p.playStinger("pickup"));      // nothing plays yet
}

// A sample instrument's file is read relative to the song; one that
// cannot be read is an error naming the instrument.
void TestSongPlayer::v2SampleInstrumentsLoadBesideTheSong()
{
    QTemporaryDir dir;
    QVERIFY(QDir(dir.path()).mkpath("kit"));
    QVERIFY(QFile::copy(CLAY_SOUND_DEMO_WAV, dir.filePath("kit/hit.wav")));
    const QByteArray song = R"({
        "version": 2, "tempo": 120,
        "instruments": { "hit": { "source": "sample", "sample": "kit/hit.wav", "root": 60 } },
        "tracks": { "t": { "instrument": "hit" } },
        "patterns": { "A": { "t": [ { "t": 1, "note": 60, "dur": 1 } ] } }
    })";
    const QString path = writeSong(dir, song);

    SongPlayer p;
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY2(p.loaded(), qPrintable(p.error()));
    const QVector<float> pcm = p.renderOffline();
    QCOMPARE(pcm.size(), 88200);                    // one bar at 120 bpm
    const int beat = 22050;
    for (int i = 0; i < beat; ++i) QCOMPARE(pcm[i], 0.0f);
    float peak = 0.0f;
    for (int i = beat; i < 2 * beat; ++i) peak = std::max(peak, std::abs(pcm[i]));
    QVERIFY(peak > 0.01f);

    QByteArray missing = song;
    missing.replace("kit/hit.wav", "kit/gone.wav");
    SongPlayer q;
    QSignalSpy errSpy(&q, &SongPlayer::parseError);
    q.setSource(QUrl::fromLocalFile(writeSong(dir, missing)));
    QVERIFY(!q.loaded());
    QCOMPARE(errSpy.count(), 1);
    QVERIFY2(q.error().startsWith("instruments.hit.sample: "), qPrintable(q.error()));
}

// Edited while it plays, a v2 song goes on in the segment it was in.
void TestSongPlayer::v2HotReloadStaysInTheSegment()
{
    namespace cs = clay::sound;
    auto &eng = cs::AudioOutput::instance().engine();
    QTemporaryDir dir;
    QFile demo(CLAY_SOUND_DEMO_ADAPTIVE);
    QVERIFY(demo.open(QIODevice::ReadOnly));
    const QByteArray original = demo.readAll();
    const QString path = writeSong(dir, original);

    SongPlayer p;
    p.setState("combat");
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY(p.loaded());
    p.play();
    std::vector<float> pass(882);
    for (int i = 0; i < 40; ++i) {          // 0.8 s: beat 1.6 of combat
        eng.renderOffline(pass.data(), 882);
        QMetaObject::invokeMethod(&p, "tick");
    }
    QCOMPARE(p.segment(), QStringLiteral("combat"));
    QVERIFY(p.position() > 1.0);

    QSignalSpy hotSpy(&p, &SongPlayer::hotReloaded);
    QByteArray edited = original;
    edited.replace("\"tempo\": 120", "\"tempo\": 100");
    QVERIFY(!writeSong(dir, edited).isEmpty());
    QVERIFY(waitUntil([&] { return hotSpy.count() > 0; }, 5000));
    QCOMPARE(p.tempo(), 100.0);
    QCOMPARE(p.segment(), QStringLiteral("combat"));
    QVERIFY(p.playing());
    QVERIFY(p.position() > 1.0);
    p.stop();
}

QTEST_MAIN(TestSongPlayer)
#include "tst_song_player.moc"
