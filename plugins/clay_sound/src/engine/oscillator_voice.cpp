// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "oscillator_voice.h"
#include "note_event.h"
#include <algorithm>
#include <cmath>

namespace clay::sound {

// M_PI is not part of the C++ standard; MSVC omits it unless
// _USE_MATH_DEFINES is set before <cmath>. Define our own so this
// file stays portable across compilers.
static constexpr double kPi = 3.14159265358979323846;

void OscillatorVoice::onNoteOn(const NoteEvent& ev, int sampleRate)
{
    sampleRate_ = sampleRate;
    startFrame_ = ev.timeFrames;
    endFrame_   = ev.timeFrames + ev.durationFrames;
    freqHz_     = ev.freqHz;
    gain_       = ev.velocity;
    phase_      = 0.0;
    // Deterministic-per-voice noise seed. Derived from start frame so
    // two noise notes at different times produce different sequences.
    noiseSeed_ = 12345u + static_cast<uint32_t>(ev.timeFrames & 0xffffffff);
}

void OscillatorVoice::onNoteOff(int64_t atFrame)
{
    // Clamp note end forward; lets external code cut a ringing voice.
    if (atFrame < endFrame_)
        endFrame_ = atFrame;
}

bool OscillatorVoice::isFinished(int64_t currentFrame) const
{
    return currentFrame >= endFrame_;
}

double OscillatorVoice::renderSample(int64_t frame)
{
    // Time since noteOn, in seconds.
    const double t        = static_cast<double>(frame - startFrame_) / sampleRate_;
    const double duration = static_cast<double>(endFrame_ - startFrame_) / sampleRate_;

    // --- Envelope -----------------------------------------------------
    double env = 0.0;
    if (t >= 0.0) {
        const double releaseStart = duration - patch_.release;
        if (t < patch_.attack) {
            env = (patch_.attack > 0.0) ? (t / patch_.attack) : 1.0;
        } else if (t < patch_.attack + patch_.decay) {
            const double p = (patch_.decay > 0.0)
                                 ? (t - patch_.attack) / patch_.decay
                                 : 1.0;
            env = 1.0 - (1.0 - patch_.sustain) * p;
        } else if (t < releaseStart) {
            env = patch_.sustain;
        } else if (t < duration) {
            const double p = (patch_.release > 0.0)
                                 ? (t - releaseStart) / patch_.release
                                 : 1.0;
            env = patch_.sustain * (1.0 - p);
        }
    }

    // Volume LFO shaping of envelope.
    if (patch_.lfoTarget == 2 && patch_.lfoRate > 0.0) {
        const double lfo = std::sin(2.0 * kPi * t * patch_.lfoRate);
        env *= 1.0 - patch_.lfoDepth * 0.5 * (1.0 - lfo);
    }

    // --- Waveform (uses current phase) ---------------------------------
    double wave = 0.0;
    switch (patch_.waveform) {
    case Waveform::Sine:
        wave = std::sin(2.0 * kPi * phase_);
        break;
    case Waveform::Square: {
        const double edge = 0.02;
        if (phase_ < edge)
            wave = phase_ / edge;
        else if (phase_ < 0.5 - edge)
            wave = 1.0;
        else if (phase_ < 0.5 + edge)
            wave = 1.0 - 2.0 * (phase_ - (0.5 - edge)) / (2.0 * edge);
        else if (phase_ < 1.0 - edge)
            wave = -1.0;
        else
            wave = -1.0 + (phase_ - (1.0 - edge)) / edge;
        break;
    }
    case Waveform::Triangle:
        wave = 4.0 * std::abs(phase_ - 0.5) - 1.0;
        break;
    case Waveform::Sawtooth:
        wave = 2.0 * phase_ - 1.0;
        break;
    case Waveform::Noise:
        noiseSeed_ ^= noiseSeed_ << 13;
        noiseSeed_ ^= noiseSeed_ >> 17;
        noiseSeed_ ^= noiseSeed_ << 5;
        wave = static_cast<double>(noiseSeed_) /
                   static_cast<double>(0xFFFFFFFFu) *
                   2.0 -
               1.0;
        break;
    }

    // --- Advance phase (with pitch env + LFO pitch mod) ---------------
    double effFreq = freqHz_;
    if (patch_.pitchTime > 0.0) {
        const double p = std::min(t / patch_.pitchTime, 1.0);
        const double semis =
            patch_.pitchStart + (patch_.pitchEnd - patch_.pitchStart) * p;
        effFreq *= std::pow(2.0, semis / 12.0);
    }
    if (patch_.lfoRate > 0.0 && patch_.lfoDepth > 0.0 && patch_.lfoTarget == 1) {
        const double lfo = std::sin(2.0 * kPi * t * patch_.lfoRate);
        effFreq *= std::pow(2.0, lfo * patch_.lfoDepth / 12.0);
    }

    phase_ += effFreq / static_cast<double>(sampleRate_);
    if (phase_ >= 1.0) phase_ -= 1.0;

    return wave * env * gain_;
}

void OscillatorVoice::render(float* buffer, int frames, int64_t bufferStartFrame)
{
    const int64_t bufEnd = bufferStartFrame + frames;
    const int64_t lo     = std::max(startFrame_, bufferStartFrame);
    const int64_t hi     = std::min(endFrame_, bufEnd);
    for (int64_t f = lo; f < hi; ++f) {
        const int idx = static_cast<int>(f - bufferStartFrame);
        buffer[idx] += static_cast<float>(renderSample(f));
    }
}

} // namespace clay::sound
