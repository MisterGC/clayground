// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "oscillator_voice.h"
#include "note_event.h"
#include "segment_curve.h"
#include <algorithm>
#include <cmath>
#include <iterator>

namespace clay::sound {

// M_PI is not part of the C++ standard; MSVC omits it unless
// _USE_MATH_DEFINES is set before <cmath>. Define our own so this
// file stays portable across compilers.
static constexpr double kPi = 3.14159265358979323846;

// ADSR level at `t` seconds into a note gated for `duration` seconds.
// The release runs inside the gate: it starts `release` seconds before
// the note ends, from the sustain level. Each segment follows its curve
// (segment_curve.h).
static double adsr(double t, double duration,
                   double attack, double decay, double sustain, double release,
                   double attackCurve, double decayCurve, double releaseCurve)
{
    if (t < 0.0) return 0.0;
    const double releaseStart = duration - release;
    if (t < attack)
        return (attack > 0.0) ? segmentShape(t / attack, attackCurve) : 1.0;
    if (t < attack + decay) {
        const double p = (decay > 0.0) ? (t - attack) / decay : 1.0;
        return 1.0 - (1.0 - sustain) * segmentShape(p, decayCurve);
    }
    if (t < releaseStart)
        return sustain;
    if (t < duration) {
        const double p = (release > 0.0) ? (t - releaseStart) / release : 1.0;
        return sustain * (1.0 - segmentShape(p, releaseCurve));
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
    fmPhase_    = 0.0;
    ringPhase_  = 0.0;
    filterIc1_  = 0.0;
    filterIc2_  = 0.0;
    // Deterministic-per-voice noise seed. Derived from start frame so
    // two noise notes at different times produce different sequences,
    // unless the patch names a seed of its own.
    noiseSeed_ = patch_.noiseSeed != 0
        ? patch_.noiseSeed
        : 12345u + static_cast<uint32_t>(ev.timeFrames & 0xffffffff);
    noiseDraw_ = true;
    // Apart from the noise seed, so a noise voice's LFO does not follow
    // its hiss; never 0, which xorshift would never leave.
    lfoSeed_ = patch_.lfoSeed != 0
        ? patch_.lfoSeed
        : (0x2545f491u ^ static_cast<uint32_t>(ev.timeFrames & 0xffffffff)) | 1u;
    lfoPeriod_ = 0;
    if (patch_.lfoShape == LfoShape::SampleHold || patch_.lfoShape == LfoShape::SmoothRandom) {
        lfoFrom_ = nextLfoRandom();
        lfoTo_   = nextLfoRandom();
    }
    std::fill(std::begin(pink_), std::end(pink_), 0.0);
    brown_ = 0.0;
    // The colour filters' slowest pole needs about 900 draws to settle;
    // run them past that, so a grain of a few ms starts as loud as a
    // long note does.
    if (patch_.waveform == Waveform::Noise && patch_.noiseColor != NoiseColor::White)
        for (int i = 0; i < 4096; ++i) nextNoise();
}

double OscillatorVoice::nextLfoRandom()
{
    lfoSeed_ ^= lfoSeed_ << 13;
    lfoSeed_ ^= lfoSeed_ >> 17;
    lfoSeed_ ^= lfoSeed_ << 5;
    return static_cast<double>(lfoSeed_) / static_cast<double>(0xFFFFFFFFu) * 2.0 - 1.0;
}

// The LFO's value at `t` seconds into the note, -1..1. Called once per
// rendered sample, in order: a random shape draws its values as `t`
// enters each period.
double OscillatorVoice::lfoAt(double t)
{
    const double cycles = t * patch_.lfoRate;
    switch (patch_.lfoShape) {
    case LfoShape::Sine:
        return std::sin(2.0 * kPi * t * patch_.lfoRate);
    case LfoShape::Square:
        return cycles - std::floor(cycles) < 0.5 ? 1.0 : -1.0;
    case LfoShape::SampleHold:
    case LfoShape::SmoothRandom: {
        const int64_t period = static_cast<int64_t>(std::floor(cycles));
        while (lfoPeriod_ < period) {
            lfoFrom_ = lfoTo_;
            lfoTo_   = nextLfoRandom();
            ++lfoPeriod_;
        }
        if (patch_.lfoShape == LfoShape::SampleHold) return lfoFrom_;
        const double step = 0.5 - 0.5 * std::cos(kPi * (cycles - std::floor(cycles)));
        return lfoFrom_ + (lfoTo_ - lfoFrom_) * step;
    }
    }
    return 0.0;
}

double OscillatorVoice::nextWhite()
{
    noiseSeed_ ^= noiseSeed_ << 13;
    noiseSeed_ ^= noiseSeed_ >> 17;
    noiseSeed_ ^= noiseSeed_ << 5;
    return static_cast<double>(noiseSeed_) /
               static_cast<double>(0xFFFFFFFFu) *
               2.0 -
           1.0;
}

double OscillatorVoice::nextNoise()
{
    const double w = nextWhite();
    switch (patch_.noiseColor) {
    case NoiseColor::White:
        return w;
    case NoiseColor::Pink: {
        // Paul Kellet's refined pink filter: -3 dB per octave within
        // 0.05 dB above 1/4800 of the draw rate (9.2 Hz at 44.1 kHz).
        // 0.1638 brings its RMS to half of white's.
        double *b = pink_;
        b[0] = 0.99886 * b[0] + w * 0.0555179;
        b[1] = 0.99332 * b[1] + w * 0.0750759;
        b[2] = 0.96900 * b[2] + w * 0.1538520;
        b[3] = 0.86650 * b[3] + w * 0.3104856;
        b[4] = 0.55000 * b[4] + w * 0.5329522;
        b[5] = -0.7616 * b[5] - w * 0.0168980;
        const double pink = b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] + w * 0.5362;
        b[6] = w * 0.115926;
        return std::clamp(pink * 0.1638, -1.0, 1.0);
    }
    case NoiseColor::Brown:
        // A leaky integrator: -6 dB per octave above 1/1250 of the draw
        // rate (35 Hz at 44.1 kHz). Gain 0.05 brings its RMS to half of white's.
        brown_ = 0.995 * brown_ + 0.05 * w;
        return std::clamp(brown_, -1.0, 1.0);
    }
    return w;
}

void OscillatorVoice::onNoteOff(int64_t atFrame)
{
    // Clamp note end forward; lets external code cut a ringing voice.
    if (atFrame < endFrame_)
        endFrame_ = atFrame;
}

void OscillatorVoice::onRelease(int64_t atFrame)
{
    // The release runs inside the gate, so the gate ends one release
    // after `atFrame`.
    onNoteOff(atFrame + static_cast<int64_t>(std::llround(patch_.release * sampleRate_)));
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
                      patch_.sustain, patch_.release,
                      patch_.attackCurve, patch_.decayCurve, patch_.releaseCurve);

    // One LFO value per sample, whichever target reads it.
    const double lfo = patch_.lfoTarget != 0 && patch_.lfoRate > 0.0 ? lfoAt(t) : 0.0;

    // Volume LFO shaping of envelope.
    if (patch_.lfoTarget == 2 && patch_.lfoRate > 0.0)
        env *= 1.0 - patch_.lfoDepth * 0.5 * (1.0 - lfo);

    // --- Waveform (uses current phase) ---------------------------------
    // FM moves the phase the wave is read at, not the phase itself, so
    // the pitch stays the carrier's.
    double ph = phase_;
    if (patch_.fmRatio > 0.0) {
        const double index = patch_.fmIndex *
            adsr(t, duration, patch_.fmAttack, patch_.fmDecay, patch_.fmSustain,
                 patch_.fmRelease, patch_.fmAttackCurve, patch_.fmDecayCurve,
                 patch_.fmReleaseCurve);
        ph += index * std::sin(2.0 * kPi * fmPhase_) / (2.0 * kPi);
        ph -= std::floor(ph);
    }
    double wave = 0.0;
    switch (patch_.waveform) {
    case Waveform::Sine:
        wave = std::sin(2.0 * kPi * ph);
        break;
    case Waveform::Square: {
        const double edge = 0.02;
        const double pw   = std::clamp(patch_.pulseWidth, 0.05, 0.95);
        if (ph < edge)
            wave = ph / edge;
        else if (ph < pw - edge)
            wave = 1.0;
        else if (ph < pw + edge)
            wave = 1.0 - 2.0 * (ph - (pw - edge)) / (2.0 * edge);
        else if (ph < 1.0 - edge)
            wave = -1.0;
        else
            wave = -1.0 + (ph - (1.0 - edge)) / edge;
        break;
    }
    case Waveform::Triangle:
        wave = 4.0 * std::abs(ph - 0.5) - 1.0;
        break;
    case Waveform::Sawtooth:
        wave = 2.0 * ph - 1.0;
        break;
    case Waveform::Noise:
        // A clocked noise holds its value until the phase wraps.
        if (patch_.noiseRate == NoiseRate::Sample || noiseDraw_) {
            noiseHeld_ = nextNoise();
            noiseDraw_ = false;
        }
        wave = noiseHeld_;
        break;
    }

    // --- Advance phase (with pitch env + LFO pitch mod) ---------------
    double effFreq = freqHz_;
    if (patch_.pitchTime > 0.0) {
        // Past the sweep the pitch is its end, not where an exponential
        // curve stops short of it.
        const double p = t < patch_.pitchTime
            ? segmentShape(t / patch_.pitchTime, patch_.pitchCurve) : 1.0;
        const double semis =
            patch_.pitchStart + (patch_.pitchEnd - patch_.pitchStart) * p;
        effFreq *= std::pow(2.0, semis / 12.0);
    }
    if (patch_.lfoRate > 0.0 && patch_.lfoDepth > 0.0 && patch_.lfoTarget == 1)
        effFreq *= std::pow(2.0, lfo * patch_.lfoDepth / 12.0);

    if (patch_.ringRatio > 0.0) {
        wave *= std::sin(2.0 * kPi * ringPhase_);
        ringPhase_ += patch_.ringRatio * effFreq / static_cast<double>(sampleRate_);
        ringPhase_ -= std::floor(ringPhase_);
    }
    if (patch_.fmRatio > 0.0) {
        fmPhase_ += patch_.fmRatio * effFreq / static_cast<double>(sampleRate_);
        fmPhase_ -= std::floor(fmPhase_);
    }

    phase_ += effFreq / static_cast<double>(sampleRate_);
    if (phase_ >= 1.0) {
        // Above the sample rate a clocked noise draws every sample.
        if (patch_.waveform == Waveform::Noise) {
            phase_ -= std::floor(phase_);
            noiseDraw_ = true;
        } else {
            phase_ -= 1.0;
        }
    }

    if (patch_.filterType != FilterType::Off)
        wave = filter(wave, t, duration,
                      patch_.lfoTarget == 3 && patch_.lfoRate > 0.0 ? lfo * patch_.lfoDepth : 0.0);

    return wave * env * gain_;
}

double OscillatorVoice::filter(double in, double t, double duration, double lfoOctaves)
{
    // Cutoff after its envelope and a cutoff LFO's `lfoOctaves`, kept
    // below Nyquist where tan() blows up.
    double fc = patch_.cutoff;
    if (patch_.filterEnvAmount != 0.0) {
        const double fenv = adsr(t, duration, patch_.filterAttack,
                                 patch_.filterDecay, patch_.filterSustain,
                                 patch_.filterRelease, patch_.filterAttackCurve,
                                 patch_.filterDecayCurve, patch_.filterReleaseCurve);
        fc *= std::pow(2.0, patch_.filterEnvAmount * fenv);
    }
    if (lfoOctaves != 0.0) fc *= std::pow(2.0, lfoOctaves);
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
