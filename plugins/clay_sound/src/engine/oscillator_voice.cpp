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

// ADSR level at `t` seconds into a note gated for `duration` seconds.
// The release runs inside the gate: it starts `release` seconds before
// the note ends, from the sustain level.
static double adsr(double t, double duration,
                   double attack, double decay, double sustain, double release)
{
    if (t < 0.0) return 0.0;
    const double releaseStart = duration - release;
    if (t < attack)
        return (attack > 0.0) ? (t / attack) : 1.0;
    if (t < attack + decay) {
        const double p = (decay > 0.0) ? (t - attack) / decay : 1.0;
        return 1.0 - (1.0 - sustain) * p;
    }
    if (t < releaseStart)
        return sustain;
    if (t < duration) {
        const double p = (release > 0.0) ? (t - releaseStart) / release : 1.0;
        return sustain * (1.0 - p);
    }
    return 0.0;
}

void OscillatorVoice::onNoteOn(const NoteEvent& ev, int sampleRate)
{
    sampleRate_ = sampleRate;
    startFrame_ = ev.timeFrames;
    endFrame_   = ev.timeFrames + ev.durationFrames;
    freqHz_     = ev.freqHz;
    gain_       = ev.velocity;
    phase_      = 0.0;
    filterIc1_  = 0.0;
    filterIc2_  = 0.0;
    // Deterministic-per-voice noise seed. Derived from start frame so
    // two noise notes at different times produce different sequences,
    // unless the patch names a seed of its own.
    noiseSeed_ = patch_.noiseSeed != 0
        ? patch_.noiseSeed
        : 12345u + static_cast<uint32_t>(ev.timeFrames & 0xffffffff);
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
    double env = adsr(t, duration, patch_.attack, patch_.decay,
                      patch_.sustain, patch_.release);

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
        const double pw   = std::clamp(patch_.pulseWidth, 0.05, 0.95);
        if (phase_ < edge)
            wave = phase_ / edge;
        else if (phase_ < pw - edge)
            wave = 1.0;
        else if (phase_ < pw + edge)
            wave = 1.0 - 2.0 * (phase_ - (pw - edge)) / (2.0 * edge);
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

    if (patch_.filterType != FilterType::Off)
        wave = filter(wave, t, duration);

    return wave * env * gain_;
}

double OscillatorVoice::filter(double in, double t, double duration)
{
    // Cutoff after its envelope, kept below Nyquist where tan() blows up.
    double fc = patch_.cutoff;
    if (patch_.filterEnvAmount != 0.0) {
        const double fenv = adsr(t, duration, patch_.filterAttack,
                                 patch_.filterDecay, patch_.filterSustain,
                                 patch_.filterRelease);
        fc *= std::pow(2.0, patch_.filterEnvAmount * fenv);
    }
    fc = std::clamp(fc, 20.0, 0.49 * sampleRate_);

    // Resonance maps exponentially onto the damping k = 1/Q, so equal
    // steps sound like equal steps: k = sqrt(2) (flat) down to 0.1.
    const double res = std::clamp(patch_.resonance, 0.0, 1.0);
    const double k   = std::sqrt(2.0) * std::pow(0.1 / std::sqrt(2.0), res);

    // Trapezoidal state-variable filter (Simper): stable while the
    // cutoff moves every sample, and one pass gives all three outputs.
    const double g  = std::tan(kPi * fc / sampleRate_);
    const double a1 = 1.0 / (1.0 + g * (g + k));
    const double a2 = g * a1;
    const double a3 = g * a2;
    const double v3 = in - filterIc2_;
    const double v1 = a1 * filterIc1_ + a2 * v3;
    const double v2 = filterIc2_ + a2 * filterIc1_ + a3 * v3;
    filterIc1_ = 2.0 * v1 - filterIc1_;
    filterIc2_ = 2.0 * v2 - filterIc2_;

    switch (patch_.filterType) {
    case FilterType::LowPass:  return v2;
    case FilterType::HighPass: return in - k * v1 - v2;
    case FilterType::BandPass: return k * v1;   // unity gain at the cutoff
    case FilterType::Off:      break;
    }
    return in;
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
