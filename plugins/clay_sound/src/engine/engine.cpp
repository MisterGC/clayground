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
        if (instId < 0 || static_cast<size_t>(instId) >= instruments_.size())
            continue;
        auto voice = instruments_[instId]->createVoice(f.ev, f.id, sampleRate_);
        if (!voice) continue;
        voice->onNoteOn(f.ev, sampleRate_);
        voices_.push_back(std::move(voice));
    }

    // Render every active voice into the buffer; each voice is
    // responsible for clipping to the overlap of its lifetime with
    // [bufStart, bufEnd).
    for (auto& v : voices_)
        v->render(out, frames, bufStart);

    currentFrame_ = bufEnd;

    // Reap finished voices.
    voices_.erase(
        std::remove_if(voices_.begin(), voices_.end(),
                       [this](const std::unique_ptr<IVoice>& v) {
                           return v->isFinished(currentFrame_);
                       }),
        voices_.end());
}

} // namespace clay::sound
