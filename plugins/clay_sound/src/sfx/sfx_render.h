// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The one way an effect recipe becomes sound, live and offline alike:
//
//   1. realizeSfx(recipe, seed, detune) draws the variation: every
//      parameter with a "vary" range gets base + a value in [min, max),
//      from a hash of (seed, layer, parameter) alone. The same seed gives
//      the same values on every platform; another parameter's range never
//      moves them. `detune` (semitones) raises every layer's base detune
//      before that, so a play transposed by 12 is the recipe with every
//      layer's detune raised by 12.
//   2. SfxVoices holds the instruments a recipe plays on in one engine
//      (one oscillator instrument, one sampler per sample layer) and
//      schedules the realized layers there, each at its offset.
//   3. renderSfx() does 1 and 2 on a scratch engine and renders it.
//
// SfxPlayer::play() runs 1 and 2 on the shared engine at its current
// frame, renderOffline() runs 3: voice for voice the same notes, and
// noise layers carry a seed of their own (OscillatorVoice::Patch::
// noiseSeed), so both render the same samples. What the bus does with
// them afterwards (volume, echo, reverb) is the bus's, not the
// recipe's, and is not part of an offline render.

#ifndef CLAY_SOUND_SFX_RENDER_H
#define CLAY_SOUND_SFX_RENDER_H

#include "engine/bus.h"
#include "sfx_recipe.h"

#include <QVector>

#include <array>
#include <cstdint>
#include <memory>
#include <vector>

namespace clay::sound {

class Engine;
class OscillatorInstrument;
class SamplerInstrument;
struct PcmBuffer;

// One layer of one variation: the values it plays with.
struct SfxNote
{
    int layer = 0;
    std::array<double, kSfxParamCount> value{};
    uint32_t noiseSeed = 1;     // never 0: 0 would fall back to the start frame

    double get(SfxParam p) const { return value[static_cast<int>(p)]; }
};

// The seed play() uses for its `index`-th variation: index modulo the
// pool when the recipe has one. In 0..2^31-1, so QML holds it as an int.
uint32_t sfxVariationSeed(const SfxRecipe &recipe, int index);

std::vector<SfxNote> realizeSfx(const SfxRecipe &recipe, uint32_t seed, double detune = 0.0);

// The decoded WAV of each sample layer, indexed like recipe.layers;
// null for the other layers.
using SfxSamples = QVector<std::shared_ptr<const PcmBuffer>>;

class SfxVoices
{
public:
    // Register the instruments `recipe` plays on with `engine`. The
    // engine owns them; detach() drops them and any voice still ringing.
    void attach(Engine &engine, const SfxRecipe &recipe, const SfxSamples &samples);
    void detach(Engine &engine);
    bool attached() const { return oscId_ >= 0; }

    // Instrument gain (0..1), pan (-1..1) and bus of every layer.
    void setGain(float g);
    void setPan(float p);
    void setBus(Bus b);

    // Schedule `notes` to start at engine frame `at` (each layer at its
    // offset), every layer's gain scaled by `velocity`. Returns the
    // number of frames from `at` until the last layer has ended.
    int64_t play(Engine &engine, const std::vector<SfxNote> &notes, int64_t at,
                 float velocity, int gainStage = -1) const;

private:
    struct Sampler { int id = -1; SamplerInstrument *inst = nullptr; };

    int oscId_ = -1;
    OscillatorInstrument *osc_ = nullptr;
    QVector<Sampler> samplers_;     // per layer; id -1 for oscillator layers
    SfxSamples samples_;
    SfxRecipe recipe_;
};

// What SfxVoices::play() of `seed` at `velocity`, transposed by `detune`
// semitones, sends into its bus, rendered on a scratch engine from frame
// 0 until the last layer ends, or for `frames` frames when that is >= 0:
// interleaved stereo, or the (L + R) / 2 downmix when !stereo.
std::vector<float> renderSfx(const SfxRecipe &recipe, const SfxSamples &samples,
                             uint32_t seed, float velocity, float gain, float pan,
                             int sampleRate, bool stereo, int64_t frames = -1,
                             double detune = 0.0);

// renderSfx() clamped to [-1, 1] like the live sink, `seconds` long
// (<= 0: until the last layer ends). SfxPlayer::renderOffline() and a
// program without QML render a recipe through this.
std::vector<float> renderRecipe(const SfxRecipe &recipe, const SfxSamples &samples,
                                uint32_t seed, float velocity, float gain, float pan,
                                int sampleRate, bool stereo, double seconds = 0.0,
                                double detune = 0.0);

} // namespace clay::sound

#endif // CLAY_SOUND_SFX_RENDER_H
