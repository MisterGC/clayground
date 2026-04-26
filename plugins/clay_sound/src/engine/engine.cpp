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

void Engine::renderOffline(float* out, int frames)
{
    if (frames <= 0) return;
    std::memset(out, 0, sizeof(float) * static_cast<size_t>(frames));

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
        voices_.push_back({instId, std::move(voice)});
    }

    // Render each voice into a per-pass scratch buffer so we can apply
    // the source instrument's gain before summing into `out`. The
    // scratch is reused across voices in this pass.
    if (static_cast<int>(scratch_.size()) < frames)
        scratch_.assign(static_cast<size_t>(frames), 0.0f);

    for (auto& av : voices_) {
        IInstrument* inst = instrumentAt(av.instrumentId);
        if (!inst) continue; // tombstoned; will be reaped below
        std::fill_n(scratch_.begin(), frames, 0.0f);
        av.voice->render(scratch_.data(), frames, bufStart);
        const float g = inst->gain();
        if (g == 1.0f) {
            for (int i = 0; i < frames; ++i) out[i] += scratch_[i];
        } else {
            for (int i = 0; i < frames; ++i) out[i] += scratch_[i] * g;
        }
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
