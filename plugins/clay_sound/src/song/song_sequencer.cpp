// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song_sequencer.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace clay::sound {

namespace {

constexpr int64_t kNoEnd = std::numeric_limits<int64_t>::max();

// Runs kept behind the current one, for segmentAt() of a frame the
// engine has not played yet.
constexpr int kRunHistory = 16;

} // namespace

SongSequencer::SongSequencer(const SongModel &model, int sampleRate, const QString &segment,
                             double beat, double intensity)
    : model_(model)
{
    const double tempo = model_.tempo > 0.0 ? model_.tempo : 120.0;
    framesPerBeat_ = sampleRate * 60.0 / tempo;

    QMap<QString, int> layerOfTrack;
    for (auto it = model_.layers.begin(); it != model_.layers.end(); ++it) {
        for (const QString &track : it->tracks) layerOfTrack.insert(track, layers_.size());
        layers_.append(it.value());
    }

    // A pattern's notes from `offset` on, each track in name order and
    // its notes as written; the stable sort keeps that order for notes
    // on one beat, so the same song always hands them out alike.
    auto addPattern = [&](QVector<SegNote> &notes, const QString &pattern, double offset, bool layered) {
        const Pattern p = model_.patterns.value(pattern);
        for (auto tit = p.trackEvents.begin(); tit != p.trackEvents.end(); ++tit) {
            const QString instrument = model_.tracks.value(tit.key()).instrument;
            const int layer = layered ? layerOfTrack.value(tit.key(), -1) : -1;
            for (const NoteCell &n : tit.value())
                notes.append({offset + n.t, n.dur, n.vel, n.midi, instrument, layer});
        }
    };
    auto byBeat = [](const SegNote &a, const SegNote &b) { return a.beat < b.beat; };
    for (auto it = model_.segments.begin(); it != model_.segments.end(); ++it) {
        QVector<SegNote> notes;
        double offset = 0.0;
        for (const SectionRef &sec : it->sections) {
            const double len = patternBeats(model_, sec.patternName);
            for (int rep = 0; rep < sec.repeat; ++rep, offset += len)
                addPattern(notes, sec.patternName, offset, true);
        }
        std::stable_sort(notes.begin(), notes.end(), byBeat);
        segmentNotes_.insert(it.key(), notes);
    }
    // A stinger plays at full level, whatever layer its tracks are in.
    for (auto it = model_.stingers.begin(); it != model_.stingers.end(); ++it) {
        QVector<SegNote> notes;
        addPattern(notes, it->pattern, 0.0, false);
        std::stable_sort(notes.begin(), notes.end(), byBeat);
        stingerNotes_.insert(it.key(), notes);
    }

    intensity_ = std::clamp(intensity, 0.0, 1.0);
    for (const Layer &l : std::as_const(layers_)) {
        const double level = layerLevel(l, intensity_);
        ramps_.append({0, level, level, 0});
    }

    // `beat` into the segment at frame 0: the run began that long ago,
    // and its notes before frame 0 are skipped.
    startRun(model_.segments.contains(segment) ? segment : model_.start, -std::max(0.0, beat));
}

int64_t SongSequencer::frameOf(double beat) const
{
    return std::llround(beat * framesPerBeat_);
}

double SongSequencer::layerLevel(const Layer &layer, double intensity) const
{
    if (intensity >= layer.high) return 1.0;
    if (intensity <= layer.low) return 0.0;
    return (intensity - layer.low) / (layer.high - layer.low);
}

double SongSequencer::levelAt(int layer, int64_t frame) const
{
    const Ramp &r = ramps_.at(layer);
    if (r.frames <= 0 || frame >= r.from + r.frames) return r.target;
    if (frame <= r.from) return r.start;
    return r.start + (r.target - r.start) * static_cast<double>(frame - r.from) / r.frames;
}

void SongSequencer::startRun(const QString &segment, double startBeat)
{
    runs_.append({segment, startBeat, segmentBeats(model_, segment), 0});
    if (runs_.size() > kRunHistory) runs_.remove(0, runs_.size() - kRunHistory);
}

void SongSequencer::emitNotes(const QVector<SegNote> &notes, double startBeat, int64_t endFrame,
                              int &next, int64_t until, std::vector<SequencedNote> &out) const
{
    const double secondsPerBeat = 60.0 / (model_.tempo > 0.0 ? model_.tempo : 120.0);
    while (next < notes.size()) {
        const SegNote &n = notes.at(next);
        const int64_t frame = frameOf(startBeat + n.beat);
        // A note on or after a transition belongs to what follows it.
        if (frame >= until || frame >= endFrame) break;
        ++next;
        if (frame < cursor_) continue;      // before frame 0 of a run started midway
        double vel = n.vel;
        if (n.layer >= 0) vel *= levelAt(n.layer, frame);
        if (vel <= 0.0) continue;
        uint32_t seed = 12345u + static_cast<uint32_t>(frameOf(n.beat) & 0xffffffff);
        if (seed == 0) seed = 1;
        out.push_back({frame, n.durBeats * secondsPerBeat, vel, n.midi, n.instrument, seed});
    }
}

void SongSequencer::advance(int64_t until, std::vector<SequencedNote> &out)
{
    if (until <= cursor_) return;
    const size_t first = out.size();

    while (!ended_) {
        // By value: startRun() below may move the runs.
        const Run run = runs_.last();
        const double segEnd = run.startBeat + run.lengthBeats;
        const double blockEnd = pending_ ? pendingBeat_ : segEnd;
        const int64_t blockEndFrame = frameOf(blockEnd);
        emitNotes(segmentNotes_[run.name], run.startBeat, blockEndFrame, runs_.last().next, until, out);
        if (blockEndFrame >= until) break;

        QString next;
        QString stinger;
        if (pending_) {
            next = pendingTo_;
            stinger = pendingStinger_;
            pending_ = false;
        } else {
            next = model_.segments.value(run.name).next;
            if (next.isEmpty() && loop_) next = run.name;
            if (next.isEmpty()) {
                ended_ = true;
                endBeat_ = blockEnd;
                break;
            }
        }
        startRun(next, blockEnd);
        if (!stinger.isEmpty()) stingers_.append({stinger, blockEnd, 0});
    }

    for (StingerRun &s : stingers_)
        emitNotes(stingerNotes_[s.name], s.startBeat, kNoEnd, s.next, until, out);
    stingers_.erase(std::remove_if(stingers_.begin(), stingers_.end(),
                                   [this](const StingerRun &s) {
                                       return s.next >= stingerNotes_.value(s.name).size();
                                   }),
                    stingers_.end());

    std::stable_sort(out.begin() + static_cast<std::ptrdiff_t>(first), out.end(),
                     [](const SequencedNote &a, const SequencedNote &b) { return a.frame < b.frame; });
    cursor_ = until;
}

double SongSequencer::syncPoint(SongSync sync) const
{
    const Run &run = runs_.last();
    const double segEnd = run.startBeat + run.lengthBeats;
    // The first point start + k * unit not handed out yet.
    auto firstOf = [&](double unit) {
        const double into = cursor_ / framesPerBeat_ - run.startBeat;
        for (double k = std::max(0.0, std::floor(into / unit) - 1.0);; k += 1.0) {
            const double p = run.startBeat + k * unit;
            if (p >= segEnd) return segEnd;
            if (frameOf(p) >= cursor_) return p;
        }
    };
    switch (sync) {
    case SongSync::Beat: return firstOf(1.0);
    case SongSync::Bar:  return firstOf(model_.beatsPerBar);
    case SongSync::Exit:
        for (double e : model_.segments.value(run.name).exits)
            if (frameOf(run.startBeat + e) >= cursor_) return run.startBeat + e;
        return segEnd;
    case SongSync::End:  return segEnd;
    }
    return segEnd;
}

bool SongSequencer::setState(const QString &segment)
{
    if (!model_.segments.contains(segment)) return false;
    if (ended_) return true;
    const QString current = runs_.last().name;
    if (segment == current) {
        pending_ = false;       // stay: a move not reached yet is dropped
        return true;
    }
    const Transition *rule = nullptr;
    for (const Transition &t : std::as_const(model_.transitions)) {
        if ((t.from.isEmpty() || t.from == current) && (t.to.isEmpty() || t.to == segment)) {
            rule = &t;
            break;
        }
    }
    pending_ = true;
    pendingTo_ = segment;
    pendingStinger_ = rule ? rule->stinger : QString();
    pendingBeat_ = syncPoint(rule ? rule->sync : SongSync::Bar);
    return true;
}

void SongSequencer::setIntensity(double intensity)
{
    intensity_ = std::clamp(intensity, 0.0, 1.0);
    for (int i = 0; i < layers_.size(); ++i) {
        ramps_[i] = {cursor_, levelAt(i, cursor_), layerLevel(layers_.at(i), intensity_),
                     std::llround(layers_.at(i).fade * framesPerBeat_)};
    }
}

bool SongSequencer::playStinger(const QString &name)
{
    if (!model_.stingers.contains(name)) return false;
    stingers_.append({name, syncPoint(model_.stingers.value(name).sync), 0});
    return true;
}

QString SongSequencer::segmentAt(int64_t frame) const
{
    for (int i = runs_.size() - 1; i > 0; --i)
        if (frameOf(runs_.at(i).startBeat) <= frame) return runs_.at(i).name;
    return runs_.first().name;
}

double SongSequencer::beatAt(int64_t frame) const
{
    int i = runs_.size() - 1;
    while (i > 0 && frameOf(runs_.at(i).startBeat) > frame) --i;
    const Run &run = runs_.at(i);
    const double beat = frame / framesPerBeat_ - run.startBeat;
    return std::clamp(beat, 0.0, run.lengthBeats);
}

int64_t SongSequencer::endFrame() const
{
    return ended_ ? frameOf(endBeat_) : -1;
}

} // namespace clay::sound
