// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SynthInstrument::bake() — synth-to-sample WAV bounce.

#include "synth_instrument.h"
#include "engine/pcm_buffer.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QFileInfo>

class TestSynthBake : public QObject
{
    Q_OBJECT

private slots:
    void returnsExistingWavForSameInputs();
    void differentParamsProduceDifferentFiles();
    void rejectsBadInputs();
};

void TestSynthBake::returnsExistingWavForSameInputs()
{
    SynthInstrument s;
    s.setWaveform("square");
    s.setAttack(0.005);
    s.setRelease(0.05);

    const QString path1 = s.bake(69, 0.25);
    QVERIFY2(!path1.isEmpty(), "bake() returned empty path");
    QVERIFY(path1.endsWith(".wav"));
    QVERIFY(QFileInfo::exists(path1));

    std::string err;
    auto loaded = clay::sound::PcmBuffer::loadWav(path1.toStdString(), &err);
    QVERIFY2(loaded.has_value(), err.c_str());
    QCOMPARE(loaded->sampleRate, 44100);
    QCOMPARE(loaded->samples.size(), size_t(44100 / 4));

    const QString path2 = s.bake(69, 0.25);
    QCOMPARE(path2, path1);
}

void TestSynthBake::differentParamsProduceDifferentFiles()
{
    SynthInstrument s;
    s.setWaveform("square");
    const QString pA = s.bake(69, 0.25);
    s.setWaveform("sine");
    const QString pB = s.bake(69, 0.25);
    QVERIFY(!pA.isEmpty());
    QVERIFY(!pB.isEmpty());
    QVERIFY(pA != pB);

    s.setWaveform("sine");
    const QString pC = s.bake(72, 0.25);
    QVERIFY(pC != pB);
}

void TestSynthBake::rejectsBadInputs()
{
    SynthInstrument s;
    QVERIFY(s.bake(60, 0.0).isEmpty());
    QVERIFY(s.bake(60, -1.0).isEmpty());
    QVERIFY(s.bake(-1, 0.25).isEmpty());
    QVERIFY(s.bake(200, 0.25).isEmpty());
}

QTEST_MAIN(TestSynthBake)
#include "tst_synth_bake.moc"
