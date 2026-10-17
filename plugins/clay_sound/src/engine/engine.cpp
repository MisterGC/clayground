// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "engine.h"
#include "instrument.h"
#include "voice.h"
#include <algorithm>
#include <cstring>

namespace clay::sound {

Engine::Engine(int sampleRate) : sampleRate_(sampleRate) {}
Engine::~Engine() = default;

int Engine::addInstrument(std::unique_ptr<IInstrument> inst)
{
    instruments_.push_back(std::move(inst));
    return static_cast<int>(instruments_.size()) - 1;
}

void Engine::removeInstrument(int id)
{
    if (id < 0 || static_cast<size_t>(id) >= instruments_.size()) return;
    instruments_[id].reset(); // tombstone — keeps subsequent ids stable
    // Drop any active voices that belonged to it; their factory is gone.
    voices_.erase(
        std::remove_if(voices_.begin(), voices_.end(),
                       [id](const ActiveVoice& av) { return av.instrumentId == id; }),
        voices_.end());
}

IInstrument* Engine::instrumentAt(int id) const
{
    if (id < 0 || static_cast<size_t>(id) >= instruments_.size()) return nullptr;
    return instruments_[id].get();
}

EventId Engine::schedule(const NoteEvent& ev)
{
    return scheduler_.schedule(ev);
}

bool Engine::cancel(EventId id)
{
    return scheduler_.cancel(id);
}

void Engine::clearSchedule()
{
    scheduler_.clear();
}

void Engine::resetVoices()
{
    voices_.clear();
}

size_t Engine::activeVoices(int instrumentId) const
{
    size_t n = 0;
    for (const auto& av : voices_)
        if (av.instrumentId == instrumentId) ++n;
    return n;
}

static float clamp01(float g) { return g < 0.0f ? 0.0f : (g > 1.0f ? 1.0f : g); }

void Engine::setBusGain(Bus bus, float g)
{
    busGain_[static_cast<int>(bus)].store(clamp01(g), std::memory_order_relaxed);
}

float Engine::busGain(Bus bus) const
{
    return busGain_[static_cast<int>(bus)].load(std::memory_order_relaxed);
}

int Engine::addGainStage(float g)
{
    gainStages_.push_back(std::make_unique<std::atomic<float>>(clamp01(g)));
    return static_cast<int>(gainStages_.size()) - 1;
}

void Engine::setGainStage(int id, float g)
{
    if (id < 0 || static_cast<size_t>(id) >= gainStages_.size()) return;
    gainStages_[id]->store(clamp01(g), std::memory_order_relaxed);
}

float Engine::gainStage(int id) const
{
    if (id < 0 || static_cast<size_t>(id) >= gainStages_.size()) return 1.0f;
    return gainStages_[id]->load(std::memory_order_relaxed);
}

void Engine::renderOffline(float* out, int frames)
{
    if (frames <= 0) return;
    if (static_cast<int>(stereo_.size()) < 2 * frames)
        stereo_.assign(2 * static_cast<size_t>(frames), 0.0f);
    renderStereo(stereo_.data(), frames);
    // A centred voice is s in both channels, and (s + s) * 0.5 is s
    // again exactly, so centred mono content keeps its samples.
    for (int i = 0; i < frames; ++i)
        out[i] = (stereo_[2 * i] + stereo_[2 * i + 1]) * 0.5f;
}

void Engine::renderStereo(float* out, int frames)
{
    if (frames <= 0) return;
    const size_t n = 2 * static_cast<size_t>(frames);
    std::memset(out, 0, sizeof(float) * n);

    const int64_t bufStart = currentFrame_;
    const int64_t bufEnd = currentFrame_ + frames;

    // Fire any events that fall within this buffer's frame window.
    auto fired = scheduler_.popDue(bufEnd - 1);
    for (const auto& f : fired) {
        const int instId = f.ev.instrumentId;
        IInstrument* inst = instrumentAt(instId);
        if (!inst) continue;
        auto voice = inst->createVoice(f.ev, f.id, sampleRate_);
        if (!voice) continue;
        voice->onNoteOn(f.ev, sampleRate_);
        // voices_ is in note-on order, so the first of this instrument's
        // voices is its oldest; cut those until the new one fits.
        if (const int cap = inst->maxVoices(); cap > 0) {
            const size_t have = activeVoices(instId);
            size_t excess = have >= static_cast<size_t>(cap) ? have - cap + 1 : 0;
            for (auto it = voices_.begin(); excess > 0 && it != voices_.end();) {
                if (it->instrumentId == instId) { it = voices_.erase(it); --excess; }
                else ++it;
            }
        }
        voices_.push_back({instId, std::move(voice), f.ev.pan, f.ev.gainStage});
    }

    // Render each voice into a per-pass scratch buffer so we can apply
    // the source instrument's gain and pan before summing into its
    // bus. The scratch is reused across voices in this pass.
    if (static_cast<int>(scratch_.size()) < frames)
        scratch_.assign(static_cast<size_t>(frames), 0.0f);
    bool busUsed[kBusCount] = {};

    for (auto& av : voices_) {
        IInstrument* inst = instrumentAt(av.instrumentId);
        if (!inst) continue; // tombstoned; will be reaped below
        std::fill_n(scratch_.begin(), frames, 0.0f);
        av.voice->render(scratch_.data(), frames, bufStart);

        const int b = static_cast<int>(inst->bus());
        std::vector<float>& mix = busMix_[b];
        if (!busUsed[b]) {
            if (mix.size() < n) mix.resize(n);
            std::fill_n(mix.begin(), n, 0.0f);
            busUsed[b] = true;
        }
        float pl = 1.0f, pr = 1.0f;
        panGains(std::clamp(inst->pan() + av.pan, -1.0f, 1.0f), pl, pr);
        // A product of ones is one, so a centred voice at full gain
        // adds its samples unscaled, as the mono mix did.
        const float g = inst->gain() * gainStage(av.gainStage);
        const float gl = g * pl;
        const float gr = g * pr;
        for (int i = 0; i < frames; ++i) {
            mix[2 * i]     += scratch_[i] * gl;
            mix[2 * i + 1] += scratch_[i] * gr;
        }
    }

    for (int b = 0; b < kBusCount; ++b) {
        if (!busUsed[b]) continue;
        const float bg = busGain_[b].load(std::memory_order_relaxed);
        const std::vector<float>& mix = busMix_[b];
        for (size_t i = 0; i < n; ++i) out[i] += mix[i] * bg;
    }

    currentFrame_ = bufEnd;

    // Reap finished voices, plus any whose instrument was removed.
    voices_.erase(
        std::remove_if(voices_.begin(), voices_.end(),
                       [this](const ActiveVoice& av) {
                           return !instrumentAt(av.instrumentId)
                               || av.voice->isFinished(currentFrame_);
                       }),
        voices_.end());
}

} // namespace clay::sound
