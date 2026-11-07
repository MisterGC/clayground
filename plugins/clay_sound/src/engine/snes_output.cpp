// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "snes_output.h"

#include <algorithm>
#include <cmath>
#include <numeric>

namespace clay::sound {

namespace {

constexpr int kMaxRate = 192000;   // the rings hold the reach of rates up to this
constexpr int kMaxTablePhases = 4096;
constexpr double kPi = 3.14159265358979323846;

int64_t floorDiv(int64_t a, int64_t b)
{
    int64_t q = a / b;
    if ((a % b != 0) && ((a < 0) != (b < 0))) --q;
    return q;
}

int64_t ceilDiv(int64_t a, int64_t b) { return -floorDiv(-a, b); }

int gaussReachFrames(int sampleRate)
{
    // kGaussReach * rate / 32000, rounded up: 2.5 = 5 / 2.
    return static_cast<int>(ceilDiv(5 * static_cast<int64_t>(sampleRate), 2 * SnesOutput::kRate));
}

} // namespace

void SnesOutput::setEnabled(bool on)
{
    if (enabled_.load(std::memory_order_relaxed) == on) return;
    if (on) {
        origin_.store(kNextPass, std::memory_order_relaxed);
        starts_.fetch_add(1, std::memory_order_release);
    }
    enabled_.store(on, std::memory_order_relaxed);
}

unsigned SnesOutput::start(int64_t originFrame)
{
    origin_.store(originFrame, std::memory_order_relaxed);
    const unsigned token = starts_.fetch_add(1, std::memory_order_release) + 1;
    enabled_.store(true, std::memory_order_relaxed);
    return token;
}

void SnesOutput::release(unsigned token)
{
    if (starts_.load(std::memory_order_relaxed) == token) setEnabled(false);
}

int SnesOutput::latencyFrames(int sampleRate)
{
    // Output j reads the 32 kHz stream up to kSincReach samples past
    // input j - delay, and that sample reads the input gaussReach
    // frames past its own position; both must be in by frame j.
    return static_cast<int>(ceilDiv(kSincReach * static_cast<int64_t>(sampleRate), kRate))
        + gaussReachFrames(sampleRate);
}

// Taps for the 32 kHz sample at input position kc + rem / 32000 (in
// frames from the origin): inputs kc - reach + 1 .. kc + reach.
void SnesOutput::gaussWeights(int64_t rem, float* w) const
{
    const double frac = static_cast<double>(rem) / kRate;
    const double toS32 = static_cast<double>(kRate) / rate_;
    const int taps = 2 * gaussReach_;
    double sum = 0.0;
    double raw[2 * 64];
    for (int i = 0; i < taps; ++i) {
        const double d = ((i - gaussReach_ + 1) - frac) * toS32;
        raw[i] = std::abs(d) <= kGaussReach ? std::exp(-d * d / (2.0 * kGaussVariance)) : 0.0;
        sum += raw[i];
    }
    for (int i = 0; i < taps; ++i) w[i] = static_cast<float>(raw[i] / sum);
}

// Taps for output at 32 kHz position mc + rem / rate: 32 kHz samples
// mc - kSincReach + 1 .. mc + kSincReach.
void SnesOutput::sincWeights(int64_t rem, float* w) const
{
    const double frac = static_cast<double>(rem) / rate_;
    // Below 32 kHz the engine's own Nyquist limits the cutoff too.
    const double cutoff = std::min(kSincCutoffHz, 0.4375 * rate_);
    const double fc = 2.0 * cutoff / kRate;   // of the 32 kHz Nyquist
    const int taps = 2 * kSincReach;
    double sum = 0.0;
    double raw[2 * kSincReach];
    for (int i = 0; i < taps; ++i) {
        const double x = frac + (kSincReach - 1 - i);
        const double sx = fc * x;
        const double sinc = sx == 0.0 ? 1.0 : std::sin(kPi * sx) / (kPi * sx);
        const double y = x / kSincReach;
        const double win = std::abs(y) < 1.0
            ? 0.42 + 0.5 * std::cos(kPi * y) + 0.08 * std::cos(2.0 * kPi * y) : 0.0;
        raw[i] = fc * sinc * win;
        sum += raw[i];
    }
    for (int i = 0; i < taps; ++i) w[i] = static_cast<float>(raw[i] / sum);
}

void SnesOutput::reset(int64_t origin, int64_t firstFrame, int sampleRate)
{
    if (sampleRate != rate_) {
        rate_ = sampleRate;
        gaussReach_ = gaussReachFrames(sampleRate);
        delay_ = latencyFrames(sampleRate);
        gcd_ = std::gcd(sampleRate, kRate);
        // The phases repeat: 32 kHz samples every 32000 / gcd, engine
        // frames every rate / gcd. Tables when that is few, and the
        // same weights computed per sample otherwise.
        const int gaussPhases = kRate / gcd_;
        const int sincPhases = sampleRate / gcd_;
        gaussTable_.clear();
        sincTable_.clear();
        if (gaussPhases <= kMaxTablePhases) {
            gaussTable_.resize(static_cast<size_t>(gaussPhases) * 2 * gaussReach_);
            for (int p = 0; p < gaussPhases; ++p)
                gaussWeights(static_cast<int64_t>(p) * gcd_, &gaussTable_[static_cast<size_t>(p) * 2 * gaussReach_]);
        }
        if (sincPhases <= kMaxTablePhases) {
            sincTable_.resize(static_cast<size_t>(sincPhases) * 2 * kSincReach);
            for (int p = 0; p < sincPhases; ++p)
                sincWeights(static_cast<int64_t>(p) * gcd_, &sincTable_[static_cast<size_t>(p) * 2 * kSincReach]);
        }
    }
    originUsed_ = origin == kNextPass ? firstFrame : origin;
    for (auto& f : in_)  f[0] = f[1] = 0.0f;
    for (auto& f : s32_) f[0] = f[1] = 0.0f;
    // An origin already behind: the inputs before this pass are silent,
    // and so is every 32 kHz sample that reads only them.
    firstIn_ = std::max<int64_t>(0, firstFrame - originUsed_);
    firstM_ = std::max<int64_t>(0, floorDiv((firstIn_ - gaussReach_) * kRate, rate_));
    nextM_ = firstM_;
    fresh_ = false;
}

void SnesOutput::produce32k(int64_t m)
{
    const int64_t pos = m * rate_;
    const int64_t kc = pos / kRate;             // m >= 0
    const int64_t rem = pos - kc * kRate;
    const int taps = 2 * gaussReach_;
    float local[2 * 64];
    const float* w = local;
    if (!gaussTable_.empty()) w = &gaussTable_[static_cast<size_t>(rem / gcd_) * taps];
    else gaussWeights(rem, local);
    float l = 0.0f, r = 0.0f;
    const int64_t k0 = kc - gaussReach_ + 1;
    for (int i = 0; i < taps; ++i) {
        const int64_t k = k0 + i;
        if (k < firstIn_) continue;
        const float* x = in_[k & (kRing - 1)];
        l += w[i] * x[0];
        r += w[i] * x[1];
    }
    float* s = s32_[m & (kRing - 1)];
    s[0] = l;
    s[1] = r;
}

void SnesOutput::process(float* mix, int frames, int64_t firstFrame, int sampleRate)
{
    if (!enabled() || frames <= 0 || sampleRate <= 0 || sampleRate > kMaxRate) return;
    if (const unsigned s = starts_.load(std::memory_order_acquire); s != started_ || fresh_ || sampleRate != rate_) {
        started_ = s;
        reset(origin_.load(std::memory_order_relaxed), firstFrame, sampleRate);
    }

    const int taps = 2 * kSincReach;
    float local[2 * kSincReach];
    for (int i = 0; i < frames; ++i) {
        const int64_t j = firstFrame + i - originUsed_;
        if (j < 0) continue;                    // before the origin: dry

        float* x = in_[j & (kRing - 1)];
        x[0] = mix[2 * i];
        x[1] = mix[2 * i + 1];
        // Every 32 kHz sample whose last input is in.
        while ((nextM_ * rate_) / kRate + gaussReach_ <= j) produce32k(nextM_++);

        const int64_t t = (j - delay_) * kRate;
        const int64_t mc = floorDiv(t, rate_);
        const int64_t rem = t - mc * rate_;
        const float* w = local;
        if (!sincTable_.empty()) w = &sincTable_[static_cast<size_t>(rem / gcd_) * taps];
        else sincWeights(rem, local);
        float l = 0.0f, r = 0.0f;
        const int64_t m0 = mc - kSincReach + 1;
        for (int k = 0; k < taps; ++k) {
            const int64_t m = m0 + k;
            if (m < firstM_) continue;
            const float* y = s32_[m & (kRing - 1)];
            l += w[k] * y[0];
            r += w[k] * y[1];
        }
        mix[2 * i] = l;
        mix[2 * i + 1] = r;
    }
}

} // namespace clay::sound
