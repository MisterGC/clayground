// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Scheduler — mutable, sample-accurate event queue.
//
// Events can be added, cancelled, or cleared while the engine is running;
// only events whose trigger frame has not yet been reached are affected.
// This is the foundation for live composition: hot-patching a song
// translates into schedule()/cancel() calls that take effect at the next
// safe boundary (enforced at higher layers).

#pragma once

#include "note_event.h"
#include <cstdint>
#include <vector>

namespace clay::sound {

using EventId = uint64_t;

class Scheduler
{
public:
    // Enqueue an event. Returns a ticket usable with cancel().
    EventId schedule(const NoteEvent& ev);

    // Remove a pending event. No-op if already fired or not found.
    // Returns true if the event was cancelled.
    bool cancel(EventId id);

    // Drop all pending events.
    void clear();

    // Pop all events with timeFrames <= maxFrame, in ascending time order.
    // Returned events carry their original EventId so the caller can correlate.
    struct Fired { EventId id; NoteEvent ev; };
    std::vector<Fired> popDue(int64_t maxFrame);

    // Introspection helpers.
    size_t pending() const { return pending_.size(); }
    bool hasPending() const { return !pending_.empty(); }

private:
    struct Entry
    {
        EventId id;
        NoteEvent ev;
    };

    // Sorted ascending by ev.timeFrames. Linear-scan operations are fine
    // for Stage 0; a heap can replace this when profiling demands it.
    std::vector<Entry> pending_;
    EventId nextId_ = 1;
};

} // namespace clay::sound
