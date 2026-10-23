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
    // Noise only. The colour: white is flat, pink falls 3 dB and brown
    // 6 dB per octave. The rate: Sample draws a new value every sample,
    // Freq holds each value for one period of the voice's frequency (pitch
    // envelope and pitch LFO included), as the SNES noise clock does, so
    // a lower frequency moves the whole spectrum down.
    enum class NoiseColor { White, Pink, Brown };
    enum class NoiseRate { Sample, Freq };

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

        // Curve of each ADSR segment: 0 linear .. 1 exponential, a
        // straight line in dB (segment_curve.h).
        double attackCurve  = 0.0;
        double decayCurve   = 0.0;
        double releaseCurve = 0.0;

        // Pitch envelope (semitone offsets, sweep time in seconds) and
        // the curve of its sweep, 0 linear .. 1 exponential.
        double pitchStart = 0.0;
        double pitchEnd   = 0.0;
        double pitchTime  = 0.0;
        double pitchCurve = 0.0;

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
        // Curves of the cutoff envelope's segments, as attackCurve,
        // decayCurve and releaseCurve.
        double filterAttackCurve  = 0.0;
        double filterDecayCurve   = 0.0;
        double filterReleaseCurve = 0.0;

        // Noise only: the seed of the noise sequence. 0, the default,
        // seeds it from the note's start frame, so two notes at
        // different times hiss differently; any other value gives the
        // same sequence wherever the note starts (an effect recipe's
        // seeded noise layer, live and offline alike).
        uint32_t noiseSeed = 0;

        // Noise only: white, drawn every sample, sounds as noise did
        // before the two existed. Pink and brown sit about 6 dB below
        // white, so their peaks stay inside -1..1 as white's do.
        NoiseColor noiseColor = NoiseColor::White;
        NoiseRate  noiseRate  = NoiseRate::Sample;
    };

    void setPatch(const Patch& p) { patch_ = p; }

    void onNoteOn(const NoteEvent& ev, int sampleRate) override;
    void onNoteOff(int64_t atFrame) override;
    void onRelease(int64_t atFrame) override;
    void render(float* buffer, int frames, int64_t bufferStartFrame) override;
    bool isFinished(int64_t currentFrame) const override;

private:
    double renderSample(int64_t frame);
    double filter(double in, double t, double duration);
    double nextWhite();
    double nextNoise();

    Patch    patch_{};
    int      sampleRate_   = 44100;
    int64_t  startFrame_   = 0;
    int64_t  endFrame_     = 0;          // hard cutoff, driven by note duration
    double   freqHz_       = 440.0;
    double   gain_         = 1.0;        // velocity at onNoteOn
    double   phase_        = 0.0;        // 0..1
    uint32_t noiseSeed_    = 12345;
    double   noiseHeld_    = 0.0;        // the value a clocked noise holds
    bool     noiseDraw_    = true;       // draw the next one this sample
    double   pink_[7]      = {};         // pink filter states
    double   brown_        = 0.0;        // brown integrator state
    double   filterIc1_    = 0.0;        // SVF integrator states
    double   filterIc2_    = 0.0;
};

} // namespace clay::sound
