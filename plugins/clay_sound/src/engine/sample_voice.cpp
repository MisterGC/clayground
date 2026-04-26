// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sample_voice.h"
#include "note_event.h"
#include "pcm_buffer.h"

#include <algorithm>
#include <cmath>

namespace clay::sound {

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
    const size_t i1 = i0 + 1;
    if (i0 >= n) return 0.0;
    const double frac = pos - static_cast<double>(i0);
    const double a = s[i0];
    const double b = (i1 < n) ? s[i1] : 0.0;
    return a + (b - a) * frac;
}

double SampleVoice::envelopeAt(int64_t frame) const
{
    const double t = static_cast<double>(frame - startFrame_) / sampleRate_;
    const double duration = static_cast<double>(endFrame_ - startFrame_) / sampleRate_;
    const double releaseStart = duration - patch_.release;

    if (t < 0.0) return 0.0;
    if (patch_.attack > 0.0 && t < patch_.attack)
        return t / patch_.attack;
    if (patch_.decay > 0.0 && t < patch_.attack + patch_.decay) {
        const double p = (t - patch_.attack) / patch_.decay;
        return 1.0 - (1.0 - patch_.sustain) * p;
    }
    if (t < releaseStart)
        return patch_.sustain > 0.0 ? patch_.sustain : 1.0;
    if (patch_.release > 0.0 && t < duration) {
        const double p = (t - releaseStart) / patch_.release;
        const double base = patch_.sustain > 0.0 ? patch_.sustain : 1.0;
        return base * (1.0 - p);
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
        buffer[idx] += static_cast<float>(s * velocity_ * envGate);

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
