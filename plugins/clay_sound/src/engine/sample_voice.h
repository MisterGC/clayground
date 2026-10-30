// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SampleVoice — IVoice reading from a shared PcmBuffer. Pitch shift is
// via playback-rate; between source samples the voice interpolates
// nearest, linear (the default) or Gaussian. Supports an optional loop
// segment and a lightweight envelope overlay.

#pragma once

#include "voice.h"
#include <cstdint>
#include <memory>

namespace clay::sound {

struct PcmBuffer;

class SampleVoice : public IVoice
{
public:
    // How a position between two source samples is read.
    //   Nearest  — the closest sample: hard, aliased, 8-bit-console grit.
    //   Linear   — straight line between the two neighbours.
    //   Gaussian — four taps weighted by a Gaussian, like the SNES DSP:
    //              soft and slightly muffled, the highs rolled off.
    enum class Interpolation { Nearest, Linear, Gaussian };

    struct Patch
    {
        Interpolation interpolation = Interpolation::Linear;
        bool   looping      = false;
        double loopStartFrac = 0.0;  // 0..1 of buffer length
        double loopEndFrac   = 1.0;

        // ADSR overlay (in seconds). attack = 0 + release = 0 means
        // "play the sample raw".
        double attack  = 0.0;
        double decay   = 0.0;
        double sustain = 1.0;
        double release = 0.0;

        // Curve of each segment: 0 linear .. 1 exponential, a straight
        // line in dB (segment_curve.h).
        double attackCurve  = 0.0;
        double decayCurve   = 0.0;
        double releaseCurve = 0.0;
    };

    // Configure before onNoteOn(). Shared ownership of the source
    // buffer keeps this cheap across many voices.
    void setSource(std::shared_ptr<const PcmBuffer> source, int rootMidiNote);
    void setPatch(const Patch& p) { patch_ = p; }

    void onNoteOn(const NoteEvent& ev, int sampleRate) override;
    void onNoteOff(int64_t atFrame) override;
    void onRelease(int64_t atFrame) override;
    void render(float* buffer, int frames, int64_t bufferStartFrame) override;
    bool isFinished(int64_t currentFrame) const override;

private:
    double envelopeAt(int64_t frame) const;
    double sampleAtPos(double pos) const;

    std::shared_ptr<const PcmBuffer> source_;
    int     rootMidiNote_ = 60;
    Patch   patch_{};

    int     sampleRate_ = 44100;
    int64_t startFrame_ = 0;
    int64_t endFrame_   = 0;           // hard cutoff per duration; 0 = "play to sample end"
    double  velocity_   = 1.0;
    double  srcPos_     = 0.0;         // current position in source samples
    double  srcStep_    = 1.0;         // per engine sample
    bool    exhausted_  = false;       // non-looping sample reached end
};

} // namespace clay::sound
