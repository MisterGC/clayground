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

QTEST_MAIN(TestSongParser)
#include "tst_song_parser.moc"
