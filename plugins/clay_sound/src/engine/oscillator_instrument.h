// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// OscillatorInstrument — spawns OscillatorVoice instances configured
// from a per-event patch queue. Callers push a patch via pushPatch()
// keyed on the EventId returned by Engine::schedule(); when that event
// fires, createVoice() pops the patch and stamps it onto the new voice.

#pragma once

#include "instrument.h"
#include "oscillator_voice.h"
#include <memory>
#include <unordered_map>

namespace clay::sound {

class OscillatorInstrument : public IInstrument
{
public:
    // Associate a patch with a scheduled event. The patch is consumed
    // (removed) when the event fires.
    void pushPatch(EventId id, const OscillatorVoice::Patch& patch)
    {
        patches_[id] = patch;
    }

    // Default patch applied when no event-specific patch was queued.
    void setDefaultPatch(const OscillatorVoice::Patch& patch)
    {
        defaultPatch_ = patch;
    }

    std::unique_ptr<IVoice> createVoice(const NoteEvent& ev,
                                        EventId id,
                                        int sampleRate) override;

    size_t queuedPatches() const { return patches_.size(); }
    void clearPatches() { patches_.clear(); }

private:
    OscillatorVoice::Patch defaultPatch_{};
    std::unordered_map<EventId, OscillatorVoice::Patch> patches_;
};

} // namespace clay::sound
