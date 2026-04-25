// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// IInstrument — note-event -> voice factory. A patch lives here; the
// scheduler doesn't care whether the voice it gets back is oscillator-
// based or PCM-based.
//
// Each instrument also carries a per-instrument linear `gain` (default
// 1.0). When the engine mixes voices into a shared buffer it applies
// the source instrument's current gain to that voice's contribution,
// so multiple instruments sharing one engine + sink can each have
// independent volume.

#pragma once

#include "scheduler.h"
#include <atomic>
#include <memory>

namespace clay::sound {

struct NoteEvent;
class IVoice;

class IInstrument
{
public:
    virtual ~IInstrument() = default;

    // Build a fully-configured voice for this event. The engine owns
    // the returned voice for its lifetime. `id` is the scheduler ticket
    // returned by Engine::schedule(); instruments that keep per-event
    // side state (e.g. patches queued before scheduling) key on it.
    virtual std::unique_ptr<IVoice> createVoice(const NoteEvent& ev,
                                                EventId id,
                                                int sampleRate) = 0;

    // Per-instrument linear gain in [0, 1]. Read by the engine on every
    // mix pass; safe to update from the QML thread while the audio
    // thread renders (atomic relaxed is sufficient for a single float).
    void  setGain(float g) { gain_.store(clampGain(g), std::memory_order_relaxed); }
    float gain() const     { return gain_.load(std::memory_order_relaxed); }

private:
    static float clampGain(float g) { return g < 0.0f ? 0.0f : (g > 1.0f ? 1.0f : g); }
    std::atomic<float> gain_{1.0f};
};

} // namespace clay::sound
