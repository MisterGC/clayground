// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Platform-agnostic waveform enum shared by the classic SoftSynth
// NoteEvent, the ChipTracker patch->waveform mapper, and any other
// caller that speaks in terms of Voice::Waveform. Kept free of Qt so
// it compiles into both desktop and WASM builds regardless of the
// surrounding audio-backend guards.

#ifndef CLAY_SOUND_VOICE_WAVEFORM_H
#define CLAY_SOUND_VOICE_WAVEFORM_H

struct Voice
{
    enum Waveform { Sine, Square, Triangle, Sawtooth, Noise };
};

#endif // CLAY_SOUND_VOICE_WAVEFORM_H
