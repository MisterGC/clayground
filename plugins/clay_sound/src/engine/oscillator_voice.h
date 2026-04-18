// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// OscillatorVoice — IVoice implementation carrying the oscillator +
// envelope + LFO + pitch-envelope DSP lifted out of SoftSynth.
//
// The voice is patch-configurable; a sibling OscillatorInstrument owns
// the patches and stamps them onto voices at createVoice() time. For
// legacy callers (existing SoftSynth) the patch may also be set
// directly via setPatch() before onNoteOn().

#pragma once

#include "voice.h"
#include <cstdint>

namespace clay::sound {

class OscillatorVoice : public IVoice
{
public:
    enum class Waveform { Sine, Square, Triangle, Sawtooth, Noise };

    struct Patch
    {
        Waveform waveform = Waveform::Sine;

        // ADSR in seconds.
        double attack  = 0.01;
        double decay   = 0.10;
        double sustain = 0.60;
        double release = 0.30;

        // Pitch envelope (semitone offsets, sweep time in seconds).
        double pitchStart = 0.0;
        double pitchEnd   = 0.0;
        double pitchTime  = 0.0;

        // LFO. lfoTarget: 0=off, 1=pitch, 2=volume.
        double lfoRate   = 0.0;
        double lfoDepth  = 0.0;
        int    lfoTarget = 0;
    };

    void setPatch(const Patch& p) { patch_ = p; }

    void onNoteOn(const NoteEvent& ev, int sampleRate) override;
    void onNoteOff(int64_t atFrame) override;
    void render(float* buffer, int frames, int64_t bufferStartFrame) override;
    bool isFinished(int64_t currentFrame) const override;

private:
    double renderSample(int64_t frame);

    Patch    patch_{};
    int      sampleRate_   = 44100;
    int64_t  startFrame_   = 0;
    int64_t  endFrame_     = 0;          // hard cutoff, driven by note duration
    double   freqHz_       = 440.0;
    double   gain_         = 1.0;        // velocity at onNoteOn
    double   phase_        = 0.0;        // 0..1
    uint32_t noiseSeed_    = 12345;
};

} // namespace clay::sound
