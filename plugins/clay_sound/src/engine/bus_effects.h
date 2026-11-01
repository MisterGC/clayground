// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Bus effects — an echo and a small reverb that a bus runs over its
// stereo mix before its volume scales it. Both are off by default, and
// a bus with no effect on renders exactly the samples it did without
// them. Parameters are atomics: the GUI thread sets them while the
// audio thread renders, and a change lands on the next mix pass.
//
// Turning an effect off drops its tail; turning it on again starts
// from silence. Neither draws a random number, so the same notes render
// the same samples.

#pragma once

#include <atomic>
#include <vector>

namespace clay::sound {

// The SNES echo: the bus mix is written into a delay line, the delayed
// signal runs through an 8-tap FIR filter, and the filter's output is
// both added to the bus (scaled by volume) and fed back into the delay
// line (scaled by feedback). A low-pass FIR darkens every repeat a
// little more, which is where the SNES warmth comes from. The taps
// are consecutive samples at the engine's rate; tap 0 is the newest.
// The default taps {1, 0, ..., 0} pass the delayed signal unchanged, so
// repeat n is volume * feedback^(n-1) times the input, delay * n later.
class Echo
{
public:
    static constexpr int   kTaps       = 8;
    static constexpr float kMaxDelayMs = 1000.0f;

    // Off by default. Once on, the defaults are a 120 ms delay, each
    // repeat at half the level of the one before it, added at half volume.
    void  setEnabled(bool on);
    bool  enabled() const     { return enabled_.load(std::memory_order_relaxed); }
    // Delay in milliseconds, clamped to [1, kMaxDelayMs].
    void  setDelayMs(float ms);
    float delayMs() const     { return delayMs_.load(std::memory_order_relaxed); }
    // Fraction of the filtered echo written back, clamped to [-1, 1].
    // A negative feedback flips the sign of every other repeat.
    void  setFeedback(float fb);
    float feedback() const    { return feedback_.load(std::memory_order_relaxed); }
    // Level of the filtered echo added to the bus, clamped to [0, 1].
    void  setVolume(float v);
    float volume() const      { return volume_.load(std::memory_order_relaxed); }
    // FIR coefficient `tap` in [0, kTaps), clamped to [-1, 1]. Taps
    // whose sum exceeds 1 can make the feedback loop grow; the delay
    // line clips at +-kClip so it cannot run away.
    void  setFirTap(int tap, float c);
    float firTap(int tap) const;

    // Add the echo to `mix` (interleaved stereo, `frames` frames) in
    // place. Audio thread only. Does nothing while disabled.
    void process(float* mix, int frames, int sampleRate);

private:
    static constexpr float kClip = 4.0f;

    std::atomic<bool>  enabled_{false};
    std::atomic<unsigned> starts_{0};  // counts off -> on, so a new start clears the line
    std::atomic<float> delayMs_{120.0f};
    std::atomic<float> feedback_{0.5f};
    std::atomic<float> volume_{0.5f};
    std::atomic<float> fir_[kTaps] = {1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};

    // Audio-thread state. The delay line holds a full kMaxDelayMs, so a
    // delay change only moves the read position.
    unsigned started_ = 0;
    std::vector<float> line_;          // interleaved stereo ring
    int capacity_ = 0;                 // frames in line_
    int write_ = 0;
    float history_[2][kTaps] = {};     // the last delayed samples per channel
    int head_ = 0;
};

// A small Schroeder reverb in the Freeverb pattern: four damped
// feedback combs in parallel and two allpasses in series per channel,
// fed the mono sum of the bus and added back scaled by volume. The
// right channel's delays are a little longer than the left's, so the
// tail is wide even for a centred source.
class Reverb
{
public:
    // Off by default. Once on, the defaults are room size 0.5, damping
    // 0.5 and volume 0.3.
    void  setEnabled(bool on);
    bool  enabled() const     { return enabled_.load(std::memory_order_relaxed); }
    // 0..1: the comb feedback, so the length of the tail.
    void  setRoomSize(float r);
    float roomSize() const    { return roomSize_.load(std::memory_order_relaxed); }
    // 0..1: how fast the high frequencies die in the tail.
    void  setDamping(float d);
    float damping() const     { return damping_.load(std::memory_order_relaxed); }
    // 0..1: level of the reverberated signal added to the bus.
    void  setVolume(float v);
    float volume() const      { return volume_.load(std::memory_order_relaxed); }

    // Add the reverb to `mix` (interleaved stereo) in place. Audio
    // thread only. Does nothing while disabled.
    void process(float* mix, int frames, int sampleRate);

private:
    static constexpr int kCombs = 4;
    static constexpr int kAllpasses = 2;

    struct Line {
        std::vector<float> buf;
        int pos = 0;
        float filter = 0.0f;           // comb only: the damping low-pass
    };

    std::atomic<bool>  enabled_{false};
    std::atomic<unsigned> starts_{0};
    std::atomic<float> roomSize_{0.5f};
    std::atomic<float> damping_{0.5f};
    std::atomic<float> volume_{0.3f};

    unsigned started_ = 0;
    Line combs_[2][kCombs];
    Line allpasses_[2][kAllpasses];
};

} // namespace clay::sound
