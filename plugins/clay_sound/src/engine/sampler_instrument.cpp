// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sampler_instrument.h"
#include "note_event.h"

namespace clay::sound {

std::unique_ptr<IVoice> SamplerInstrument::createVoice(const NoteEvent& /*ev*/,
                                                      EventId id,
                                                      int /*sampleRate*/)
{
    auto voice = std::make_unique<SampleVoice>();
    voice->setSource(source_, rootMidiNote_);
    auto it = patches_.find(id);
    if (it != patches_.end()) {
        voice->setPatch(it->second);
        patches_.erase(it);
    } else {
        voice->setPatch(defaultPatch_);
    }
    return voice;
}

} // namespace clay::sound
