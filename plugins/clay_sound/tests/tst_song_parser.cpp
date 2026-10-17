// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song/song_parser.h"

#include <QtTest/QtTest>

using clay::sound::SongParser;
using clay::sound::SongModel;
using clay::sound::Pattern;

class TestSongParser : public QObject
{
    Q_OBJECT

private slots:
    void noteNames();
    void noteNamesOutOfRange();
    void minimalHappyPath();
    void defaultsAppliedForDurVel();
    void midiNumberAccepted();
    void missingTempoFails();
    void unknownTopLevelKeyFails();
    void unknownEventKeyFails();
    void patternReferencesUnknownTrackFails();
    void sectionReferencesUnknownPatternFails();
    void defaultSectionsFromPatternsWhenOmitted();
    void repeatClampsToOne();
    void negativeTimeFails();
    void zeroDurationFails();
    void velOutOfRangeFails();

    void v2DefinesItsInstruments();
    void v2Structure();
    void v2WithoutSegmentsPlaysOneSegment();
    void v2KeysNeedVersion2();
    void v2Errors_data();
    void v2Errors();
};

void TestSongParser::noteNames()
{
    int m = -1;
    QVERIFY(SongParser::parseNote("C4", &m));  QCOMPARE(m, 60);
    QVERIFY(SongParser::parseNote("A4", &m));  QCOMPARE(m, 69);
    QVERIFY(SongParser::parseNote("C-1", &m)); QCOMPARE(m, 0);
    QVERIFY(SongParser::parseNote("G9", &m));  QCOMPARE(m, 127);
    QVERIFY(SongParser::parseNote("F#3", &m)); QCOMPARE(m, 54);
    QVERIFY(SongParser::parseNote("Bb4", &m)); QCOMPARE(m, 70);
    QVERIFY(SongParser::parseNote("c5", &m));  QCOMPARE(m, 72);
}

void TestSongParser::noteNamesOutOfRange()
{
    int m = -1;
    QVERIFY(!SongParser::parseNote("C10", &m));
    QVERIFY(!SongParser::parseNote("Cb-1", &m));
    QVERIFY(!SongParser::parseNote("H4", &m));
    QVERIFY(!SongParser::parseNote("", &m));
}

void TestSongParser::minimalHappyPath()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "lead": { "instrument": "leadSynth" } },
        "patterns": {
          "A": {
            "lead": [
              { "t": 0,   "note": "C4", "dur": 0.5, "vel": 0.8 },
              { "t": 0.5, "note": 64,   "dur": 0.5 }
            ]
          }
        },
        "sections": [ { "pattern": "A", "repeat": 2 } ]
    })";
    const auto r = SongParser::parse(json);
    QVERIFY2(r.ok, qPrintable(r.error));
    QCOMPARE(r.model.tempo, 120.0);
    QVERIFY(r.model.tracks.contains("lead"));
    QCOMPARE(r.model.tracks["lead"].instrument, QStringLiteral("leadSynth"));
    QVERIFY(r.model.patterns.contains("A"));
    const Pattern p = r.model.patterns.value("A");
    const auto events = p.trackEvents.value("lead");
    QCOMPARE(events.size(), 2);
    QCOMPARE(events.at(0).midi, 60);
    QCOMPARE(events.at(1).midi, 64);
    QCOMPARE(r.model.sections.size(), 1);
    QCOMPARE(r.model.sections.at(0).patternName, QStringLiteral("A"));
    QCOMPARE(r.model.sections.at(0).repeat, 2);
}

void TestSongParser::defaultsAppliedForDurVel()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": "C4" } ] } }
    })";
    const auto r = SongParser::parse(json);
    QVERIFY2(r.ok, qPrintable(r.error));
    const Pattern p = r.model.patterns.value("A");
    const auto events = p.trackEvents.value("l");
    QCOMPARE(events.size(), 1);
    QCOMPARE(events.first().dur, 0.5);
    QCOMPARE(events.first().vel, 0.8);
}

void TestSongParser::midiNumberAccepted()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": 72 } ] } }
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(r.ok);
    QCOMPARE(r.model.patterns.value("A").trackEvents.value("l").at(0).midi, 72);
}

void TestSongParser::missingTempoFails()
{
    const QByteArray json = R"({ "tracks": { "l": { "instrument": "x" } } })";
    const auto r = SongParser::parse(json);
    QVERIFY(!r.ok);
    QVERIFY(r.error.contains("tempo"));
}

void TestSongParser::unknownTopLevelKeyFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "typo": 1
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(!r.ok);
    QVERIFY(r.error.contains("typo"));
}

void TestSongParser::unknownEventKeyFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": "C4", "typo": 1 } ] } }
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(!r.ok);
    QVERIFY(r.error.contains("typo"));
}

void TestSongParser::patternReferencesUnknownTrackFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "lead": { "instrument": "x" } },
        "patterns": { "A": { "bass": [ { "t": 0, "note": "C4" } ] } }
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(!r.ok);
    QVERIFY(r.error.contains("bass"));
}

void TestSongParser::sectionReferencesUnknownPatternFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "sections": [ { "pattern": "Z" } ]
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(!r.ok);
    QVERIFY(r.error.contains("Z"));
}

void TestSongParser::defaultSectionsFromPatternsWhenOmitted()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": {
          "A": { "l": [ { "t": 0, "note": "C4" } ] },
          "B": { "l": [ { "t": 0, "note": "D4" } ] }
        }
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(r.ok);
    QCOMPARE(r.model.sections.size(), 2);
    QCOMPARE(r.model.sections.at(0).repeat, 1);
    QCOMPARE(r.model.sections.at(1).repeat, 1);
}

void TestSongParser::repeatClampsToOne()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": "C4" } ] } },
        "sections": [ { "pattern": "A", "repeat": 0 } ]
    })";
    const auto r = SongParser::parse(json);
    QVERIFY(r.ok);
    QCOMPARE(r.model.sections.at(0).repeat, 1);
}

void TestSongParser::negativeTimeFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": -1, "note": "C4" } ] } }
    })";
    QVERIFY(!SongParser::parse(json).ok);
}

void TestSongParser::zeroDurationFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": "C4", "dur": 0 } ] } }
    })";
    QVERIFY(!SongParser::parse(json).ok);
}

void TestSongParser::velOutOfRangeFails()
{
    const QByteArray json = R"({
        "tempo": 120,
        "tracks": { "l": { "instrument": "x" } },
        "patterns": { "A": { "l": [ { "t": 0, "note": "C4", "vel": 1.5 } ] } }
    })";
    QVERIFY(!SongParser::parse(json).ok);
}

// A v2 song with every key, its numbers in the file's units.
static const QByteArray kV2Song = R"({
    "version": 2,
    "tempo": 120,
    "beatsPerBar": 3,
    "instruments": {
      "lead": { "source": "square", "pulseWidth": 0.25,
                "envelope": { "attack": 5, "decay": 120, "sustain": 0.5, "release": 80 },
                "filter": { "type": "lowpass", "cutoff": 2400, "resonance": 0.3 },
                "lfo": { "target": "pitch", "rate": 5, "depth": 0.2 },
                "gain": -6, "pan": -0.5, "maxVoices": 3 },
      "kit": { "source": "sample", "sample": "kit/kick.wav", "root": "C3",
               "interpolation": "gaussian", "loop": { "start": 0.25, "end": 0.75 },
               "envelope": { "release": 40 }, "bus": "sfx" }
    },
    "tracks": { "melody": { "instrument": "lead" }, "drums": { "instrument": "kit" } },
    "patterns": {
      "Calm":  { "melody": [ { "t": 0, "note": "C4", "dur": 4 } ] },
      "Fight": { "melody": [ { "t": 0, "note": "C5", "dur": 1 } ],
                 "drums":  [ { "t": 0, "note": "C3", "dur": 1 } ] },
      "Hit":   { "melody": [ { "t": 0, "note": "G5", "dur": 0.5 } ] }
    },
    "segments": {
      "calm":  { "sections": [ { "pattern": "Calm", "repeat": 2 } ], "exits": [3, 6] },
      "fight": { "sections": [ { "pattern": "Fight" } ], "next": "calm" }
    },
    "start": "calm",
    "layers": { "beat": { "tracks": ["drums"], "intensity": [0.25, 0.75], "fade": 2 } },
    "transitions": [ { "from": "calm", "to": "fight", "sync": "exit", "stinger": "hit" },
                     { "to": "calm", "sync": "end" } ],
    "stingers": { "hit": { "pattern": "Hit" } }
})";

void TestSongParser::v2DefinesItsInstruments()
{
    using clay::sound::InstrumentSpec;
    using clay::sound::Bus;
    const auto r = SongParser::parse(kV2Song);
    QVERIFY2(r.ok, qPrintable(r.error));
    QCOMPARE(r.model.version, 2);
    QCOMPARE(r.model.tracks.value("melody").instrument, QStringLiteral("lead"));

    const auto lead = r.model.instruments.value("lead");
    QCOMPARE(lead.spec.kind, InstrumentSpec::Kind::Synth);
    QCOMPARE(lead.spec.synth.waveform, clay::sound::OscillatorVoice::Waveform::Square);
    QCOMPARE(lead.spec.synth.pulseWidth, 0.25);
    QCOMPARE(lead.spec.synth.attack, 0.005);      // ms in the file, seconds in the patch
    QCOMPARE(lead.spec.synth.decay, 0.12);
    QCOMPARE(lead.spec.synth.sustain, 0.5);
    QCOMPARE(lead.spec.synth.release, 0.08);
    QCOMPARE(lead.spec.synth.filterType, clay::sound::OscillatorVoice::FilterType::LowPass);
    QCOMPARE(lead.spec.synth.cutoff, 2400.0);
    QCOMPARE(lead.spec.synth.resonance, 0.3);
    QCOMPARE(lead.spec.synth.lfoTarget, 1);
    QVERIFY(qAbs(lead.spec.gain - 0.501187f) < 1e-5f);   // -6 dB
    QCOMPARE(lead.spec.pan, -0.5f);
    QCOMPARE(lead.spec.bus, Bus::Music);                 // a song's instruments default to music
    QCOMPARE(lead.spec.maxVoices, 3);
    QVERIFY(lead.sample.isEmpty());

    const auto kit = r.model.instruments.value("kit");
    QCOMPARE(kit.spec.kind, InstrumentSpec::Kind::Sampler);
    QCOMPARE(kit.sample, QStringLiteral("kit/kick.wav"));
    QVERIFY(!kit.spec.sample);                           // decoded by whoever loads the song
    QCOMPARE(kit.spec.rootMidiNote, 48);
    QCOMPARE(kit.spec.sampler.interpolation, clay::sound::SampleVoice::Interpolation::Gaussian);
    QVERIFY(kit.spec.sampler.looping);
    QCOMPARE(kit.spec.sampler.loopStartFrac, 0.25);
    QCOMPARE(kit.spec.sampler.loopEndFrac, 0.75);
    QCOMPARE(kit.spec.sampler.release, 0.04);
    QCOMPARE(kit.spec.gain, 1.0f);                       // 0 dB
    QCOMPARE(kit.spec.bus, Bus::Sfx);
}

void TestSongParser::v2Structure()
{
    using clay::sound::SongSync;
    const auto r = SongParser::parse(kV2Song);
    QVERIFY2(r.ok, qPrintable(r.error));
    const auto &m = r.model;
    QCOMPARE(m.beatsPerBar, 3);
    // A v2 pattern lasts whole bars: 4 beats round up to 2 bars of 3.
    QCOMPARE(clay::sound::patternBeats(m, "Calm"), 6.0);
    QCOMPARE(clay::sound::patternBeats(m, "Fight"), 3.0);
    QCOMPARE(clay::sound::segmentBeats(m, "calm"), 12.0);

    QCOMPARE(m.segments.size(), 2);
    QCOMPARE(m.start, QStringLiteral("calm"));
    QCOMPARE(m.segments.value("calm").next, QStringLiteral("calm"));   // itself by default
    QCOMPARE(m.segments.value("fight").next, QStringLiteral("calm"));
    QCOMPARE(m.segments.value("calm").exits, (QVector<double>{3, 6}));
    QCOMPARE(m.segments.value("calm").sections.at(0).repeat, 2);
    QVERIFY(m.sections.isEmpty());

    const auto beat = m.layers.value("beat");
    QCOMPARE(beat.tracks, QStringList{"drums"});
    QCOMPARE(beat.low, 0.25);
    QCOMPARE(beat.high, 0.75);
    QCOMPARE(beat.fade, 2.0);

    QCOMPARE(m.transitions.size(), 2);
    QCOMPARE(m.transitions.at(0).from, QStringLiteral("calm"));
    QCOMPARE(m.transitions.at(0).sync, SongSync::Exit);
    QCOMPARE(m.transitions.at(0).stinger, QStringLiteral("hit"));
    QVERIFY(m.transitions.at(1).from.isEmpty());
    QCOMPARE(m.transitions.at(1).sync, SongSync::End);
    QCOMPARE(m.stingers.value("hit").pattern, QStringLiteral("Hit"));
    QCOMPARE(m.stingers.value("hit").sync, SongSync::Beat);
}

void TestSongParser::v2WithoutSegmentsPlaysOneSegment()
{
    const auto r = SongParser::parse(R"({
        "version": 2, "tempo": 100,
        "instruments": { "i": { "source": "sine" } },
        "tracks": { "t": { "instrument": "i" } },
        "patterns": { "A": { "t": [ { "t": 0, "note": 60, "dur": 1 } ] } },
        "sections": [ { "pattern": "A", "repeat": 3 } ]
    })");
    QVERIFY2(r.ok, qPrintable(r.error));
    QCOMPARE(r.model.start, QStringLiteral("main"));
    QCOMPARE(r.model.segments.size(), 1);
    QVERIFY(r.model.segments.value("main").next.isEmpty());   // the song ends after it
    QCOMPARE(clay::sound::segmentBeats(r.model, "main"), 12.0);
    // An instrument without numbers plays the default patch at unity.
    const auto spec = r.model.instruments.value("i").spec;
    QCOMPARE(spec.gain, 1.0f);
    QCOMPARE(spec.synth.attack, clay::sound::OscillatorVoice::Patch{}.attack);
}

void TestSongParser::v2KeysNeedVersion2()
{
    const auto r = SongParser::parse(R"({
        "tempo": 120,
        "instruments": { "i": { "source": "sine" } },
        "tracks": { "t": { "instrument": "i" } }
    })");
    QVERIFY(!r.ok);
    QVERIFY2(r.error.contains("unknown key 'instruments'"), qPrintable(r.error));

    const auto v1 = SongParser::parse(R"({ "version": 1, "tempo": 120,
        "tracks": { "t": { "instrument": "i" } } })");
    QVERIFY2(v1.ok, qPrintable(v1.error));
    QCOMPARE(v1.model.version, 1);

    QVERIFY(!SongParser::parse(R"({ "version": 3, "tempo": 120,
        "tracks": { "t": { "instrument": "i" } } })").ok);
}

void TestSongParser::v2Errors_data()
{
    QTest::addColumn<QByteArray>("edit");       // "<from>|<to>" applied to kV2Song
    QTest::addColumn<QString>("error");

    QTest::newRow("undefined instrument")
        << QByteArray(R"("instrument": "kit" }|"instrument": "drumkit" })")
        << "track 'drums' plays 'drumkit', which 'instruments' does not define";
    QTest::newRow("sample field on a synth")
        << QByteArray(R"("pulseWidth": 0.25,|"pulseWidth": 0.25, "root": 60,)")
        << "instruments.lead.root: belongs to a sample instrument";
    QTest::newRow("filter on a sample")
        << QByteArray(R"("bus": "sfx" }|"bus": "sfx", "filter": {} })")
        << "instruments.kit.filter: does not apply to a sample instrument";
    QTest::newRow("attack out of range")
        << QByteArray(R"("attack": 5,|"attack": -5,)")
        << "instruments.lead.envelope.attack: -5 is outside 0..10000";
    QTest::newRow("gain above unity")
        << QByteArray(R"("gain": -6,|"gain": 3,)")
        << "instruments.lead.gain: 3 is outside -96..0";
    QTest::newRow("unknown bus")
        << QByteArray(R"("bus": "sfx"|"bus": "fx")")
        << "instruments.kit.bus: unknown bus 'fx' (sfx, music, voice)";
    QTest::newRow("exit past the segment")
        << QByteArray(R"("exits": [3, 6]|"exits": [3, 12])")
        << "segments.calm.exits: every exit is a beat in 0..12 (the segment's length)";
    QTest::newRow("exits descend")
        << QByteArray(R"("exits": [3, 6]|"exits": [6, 3])")
        << "segments.calm.exits: exits must ascend";
    QTest::newRow("next unknown")
        << QByteArray(R"("next": "calm"|"next": "rest")")
        << "segments.fight.next: unknown segment 'rest'";
    QTest::newRow("no start")
        << QByteArray(R"("start": "calm",|)")
        << "start: a song of several segments names the one it starts in";
    QTest::newRow("sections beside segments")
        << QByteArray(R"("start": "calm",|"start": "calm", "sections": [],)")
        << "'sections' and 'segments' exclude each other: give each segment its sections";
    QTest::newRow("track in two layers")
        << QByteArray(R"("fade": 2 } }|"fade": 2 }, "more": { "tracks": ["drums"], "intensity": 1 } })")
        << "layers.more.tracks: track 'drums' is already in layer 'beat'";
    QTest::newRow("intensity reversed")
        << QByteArray(R"([0.25, 0.75]|[0.75, 0.25])")
        << "layers.beat.intensity: must lie in 0..1, low not above high";
    QTest::newRow("unknown sync")
        << QByteArray(R"("sync": "exit"|"sync": "phrase")")
        << "transitions[0].sync: unknown sync 'phrase' (beat, bar, exit, end)";
    QTest::newRow("unknown stinger")
        << QByteArray(R"("stinger": "hit"|"stinger": "boom")")
        << "transitions[0].stinger: unknown stinger 'boom'";
    QTest::newRow("stinger pattern unknown")
        << QByteArray(R"("pattern": "Hit" }|"pattern": "Miss" })")
        << "stingers.hit.pattern: unknown pattern 'Miss'";
}

void TestSongParser::v2Errors()
{
    QFETCH(QByteArray, edit);
    QFETCH(QString, error);
    const QList<QByteArray> parts = edit.split('|');
    QByteArray song = kV2Song;
    QVERIFY2(song.contains(parts.at(0)), parts.at(0).constData());
    song.replace(parts.at(0), parts.at(1));
    const auto r = SongParser::parse(song);
    QVERIFY(!r.ok);
    QCOMPARE(r.error, error);
}

QTEST_MAIN(TestSongParser)
#include "tst_song_parser.moc"
