// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// InstrumentSpec — everything an engine instrument plays a note with:
// an oscillator patch, or a sample with its root note and patch, plus
// gain, pan, bus and voice cap. SynthInstrument and SampleInstrument
// (QML) hold one; a program without QML fills one in.
//
// scheduleNote() is the one way a note of such an instrument reaches an
// engine: SynthInstrument::trigger() and SampleInstrument::trigger()
// call it on the shared engine at its current frame, renderSong() on a
// scratch engine at the note's frame, so both play the same voice.

#pragma once

#include "bus.h"
#include "oscillator_voice.h"
#include "sample_voice.h"
#include "scheduler.h"

#include <cstdint>
#include <memory>

namespace clay::sound {

class Engine;
class IInstrument;
struct PcmBuffer;

struct InstrumentSpec
{
    enum class Kind { Synth, Sampler };
    Kind kind = Kind::Synth;

    OscillatorVoice::Patch synth{};             // Kind::Synth

    std::shared_ptr<const PcmBuffer> sample;    // Kind::Sampler
    int rootMidiNote = 60;                      // plays the sample as recorded
    SampleVoice::Patch sampler{};

    float gain = 0.8f;      // 0..1
    float pan = 0.0f;       // -1 left .. +1 right
    Bus   bus = Bus::Sfx;
    int   maxVoices = 0;    // 0 = no cap
};

// The frequency of a MIDI note: A4 = 69 = 440 Hz.
double midiToHz(int midiNote);

// A new engine instrument for `spec`, its gain, pan, bus and voice cap
// set; the engine owns it. Returns its id.
int addInstrument(Engine &engine, const InstrumentSpec &spec);

// Apply gain, pan, bus and voice cap of `spec` to `inst`.
void applyMix(IInstrument &inst, const InstrumentSpec &spec);

// Schedule one note of `spec` on the engine instrument `id` (`inst`,
// built for spec.kind) to start at engine frame `at`. velocity 0..1;
// a sampler note of durationSeconds <= 0 plays to the sample's end, or
// 60 s when it loops. Returns the scheduler ticket (Engine::cancel()),
// 0 when the note cannot sound (no frequency, no duration for a synth,
// no sample for a sampler).
EventId scheduleNote(Engine &engine, int id, IInstrument &inst, const InstrumentSpec &spec,
                     double freqHz, double velocity, double durationSeconds,
                     int64_t at, int gainStage = -1);

} // namespace clay::sound
