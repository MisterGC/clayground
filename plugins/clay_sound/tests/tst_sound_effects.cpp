// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The bus echo and reverb, measured on offline renders (#426): the
// echo's delay as the lag where the wet signal matches the dry one, its
// decay as the level ratio of successive repeats, the FIR as the gain
// of each repeat at two frequencies against the filter's computed
// response, and the reverb as the level of its tail over time. Every
// render is the (L + R) / 2 downmix of renderOffline. Sample equality
// is only asserted between renders on the same machine.

#include "audio_output.h"
#include "bus_effect_objects.h"
#include "engine/bus_effects.h"
#include "engine/engine.h"
#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "sound_mixer.h"
#include "synth_instrument.h"

#include <QtTest/QtTest>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <cmath>
#include <complex>
#include <memory>
#include <vector>

namespace cs = clay::sound;

static constexpr int    kRate = 44100;
static constexpr double kPi   = 3.14159265358979323846;
// The live sink pulls about this many frames per pass (20 ms).
static constexpr int    kChunk = 882;

static int frames(double seconds) { return static_cast<int>(std::lround(seconds * kRate)); }

// A fresh engine with one flat-envelope sine instrument on `bus`.
struct Rig
{
    cs::Engine eng{kRate};
    int id = -1;

    explicit Rig(cs::Bus bus = cs::Bus::Sfx)
    {
        auto osc = std::make_unique<cs::OscillatorInstrument>();
        cs::OscillatorVoice::Patch flat;
        flat.attack = 0.0; flat.decay = 0.0; flat.sustain = 1.0; flat.release = 0.0;
        osc->setDefaultPatch(flat);
        osc->setBus(bus);
        id = eng.addInstrument(std::move(osc));
    }

    void note(double freq, double seconds, double vel = 0.5)
    {
        cs::NoteEvent ev;
        ev.instrumentId = id;
        ev.timeFrames = eng.currentFrame();
        ev.durationFrames = frames(seconds);
        ev.freqHz = freq;
        ev.velocity = vel;
        eng.schedule(ev);
    }

    // Rendered pass by pass, as the sink pulls it, so the voice is gone
    // from most passes and only the bus effects still sound.
    std::vector<float> render(double seconds, int chunk = kChunk)
    {
        std::vector<float> out(static_cast<size_t>(frames(seconds)));
        for (size_t at = 0; at < out.size(); at += chunk) {
            const int n = static_cast<int>(std::min<size_t>(chunk, out.size() - at));
            eng.renderOffline(out.data() + at, n);
        }
        return out;
    }
};

static double rms(const std::vector<float> &buf, int from, int n)
{
    double acc = 0.0;
    for (int i = from; i < from + n; ++i) acc += double(buf[i]) * buf[i];
    return std::sqrt(acc / n);
}

static double amplitudeAt(const std::vector<float> &buf, int from, int n, double freq)
{
    std::complex<double> acc = 0.0;
    for (int i = 0; i < n; ++i) {
        const double w = 2.0 * kPi * freq * i / kRate;
        acc += static_cast<double>(buf[from + i]) * std::complex<double>(std::cos(w), -std::sin(w));
    }
    return 2.0 * std::abs(acc) / n;
}

// Wet = with the effect minus without it, same notes on a fresh engine.
static std::vector<float> minus(const std::vector<float> &a, const std::vector<float> &b)
{
    std::vector<float> d(a.size());
    for (size_t i = 0; i < a.size(); ++i) d[i] = a[i] - b[i];
    return d;
}

// The lag in [lo, hi] at which wet best matches dry, by correlation.
static int bestLag(const std::vector<float> &wet, const std::vector<float> &dry,
                   int dryLen, int lo, int hi)
{
    int best = lo;
    double bestC = -1e300;
    for (int lag = lo; lag <= hi; ++lag) {
        double c = 0.0;
        for (int i = 0; i < dryLen; ++i) c += double(dry[i]) * wet[i + lag];
        if (c > bestC) { bestC = c; best = lag; }
    }
    return best;
}

class SoundEffectsTest : public QObject
{
    Q_OBJECT
private slots:
    void offByDefault();
    void noEffectLeavesTheMixAsItWas();
    void echoDelayAndDecay_data();
    void echoDelayAndDecay();
    void negativeFeedbackFlipsEveryOtherRepeat();
    void firLowPassDarkensEachRepeat();
    void echoStaysOnItsBus();
    void reEnabledEchoStartsFromSilence();
    void reverbTailDecaysAndGrowsWithRoomSize();
    void sameNotesRenderSameSamples();
    void clampsAndSignals();
    void settableFromQml();
    void cleanup();
};

void SoundEffectsTest::cleanup()
{
    // The shared engine's buses outlive a test; leave them off.
    auto &eng = cs::AudioOutput::instance().engine();
    for (cs::Bus b : {cs::Bus::Sfx, cs::Bus::Music, cs::Bus::Voice}) {
        eng.echo(b).setEnabled(false);
        eng.reverb(b).setEnabled(false);
    }
}

void SoundEffectsTest::offByDefault()
{
    cs::Engine eng(kRate);
    SoundMixer m;
    const EchoEffect *echoes[] = {m.sfxEcho(), m.musicEcho(), m.voiceEcho()};
    const ReverbEffect *reverbs[] = {m.sfxReverb(), m.musicReverb(), m.voiceReverb()};
    for (int b = 0; b < cs::kBusCount; ++b) {
        QVERIFY(!eng.echo(cs::Bus(b)).enabled());
        QVERIFY(!eng.reverb(cs::Bus(b)).enabled());
        QVERIFY(!echoes[b]->enabled());
        QVERIFY(!reverbs[b]->enabled());
        QCOMPARE(echoes[b]->fir(), QList<qreal>({1, 0, 0, 0, 0, 0, 0, 0}));
    }
    QCOMPARE(m.sfxEcho()->delay(), 120.0);
    QCOMPARE(m.sfxEcho()->feedback(), 0.5);
    QCOMPARE(m.sfxEcho()->volume(), 0.5);
    QCOMPARE(m.sfxReverb()->roomSize(), 0.5);
    QCOMPARE(m.sfxReverb()->damping(), 0.5);
    QVERIFY(std::abs(m.sfxReverb()->volume() - 0.3) < 1e-6);
}

void SoundEffectsTest::noEffectLeavesTheMixAsItWas()
{
    // A note ends and nothing follows it: no bus rings by default.
    Rig r;
    r.note(440.0, 0.05);
    const auto out = r.render(0.5);
    QVERIFY(rms(out, 0, frames(0.05)) > 0.1);
    QCOMPARE(rms(out, frames(0.06), frames(0.44)), 0.0);

    // An echo switched on and off again before the note leaves it the
    // same samples as an engine that never had one.
    Rig a, b;
    a.eng.echo(cs::Bus::Sfx).setEnabled(true);
    a.eng.reverb(cs::Bus::Sfx).setEnabled(true);
    a.eng.echo(cs::Bus::Sfx).setEnabled(false);
    a.eng.reverb(cs::Bus::Sfx).setEnabled(false);
    a.note(440.0, 0.05);
    b.note(440.0, 0.05);
    QCOMPARE(a.render(0.3), b.render(0.3));
}

void SoundEffectsTest::echoDelayAndDecay_data()
{
    QTest::addColumn<double>("delayMs");
    QTest::addColumn<double>("feedback");
    QTest::addColumn<double>("volume");
    QTest::newRow("60 ms, fb 0.5") << 60.0 << 0.5 << 1.0;
    QTest::newRow("125 ms, fb 0.7, vol 0.6") << 125.0 << 0.7 << 0.6;
    QTest::newRow("240 ms, fb 0.25") << 240.0 << 0.25 << 0.8;
}

void SoundEffectsTest::echoDelayAndDecay()
{
    // The issue's criterion: an offline render measures the echo's delay
    // and decay. A 20 ms burst, shorter than any delay, so the repeats
    // stand apart; with the default taps repeat n is
    // volume * feedback^(n-1) times the burst, n * delay later.
    QFETCH(double, delayMs);
    QFETCH(double, feedback);
    QFETCH(double, volume);
    const double burst = 0.02;
    const int d = frames(delayMs / 1000.0);
    const double seconds = 4.5 * delayMs / 1000.0 + burst;

    Rig dry, wetRig;
    auto &echo = wetRig.eng.echo(cs::Bus::Sfx);
    echo.setEnabled(true);
    echo.setDelayMs(float(delayMs));
    echo.setFeedback(float(feedback));
    echo.setVolume(float(volume));
    dry.note(500.0, burst);
    wetRig.note(500.0, burst);
    const auto drySig = dry.render(seconds);
    const auto wet = minus(wetRig.render(seconds), drySig);

    const int b = frames(burst);
    QCOMPARE(rms(wet, 0, d), 0.0);      // nothing before the delay
    const int lag = bestLag(wet, drySig, b, 1, 2 * d - b);
    QVERIFY2(lag == d, qPrintable(QString("delay %1 frames, measured %2").arg(d).arg(lag)));

    const double ref = rms(drySig, 0, b);
    double prev = 0.0;
    for (int n = 1; n <= 4; ++n) {
        const double level = rms(wet, n * d, b);
        const double expected = ref * volume * std::pow(feedback, n - 1);
        QVERIFY2(std::abs(level / expected - 1.0) < 1e-4,
                 qPrintable(QString("repeat %1: %2, expected %3").arg(n).arg(level).arg(expected)));
        if (n > 1)
            QVERIFY2(std::abs(level / prev - feedback) < 1e-4,
                     qPrintable(QString("decay %1 -> %2: %3").arg(n - 1).arg(n).arg(level / prev)));
        // Between repeats the echo is silent.
        QVERIFY(rms(wet, n * d + b, d - b) < 1e-6);
        prev = level;
    }
}

void SoundEffectsTest::negativeFeedbackFlipsEveryOtherRepeat()
{
    const double burst = 0.02;
    const int d = frames(0.05);
    Rig dry, wetRig;
    auto &echo = wetRig.eng.echo(cs::Bus::Sfx);
    echo.setEnabled(true);
    echo.setDelayMs(50.0f);
    echo.setFeedback(-0.5f);
    echo.setVolume(1.0f);
    dry.note(500.0, burst);
    wetRig.note(500.0, burst);
    const auto drySig = dry.render(0.25);
    const auto wet = minus(wetRig.render(0.25), drySig);
    const int b = frames(burst);
    for (int n = 1; n <= 3; ++n) {
        double c = 0.0;
        for (int i = 0; i < b; ++i) c += double(drySig[i]) * wet[n * d + i];
        QVERIFY2((n % 2 == 1) == (c > 0.0), qPrintable(QString("repeat %1 correlates %2").arg(n).arg(c)));
    }
}

void SoundEffectsTest::firLowPassDarkensEachRepeat()
{
    // Taps {1/4, 1/4, 1/4, 1/4}: a moving average, whose gain at f is
    // |sin(4 w / 2) / (4 sin(w / 2))| with w = 2 pi f / fs. 300 Hz
    // passes almost whole, 6300 Hz drops to about 0.56 per pass, so
    // every repeat is darker than the one before. Both tones are whole
    // periods in the 1470-frame window.
    const double burst = 0.05;
    const int d = frames(0.1);
    const int from = frames(0.01), len = 1470;
    auto response = [](double f) {
        const double w = 2.0 * kPi * f / kRate;
        return std::abs(std::sin(2.0 * w) / (4.0 * std::sin(w / 2.0)));
    };
    for (double f : {300.0, 6300.0}) {
        Rig dry, wetRig;
        auto &echo = wetRig.eng.echo(cs::Bus::Sfx);
        echo.setEnabled(true);
        echo.setDelayMs(100.0f);
        echo.setFeedback(1.0f);
        echo.setVolume(1.0f);
        for (int k = 0; k < cs::Echo::kTaps; ++k) echo.setFirTap(k, k < 4 ? 0.25f : 0.0f);
        dry.note(f, burst);
        wetRig.note(f, burst);
        const auto drySig = dry.render(0.45);
        const auto wet = minus(wetRig.render(0.45), drySig);
        const double ref = amplitudeAt(drySig, from, len, f);
        QVERIFY(ref > 0.1);
        for (int n = 1; n <= 3; ++n) {
            const double gain = amplitudeAt(wet, n * d + from, len, f) / ref;
            const double expected = std::pow(response(f), n);
            QVERIFY2(std::abs(gain / expected - 1.0) < 1e-3,
                     qPrintable(QString("%1 Hz repeat %2: gain %3, expected %4")
                                    .arg(f).arg(n).arg(gain).arg(expected)));
        }
    }
    QVERIFY(response(6300.0) < 0.57 && response(300.0) > 0.99);
}

void SoundEffectsTest::echoStaysOnItsBus()
{
    // The music bus echoes; a note on the sfx bus does not.
    Rig r(cs::Bus::Sfx);
    r.eng.echo(cs::Bus::Music).setEnabled(true);
    r.eng.reverb(cs::Bus::Music).setEnabled(true);
    r.note(440.0, 0.05);
    const auto out = r.render(0.4);
    QCOMPARE(rms(out, frames(0.06), frames(0.3)), 0.0);

    Rig m(cs::Bus::Music);
    m.eng.echo(cs::Bus::Music).setEnabled(true);
    m.note(440.0, 0.05);
    QVERIFY(rms(m.render(0.4), frames(0.12), frames(0.05)) > 0.01);
}

void SoundEffectsTest::reEnabledEchoStartsFromSilence()
{
    Rig r;
    auto &echo = r.eng.echo(cs::Bus::Sfx);
    echo.setEnabled(true);
    echo.setFeedback(0.9f);
    r.note(440.0, 0.05);
    const auto ringing = r.render(0.2);
    QVERIFY(rms(ringing, frames(0.12), frames(0.05)) > 0.01);
    echo.setEnabled(false);
    echo.setEnabled(true);
    QCOMPARE(rms(r.render(1.0), 0, frames(1.0)), 0.0);
}

void SoundEffectsTest::reverbTailDecaysAndGrowsWithRoomSize()
{
    // A 50 ms burst, then the tail: it is there, it is wide (the two
    // channels differ for a centred source), it fades, and a larger
    // room keeps it longer.
    auto tail = [](float room) {
        Rig r;
        auto &rv = r.eng.reverb(cs::Bus::Sfx);
        rv.setEnabled(true);
        rv.setRoomSize(room);
        rv.setDamping(0.3f);
        rv.setVolume(1.0f);
        r.note(440.0, 0.05);
        const int n = frames(1.5);
        std::vector<float> stereo(2 * static_cast<size_t>(n));
        for (int at = 0; at < n; at += kChunk)
            r.eng.renderStereo(stereo.data() + 2 * at, std::min(kChunk, n - at));
        return stereo;
    };
    auto level = [](const std::vector<float> &stereo, double t0, double len) {
        std::vector<float> mono(stereo.size() / 2);
        for (size_t i = 0; i < mono.size(); ++i) mono[i] = (stereo[2 * i] + stereo[2 * i + 1]) * 0.5f;
        return rms(mono, frames(t0), frames(len));
    };
    const auto small = tail(0.2f);
    const auto large = tail(0.9f);
    const double early = level(small, 0.1, 0.1);
    const double late  = level(small, 0.5, 0.1);
    QVERIFY2(early > 1e-3, qPrintable(QString("tail at 0.1 s: %1").arg(early)));
    QVERIFY2(late < 0.1 * early, qPrintable(QString("tail 0.1 s %1, 0.5 s %2").arg(early).arg(late)));
    const double largeLate = level(large, 0.5, 0.1);
    QVERIFY2(largeLate > 10.0 * late,
             qPrintable(QString("at 0.5 s: room 0.9 %1, room 0.2 %2").arg(largeLate).arg(late)));

    double diff = 0.0;
    for (int i = frames(0.1); i < frames(0.2); ++i)
        diff += std::abs(small[2 * i] - small[2 * i + 1]);
    QVERIFY(diff > 0.0);
}

void SoundEffectsTest::sameNotesRenderSameSamples()
{
    // Same notes, echo and reverb on, two engines: same samples, and the
    // size of the passes does not change them - live and offline agree.
    auto run = [](int chunk) {
        Rig r;
        auto &e = r.eng.echo(cs::Bus::Sfx);
        e.setEnabled(true);
        e.setDelayMs(80.0f);
        e.setFeedback(0.6f);
        for (int k = 0; k < cs::Echo::kTaps; ++k) e.setFirTap(k, 0.125f);
        r.eng.reverb(cs::Bus::Sfx).setEnabled(true);
        r.note(330.0, 0.1);
        return r.render(0.6, chunk);
    };
    const auto a = run(kChunk);
    QCOMPARE(a, run(kChunk));
    QCOMPARE(a, run(int(a.size())));
    QCOMPARE(a, run(37));
}

void SoundEffectsTest::clampsAndSignals()
{
    SoundMixer m;
    EchoEffect *e = m.voiceEcho();
    QSignalSpy delaySpy(e, &EchoEffect::delayChanged);
    e->setDelay(5000.0);
    QCOMPARE(e->delay(), 1000.0);
    e->setDelay(5000.0);
    QCOMPARE(delaySpy.count(), 1);
    e->setDelay(0.0);
    QCOMPARE(e->delay(), 1.0);
    e->setFeedback(-3.0);
    QCOMPARE(e->feedback(), -1.0);
    e->setVolume(2.0);
    QCOMPARE(e->volume(), 1.0);

    QSignalSpy firSpy(e, &EchoEffect::firChanged);
    e->setFir({0.5, 0.5});
    QCOMPARE(e->fir(), QList<qreal>({0.5, 0.5, 0, 0, 0, 0, 0, 0}));
    QCOMPARE(firSpy.count(), 1);
    QTest::ignoreMessage(QtWarningMsg, QRegularExpression("at most 8 taps"));
    e->setFir(QList<qreal>(9, 0.1));
    QCOMPARE(firSpy.count(), 1);
    e->setFir({2.0});
    QCOMPARE(e->fir().first(), 1.0);

    ReverbEffect *r = m.voiceReverb();
    QSignalSpy onSpy(r, &ReverbEffect::enabledChanged);
    r->setEnabled(true);
    r->setEnabled(true);
    QCOMPARE(onSpy.count(), 1);
    r->setRoomSize(1.5);
    QCOMPARE(r->roomSize(), 1.0);
    r->setDamping(-1.0);
    QCOMPARE(r->damping(), 0.0);

    // The values are the engine's, so another mixer sees them.
    SoundMixer other;
    QCOMPARE(other.voiceEcho()->delay(), 1.0);
    QVERIFY(other.voiceReverb()->enabled());
    // Restore what the other tests expect of the shared engine.
    e->setDelay(120.0);
    e->setFeedback(0.5);
    e->setVolume(0.5);
    e->setFir({1.0});
    r->setRoomSize(0.5);
    r->setDamping(0.5);
}

void SoundEffectsTest::settableFromQml()
{
    // QML switches the music bus's echo on and sets it; a SynthInstrument
    // on that bus then echoes at the delay QML gave it. The URI is not
    // Clayground.Sound: that would load the built plugin from bin/qml,
    // whose SoundMixer drives the plugin's engine, not this binary's.
    QQmlEngine qml;
    qmlRegisterSingletonType<SoundMixer>("ClaySoundEffectsTest", 1, 0, "SoundMixer",
                                         [](QQmlEngine *, QJSEngine *) -> QObject * {
                                             return new SoundMixer;
                                         });
    QQmlComponent c(&qml);
    c.setData("import QtQuick\n"
              "import ClaySoundEffectsTest\n"
              "QtObject {\n"
              "  Component.onCompleted: {\n"
              "    SoundMixer.musicEcho.enabled = true\n"
              "    SoundMixer.musicEcho.delay = 75\n"
              "    SoundMixer.musicEcho.feedback = 0.4\n"
              "    SoundMixer.musicEcho.volume = 1\n"
              "    SoundMixer.musicEcho.fir = [1]\n"
              "    SoundMixer.musicReverb.roomSize = 0.8\n"
              "  }\n"
              "  property bool sfxOff: !SoundMixer.sfxEcho.enabled && !SoundMixer.sfxReverb.enabled\n"
              "  property var taps: SoundMixer.musicEcho.fir\n"
              "}\n",
              QUrl());
    std::unique_ptr<QObject> obj(c.create());
    QVERIFY2(obj, qPrintable(c.errorString()));
    QVERIFY(obj->property("sfxOff").toBool());
    QCOMPARE(obj->property("taps").toList().size(), 8);

    auto &eng = cs::AudioOutput::instance().engine();
    QVERIFY(eng.echo(cs::Bus::Music).enabled());
    QCOMPARE(eng.echo(cs::Bus::Music).delayMs(), 75.0f);
    QVERIFY(std::abs(eng.echo(cs::Bus::Music).feedback() - 0.4f) < 1e-6f);
    QVERIFY(!eng.reverb(cs::Bus::Music).enabled());
    QVERIFY(std::abs(eng.reverb(cs::Bus::Music).roomSize() - 0.8f) < 1e-6f);
    eng.reverb(cs::Bus::Music).setRoomSize(0.5f);

    SynthInstrument s;
    s.setWaveform("sine");
    s.setAttack(0.0);
    s.setDecay(0.0);
    s.setSustain(1.0);
    s.setRelease(0.0);
    s.setBus("music");
    s.trigger(500.0, 0.5, 0.02);
    const int n = frames(0.3);
    std::vector<float> out(static_cast<size_t>(n));
    for (int at = 0; at < n; at += kChunk) eng.renderOffline(out.data() + at, std::min(kChunk, n - at));
    const int b = frames(0.02), d = frames(0.075);
    QVERIFY(rms(out, 0, b) > 0.1);
    QVERIFY(rms(out, b + 10, d - b - 20) < 1e-6);
    const double r1 = rms(out, d, b), r2 = rms(out, 2 * d, b);
    QVERIFY2(std::abs(r1 / rms(out, 0, b) - 1.0) < 1e-4, qPrintable(QString("repeat 1: %1").arg(r1)));
    QVERIFY2(std::abs(r2 / r1 - 0.4) < 1e-4, qPrintable(QString("decay: %1").arg(r2 / r1)));
    eng.echo(cs::Bus::Music).setDelayMs(120.0f);
    eng.echo(cs::Bus::Music).setFeedback(0.5f);
    eng.echo(cs::Bus::Music).setVolume(0.5f);
}

QTEST_MAIN(SoundEffectsTest)
#include "tst_sound_effects.moc"
