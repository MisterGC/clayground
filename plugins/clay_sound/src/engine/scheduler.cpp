// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "scheduler.h"
#include <algorithm>

namespace clay::sound {

EventId Scheduler::schedule(const NoteEvent& ev)
{
    const EventId id = nextId_++;
    const Entry e{ id, ev };
    // Keep the queue ordered by event time; ties preserve insertion order
    // via upper_bound on timeFrames.
    auto it = std::upper_bound(
        pending_.begin(), pending_.end(), ev.timeFrames,
        [](int64_t t, const Entry& x) { return t < x.ev.timeFrames; });
    pending_.insert(it, e);
    return id;
}

bool Scheduler::cancel(EventId id)
{
    auto it = std::find_if(pending_.begin(), pending_.end(),
                           [id](const Entry& x) { return x.id == id; });
    if (it == pending_.end()) return false;
    pending_.erase(it);
    return true;
}

void Scheduler::clear()
{
    pending_.clear();
}

std::vector<Scheduler::Fired> Scheduler::popDue(int64_t maxFrame)
{
    std::vector<Fired> out;
    auto cut = std::upper_bound(
        pending_.begin(), pending_.end(), maxFrame,
        [](int64_t t, const Entry& x) { return t < x.ev.timeFrames; });
    out.reserve(static_cast<size_t>(cut - pending_.begin()));
    for (auto it = pending_.begin(); it != cut; ++it)
        out.push_back({ it->id, it->ev });
    pending_.erase(pending_.begin(), cut);
    return out;
}

} // namespace clay::sound
