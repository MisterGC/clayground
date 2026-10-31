// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sample_voice.h"
#include "note_event.h"
#include "pcm_buffer.h"
#include "segment_curve.h"

#include <algorithm>
#include <array>
#include <cmath>

namespace clay::sound {

namespace {

// The SNES DSP reads a 512-entry table of four Gaussian taps per phase.
// This computes such a table instead of copying it: at phase 0 the SNES
// weighs the centre sample 0.64 and each neighbour 0.18, which is a
// Gaussian of variance 0.4 (exp(-1 / (2 * 0.4)) = 0.29 = 0.18 / 0.64).
// Each phase's taps are normalised to sum 1, so a constant signal keeps
// its level; the SNES table sums slightly below 1 instead.
constexpr int kGaussPhases = 256;
using GaussTaps = std::array<double, 4>;

const std::array<GaussTaps, kGaussPhases>& gaussianTaps()
{
    static const std::array<GaussTaps, kGaussPhases> table = [] {
        constexpr double kVariance = 0.4;
        std::array<GaussTaps, kGaussPhases> t{};
        for (int p = 0; p < kGaussPhases; ++p) {
            const double frac = static_cast<double>(p) / kGaussPhases;
            double sum = 0.0;
            for (int k = 0; k < 4; ++k) {
                const double d = static_cast<double>(k - 1) - frac;
                t[p][k] = std::exp(-d * d / (2.0 * kVariance));
                sum += t[p][k];
            }
            for (double& w : t[p]) w /= sum;
        }
        return t;
    }();
    return table;
}

} // namespace

void SampleVoice::setSource(std::shared_ptr<const PcmBuffer> source, int rootMidiNote)
{
    source_ = std::move(source);
    rootMidiNote_ = rootMidiNote;
}

void SampleVoice::onNoteOn(const NoteEvent& ev, int sampleRate)
{
    sampleRate_ = sampleRate;
    startFrame_ = ev.timeFrames;
    endFrame_   = ev.timeFrames + ev.durationFrames;
    velocity_   = ev.velocity;
    srcPos_     = 0.0;
    exhausted_  = false;
    driveCrush_.start(patch_.driveCrush, sampleRate);

    if (!source_ || source_->sampleRate <= 0) {
        srcStep_ = 1.0;
        return;
    }

    // Playback rate combines (a) source-vs-engine sample rate and
    // (b) pitch shift from root note to played note.
    const double rootFreq = 440.0 * std::pow(2.0, (rootMidiNote_ - 69) / 12.0);
    const double pitchRatio = (rootFreq > 0.0) ? (ev.freqHz / rootFreq) : 1.0;
    const double srcOverEngine =
        static_cast<double>(source_->sampleRate) / static_cast<double>(sampleRate_);
    srcStep_ = srcOverEngine * pitchRatio;
}

void SampleVoice::onNoteOff(int64_t atFrame)
{
    if (atFrame < endFrame_ || endFrame_ == startFrame_)
        endFrame_ = atFrame;
}

void SampleVoice::onRelease(int64_t atFrame)
{
    // As OscillatorVoice: the release runs inside the gate.
    onNoteOff(atFrame + static_cast<int64_t>(std::llround(patch_.release * sampleRate_)));
}

bool SampleVoice::isFinished(int64_t currentFrame) const
{
    if (exhausted_) return true;
    if (currentFrame < startFrame_) return false;
    // For sampled voices `endFrame_` may exceed the source length; we
    // still stop once the sample is consumed.
    return currentFrame >= endFrame_;
}

double SampleVoice::sampleAtPos(double pos) const
{
    if (!source_ || source_->samples.empty()) return 0.0;
    const auto& s = source_->samples;
    const size_t n = s.size();

    // Clamp to buffer bounds. Looping (if any) wraps into
    // [loopStart, loopEnd).
    if (patch_.looping) {
        const double ls = std::clamp(patch_.loopStartFrac, 0.0, 1.0) * n;
        const double le = std::clamp(patch_.loopEndFrac,   0.0, 1.0) * n;
        if (le > ls && pos >= le) {
            const double span = le - ls;
            pos = ls + std::fmod(pos - ls, span);
            if (pos < ls) pos += span;
        }
    } else if (pos >= static_cast<double>(n - 1)) {
        return 0.0;
    }

    const size_t i0 = static_cast<size_t>(pos);
    if (i0 >= n) return 0.0;
    const double frac = pos - static_cast<double>(i0);
    // Taps outside the buffer read silence.
    auto at = [&s, n](size_t i) -> double { return i < n ? s[i] : 0.0; };

    switch (patch_.interpolation) {
    case Interpolation::Nearest:
        return frac < 0.5 ? s[i0] : at(i0 + 1);
    case Interpolation::Gaussian: {
        const auto& w = gaussianTaps()[static_cast<size_t>(frac * kGaussPhases)];
        // i0 - 1 wraps to SIZE_MAX at the buffer's start, which at()
        // reads as silence.
        return w[0] * at(i0 - 1) + w[1] * s[i0] + w[2] * at(i0 + 1) + w[3] * at(i0 + 2);
    }
    case Interpolation::Linear:
        break;
    }
    const double a = s[i0];
    const double b = at(i0 + 1);
    return a + (b - a) * frac;
}

double SampleVoice::envelopeAt(int64_t frame) const
{
    const double t = static_cast<double>(frame - startFrame_) / sampleRate_;
    const double duration = static_cast<double>(endFrame_ - startFrame_) / sampleRate_;
    const double releaseStart = duration - patch_.release;

    if (t < 0.0) return 0.0;
    if (patch_.attack > 0.0 && t < patch_.attack)
        return segmentShape(t / patch_.attack, patch_.attackCurve);
    if (patch_.decay > 0.0 && t < patch_.attack + patch_.decay) {
        const double p = (t - patch_.attack) / patch_.decay;
        return 1.0 - (1.0 - patch_.sustain) * segmentShape(p, patch_.decayCurve);
    }
    if (t < releaseStart)
        return patch_.sustain > 0.0 ? patch_.sustain : 1.0;
    if (patch_.release > 0.0 && t < duration) {
        const double p = (t - releaseStart) / patch_.release;
        const double base = patch_.sustain > 0.0 ? patch_.sustain : 1.0;
        return base * (1.0 - segmentShape(p, patch_.releaseCurve));
    }
    // Default: raw playback with a hard gate at duration.
    return (t < duration) ? 1.0 : 0.0;
}

void SampleVoice::render(float* buffer, int frames, int64_t bufferStartFrame)
{
    if (!source_ || source_->samples.empty() || exhausted_) return;

    const int64_t bufEnd = bufferStartFrame + frames;
    const int64_t lo     = std::max(startFrame_, bufferStartFrame);
    const int64_t hi     = std::min(endFrame_, bufEnd);

    const size_t n = source_->samples.size();
    const bool hasEnvelope =
        patch_.attack > 0.0 || patch_.decay > 0.0 || patch_.release > 0.0;

    for (int64_t f = lo; f < hi; ++f) {
        const int idx = static_cast<int>(f - bufferStartFrame);
        const double s = sampleAtPos(srcPos_);
        const double envGate = hasEnvelope ? envelopeAt(f) : 1.0;
        // Without drive or crush in the order it always had, so the
        // samples stay those it rendered before the two existed.
        buffer[idx] += static_cast<float>(patch_.driveCrush.active()
            ? driveCrush_.process(s * envGate) * velocity_
            : s * velocity_ * envGate);

        srcPos_ += srcStep_;
        if (!patch_.looping && srcPos_ >= static_cast<double>(n - 1)) {
            exhausted_ = true;
            // Finish the voice at this frame so the engine drops it.
            if (endFrame_ > f + 1) endFrame_ = f + 1;
            break;
        }
    }
}

} // namespace clay::sound
