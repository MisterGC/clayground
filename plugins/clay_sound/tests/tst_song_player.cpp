// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongPlayer tests — drive the player against a fake recording
// instrument and verify correct triggerNote() calls in the correct
// order.

#include "song_player.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QVariantList>

class FakeInstrument : public QObject
{
    Q_OBJECT
public:
    struct Call { int midi; qreal vel; qreal durSec; };
    QVector<Call> calls;

    Q_INVOKABLE void triggerNote(int midiNote, qreal velocity, qreal durationSeconds)
    {
        calls.push_back({ midiNote, velocity, durationSeconds });
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

QTEST_MAIN(TestSongPlayer)
#include "tst_song_player.moc"
