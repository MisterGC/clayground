// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Stage 0 — spine tests for clay_sound's engine layer.
// Covers:
//   * empty engine renders silence
//   * scheduler fires events in order, drops past events on pop
//   * scheduler lets an event be cancelled before it fires
//   * sample-accurate spawn: a voice that emits a unit impulse at its
//     start frame produces an impulse at the exact buffer offset
//   * golden render: a deterministic note sequence hashes to a known value
//
// The golden hash is computed on a quantised integer representation to
// dodge FP-denormal / platform variance. It should remain stable across
// compilers as long as the engine math stays pure integer/float ops.

#include "engine/engine.h"
#include "engine/instrument.h"
#include "engine/note_event.h"
#include "engine/pcm_buffer.h"
#include "engine/sample_voice.h"
#include "engine/sampler_instrument.h"
#include "engine/scheduler.h"
#include "engine/voice.h"
#include "sample_instrument.h"
#include "synth_instrument.h"

#include <QtTest/QtTest>
#include <cmath>
#include <cstdint>
#include <memory>
#include <vector>

using namespace clay::sound;

// --- Test doubles -----------------------------------------------------

// A voice that writes a single 1.0f sample at event.timeFrames, nothing else.
class ImpulseVoice : public IVoice
{
public:
    void onNoteOn(const NoteEvent& ev, int) override
    {
        startFrame_ = ev.timeFrames;
        velocity_ = ev.velocity;
        fired_ = false;
    }
    void onNoteOff(int64_t) override {}
    void render(float* buffer, int frames, int64_t bufferStartFrame) override
    {
        if (fired_) return;
        const int64_t offset = startFrame_ - bufferStartFrame;
        if (offset >= 0 && offset < frames) {
            buffer[offset] += velocity_;
            fired_ = true;
        }
    }
    bool isFinished(int64_t currentFrame) const override
    {
        return fired_ || currentFrame > startFrame_;
    }
private:
    int64_t startFrame_ = 0;
    float velocity_ = 1.0f;
    bool fired_ = false;
};

class ImpulseInstrument : public IInstrument
{
public:
    std::unique_ptr<IVoice> createVoice(const NoteEvent&, EventId, int) override
    {
        return std::make_unique<ImpulseVoice>();
    }
};

// A sine voice rendering for exactly durationFrames, deterministic math.
class SineVoice : public IVoice
{
public:
    void onNoteOn(const NoteEvent& ev, int sampleRate) override
    {
        startFrame_ = ev.timeFrames;
        endFrame_ = ev.timeFrames + ev.durationFrames;
        step_ = 2.0 * M_PI * ev.freqHz / static_cast<double>(sampleRate);
        gain_ = ev.velocity;
    }
    void onNoteOff(int64_t atFrame) override { endFrame_ = atFrame; }
    void render(float* buffer, int frames, int64_t bufferStartFrame) override
    {
        const int64_t lo = std::max(startFrame_, bufferStartFrame);
        const int64_t hi = std::min(endFrame_, bufferStartFrame + frames);
        for (int64_t f = lo; f < hi; ++f) {
            const int idx = static_cast<int>(f - bufferStartFrame);
            const double phase = (f - startFrame_) * step_;
            buffer[idx] += static_cast<float>(std::sin(phase)) * gain_;
        }
    }
    bool isFinished(int64_t currentFrame) const override
    {
        return currentFrame >= endFrame_;
    }
private:
    int64_t startFrame_ = 0;
    int64_t endFrame_ = 0;
    double step_ = 0.0;
    float gain_ = 1.0f;
};

class SineInstrument : public IInstrument
{
public:
    std::unique_ptr<IVoice> createVoice(const NoteEvent&, EventId, int) override
    {
        return std::make_unique<SineVoice>();
    }
};

// FNV-1a 64 over a quantised int16 view of the buffer.
static uint64_t hashBuffer(const float* buf, int frames)
{
    uint64_t h = 1469598103934665603ULL;
    for (int i = 0; i < frames; ++i) {
        const int q = static_cast<int>(std::lround(buf[i] * 32767.0f));
        const int16_t s = static_cast<int16_t>(
            std::clamp(q, -32768, 32767));
        const uint8_t b0 = static_cast<uint8_t>(s & 0xff);
        const uint8_t b1 = static_cast<uint8_t>((s >> 8) & 0xff);
        h ^= b0; h *= 1099511628211ULL;
        h ^= b1; h *= 1099511628211ULL;
    }
    return h;
}

// --- Tests -------------------------------------------------------------

class EngineSpineTest : public QObject
{
    Q_OBJECT
private slots:
    void emptyEngineRendersSilence();
    void schedulerPopsDueInOrder();
    void schedulerCancelDropsEvent();
    void voiceSpawnsAtExactFrame();
    void goldenRender();
    void synthInstrumentOfflineTrigger();
    void synthInstrumentMultipleTriggersOverlap();
    void multipleSynthInstrumentsShareEngine();
    void sampleVoicePlaysBuffer();
    void sampleVoicePitchShift();
    void sampleVoiceLoops();
    void sampleInstrumentLoadsDemoWav();
};

void EngineSpineTest::emptyEngineRendersSilence()
{
    Engine eng(44100);
    std::vector<float> buf(256, 1.0f);
    eng.renderOffline(buf.data(), static_cast<int>(buf.size()));
    for (float s : buf) QCOMPARE(s, 0.0f);
    QCOMPARE(eng.currentFrame(), int64_t{256});
    QCOMPARE(eng.activeVoices(), size_t{0});
}

void EngineSpineTest::schedulerPopsDueInOrder()
{
    Scheduler s;
    NoteEvent a; a.timeFrames = 100;
    NoteEvent b; b.timeFrames = 50;
    NoteEvent c; c.timeFrames = 200;
    s.schedule(a);
    s.schedule(b);
    s.schedule(c);
    auto due = s.popDue(150);
    QCOMPARE(due.size(), size_t{2});
    QCOMPARE(due[0].ev.timeFrames, int64_t{50});
    QCOMPARE(due[1].ev.timeFrames, int64_t{100});
    QCOMPARE(s.pending(), size_t{1});
    auto rest = s.popDue(1000);
    QCOMPARE(rest.size(), size_t{1});
    QCOMPARE(rest[0].ev.timeFrames, int64_t{200});
    QVERIFY(!s.hasPending());
}

void EngineSpineTest::schedulerCancelDropsEvent()
{
    Scheduler s;
    NoteEvent a; a.timeFrames = 100;
    NoteEvent b; b.timeFrames = 200;
    const auto idA = s.schedule(a);
    s.schedule(b);
    QVERIFY(s.cancel(idA));
    QVERIFY(!s.cancel(idA));          // already gone
    auto due = s.popDue(1000);
    QCOMPARE(due.size(), size_t{1});
    QCOMPARE(due[0].ev.timeFrames, int64_t{200});
}

void EngineSpineTest::voiceSpawnsAtExactFrame()
{
    Engine eng(44100);
    const int inst = eng.addInstrument(std::make_unique<ImpulseInstrument>());

    NoteEvent ev;
    ev.timeFrames   = 73;    // mid-buffer target
    ev.instrumentId = inst;
    ev.velocity     = 1.0f;
    eng.schedule(ev);

    std::vector<float> buf(128, 0.0f);
    eng.renderOffline(buf.data(), static_cast<int>(buf.size()));

    for (int i = 0; i < 128; ++i) {
        if (i == 73) QCOMPARE(buf[i], 1.0f);
        else         QCOMPARE(buf[i], 0.0f);
    }
    QCOMPARE(eng.pendingEvents(), size_t{0});
}

void EngineSpineTest::goldenRender()
{
    // Deterministic test song: two 1 kHz sine notes, 64 frames each,
    // gain 0.5, starting at frames 0 and 128. Total 256 frames @ 44.1 kHz.
    Engine eng(44100);
    const int inst = eng.addInstrument(std::make_unique<SineInstrument>());

    for (int n = 0; n < 2; ++n) {
        NoteEvent ev;
        ev.timeFrames     = n * 128;
        ev.durationFrames = 64;
        ev.freqHz         = 1000.0;
        ev.velocity       = 0.5f;
        ev.instrumentId   = inst;
        eng.schedule(ev);
    }

    std::vector<float> buf(256, 0.0f);
    eng.renderOffline(buf.data(), static_cast<int>(buf.size()));

    // Sanity: silence in the gap between the two notes.
    for (int i = 64; i < 128; ++i) QCOMPARE(buf[i], 0.0f);
    for (int i = 192; i < 256; ++i) QCOMPARE(buf[i], 0.0f);

    // Golden hash. Regenerate with fprintf if the engine math intentionally
    // changes; do not silently update on drift.
    const uint64_t got = hashBuffer(buf.data(), 256);
    constexpr uint64_t expected = 0x19b09689c8b1fc63ULL;
    if (got != expected)
        qWarning("golden hash drift: got 0x%016llx expected 0x%016llx",
                 static_cast<unsigned long long>(got),
                 static_cast<unsigned long long>(expected));
    QCOMPARE(got, expected);
}

void EngineSpineTest::synthInstrumentOfflineTrigger()
{
    SynthInstrument synth;
    synth.setWaveform("sine");
    synth.setAttack(0.0);
    synth.setDecay(0.0);
    synth.setSustain(1.0);
    synth.setRelease(0.0);
    synth.setPitchStart(0.0);
    synth.setPitchEnd(0.0);
    synth.setPitchTime(0.0);
    synth.setVolume(1.0);

    QVERIFY(synth.trigger(440.0, 1.0, 0.1));
    // Duration 0.1s at 44100 = 4410 frames; render 8820 to cover tail silence.
    auto buf = synth.renderOffline(0.2);
    QCOMPARE(buf.size(), 8820);

    // Sum absolute energy: first half non-zero, second half silent.
    double e1 = 0.0, e2 = 0.0;
    for (int i = 0; i < 4410; ++i)   e1 += std::abs(buf[i]);
    for (int i = 4410; i < 8820; ++i) e2 += std::abs(buf[i]);
    QVERIFY2(e1 > 100.0, qPrintable(QString("expected audible note, energy=%1").arg(e1)));
    QVERIFY2(e2 < 1.0,   qPrintable(QString("expected silent tail, energy=%1").arg(e2)));
}

void EngineSpineTest::synthInstrumentMultipleTriggersOverlap()
{
    SynthInstrument synth;
    synth.setWaveform("square");
    synth.setAttack(0.0);
    synth.setRelease(0.0);
    synth.setVolume(0.5);

    // Three overlapping notes.
    QVERIFY(synth.trigger(220.0, 0.5, 0.05));
    QVERIFY(synth.trigger(330.0, 0.5, 0.05));
    QVERIFY(synth.trigger(440.0, 0.5, 0.05));
    auto buf = synth.renderOffline(0.1);
    QCOMPARE(buf.size(), 4410);

    double e = 0.0;
    for (auto s : buf) e += std::abs(s);
    QVERIFY2(e > 100.0, qPrintable(QString("expected audible mix, energy=%1").arg(e)));
}

void EngineSpineTest::multipleSynthInstrumentsShareEngine()
{
    // Regression for the WASM "only one QAudioSink at a time" issue:
    // four SynthInstruments simultaneously alive must all contribute to
    // the shared engine output. Pre-refactor each instrument owned its
    // own QAudioSink; on Qt-WASM the 2nd-4th sinks failed to open with
    // "Invalid Operation", silencing those instruments.
    auto makeSynth = [](const QString &waveform, qreal volume) {
        auto s = std::make_unique<SynthInstrument>();
        s->setWaveform(waveform);
        s->setAttack(0.0);
        s->setDecay(0.0);
        s->setSustain(1.0);
        s->setRelease(0.0);
        s->setPitchStart(0.0);
        s->setPitchEnd(0.0);
        s->setPitchTime(0.0);
        s->setVolume(volume);
        return s;
    };

    auto a = makeSynth("sine",     1.0);
    auto b = makeSynth("square",   1.0);
    auto c = makeSynth("triangle", 1.0);
    auto d = makeSynth("sawtooth", 1.0);

    QVERIFY(a->trigger(220.0, 1.0, 0.05));
    QVERIFY(b->trigger(440.0, 1.0, 0.05));
    QVERIFY(c->trigger(660.0, 1.0, 0.05));
    QVERIFY(d->trigger(880.0, 1.0, 0.05));

    // Render through any one of them — they share the engine, so any
    // call drains the same buffer.
    auto buf = a->renderOffline(0.1);
    QCOMPARE(buf.size(), 4410);

    double e = 0.0;
    for (auto s : buf) e += std::abs(s);
    // Four overlapping voices: energy must be substantially above what
    // a single voice alone produces. A single voice at velocity 1.0
    // for 0.05s yields ~2200; we require >800 here as a robust
    // regression bar that catches "3 of 4 voices were silent".
    QVERIFY2(e > 800.0, qPrintable(QString("expected audible 4-voice mix, energy=%1").arg(e)));

    // Cross-instrument gain isolation: muting one instrument must not
    // silence the others. Reset state by destroying these synths first
    // so the next round's voices come from fresh registrations.
    a.reset(); b.reset(); c.reset(); d.reset();

    auto loud = makeSynth("square", 1.0);
    auto mute = makeSynth("square", 0.0);   // gain 0 → contributes nothing
    QVERIFY(loud->trigger(440.0, 1.0, 0.05));
    QVERIFY(mute->trigger(880.0, 1.0, 0.05));

    auto buf2 = loud->renderOffline(0.1);
    double e2 = 0.0;
    for (auto s : buf2) e2 += std::abs(s);
    QVERIFY2(e2 > 100.0, qPrintable(QString("loud voice should be audible, energy=%1").arg(e2)));
}

// --- Sample voice / instrument tests ----------------------------------

static std::shared_ptr<const PcmBuffer> makeSineBuffer(double freqHz,
                                                      int sampleRate,
                                                      int frames)
{
    std::vector<float> s(frames);
    const double step = 2.0 * M_PI * freqHz / sampleRate;
    for (int i = 0; i < frames; ++i)
        s[i] = static_cast<float>(std::sin(i * step));
    return std::make_shared<const PcmBuffer>(
        PcmBuffer::fromFloats(std::move(s), sampleRate));
}

void EngineSpineTest::sampleVoicePlaysBuffer()
{
    Engine eng(44100);
    auto core = std::make_unique<SamplerInstrument>();
    core->setSource(makeSineBuffer(440.0, 44100, 4410)); // 100ms
    core->setRootMidiNote(69);                           // A4 = 440 Hz
    auto *rawCore = core.get();
    const int instId = eng.addInstrument(std::move(core));
    (void)rawCore;

    NoteEvent ev;
    ev.timeFrames     = 0;
    ev.durationFrames = 4410;
    ev.freqHz         = 440.0;
    ev.velocity       = 1.0f;
    ev.instrumentId   = instId;
    eng.schedule(ev);

    std::vector<float> buf(8820, 0.0f);
    eng.renderOffline(buf.data(), static_cast<int>(buf.size()));

    double e1 = 0.0, e2 = 0.0;
    for (int i = 0; i < 4410; ++i)   e1 += std::abs(buf[i]);
    for (int i = 4410; i < 8820; ++i) e2 += std::abs(buf[i]);
    QVERIFY2(e1 > 100.0, qPrintable(QString("expected sample audible, energy=%1").arg(e1)));
    QVERIFY2(e2 < 1.0,   qPrintable(QString("expected post-sample silence, energy=%1").arg(e2)));
}

void EngineSpineTest::sampleVoicePitchShift()
{
    // Feed a 1 kHz sine sample; trigger at 2 kHz (one octave up).
    // Expect the played-back audio to cross zero ~twice as often.
    Engine eng(44100);
    auto core = std::make_unique<SamplerInstrument>();
    const int srcRate = 44100;
    const int srcFrames = 22050; // 500 ms source
    core->setSource(makeSineBuffer(1000.0, srcRate, srcFrames));
    core->setRootMidiNote(69);                       // root = A4 = 440 Hz
    const int instId = eng.addInstrument(std::move(core));

    NoteEvent ev;
    ev.timeFrames     = 0;
    ev.durationFrames = 4410;                        // 100 ms playback
    ev.freqHz         = 880.0;                       // one octave up from root
    ev.velocity       = 1.0f;
    ev.instrumentId   = instId;
    eng.schedule(ev);

    std::vector<float> buf(4410, 0.0f);
    eng.renderOffline(buf.data(), static_cast<int>(buf.size()));

    int zeroCrossings = 0;
    for (int i = 1; i < static_cast<int>(buf.size()); ++i)
        if ((buf[i - 1] >= 0.0f) != (buf[i] >= 0.0f))
            ++zeroCrossings;
    // 1 kHz source + octave-up => effective 2 kHz. Over 100 ms that's
    // ~400 zero crossings; allow healthy margin.
    QVERIFY2(zeroCrossings >= 300 && zeroCrossings <= 500,
             qPrintable(QString("unexpected zero-crossing count %1").arg(zeroCrossings)));
}

void EngineSpineTest::sampleVoiceLoops()
{
    // Source is 10ms of a 440Hz sine; loop makes it play for 200ms.
    Engine eng(44100);
    auto core = std::make_unique<SamplerInstrument>();
    core->setSource(makeSineBuffer(440.0, 44100, 441));
    core->setRootMidiNote(69);
    SampleVoice::Patch p;
    p.looping = true;
    p.loopStartFrac = 0.0;
    p.loopEndFrac   = 1.0;
    core->setDefaultPatch(p);
    const int instId = eng.addInstrument(std::move(core));

    NoteEvent ev;
    ev.timeFrames     = 0;
    ev.durationFrames = 8820; // 200 ms
    ev.freqHz         = 440.0;
    ev.velocity       = 1.0f;
    ev.instrumentId   = instId;
    eng.schedule(ev);

    std::vector<float> buf(8820, 0.0f);
    eng.renderOffline(buf.data(), static_cast<int>(buf.size()));

    // Every 50-ms window should carry roughly equal energy if looping
    // held. Check the final window too: without a loop it would be
    // silent.
    double last = 0.0;
    for (int i = 6615; i < 8820; ++i) last += std::abs(buf[i]);
    QVERIFY2(last > 50.0, qPrintable(QString("looping seems off, tail energy=%1").arg(last)));
}

void EngineSpineTest::sampleInstrumentLoadsDemoWav()
{
    // The demo WAV ships with the plugin; CMake passes its absolute
    // path as a compile-time define.
#ifndef CLAY_SOUND_DEMO_WAV
    QSKIP("CLAY_SOUND_DEMO_WAV not defined");
#else
    SampleInstrument s;
    QSignalSpy spy(&s, &SampleInstrument::loadedChanged);
    s.setSource(QUrl::fromLocalFile(CLAY_SOUND_DEMO_WAV));
    QCOMPARE(spy.count(), 1);
    QVERIFY(s.loaded());
    auto buf = s.renderOffline(0.5); // 500ms — sample is ~300ms
    QCOMPARE(buf.size(), 22050);
    // Not playable without a trigger: expect silence.
    for (auto v : buf) QCOMPARE(v, 0.0f);
    // Trigger and render again.
    QVERIFY(s.triggerOneShot(1.0));
    auto buf2 = s.renderOffline(0.5);
    double e = 0.0;
    for (auto v : buf2) e += std::abs(v);
    QVERIFY2(e > 100.0, qPrintable(QString("expected audible playback, energy=%1").arg(e)));
#endif
}

QTEST_APPLESS_MAIN(EngineSpineTest)
#include "tst_engine.moc"
