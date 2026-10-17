// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "instrument_spec.h"

#include "engine.h"
#include "note_event.h"
#include "oscillator_instrument.h"
#include "pcm_buffer.h"
#include "sampler_instrument.h"

#include <algorithm>
#include <cmath>

namespace clay::sound {

double midiToHz(int midiNote)
{
    return 440.0 * std::pow(2.0, (midiNote - 69) / 12.0);
}

void applyMix(IInstrument &inst, const InstrumentSpec &spec)
{
    inst.setGain(spec.gain);
    inst.setPan(spec.pan);
    inst.setBus(spec.bus);
    inst.setMaxVoices(spec.maxVoices);
}

int addInstrument(Engine &engine, const InstrumentSpec &spec)
{
    std::unique_ptr<IInstrument> inst;
    if (spec.kind == InstrumentSpec::Kind::Sampler) {
        auto sampler = std::make_unique<SamplerInstrument>();
        sampler->setSource(spec.sample);
        sampler->setRootMidiNote(spec.rootMidiNote);
        sampler->setDefaultPatch(spec.sampler);
        inst = std::move(sampler);
    } else {
        auto osc = std::make_unique<OscillatorInstrument>();
        osc->setDefaultPatch(spec.synth);
        inst = std::move(osc);
    }
    applyMix(*inst, spec);
    return engine.addInstrument(std::move(inst));
}

bool scheduleNote(Engine &engine, int id, IInstrument &inst, const InstrumentSpec &spec,
                  double freqHz, double velocity, double durationSeconds,
                  int64_t at, int gainStage)
{
    if (freqHz <= 0.0 || id < 0) return false;
    const int rate = engine.sampleRate();
    const bool sampler = spec.kind == InstrumentSpec::Kind::Sampler;

    double dur = durationSeconds;
    if (sampler) {
        if (!spec.sample) return false;
        // Without a duration the note plays to the sample's end (adjusted
        // for the playback rate). A loop still gets 60 s so the scheduler
        // has an end frame; it can be retriggered beyond.
        if (dur <= 0.0) {
            if (spec.sampler.looping) {
                dur = 60.0;
            } else {
                const double rootFreq = midiToHz(spec.rootMidiNote);
                const double step = (spec.sample->sampleRate / static_cast<double>(rate))
                                    * (freqHz / (rootFreq > 0.0 ? rootFreq : 1.0));
                const double frames = static_cast<double>(spec.sample->frames())
                                      / (step > 0.0 ? step : 1.0);
                dur = frames / static_cast<double>(rate);
            }
        }
    } else if (dur <= 0.0) {
        return false;
    }

    NoteEvent ev;
    ev.timeFrames     = at;
    ev.durationFrames = static_cast<int64_t>(std::llround(dur * rate));
    ev.freqHz         = freqHz;
    ev.velocity       = static_cast<float>(std::clamp(velocity, 0.0, 1.0));
    ev.instrumentId   = id;
    ev.gainStage      = gainStage;

    const EventId ticket = engine.schedule(ev);
    if (sampler) static_cast<SamplerInstrument &>(inst).pushPatch(ticket, spec.sampler);
    else         static_cast<OscillatorInstrument &>(inst).pushPatch(ticket, spec.synth);
    return true;
}

} // namespace clay::sound
