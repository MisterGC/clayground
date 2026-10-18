// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "bus_effects.h"

#include <algorithm>
#include <cmath>

namespace clay::sound {

static float clampTo(float v, float lo, float hi) { return std::clamp(v, lo, hi); }

// Off -> on bumps `starts`; the audio thread clears its state when it
// sees a count it has not started from, so a re-enabled effect never
// replays the tail it had when it was turned off.
static void switchOn(std::atomic<bool>& enabled, std::atomic<unsigned>& starts, bool on)
{
    if (enabled.load(std::memory_order_relaxed) == on) return;
    if (on) starts.fetch_add(1, std::memory_order_relaxed);
    enabled.store(on, std::memory_order_relaxed);
}

void Echo::setEnabled(bool on) { switchOn(enabled_, starts_, on); }

void Echo::setDelayMs(float ms)  { delayMs_.store(clampTo(ms, 1.0f, kMaxDelayMs), std::memory_order_relaxed); }
void Echo::setFeedback(float fb) { feedback_.store(clampTo(fb, -1.0f, 1.0f), std::memory_order_relaxed); }
void Echo::setVolume(float v)    { volume_.store(clampTo(v, 0.0f, 1.0f), std::memory_order_relaxed); }

void Echo::setFirTap(int tap, float c)
{
    if (tap < 0 || tap >= kTaps) return;
    fir_[tap].store(clampTo(c, -1.0f, 1.0f), std::memory_order_relaxed);
}

float Echo::firTap(int tap) const
{
    if (tap < 0 || tap >= kTaps) return 0.0f;
    return fir_[tap].load(std::memory_order_relaxed);
}

void Echo::process(float* mix, int frames, int sampleRate)
{
    if (!enabled()) return;
    // The count may still lag the switch it belongs to by a pass; an
    // empty line is cleared from either way.
    if (const unsigned s = starts_.load(std::memory_order_relaxed); s != started_ || capacity_ == 0) {
        started_ = s;
        // Sized once per sample rate; a re-enable only clears it.
        const int cap = static_cast<int>(std::ceil(kMaxDelayMs * sampleRate / 1000.0f));
        if (capacity_ != cap) { capacity_ = cap; line_.assign(2 * static_cast<size_t>(cap), 0.0f); }
        else std::fill(line_.begin(), line_.end(), 0.0f);
        std::fill(&history_[0][0], &history_[0][0] + 2 * kTaps, 0.0f);
        write_ = 0;
        head_ = 0;
    }

    const int delay = std::clamp(static_cast<int>(std::lround(delayMs() * sampleRate / 1000.0f)),
                                 1, capacity_);
    const float fb = feedback();
    const float vol = volume();
    float c[kTaps];
    for (int k = 0; k < kTaps; ++k) c[k] = firTap(k);

    for (int i = 0; i < frames; ++i) {
        // delay <= capacity_, so the read lands on a frame written
        // `delay` frames ago (or, at the full delay, the oldest one).
        int read = write_ - delay;
        if (read < 0) read += capacity_;
        for (int ch = 0; ch < 2; ++ch) {
            float* h = history_[ch];
            h[head_] = line_[2 * static_cast<size_t>(read) + ch];
            float fir = 0.0f;
            for (int k = 0; k < kTaps; ++k) fir += c[k] * h[(head_ - k + kTaps) % kTaps];
            const float in = mix[2 * i + ch];
            line_[2 * static_cast<size_t>(write_) + ch] = clampTo(in + fb * fir, -kClip, kClip);
            mix[2 * i + ch] = in + vol * fir;
        }
        head_ = (head_ + 1) % kTaps;
        if (++write_ == capacity_) write_ = 0;
    }
}

// Freeverb's tunings at 44.1 kHz, scaled to the engine's rate.
static constexpr int kCombTuning[] = {1116, 1188, 1277, 1356};
static constexpr int kAllpassTuning[] = {556, 441};
static constexpr int kStereoSpread = 23;
// Four combs in parallel sum their input four times over.
static constexpr float kInputGain = 0.25f;
static constexpr float kAllpassFeedback = 0.5f;

void Reverb::setEnabled(bool on) { switchOn(enabled_, starts_, on); }
void Reverb::setRoomSize(float r) { roomSize_.store(clampTo(r, 0.0f, 1.0f), std::memory_order_relaxed); }
void Reverb::setDamping(float d)  { damping_.store(clampTo(d, 0.0f, 1.0f), std::memory_order_relaxed); }
void Reverb::setVolume(float v)   { volume_.store(clampTo(v, 0.0f, 1.0f), std::memory_order_relaxed); }

void Reverb::process(float* mix, int frames, int sampleRate)
{
    if (!enabled()) return;
    if (const unsigned s = starts_.load(std::memory_order_relaxed);
        s != started_ || combs_[0][0].buf.empty()) {
        started_ = s;
        const double scale = sampleRate / 44100.0;
        auto size = [scale](int tuning, int ch) {
            return std::max(1, static_cast<int>(std::lround((tuning + ch * kStereoSpread) * scale)));
        };
        for (int ch = 0; ch < 2; ++ch) {
            for (int k = 0; k < kCombs; ++k)
                combs_[ch][k] = {std::vector<float>(size(kCombTuning[k], ch), 0.0f), 0, 0.0f};
            for (int k = 0; k < kAllpasses; ++k)
                allpasses_[ch][k] = {std::vector<float>(size(kAllpassTuning[k], ch), 0.0f), 0, 0.0f};
        }
    }

    // Freeverb's mapping: feedback 0.7 .. 0.98, damping 0 .. 0.4.
    const float fb = 0.7f + 0.28f * roomSize();
    const float damp = 0.4f * damping();
    const float vol = volume();

    for (int i = 0; i < frames; ++i) {
        const float in = (mix[2 * i] + mix[2 * i + 1]) * 0.5f * kInputGain;
        for (int ch = 0; ch < 2; ++ch) {
            float wet = 0.0f;
            for (Line& comb : combs_[ch]) {
                const float out = comb.buf[comb.pos];
                comb.filter = out * (1.0f - damp) + comb.filter * damp;
                // A decaying tail ends in denormals, which are slow on
                // some CPUs; it is silence long before that.
                if (std::abs(comb.filter) < 1e-15f) comb.filter = 0.0f;
                comb.buf[comb.pos] = in + comb.filter * fb;
                if (++comb.pos == static_cast<int>(comb.buf.size())) comb.pos = 0;
                wet += out;
            }
            for (Line& ap : allpasses_[ch]) {
                const float delayed = ap.buf[ap.pos];
                ap.buf[ap.pos] = wet + delayed * kAllpassFeedback;
                if (++ap.pos == static_cast<int>(ap.buf.size())) ap.pos = 0;
                wet = delayed - wet;
            }
            mix[2 * i + ch] += vol * wet;
        }
    }
}

} // namespace clay::sound
