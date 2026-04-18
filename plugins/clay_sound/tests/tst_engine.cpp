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
#include "engine/scheduler.h"
#include "engine/voice.h"

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
    std::unique_ptr<IVoice> createVoice(const NoteEvent&, int) override
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
    std::unique_ptr<IVoice> createVoice(const NoteEvent&, int) override
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

QTEST_APPLESS_MAIN(EngineSpineTest)
#include "tst_engine.moc"
