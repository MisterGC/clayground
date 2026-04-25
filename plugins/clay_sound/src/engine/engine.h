// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Engine — hosts instruments + scheduler + voice pool. The single
// offline renderer entrypoint used both by tests and (at later stages)
// by platform sinks that pull sample buffers.

#pragma once

#include "scheduler.h"
#include <cstdint>
#include <memory>
#include <vector>

namespace clay::sound {

class IInstrument;
class IVoice;

class Engine
{
public:
    explicit Engine(int sampleRate);
    ~Engine();

    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    // Register an instrument. Takes ownership. Returns its id (>= 0).
    // Ids are stable for the lifetime of the engine — removeInstrument()
    // tombstones the slot rather than reindexing, so existing ids never
    // change meaning.
    int addInstrument(std::unique_ptr<IInstrument> inst);

    // Drop an instrument and any of its still-active voices. Idempotent.
    void removeInstrument(int id);

    // Non-owning lookup; returns nullptr for unknown or removed ids.
    IInstrument* instrumentAt(int id) const;

    // Enqueue an event on the scheduler. Returns the scheduler ticket.
    EventId schedule(const NoteEvent& ev);

    // Cancel a pending event (before it fires).
    bool cancel(EventId id);

    // Remove all pending events; active voices keep ringing until they
    // self-finish. Use resetVoices() to also silence the voice pool.
    void clearSchedule();

    // Drop all active voices immediately (hard cut).
    void resetVoices();

    // Render `frames` mono samples into `out`. Additive: `out` is
    // overwritten, not accumulated. Advances currentFrame by `frames`.
    // Each voice's contribution is scaled by its source instrument's
    // current `gain()` before being summed.
    void renderOffline(float* out, int frames);

    int sampleRate() const { return sampleRate_; }
    int64_t currentFrame() const { return currentFrame_; }
    size_t activeVoices() const { return voices_.size(); }
    // Voices currently active for a specific instrument id.
    size_t activeVoices(int instrumentId) const;
    size_t pendingEvents() const { return scheduler_.pending(); }

private:
    struct ActiveVoice {
        int instrumentId = -1;          // owner; -1 means tombstoned
        std::unique_ptr<IVoice> voice;
    };

    int sampleRate_;
    int64_t currentFrame_ = 0;

    Scheduler scheduler_;
    std::vector<std::unique_ptr<IInstrument>> instruments_; // sparse: nullptr after remove
    std::vector<ActiveVoice> voices_;
    std::vector<float> scratch_;        // reused per render pass
};

} // namespace clay::sound
