// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SfxRecipe — pure data of an effect recipe (*.sfx.json): a stack of
// layers, each one voice with a source, an envelope, a pitch curve, a
// filter curve, a start offset, a gain and a pan, all in physical units
// (Hz, ms, semitones, dB), an oscillator layer FM or ring modulation, plus a variation spec: a random range per
// layer parameter, a seed and a round-robin pool size. A layer with a
// burst plays as many short seeded notes, its grains, and the recipe's
// voice cap bounds how many of them ring at once.
//
// Built by SfxParser, turned into notes by sfx_render.h.

#ifndef CLAY_SOUND_SFX_RECIPE_H
#define CLAY_SOUND_SFX_RECIPE_H

#include "engine/oscillator_voice.h"
#include "engine/sample_voice.h"

#include <QString>
#include <QVector>

#include <array>
#include <cstdint>

namespace clay::sound {

// Every number a layer has. Each parameter draws its variation from a
// hash of the seed and its index here, so a new one goes at the end:
// put anywhere else it would move the values of those after it.
enum class SfxParam : int {
    Freq, Detune, Gain, Pan, Offset, Length,
    Attack, Decay, Sustain, Release,
    PitchStart, PitchEnd, PitchTime,
    Cutoff, Resonance, FilterAttack, FilterDecay, FilterSustain, FilterRelease, FilterAmount,
    PulseWidth, LfoRate, LfoDepth,
    AttackCurve, DecayCurve, ReleaseCurve, PitchCurve,
    FilterAttackCurve, FilterDecayCurve, FilterReleaseCurve,
    BurstCount, BurstDuration, BurstDensity,
    JitterTime, JitterGain, JitterCutoff, JitterFreq, JitterLength,
    FmRatio, FmIndex, FmAttack, FmDecay, FmSustain, FmRelease,
    FmAttackCurve, FmDecayCurve, FmReleaseCurve,
    RingRatio,
    Count
};

inline constexpr int kSfxParamCount = static_cast<int>(SfxParam::Count);

struct SfxParamInfo
{
    const char *path;   // as written in the file and in "vary"
    double min;
    double max;
    double def;
};

// Indexed by SfxParam.
inline constexpr std::array<SfxParamInfo, kSfxParamCount> kSfxParams = {{
    {"freq",            1.0,      20000.0, 440.0},   // Hz
    {"detune",        -48.0,         48.0,   0.0},   // semitones
    {"gain",          -96.0,         12.0,   0.0},   // dB
    {"pan",            -1.0,          1.0,   0.0},   // -1 left .. +1 right
    {"offset",          0.0,      10000.0,   0.0},   // ms after play()
    {"length",          0.0,      10000.0,   0.0},   // ms gate; release inside it
    {"envelope.attack", 0.0,      10000.0,   0.0},   // ms
    {"envelope.decay",  0.0,      10000.0,   0.0},   // ms
    {"envelope.sustain",0.0,          1.0,   1.0},   // level
    {"envelope.release",0.0,      10000.0,   0.0},   // ms
    {"pitch.start",   -96.0,         96.0,   0.0},   // semitones
    {"pitch.end",     -96.0,         96.0,   0.0},   // semitones
    {"pitch.time",      0.0,      10000.0,   0.0},   // ms
    {"filter.cutoff",  20.0,      20000.0, 1000.0},  // Hz
    {"filter.resonance",0.0,          1.0,   0.0},
    {"filter.attack",   0.0,      10000.0,   0.0},   // ms
    {"filter.decay",    0.0,      10000.0,   0.0},   // ms
    {"filter.sustain",  0.0,          1.0,   1.0},   // level
    {"filter.release",  0.0,      10000.0,   0.0},   // ms
    {"filter.amount", -10.0,         10.0,   0.0},   // octaves at the envelope's peak
    {"pulseWidth",      0.05,         0.95,  0.5},
    {"lfo.rate",        0.0,        100.0,   0.0},   // Hz
    {"lfo.depth",       0.0,         48.0,   0.0},   // semitones (pitch), 0..1 (volume) or octaves (cutoff)
    // Segment curves: 0 linear .. 1 exponential (engine/segment_curve.h).
    {"envelope.attackCurve",  0.0,   1.0,   0.0},
    {"envelope.decayCurve",   0.0,   1.0,   0.0},
    {"envelope.releaseCurve", 0.0,   1.0,   0.0},
    {"pitch.curve",           0.0,   1.0,   0.0},
    {"filter.attackCurve",    0.0,   1.0,   0.0},
    {"filter.decayCurve",     0.0,   1.0,   0.0},
    {"filter.releaseCurve",   0.0,   1.0,   0.0},
    // A burst: the layer plays `count` grains (rounded) inside `duration`,
    // the grain rate at the end `density` times the one at the start.
    {"burst.count",           1.0,   256.0,   1.0},
    {"burst.duration",        0.0, 10000.0,   0.0},   // ms
    {"burst.density",         0.01,  100.0,   1.0},   // end rate / start rate
    // How far each grain strays, either way, from the layer's value.
    {"burst.jitter.time",     0.0,     1.0,   0.0},   // of its slot; 1 = anywhere in it
    {"burst.jitter.gain",     0.0,    48.0,   0.0},   // dB
    {"burst.jitter.cutoff",   0.0,     8.0,   0.0},   // octaves
    {"burst.jitter.freq",     0.0,    48.0,   0.0},   // semitones
    {"burst.jitter.length",   0.0, 10000.0,   0.0},   // ms
    // Two-operator FM: the modulator at `ratio` times the layer's pitch,
    // `index` the phase deviation in radians at the peak of its envelope.
    {"fm.ratio",              0.01,   64.0,   1.0},
    {"fm.index",              0.0,    32.0,   0.0},   // radians
    {"fm.attack",             0.0, 10000.0,   0.0},   // ms
    {"fm.decay",              0.0, 10000.0,   0.0},   // ms
    {"fm.sustain",            0.0,     1.0,   1.0},   // of the index
    {"fm.release",            0.0, 10000.0,   0.0},   // ms
    {"fm.attackCurve",        0.0,     1.0,   0.0},
    {"fm.decayCurve",         0.0,     1.0,   0.0},
    {"fm.releaseCurve",       0.0,     1.0,   0.0},
    // Ring modulation: the layer times a sine at `ratio` times its pitch.
    {"ring.ratio",            0.01,   64.0,   1.0},
}};

inline const SfxParamInfo &sfxParamInfo(SfxParam p) { return kSfxParams[static_cast<int>(p)]; }

enum class SfxSource { Sine, Square, Triangle, Sawtooth, Noise, Sample };

struct SfxRange
{
    bool   on = false;
    double lo = 0.0;    // added to the parameter's value
    double hi = 0.0;
};

struct SfxLayer
{
    QString   name;                 // free label
    QString   role;                 // "", transient, body or tail
    SfxSource source = SfxSource::Sine;

    // Sample layers: the WAV, relative to the recipe file.
    QString   sample;
    SampleVoice::Interpolation interpolation = SampleVoice::Interpolation::Linear;

    OscillatorVoice::FilterType filterType = OscillatorVoice::FilterType::Off;
    int lfoTarget = 0;              // as OscillatorVoice::Patch: 0 off, 1 pitch, 2 volume, 3 cutoff
    OscillatorVoice::LfoShape lfoShape = OscillatorVoice::LfoShape::Sine;
    // Noise layers: the colour, and whether `freq` clocks the noise.
    OscillatorVoice::NoiseColor noiseColor = OscillatorVoice::NoiseColor::White;
    OscillatorVoice::NoiseRate  noiseRate  = OscillatorVoice::NoiseRate::Sample;
    bool burst = false;             // plays as grains (the burst.* numbers), not as one note
    bool fm = false;                // runs FM (the fm.* numbers)
    bool ring = false;              // runs ring modulation (ring.ratio)

    std::array<double, kSfxParamCount>   value{};
    std::array<SfxRange, kSfxParamCount> vary{};

    double  get(SfxParam p) const { return value[static_cast<int>(p)]; }
    double &at(SfxParam p)        { return value[static_cast<int>(p)]; }
};

struct SfxRecipe
{
    QString  name;
    uint32_t seed = 0;              // base of every variation seed
    int      pool = 0;              // play() cycles this many variations; 0 = a new one each time
    int      maxVoices = 0;         // burst grains that ring at once; 0 = no cap
    QVector<SfxLayer> layers;
};

} // namespace clay::sound

#endif // CLAY_SOUND_SFX_RECIPE_H
