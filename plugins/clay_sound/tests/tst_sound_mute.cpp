// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// CLAY_SOUND_MUTE=1 (#478): every output opens at volume 0 - the shared
// sink SfxPlayer, SongPlayer and Sound play through, SoftSynth's sink and
// Music's QAudioOutput - while the players still play, and an offline
// render does not change. A sink only exists where the machine has an
// output device; without one the sink checks are skipped, the rest runs.

#include "audio_devices.h"
#include "audio_output.h"
#include "music.h"
#include "sfx_player.h"
#include "softsynth.h"
#include "song_player.h"
#include "sound.h"

#include <QAudioOutput>
#include <QAudioSink>
#include <QtTest/QtTest>
#include <vector>

namespace cs = clay::sound;

class SoundMuteTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void playersPlayThroughASinkAtVolumeZero();
    void offlineRendersDoNotChange();
    void softSynthOpensItsSinkAtVolumeZero();
    void musicOutputReadsZeroAndKeepsItsVolume();
};

void SoundMuteTest::initTestCase()
{
    // Before anything opens an output: the variable is read on opening.
    qputenv("CLAY_SOUND_MUTE", "1");
    QVERIFY(cs::outputMuted());
}

void SoundMuteTest::playersPlayThroughASinkAtVolumeZero()
{
    auto &out = cs::AudioOutput::instance();

    SfxPlayer sfx;
    sfx.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_SFX));
    QVERIFY2(sfx.loaded(), qPrintable(sfx.error()));
    const int seed = sfx.play();
    QCOMPARE(seed, sfx.variationSeed(0));
    QCOMPARE(sfx.lastSeed(), seed);

    Sound sound;
    sound.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_WAV));
    QTRY_VERIFY(sound.loaded());
    QVERIFY(sound.triggerOneShot(1.0));

    SongPlayer song;
    song.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_ADAPTIVE));
    QVERIFY2(song.loaded(), qPrintable(song.error()));
    song.play();
    QVERIFY(song.playing());

    // Still mixed: a trigger starts its voice on the engine's next render,
    // whatever the sink's volume.
    std::vector<float> slice(64);
    out.engine().renderOffline(slice.data(), static_cast<int>(slice.size()));
    QVERIFY(sound.activeVoices() > 0);
    QVERIFY(out.engine().activeVoices() > size_t(sound.activeVoices()));

    if (!out.isRunning())
        QSKIP("no audio output device opened - no sink to read the volume of");
    auto *sink = out.findChild<QAudioSink *>();
    QVERIFY(sink);
    QCOMPARE(sink->volume(), 0.0);

    song.stop();
    sfx.stop();
    sound.stop();
}

void SoundMuteTest::offlineRendersDoNotChange()
{
    SfxPlayer sfx;
    sfx.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_SFX));
    QVERIFY2(sfx.loaded(), qPrintable(sfx.error()));
    Sound sound;
    sound.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_WAV));
    QTRY_VERIFY(sound.loaded());
    SongPlayer song;
    song.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_ADAPTIVE));
    QVERIFY2(song.loaded(), qPrintable(song.error()));

    const QVector<float> sfxMuted = sfx.renderOffline(sfx.variationSeed(0), 0.8);
    const QVector<float> soundMuted = sound.renderOffline(0.5);
    const QVector<float> songMuted = song.renderOffline(2.0);

    qunsetenv("CLAY_SOUND_MUTE");
    const QVector<float> sfxLoud = sfx.renderOffline(sfx.variationSeed(0), 0.8);
    const QVector<float> soundLoud = sound.renderOffline(0.5);
    const QVector<float> songLoud = song.renderOffline(2.0);
    qputenv("CLAY_SOUND_MUTE", "1");

    QVERIFY(!sfxLoud.isEmpty());
    QVERIFY(!soundLoud.isEmpty());
    QVERIFY(!songLoud.isEmpty());
    QCOMPARE(sfxMuted, sfxLoud);
    QCOMPARE(soundMuted, soundLoud);
    QCOMPARE(songMuted, songLoud);
}

void SoundMuteTest::softSynthOpensItsSinkAtVolumeZero()
{
    SoftSynth synth;
    synth.play();
    if (!synth.isPlaying())
        QSKIP("no audio output device opened - no sink to read the volume of");
    auto *sink = synth.findChild<QAudioSink *>();
    QVERIFY(sink);
    QCOMPARE(sink->volume(), 0.0);
    synth.stop();
}

void SoundMuteTest::musicOutputReadsZeroAndKeepsItsVolume()
{
    Music music;
    music.setVolume(0.8);
    auto *audioOut = music.findChild<QAudioOutput *>();
    QVERIFY(audioOut);
    QCOMPARE(audioOut->volume(), 0.0f);
    // What QML set stays what QML reads.
    QCOMPARE(music.volume(), 0.8);
}

QTEST_MAIN(SoundMuteTest)
#include "tst_sound_mute.moc"
