// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// IInstrument — note-event -> voice factory. A patch lives here; the
// scheduler doesn't care whether the voice it gets back is oscillator-
// based or PCM-based.

#pragma once

#include "scheduler.h"
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
};

} // namespace clay::sound
