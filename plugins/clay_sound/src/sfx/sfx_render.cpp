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
// Salt of a layer's grains, apart from the noise and every parameter.
constexpr uint32_t kGrainSalt = 0x6772616eu;

// 24 bits of a hash: u in [0, 1), exact in a double.
double unit(uint32_t h) { return (h >> 8) / 16777216.0; }

// Where the grain at `u` (0..1, its place among the grains) starts, in
// ms after the burst's: the grain rate changes exponentially from the
// start to `density` times that at `duration`.
double burstOnset(double u, double duration, double density)
{
    const double a = -std::log(density);
    if (std::abs(a) < 1e-9) return u * duration;
    return -duration / a * std::log(1.0 - u * (1.0 - std::exp(-a)));
}

double inRange(SfxParam p, double v)
{
    return std::clamp(v, sfxParamInfo(p).min, sfxParamInfo(p).max);
}

// The grains of the burst layer `note`: each the layer's note at its
// onset, strayed by its jitter, with its own noise.
void addGrains(const SfxNote &note, uint32_t layerSeed, std::vector<SfxNote> &notes)
{
    const int count = std::max(1, static_cast<int>(std::lround(note.get(P::BurstCount))));
    const uint32_t burstSeed = mix(layerSeed, kGrainSalt);
    for (int i = 0; i < count; ++i) {
        const uint32_t grainSeed = mix(burstSeed, static_cast<uint32_t>(i + 1));
        // In [-1, 1): the k-th jitter of this grain.
        auto spread = [grainSeed](uint32_t k) { return 2.0 * unit(mix(grainSeed, k + 1)) - 1.0; };
        SfxNote g = note;
        g.grain = true;
        // Inside its own slot, so the grains keep their order and the
        // last one starts before the burst's end.
        const double u = (i + 0.5 + 0.5 * note.get(P::JitterTime) * spread(0)) / count;
        g.at(P::Offset) += burstOnset(u, note.get(P::BurstDuration), note.get(P::BurstDensity));
        // A jitter is a range per grain, and a grain stays a valid layer
        // whatever its draw: the parser cannot bound these the way it
        // bounds a vary range, since a design's macro may move either side.
        g.at(P::Gain)    = inRange(P::Gain, note.get(P::Gain) + note.get(P::JitterGain) * spread(1));
        g.at(P::Cutoff)  = inRange(P::Cutoff, note.get(P::Cutoff) * std::exp2(note.get(P::JitterCutoff) * spread(2)));
        g.at(P::Detune)  = inRange(P::Detune, note.get(P::Detune) + note.get(P::JitterFreq) * spread(3));
        g.at(P::Length)  = std::max(0.0, note.get(P::Length) + note.get(P::JitterLength) * spread(4));
        g.noiseSeed = mix(grainSeed, kNoiseSalt) | 1u;
        notes.push_back(g);
    }
}

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
            const double u = unit(mix(layerSeed, static_cast<uint32_t>(p + 1)));
            n.value[p] += r.lo + (r.hi - r.lo) * u;
        }
        n.noiseSeed = mix(layerSeed, kNoiseSalt) | 1u;
        if (layer.burst) addGrains(n, layerSeed, notes);
        else notes.push_back(n);
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

    // Grains ring on an instrument of their own: the voice cap cuts the
    // oldest grain, never a layer that plays as one note.
    if (std::any_of(recipe.layers.cbegin(), recipe.layers.cend(),
                    [](const SfxLayer &l) { return l.burst; })) {
        auto grains = std::make_unique<OscillatorInstrument>();
        grains->setMaxVoices(recipe.maxVoices);
        grain_ = grains.get();
        grainId_ = engine.addInstrument(std::move(grains));
    }

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
    if (grainId_ >= 0) engine.removeInstrument(grainId_);
    for (const Sampler &s : std::as_const(samplers_))
        if (s.id >= 0) engine.removeInstrument(s.id);
    oscId_ = -1;
    osc_ = nullptr;
    grainId_ = -1;
    grain_ = nullptr;
    samplers_.clear();
}

void SfxVoices::setGain(float g)
{
    if (osc_) osc_->setGain(g);
    if (grain_) grain_->setGain(g);
    for (const Sampler &s : std::as_const(samplers_)) if (s.inst) s.inst->setGain(g);
}

void SfxVoices::setPan(float p)
{
    if (osc_) osc_->setPan(p);
    if (grain_) grain_->setPan(p);
    for (const Sampler &s : std::as_const(samplers_)) if (s.inst) s.inst->setPan(p);
}

void SfxVoices::setBus(Bus b)
{
    if (osc_) osc_->setBus(b);
    if (grain_) grain_->setBus(b);
    for (const Sampler &s : std::as_const(samplers_)) if (s.inst) s.inst->setBus(b);
}

SfxVoices::Span SfxVoices::play(Engine &engine, const std::vector<SfxNote> &notes, int64_t at,
                                float velocity, int gainStage) const
{
    if (!osc_) return {};
    const int rate = engine.sampleRate();
    Span span;
    int64_t tail = 0;   // the release of the layer that ends last
    auto ended = [&span, &tail](int64_t end, int64_t release) {
        if (end > span.end) { span.end = end; tail = release; }
        else if (end == span.end) tail = std::max(tail, release);
    };
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
            patch.attackCurve  = n.get(P::AttackCurve);
            patch.releaseCurve = n.get(P::ReleaseCurve);
            s.inst->pushPatch(engine.schedule(ev), patch);
            ended(offset + ev.durationFrames,
                  std::min(ev.durationFrames, msToFrames(n.get(P::Release), rate)));
        } else {
            OscillatorInstrument *inst = n.grain ? grain_ : osc_;
            ev.instrumentId   = n.grain ? grainId_ : oscId_;
            ev.freqHz         = n.get(P::Freq) * detune;
            ev.durationFrames = std::max<int64_t>(1, msToFrames(n.get(P::Length), rate));

            OscillatorVoice::Patch patch;
            patch.waveform   = waveformOf(layer.source);
            patch.pulseWidth = n.get(P::PulseWidth);
            patch.attack     = n.get(P::Attack) / 1000.0;
            patch.decay      = n.get(P::Decay) / 1000.0;
            patch.sustain    = n.get(P::Sustain);
            patch.release    = n.get(P::Release) / 1000.0;
            patch.attackCurve  = n.get(P::AttackCurve);
            patch.decayCurve   = n.get(P::DecayCurve);
            patch.releaseCurve = n.get(P::ReleaseCurve);
            patch.pitchStart = n.get(P::PitchStart);
            patch.pitchEnd   = n.get(P::PitchEnd);
            patch.pitchTime  = n.get(P::PitchTime) / 1000.0;
            patch.pitchCurve = n.get(P::PitchCurve);
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
            patch.filterAttackCurve  = n.get(P::FilterAttackCurve);
            patch.filterDecayCurve   = n.get(P::FilterDecayCurve);
            patch.filterReleaseCurve = n.get(P::FilterReleaseCurve);
            patch.noiseSeed  = n.noiseSeed;
            patch.noiseColor = layer.noiseColor;
            patch.noiseRate  = layer.noiseRate;
            inst->pushPatch(engine.schedule(ev), patch);
            ended(offset + ev.durationFrames,
                  std::min(ev.durationFrames, msToFrames(n.get(P::Release), rate)));
        }
    }
    span.period = std::max<int64_t>(span.end > 0 ? 1 : 0, span.end - tail);
    return span;
}

void SfxVoices::stop(Engine &engine) const
{
    if (osc_) {
        engine.releaseInstrument(oscId_);
        // The cancelled layers' patches would wait for events that never come.
        osc_->clearPatches();
    }
    if (grain_) {
        engine.releaseInstrument(grainId_);
        grain_->clearPatches();
    }
    for (const Sampler &s : std::as_const(samplers_)) {
        if (!s.inst) continue;
        engine.releaseInstrument(s.id);
        s.inst->clearPatches();
    }
}

std::vector<float> renderSfx(const SfxRecipe &recipe, const SfxSamples &samples,
                             uint32_t seed, float velocity, float gain, float pan,
                             int sampleRate, bool stereo, int64_t frames, double detune,
                             int passes)
{
    Engine scratch(sampleRate);
    SfxVoices voices;
    voices.attach(scratch, recipe, samples);
    voices.setGain(gain);
    voices.setPan(pan);
    const auto notes = realizeSfx(recipe, seed, detune);
    const SfxVoices::Span span = voices.play(scratch, notes, 0, velocity);
    if (frames < 0) frames = passes > 0 ? passes * span.period : span.end;
    // Every further pass that starts inside the render, as SfxPlayer
    // schedules them.
    if (passes > 0 && span.period > 0)
        for (int64_t at = span.period; at < frames; at += span.period)
            voices.play(scratch, notes, at, velocity);

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
                                int sampleRate, bool stereo, double seconds, double detune,
                                int passes)
{
    const int64_t frames = seconds > 0.0 ? std::llround(seconds * sampleRate) : -1;
    std::vector<float> out = renderSfx(recipe, samples, seed, velocity, gain, pan,
                                       sampleRate, stereo, frames, detune, passes);
    for (float &s : out) s = std::clamp(s, -1.0f, 1.0f);
    return out;
}

} // namespace clay::sound
