// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// IVoice — per-note renderer. Owns its own DSP state. Produced by an
// IInstrument in response to a NoteEvent; recycled by the engine when
// finished.

#pragma once

#include <cstdint>

namespace clay::sound {

struct NoteEvent;

class IVoice
{
public:
    virtual ~IVoice() = default;

    // Activate the voice for a concrete note. Called once.
    virtual void onNoteOn(const NoteEvent& ev, int sampleRate) = 0;

    // Early release. durationFrames on the event is the default gate;
    // this allows outside forcing of release (tracker cut, etc.).
    virtual void onNoteOff(int64_t atFrame) = 0;

    // Additively mix into `buffer` (mono, length = `frames`).
    // `bufferStartFrame` is the engine-time of buffer[0]. The voice is
    // responsible for writing only to the overlap of its own lifetime
    // with [bufferStartFrame, bufferStartFrame + frames).
    virtual void render(float* buffer, int frames, int64_t bufferStartFrame) = 0;

    // Once true, the engine can drop this voice.
    virtual bool isFinished(int64_t currentFrame) const = 0;
};

} // namespace clay::sound
