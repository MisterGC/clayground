// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Canonical note event. Sample-frame timed, instrument-agnostic.
// The same struct is produced by the sequencer and consumed by the engine,
// independent of whether the bound instrument renders via oscillator or PCM.

#pragma once

#include <cstdint>

namespace clay::sound {

struct NoteEvent
{
    int64_t  timeFrames     = 0;      // Engine-time of trigger (sample frames)
    int64_t  durationFrames = 0;      // Gate length; 0 = instrument-decided
    double   freqHz         = 440.0;  // Pitch. MIDI-note helpers live at a higher layer.
    float    velocity       = 1.0f;   // 0..1
    int      instrumentId   = -1;     // -1 = unbound; engine ignores
    float    pan            = 0.0f;   // -1 left .. +1 right (mono engine ignores for now)
    uint32_t effectPayload  = 0;      // Reserved for tracker effects; opaque in Stage 0
};

} // namespace clay::sound
