// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The stereo mix, measured (#425): pan gains per channel, bus volumes
// and gain stages as amplitude ratios of the tone each instrument
// plays, against the same tone unscaled. Two tones of different pitch
// tell two instruments apart in one render. Sample equality is only
// asserted between renders on the same machine, never against bytes.

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/instrument.h"
#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "sound_mixer.h"
#include "synth_instrument.h"

#include <QtTest/QtTest>
#include <QSignalSpy>
#include <cmath>
#include <complex>
#include <memory>
#include <vector>

namespace cs = clay::sound;

static constexpr int    kRate = 44100;
static constexpr double kPi   = 3.14159265358979323846;

// 100 Hz and 300 Hz divide 44.1 kHz, so a window of whole periods puts
// each on a DFT bin of its own and the other tone contributes nothing.
static constexpr double kLow  = 100.0;
static constexpr double kHigh = 300.0;

// One channel (0 = left, 1 = right) of an interleaved stereo buffer.
static std::vector<float> channel(const std::vector<float> &stereo, int ch)
{
    std::vector<float> out(stereo.size() / 2);
    for (size_t i = 0; i < out.size(); ++i) out[i] = stereo[2 * i + ch];
    return out;
}

// Amplitude of `freq` in buf[from, from + n).
static double amplitudeAt(const std::vector<float> &buf, int from, int n, double freq)
{
    std::complex<double> acc = 0.0;
    for (int i = 0; i < n; ++i) {
        const double w = 2.0 * kPi * freq * i / kRate;
        acc += static_cast<double>(buf[from + i]) * std::complex<double>(std::cos(w), -std::sin(w));
    }
    return 2.0 * std::abs(acc) / n;
}

// Steady-state window: past the attack, whole periods of both tones.
static constexpr int kFrom = 2205;      // 0.05 s
static constexpr int kLen  = 8820;      // 0.2 s

static double amp(const std::vector<float> &stereo, int ch, double freq)
{
    return amplitudeAt(channel(stereo, ch), kFrom, kLen, freq);
}

// A flat amplitude envelope, so the level is the mix's alone.
static void flatSine(SynthInstrument &s)
{
    s.setWaveform("sine");
    s.setAttack(0.0);
    s.setDecay(0.0);
    s.setSustain(1.0);
    s.setRelease(0.0);
    s.setVolume(1.0);
}

static cs::Engine &sharedEngine() { return cs::AudioOutput::instance().engine(); }

static std::vector<float> renderStereo(cs::Engine &eng, double seconds)
{
    const int frames = static_cast<int>(std::lround(seconds * kRate));
    std::vector<float> out(2 * static_cast<size_t>(frames));
    eng.renderStereo(out.data(), frames);
    return out;
}

static constexpr double kSeconds = 0.3;
static constexpr double kVel     = 0.5;

// Amplitude a centred flat sine at kVel renders in each channel.
static double centredAmplitude(double freq)
{
    SynthInstrument s;
    flatSine(s);
    s.trigger(freq, kVel, kSeconds);
    return amp(renderStereo(sharedEngine(), kSeconds), 0, freq);
}

class SoundMixTest : public QObject
{
    Q_OBJECT
private slots:
    void defaults();
    void centredStereoIsTheMonoRender();
    void panLawPerChannel();
    void panMovesARingingNote();
    void notePanAddsToInstrumentPan();
    void busVolumeScalesItsBusOnly();
    void unknownBusIsRejected();
    void mixerClampsAndSignals();
    void gainStageScalesItsNotesOnly();
    void gainStageFadesARingingNote();
    void sameNoteRendersSameSamples();
    void cleanup();
};

void SoundMixTest::cleanup()
{
    // The buses belong to the process-wide engine; leave them as found.
    for (cs::Bus b : {cs::Bus::Sfx, cs::Bus::Music, cs::Bus::Voice})
        sharedEngine().setBusGain(b, 1.0f);
}

void SoundMixTest::defaults()
{
    SynthInstrument s;
    QCOMPARE(s.pan(), 0.0);
    QCOMPARE(s.bus(), QString("sfx"));
    SoundMixer m;
    QCOMPARE(m.sfxVolume(), 1.0);
    QCOMPARE(m.musicVolume(), 1.0);
    QCOMPARE(m.voiceVolume(), 1.0);
}

void SoundMixTest::centredStereoIsTheMonoRender()
{
    // The issue's criterion: mono content plays centred and unchanged.
    // Same note twice on one engine: once rendered stereo, once mono.
    // Both channels of the first carry exactly the samples of the second.
    SynthInstrument s;
    s.setWaveform("sawtooth");
    s.setVolume(0.8);
    const int frames = static_cast<int>(kSeconds * kRate);

    s.trigger(220.0, kVel, kSeconds);
    std::vector<float> stereo(2 * static_cast<size_t>(frames));
    sharedEngine().renderStereo(stereo.data(), frames);

    s.trigger(220.0, kVel, kSeconds);
    std::vector<float> mono(static_cast<size_t>(frames));
    sharedEngine().renderOffline(mono.data(), frames);

    QVERIFY(amplitudeAt(mono, kFrom, kLen, 220.0) > 0.1);
    QCOMPARE(channel(stereo, 0), mono);
    QCOMPARE(channel(stereo, 1), mono);
}

void SoundMixTest::panLawPerChannel()
{
    const double ref = centredAmplitude(kLow);
    QVERIFY(ref > 0.1);

    // pan -> expected gain left, right (balance law, centre unity).
    const struct { double pan, left, right; } cases[] = {
        {-1.0,  1.0,  0.0},
        {-0.25, 1.0,  0.75},
        { 0.5,  0.5,  1.0},
        { 1.0,  0.0,  1.0},
    };
    for (const auto &c : cases) {
        SynthInstrument s;
        flatSine(s);
        s.setPan(c.pan);
        s.trigger(kLow, kVel, kSeconds);
        const auto buf = renderStereo(sharedEngine(), kSeconds);
        const double l = amp(buf, 0, kLow) / ref;
        const double r = amp(buf, 1, kLow) / ref;
        QVERIFY2(std::abs(l - c.left) < 1e-3 && std::abs(r - c.right) < 1e-3,
                 qPrintable(QString("pan %1: left %2 right %3, expected %4 %5")
                                .arg(c.pan).arg(l).arg(r).arg(c.left).arg(c.right)));
    }

    SynthInstrument s;
    s.setPan(-3.0);
    QCOMPARE(s.pan(), -1.0);
}

void SoundMixTest::panMovesARingingNote()
{
    SynthInstrument s;
    flatSine(s);
    s.trigger(kLow, kVel, 2 * kSeconds);
    const auto before = renderStereo(sharedEngine(), kSeconds);
    s.setPan(1.0);
    const auto after = renderStereo(sharedEngine(), kSeconds);
    QVERIFY(amp(before, 0, kLow) > 0.1);
    QVERIFY(amp(after, 0, kLow) < 1e-6);
    QVERIFY(std::abs(amp(after, 1, kLow) - amp(before, 1, kLow)) < 1e-3);
}

void SoundMixTest::notePanAddsToInstrumentPan()
{
    cs::Engine eng(kRate);
    auto osc = std::make_unique<cs::OscillatorInstrument>();
    cs::OscillatorVoice::Patch flat;
    flat.attack = 0.0; flat.decay = 0.0; flat.sustain = 1.0; flat.release = 0.0;
    osc->setDefaultPatch(flat);
    osc->setPan(0.5);
    const int id = eng.addInstrument(std::move(osc));

    auto play = [&](float notePan) {
        cs::NoteEvent ev;
        ev.instrumentId = id;
        ev.timeFrames = eng.currentFrame();
        ev.durationFrames = static_cast<int64_t>(kSeconds * kRate);
        ev.freqHz = kLow;
        ev.velocity = kVel;
        ev.pan = notePan;
        eng.schedule(ev);
        return renderStereo(eng, kSeconds);
    };
    const auto centred = play(-0.5);     // 0.5 + -0.5 = centre
    const auto right   = play(0.75);     // 0.5 + 0.75, clamped to +1
    const double ref = amp(centred, 1, kLow);
    QVERIFY(ref > 0.1);
    QVERIFY(std::abs(amp(centred, 0, kLow) - ref) < 1e-6);
    QVERIFY(amp(right, 0, kLow) < 1e-6);
    QVERIFY(std::abs(amp(right, 1, kLow) - ref) < 1e-6);
}

void SoundMixTest::busVolumeScalesItsBusOnly()
{
    const double refLow  = centredAmplitude(kLow);
    const double refHigh = centredAmplitude(kHigh);

    SynthInstrument music;
    flatSine(music);
    music.setBus("music");
    QCOMPARE(music.bus(), QString("music"));
    SynthInstrument sfx;
    flatSine(sfx);

    SoundMixer m;
    m.setMusicVolume(0.25);
    music.trigger(kLow, kVel, kSeconds);
    sfx.trigger(kHigh, kVel, kSeconds);
    const auto buf = renderStereo(sharedEngine(), kSeconds);
    for (int ch : {0, 1}) {
        QVERIFY(std::abs(amp(buf, ch, kLow) / refLow - 0.25) < 1e-3);
        QVERIFY(std::abs(amp(buf, ch, kHigh) / refHigh - 1.0) < 1e-3);
    }

    // The bus volume multiplies the instrument's own, and the voice bus
    // is a bus of its own.
    SynthInstrument voice;
    flatSine(voice);
    voice.setVolume(0.5);
    voice.setBus("voice");
    m.setVoiceVolume(0.5);
    m.setSfxVolume(0.0);
    voice.trigger(kLow, kVel, kSeconds);
    sfx.trigger(kHigh, kVel, kSeconds);
    const auto buf2 = renderStereo(sharedEngine(), kSeconds);
    QVERIFY(std::abs(amp(buf2, 0, kLow) / refLow - 0.25) < 1e-3);
    QVERIFY(amp(buf2, 0, kHigh) < 1e-6);
}

void SoundMixTest::unknownBusIsRejected()
{
    SynthInstrument s;
    QSignalSpy spy(&s, &SynthInstrument::busChanged);
    QTest::ignoreMessage(QtWarningMsg, QRegularExpression("unknown bus"));
    s.setBus("drums");
    QCOMPARE(s.bus(), QString("sfx"));
    QCOMPARE(spy.count(), 0);
    s.setBus("voice");
    QCOMPARE(spy.count(), 1);
}

void SoundMixTest::mixerClampsAndSignals()
{
    SoundMixer m;
    QSignalSpy spy(&m, &SoundMixer::musicVolumeChanged);
    m.setMusicVolume(2.0);
    QCOMPARE(m.musicVolume(), 1.0);
    QCOMPARE(spy.count(), 0);           // already 1
    m.setMusicVolume(-1.0);
    QCOMPARE(m.musicVolume(), 0.0);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(sharedEngine().busGain(cs::Bus::Music), 0.0f);
    // The volumes are the engine's, so a second mixer sees the same.
    SoundMixer other;
    QCOMPARE(other.musicVolume(), 0.0);
}

void SoundMixTest::gainStageScalesItsNotesOnly()
{
    // A SongPlayer names its gain stage around the triggerNote() it
    // sends; a note triggered inside that scope carries the stage.
    const double refLow  = centredAmplitude(kLow);
    const double refHigh = centredAmplitude(kHigh);
    const int stage = sharedEngine().addGainStage(0.4f);

    SynthInstrument s;
    flatSine(s);
    {
        const cs::AudioOutput::TriggerGainStage scope(stage);
        QCOMPARE(cs::AudioOutput::instance().triggerGainStage(), stage);
        s.trigger(kLow, kVel, kSeconds);
    }
    QCOMPARE(cs::AudioOutput::instance().triggerGainStage(), -1);
    s.trigger(kHigh, kVel, kSeconds);

    const auto buf = renderStereo(sharedEngine(), kSeconds);
    QVERIFY(std::abs(amp(buf, 0, kLow) / refLow - 0.4) < 1e-3);
    QVERIFY(std::abs(amp(buf, 0, kHigh) / refHigh - 1.0) < 1e-3);
}

void SoundMixTest::gainStageFadesARingingNote()
{
    const int stage = sharedEngine().addGainStage();
    SynthInstrument s;
    flatSine(s);
    {
        const cs::AudioOutput::TriggerGainStage scope(stage);
        s.trigger(kLow, kVel, 2 * kSeconds);
    }
    const auto before = renderStereo(sharedEngine(), kSeconds);
    sharedEngine().setGainStage(stage, 0.5f);
    const auto after = renderStereo(sharedEngine(), kSeconds);
    QVERIFY(amp(before, 0, kLow) > 0.1);
    QVERIFY(std::abs(amp(after, 0, kLow) / amp(before, 0, kLow) - 0.5) < 1e-3);
}

void SoundMixTest::sameNoteRendersSameSamples()
{
    // Determinism of the stereo mix on one machine: a panned note on a
    // bus at reduced volume renders the same samples twice.
    SynthInstrument s;
    s.setWaveform("square");
    s.setPan(-0.3);
    s.setBus("music");
    SoundMixer m;
    m.setMusicVolume(0.7);
    s.trigger(330.0, kVel, kSeconds);
    const auto a = renderStereo(sharedEngine(), kSeconds);
    s.trigger(330.0, kVel, kSeconds);
    const auto b = renderStereo(sharedEngine(), kSeconds);
    QCOMPARE(a, b);
}

QTEST_MAIN(SoundMixTest)
#include "tst_sound_mix.moc"
