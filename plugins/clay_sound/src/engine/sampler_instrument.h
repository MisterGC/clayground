// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SamplerInstrument — IInstrument that spawns SampleVoice instances
// backed by a shared PcmBuffer. Parallels OscillatorInstrument.

#pragma once

#include "instrument.h"
#include "sample_voice.h"
#include <memory>
#include <unordered_map>

namespace clay::sound {

struct PcmBuffer;

class SamplerInstrument : public IInstrument
{
public:
    void setSource(std::shared_ptr<const PcmBuffer> source) { source_ = std::move(source); }
    const std::shared_ptr<const PcmBuffer>& source() const { return source_; }

    void setRootMidiNote(int midiNote) { rootMidiNote_ = midiNote; }
    int  rootMidiNote() const { return rootMidiNote_; }

    void setDefaultPatch(const SampleVoice::Patch& p) { defaultPatch_ = p; }
    void pushPatch(EventId id, const SampleVoice::Patch& p) { patches_[id] = p; }
    void clearPatches() { patches_.clear(); }

    std::unique_ptr<IVoice> createVoice(const NoteEvent& ev,
                                        EventId id,
                                        int sampleRate) override;

private:
    std::shared_ptr<const PcmBuffer> source_;
    int rootMidiNote_ = 60;
    SampleVoice::Patch defaultPatch_{};
    std::unordered_map<EventId, SampleVoice::Patch> patches_;
};

} // namespace clay::sound
