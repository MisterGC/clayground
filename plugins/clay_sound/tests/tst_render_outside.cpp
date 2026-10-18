// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The engine outside QML (#429): clay_sound_render_demo, built against
// Clayground::SoundEngine alone, renders the plugin demo's recipe and
// song to wav. Each file holds the samples the QML players' offline
// render returns for the same input - the recipe for every seed of its
// pool through SfxPlayer.renderOffline(seed), the song through
// SongPlayer.renderOffline() with the demo's two SynthInstruments.
// Equality is sample for sample, between renders on the same machine.

#include "sfx_player.h"
#include "song_player.h"
#include "synth_instrument.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QProcess>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QTemporaryDir>

#include <cstring>
#include <memory>

class TestRenderOutside : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void recipeMatchesSfxPlayerForEverySeed();
    void songMatchesSongPlayer();

private:
    QTemporaryDir out_;
    QQmlEngine qml_;
    std::unique_ptr<QObject> scene_;
    QList<int> seeds_;
};

// The samples of a mono 32-bit float wav as writeWav() writes it.
static QVector<float> readFloatWav(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    const QByteArray b = f.readAll();
    if (b.size() < 44 || !b.startsWith("RIFF") || b.mid(8, 4) != "WAVE") return {};
    const auto u16 = [&](int at) { return quint16(quint8(b[at]) | quint8(b[at + 1]) << 8); };
    if (u16(20) != 3 || u16(22) != 1 || u16(34) != 32 || b.mid(36, 4) != "data") return {};
    QVector<float> s((b.size() - 44) / 4);
    std::memcpy(s.data(), b.constData() + 44, size_t(s.size()) * 4);
    return s;
}

static void compareSamples(const QVector<float> &outside, const QVector<float> &qml)
{
    QVERIFY(!qml.isEmpty());
    QCOMPARE(outside.size(), qml.size());
    for (int i = 0; i < qml.size(); ++i) {
        if (outside[i] != qml[i])
            QFAIL(qPrintable(QStringLiteral("sample %1: %2 outside, %3 in QML")
                                 .arg(i).arg(outside[i], 0, 'g', 9).arg(qml[i], 0, 'g', 9)));
    }
}

void TestRenderOutside::initTestCase()
{
    QVERIFY(out_.isValid());
    qmlRegisterType<SynthInstrument>("ClayOutsideTest", 1, 0, "SynthInstrument");
    qmlRegisterType<SongPlayer>("ClayOutsideTest", 1, 0, "SongPlayer");
    qmlRegisterType<SfxPlayer>("ClayOutsideTest", 1, 0, "SfxPlayer");

    // The demo's song instruments, as demo/Sandbox.qml declares them
    // with its volume slider at 0.8.
    QQmlComponent c(&qml_);
    // fromLocalFile, not "file://" + path: a Windows path would parse
    // as a host there (file://D:/... -> //d/...).
    const QString qmlText = QStringLiteral(R"(
        import QtQml
        import ClayOutsideTest
        QtObject {
            property SynthInstrument lead: SynthInstrument {
                objectName: "demoLead"
                waveform: "triangle"
                attack: 0.005; decay: 0.08; sustain: 0.5; release: 0.15
                volume: 0.8
            }
            property SynthInstrument bass: SynthInstrument {
                objectName: "demoBass"
                waveform: "sawtooth"
                attack: 0.01; decay: 0.1; sustain: 0.6; release: 0.2
                volume: 0.8 * 0.6
            }
            property SongPlayer song: SongPlayer {
                source: "%1"
                instruments: [lead, bass]
            }
            property SfxPlayer detent: SfxPlayer {
                source: "%2"
            }
        })").arg(QUrl::fromLocalFile(CLAY_SOUND_DEMO_SONG).toString(),
                 QUrl::fromLocalFile(CLAY_SOUND_DEMO_SFX).toString());
    c.setData(qmlText.toUtf8(), QUrl());
    scene_.reset(c.create());
    QVERIFY2(scene_, qPrintable(c.errorString()));

    auto *detent = scene_->property("detent").value<SfxPlayer *>();
    QVERIFY(detent && detent->loaded());
    QCOMPARE(detent->pool(), 6);
    QStringList args{ out_.path(), CLAY_SOUND_DEMO_SFX, CLAY_SOUND_DEMO_SONG };
    for (int i = 0; i < detent->pool(); ++i) {
        seeds_ << detent->variationSeed(i);
        args << QString::number(seeds_.last());
    }

    QProcess render;
    render.start(CLAY_SOUND_RENDER_DEMO, args);
    QVERIFY(render.waitForFinished(30000));
    QVERIFY2(render.exitStatus() == QProcess::NormalExit && render.exitCode() == 0,
             render.readAllStandardError().constData());
}

void TestRenderOutside::recipeMatchesSfxPlayerForEverySeed()
{
    auto *detent = scene_->property("detent").value<SfxPlayer *>();
    for (int seed : std::as_const(seeds_)) {
        const QVector<float> outside =
            readFloatWav(out_.filePath(QStringLiteral("recipe-%1.wav").arg(seed)));
        compareSamples(outside, detent->renderOffline(seed));
        if (QTest::currentTestFailed()) return;
    }
    // Two seeds of the pool sound different, so equality says something.
    QVERIFY(detent->renderOffline(seeds_[0]) != detent->renderOffline(seeds_[1]));
}

void TestRenderOutside::songMatchesSongPlayer()
{
    auto *song = scene_->property("song").value<SongPlayer *>();
    QVERIFY(song && song->loaded());
    const QVector<float> qml = song->renderOffline();
    // 4 repeats of a 4-beat pattern at 110 bpm.
    QCOMPARE(qml.size(), qRound(16 * 60.0 / 110.0 * 44100));
    compareSamples(readFloatWav(out_.filePath("song.wav")), qml);
}

QTEST_MAIN(TestRenderOutside)
#include "tst_render_outside.moc"
