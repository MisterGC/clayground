// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sfx_render.h"

#include "engine/engine.h"
#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "engine/pcm_buffer.h"
#include "engine/sampler_instrument.h"

#include <algorithm>
#include <cmath>

namespace clay::sound {

namespace {

using P = SfxParam;

// lowbias32 (Chris Wellons): integer-only, so a seed draws the same
// values on every platform.
uint32_t hash32(uint32_t x)
{
    x ^= x >> 16; x *= 0x7feb352du;
    x ^= x >> 15; x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

uint32_t mix(uint32_t a, uint32_t b) { return hash32(a ^ hash32(b + 0x9e3779b9u)); }

// Salt of a layer's noise seed, apart from every parameter index.
constexpr uint32_t kNoiseSalt = 0x6e6f6973u;

int64_t msToFrames(double ms, int sampleRate)
{
    return static_cast<int64_t>(std::llround(ms * sampleRate / 1000.0));
}

OscillatorVoice::Waveform waveformOf(SfxSource s)
{
    using W = OscillatorVoice::Waveform;
    switch (s) {
    case SfxSource::Square:   return W::Square;
    case SfxSource::Triangle: return W::Triangle;
    case SfxSource::Sawtooth: return W::Sawtooth;
    case SfxSource::Noise:    return W::Noise;
    default:                  return W::Sine;
    }
}

} // namespace

uint32_t sfxVariationSeed(const SfxRecipe &recipe, int index)
{
    const int i = recipe.pool > 0 ? index % recipe.pool : index;
    return mix(recipe.seed, static_cast<uint32_t>(i)) & 0x7fffffffu;
}

std::vector<SfxNote> realizeSfx(const SfxRecipe &recipe, uint32_t seed, double detune)
{
    std::vector<SfxNote> notes;
    notes.reserve(static_cast<size_t>(recipe.layers.size()));
    for (int li = 0; li < recipe.layers.size(); ++li) {
        const SfxLayer &layer = recipe.layers[li];
        const uint32_t layerSeed = mix(seed, static_cast<uint32_t>(li + 1));
        SfxNote n;
        n.layer = li;
        n.value = layer.value;
        // Before the vary range, so the sum is the one a recipe with this
        // detune written into the layer gives, to the last bit.
        n.value[static_cast<int>(P::Detune)] += detune;
        for (int p = 0; p < kSfxParamCount; ++p) {
            const SfxRange &r = layer.vary[p];
            if (!r.on) continue;
            // 24 bits of the hash: u in [0, 1), exact in a double.
            const double u = (mix(layerSeed, static_cast<uint32_t>(p + 1)) >> 8) / 16777216.0;
            n.value[p] += r.lo + (r.hi - r.lo) * u;
        }
        n.noiseSeed = mix(layerSeed, kNoiseSalt) | 1u;
        notes.push_back(n);
    }
    return notes;
}

void SfxVoices::attach(Engine &engine, const SfxRecipe &recipe, const SfxSamples &samples)
{
    detach(engine);
    recipe_ = recipe;
    samples_ = samples;
    samples_.resize(recipe.layers.size());

    auto osc = std::make_unique<OscillatorInstrument>();
    osc_ = osc.get();
    oscId_ = engine.addInstrument(std::move(osc));

    samplers_.fill({}, recipe.layers.size());
    for (int li = 0; li < recipe.layers.size(); ++li) {
        if (recipe.layers[li].source != SfxSource::Sample || !samples_[li]) continue;
        auto sampler = std::make_unique<SamplerInstrument>();
        sampler->setSource(samples_[li]);
        sampler->setRootMidiNote(69);   // detune 0 plays at 440 Hz: the sample as recorded
        samplers_[li].inst = sampler.get();
        samplers_[li].id = engine.addInstrument(std::move(sampler));
    }
}

void SfxVoices::detach(Engine &engine)
{
    if (oscId_ >= 0) engine.removeInstrument(oscId_);
    for (const Sampler &s : std::as_const(samplers_))
        if (s.id >= 0) engine.removeInstrument(s.id);
    oscId_ = -1;
    osc_ = nullptr;
    samplers_.clear();
}

void SfxVoices::setGain(float g)
{
    if (osc_) osc_->setGain(g);
    for (const Sampler &s : std::as_const(samplers_)) if (s.inst) s.inst->setGain(g);
}

void SfxVoices::setPan(float p)
{
    if (osc_) osc_->setPan(p);
    for (const Sampler &s : std::as_const(samplers_)) if (s.inst) s.inst->setPan(p);
}

void SfxVoices::setBus(Bus b)
{
    if (osc_) osc_->setBus(b);
    for (const Sampler &s : std::as_const(samplers_)) if (s.inst) s.inst->setBus(b);
}

int64_t SfxVoices::play(Engine &engine, const std::vector<SfxNote> &notes, int64_t at,
                        float velocity, int gainStage) const
{
    if (!osc_) return 0;
    const int rate = engine.sampleRate();
    int64_t end = 0;
    for (const SfxNote &n : notes) {
        if (n.layer < 0 || n.layer >= recipe_.layers.size()) continue;
        const SfxLayer &layer = recipe_.layers[n.layer];

        NoteEvent ev;
        const int64_t offset = msToFrames(n.get(P::Offset), rate);
        ev.timeFrames = at + offset;
        ev.velocity   = static_cast<float>(std::pow(10.0, n.get(P::Gain) / 20.0) * velocity);
        ev.pan        = static_cast<float>(n.get(P::Pan));
        ev.gainStage  = gainStage;
        const double detune = std::pow(2.0, n.get(P::Detune) / 12.0);

        if (layer.source == SfxSource::Sample) {
            const Sampler &s = samplers_.value(n.layer);
            const auto &pcm = samples_.value(n.layer);
            if (!s.inst || !pcm || pcm->frames() < 2 || pcm->sampleRate <= 0) continue;
            ev.instrumentId = s.id;
            ev.freqHz = 440.0 * detune;
            // Without a length the layer plays to the sample's end: the
            // voice stops itself once its read position passes the last
            // frame, which takes this many engine frames.
            const double step = static_cast<double>(pcm->sampleRate) / rate * detune;
            const int64_t whole = static_cast<int64_t>(
                std::ceil(static_cast<double>(pcm->frames() - 1) / step));
            const int64_t gate = msToFrames(n.get(P::Length), rate);
            ev.durationFrames = gate > 0 ? std::min(gate, whole) : whole;

            SampleVoice::Patch patch;
            patch.interpolation = layer.interpolation;
            patch.attack  = n.get(P::Attack) / 1000.0;
            patch.release = n.get(P::Release) / 1000.0;
            s.inst->pushPatch(engine.schedule(ev), patch);
        } else {
            ev.instrumentId   = oscId_;
            ev.freqHz         = n.get(P::Freq) * detune;
            ev.durationFrames = std::max<int64_t>(1, msToFrames(n.get(P::Length), rate));

            OscillatorVoice::Patch patch;
            patch.waveform   = waveformOf(layer.source);
            patch.pulseWidth = n.get(P::PulseWidth);
            patch.attack     = n.get(P::Attack) / 1000.0;
            patch.decay      = n.get(P::Decay) / 1000.0;
            patch.sustain    = n.get(P::Sustain);
            patch.release    = n.get(P::Release) / 1000.0;
            patch.pitchStart = n.get(P::PitchStart);
            patch.pitchEnd   = n.get(P::PitchEnd);
            patch.pitchTime  = n.get(P::PitchTime) / 1000.0;
            patch.lfoTarget  = layer.lfoTarget;
            patch.lfoRate    = n.get(P::LfoRate);
            patch.lfoDepth   = n.get(P::LfoDepth);
            patch.filterType = layer.filterType;
            patch.cutoff     = n.get(P::Cutoff);
            patch.resonance  = n.get(P::Resonance);
            patch.filterAttack    = n.get(P::FilterAttack) / 1000.0;
            patch.filterDecay     = n.get(P::FilterDecay) / 1000.0;
            patch.filterSustain   = n.get(P::FilterSustain);
            patch.filterRelease   = n.get(P::FilterRelease) / 1000.0;
            patch.filterEnvAmount = n.get(P::FilterAmount);
            patch.noiseSeed  = n.noiseSeed;
            osc_->pushPatch(engine.schedule(ev), patch);
        }
        end = std::max(end, offset + ev.durationFrames);
    }
    return end;
}

void SfxVoices::stop(Engine &engine) const
{
    if (osc_) {
        engine.releaseInstrument(oscId_);
        // The cancelled layers' patches would wait for events that never come.
        osc_->clearPatches();
    }
    for (const Sampler &s : std::as_const(samplers_)) {
        if (!s.inst) continue;
        engine.releaseInstrument(s.id);
        s.inst->clearPatches();
    }
}

std::vector<float> renderSfx(const SfxRecipe &recipe, const SfxSamples &samples,
                             uint32_t seed, float velocity, float gain, float pan,
                             int sampleRate, bool stereo, int64_t frames, double detune)
{
    Engine scratch(sampleRate);
    SfxVoices voices;
    voices.attach(scratch, recipe, samples);
    voices.setGain(gain);
    voices.setPan(pan);
    const int64_t end = voices.play(scratch, realizeSfx(recipe, seed, detune), 0, velocity);
    if (frames < 0) frames = end;

    std::vector<float> out(static_cast<size_t>(frames) * (stereo ? 2 : 1));
    // In passes of the size the live sink pulls, though the samples do
    // not depend on it.
    constexpr int kPass = 882;
    for (int64_t at = 0; at < frames; at += kPass) {
        const int n = static_cast<int>(std::min<int64_t>(kPass, frames - at));
        if (stereo) scratch.renderStereo(out.data() + 2 * at, n);
        else        scratch.renderOffline(out.data() + at, n);
    }
    return out;
}

std::vector<float> renderRecipe(const SfxRecipe &recipe, const SfxSamples &samples,
                                uint32_t seed, float velocity, float gain, float pan,
                                int sampleRate, bool stereo, double seconds, double detune)
{
    const int64_t frames = seconds > 0.0 ? std::llround(seconds * sampleRate) : -1;
    std::vector<float> out = renderSfx(recipe, samples, seed, velocity, gain, pan,
                                       sampleRate, stereo, frames, detune);
    for (float &s : out) s = std::clamp(s, -1.0f, 1.0f);
    return out;
}

} // namespace clay::sound
