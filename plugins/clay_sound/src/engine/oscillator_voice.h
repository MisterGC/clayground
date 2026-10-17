// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// OscillatorVoice — IVoice implementation carrying the oscillator +
// envelope + LFO + pitch-envelope DSP lifted out of SoftSynth, and a
// resonant filter with a cutoff envelope of its own.
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
    enum class FilterType { Off, LowPass, HighPass, BandPass };

    struct Patch
    {
        Waveform waveform = Waveform::Sine;

        // Square only: the fraction of a period the wave is high.
        // 0.5 is the plain square; clamped to 0.05..0.95.
        double pulseWidth = 0.5;

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

        // Two-pole state-variable filter after the oscillator. Off
        // bypasses it, so the voice sounds as it did before the filter.
        FilterType filterType = FilterType::Off;
        double cutoff    = 1000.0;   // Hz
        double resonance = 0.0;      // 0 = no peak (Q 0.707) .. 1 = Q 10

        // Cutoff envelope: an ADSR of its own (seconds, sustain 0..1)
        // that moves the cutoff up by filterEnvAmount octaves at its
        // peak (down, if negative). Amount 0 leaves the cutoff fixed.
        double filterAttack    = 0.0;
        double filterDecay     = 0.0;
        double filterSustain   = 1.0;
        double filterRelease   = 0.0;
        double filterEnvAmount = 0.0;
    };

    void setPatch(const Patch& p) { patch_ = p; }

    void onNoteOn(const NoteEvent& ev, int sampleRate) override;
    void onNoteOff(int64_t atFrame) override;
    void render(float* buffer, int frames, int64_t bufferStartFrame) override;
    bool isFinished(int64_t currentFrame) const override;

private:
    double renderSample(int64_t frame);
    double filter(double in, double t, double duration);

    Patch    patch_{};
    int      sampleRate_   = 44100;
    int64_t  startFrame_   = 0;
    int64_t  endFrame_     = 0;          // hard cutoff, driven by note duration
    double   freqHz_       = 440.0;
    double   gain_         = 1.0;        // velocity at onNoteOn
    double   phase_        = 0.0;        // 0..1
    uint32_t noiseSeed_    = 12345;
    double   filterIc1_    = 0.0;        // SVF integrator states
    double   filterIc2_    = 0.0;
};

} // namespace clay::sound
