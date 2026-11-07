// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SnesOutput — the colour of the SNES's output on a bus: the bus mix
// is resampled to the S-DSP's 32 kHz through the chip's gaussian
// smoothing, and brought back to the engine's rate with nothing added
// above 16 kHz. A bus runs it last, after its echo and its reverb, as
// the S-DSP mixes its echo at 32 kHz before the output.
//
//   1. 32 kHz: sample m sits at engine frame origin + m * rate / 32000
//      and is the bus mix around it weighted by a gaussian of variance
//      0.4 in 32 kHz samples, the kernel SampleVoice interpolates with
//      (sample_voice.cpp). Its response is exp(-2 pi^2 0.4 (f/32k)^2):
//      -0.1 dB at 1 kHz, -4.3 dB at 8 kHz, -9.6 dB at 12 kHz and -17 dB
//      at 16 kHz. It is also the band limit, so what lies above 16 kHz
//      folds back down, quietly, as on the chip.
//   2. Back to the engine's rate: a Blackman-windowed sinc over 16
//      samples of the 32 kHz stream, its cutoff at 14 kHz, so the
//      images above 16 kHz stay out.
//
// Both together, measured with tones at 44.1 kHz (tst_snes_output):
// -0.07 dB at 1 kHz, -4.3 dB at 8 kHz, -6.8 dB at 10 kHz, -11 dB at
// 12 kHz, -19 dB at 14 kHz, and below -55 dB at its own frequency from
// 16 kHz up; 18 kHz folds to 14 kHz at -28 dB.
//
// Off by default, and a bus with it off renders exactly the samples it
// did before. Once on, the bus is late by latencyFrames() (16 frames,
// 0.36 ms, at 44.1 and at 48 kHz). The 32 kHz grid starts at an origin frame, and
// what the bus played before the origin is silence to the stage; so the
// same mix from the same origin gives the same samples whatever frame
// it starts on and whatever passes the sink pulls - a song starts the
// stage at its first frame, live and offline. Nothing is random.

#pragma once

#include <atomic>
#include <cstdint>
#include <limits>
#include <vector>

namespace clay::sound {

class SnesOutput
{
public:
    static constexpr int    kRate          = 32000;  // the S-DSP's output rate
    static constexpr double kGaussVariance = 0.4;    // in 32 kHz samples squared
    static constexpr double kGaussReach    = 2.5;    // 32 kHz samples to each side
    static constexpr int    kSincReach     = 8;      // 32 kHz samples to each side
    static constexpr double kSincCutoffHz  = 14000.0;

    // On: the grid starts at the first frame of the next pass. Off: the
    // bus is dry again, its delay and its history dropped.
    void setEnabled(bool on);
    bool enabled() const { return enabled_.load(std::memory_order_relaxed); }

    // On, the grid at engine frame `originFrame`, the history silent.
    // An origin already rendered is fine: the stage starts at the next
    // pass with the phase that origin gives it.
    void start(int64_t originFrame);

    // How late the bus sounds with the stage on, in engine frames.
    static int latencyFrames(int sampleRate);

    // Colour `mix` (interleaved stereo, `frames` frames starting at
    // engine frame `firstFrame`) in place. Audio thread only. Does
    // nothing while disabled; frames before the origin pass unchanged.
    void process(float* mix, int frames, int64_t firstFrame, int sampleRate);

private:
    static constexpr int64_t kNextPass = std::numeric_limits<int64_t>::min();
    static constexpr int kRing = 64;   // frames kept of each stream; a power of two

    void reset(int64_t origin, int64_t firstFrame, int sampleRate);
    void produce32k(int64_t m);
    void gaussWeights(int64_t rem, float* w) const;   // 2 * gaussReach_ taps
    void sincWeights(int64_t rem, float* w) const;    // 2 * kSincReach taps

    std::atomic<bool>     enabled_{false};
    std::atomic<unsigned> starts_{0};
    std::atomic<int64_t>  origin_{kNextPass};

    // Audio-thread state. Frames are counted from the origin: input j is
    // engine frame origin + j, and so is output j, which is input
    // j - delay_ through the stage.
    unsigned started_ = 0;
    bool     fresh_ = true;            // no pass seen since the last start
    int      rate_ = 0;
    int64_t  originUsed_ = 0;
    int      delay_ = 0;
    int      gaussReach_ = 0;          // engine frames to each side
    int64_t  firstIn_ = 0;             // the first input this start wrote; older ones are silent
    int64_t  firstM_ = 0;              // the first 32 kHz sample computed; older ones are silent
    int64_t  nextM_ = 0;               // the next 32 kHz sample to compute
    int      gcd_ = 1;                 // of the engine's rate and 32 kHz
    std::vector<float> gaussTable_;    // per phase; empty: computed per sample
    std::vector<float> sincTable_;
    float    in_[kRing][2] = {};
    float    s32_[kRing][2] = {};
};

} // namespace clay::sound
