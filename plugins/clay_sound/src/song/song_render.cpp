// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song_render.h"

#include "engine/engine.h"

#include <QHash>

#include <algorithm>
#include <cmath>

namespace clay::sound {

QVector<SongNote> songSchedule(const SongModel &model, double *totalBeats)
{
    QVector<SongNote> notes;

    // Pattern lengths, rounded up to the next full beat.
    QHash<QString, double> patternLength;
    for (auto it = model.patterns.begin(); it != model.patterns.end(); ++it) {
        double endBeat = 0.0;
        for (auto tit = it->trackEvents.begin(); tit != it->trackEvents.end(); ++tit) {
            for (const auto &n : tit.value())
                endBeat = std::max(endBeat, n.t + n.dur);
        }
        patternLength.insert(it.key(), std::ceil(endBeat));
    }

    double cursor = 0.0;
    for (const auto &sec : std::as_const(model.sections)) {
        if (!model.patterns.contains(sec.patternName)) continue;
        const auto pattern = model.patterns.value(sec.patternName);
        const double len = patternLength.value(sec.patternName, 1.0);
        for (int rep = 0; rep < sec.repeat; ++rep) {
            for (auto tit = pattern.trackEvents.begin(); tit != pattern.trackEvents.end(); ++tit) {
                for (const auto &n : tit.value()) {
                    SongNote sn;
                    sn.beat     = cursor + n.t;
                    sn.durBeats = n.dur;
                    sn.vel      = n.vel;
                    sn.midi     = n.midi;
                    sn.track    = tit.key();
                    notes.append(sn);
                }
            }
            cursor += len;
        }
    }

    std::sort(notes.begin(), notes.end(),
              [](const SongNote &a, const SongNote &b) { return a.beat < b.beat; });
    if (totalBeats) *totalBeats = cursor;
    return notes;
}

std::vector<float> renderSong(const SongModel &model, const SongInstruments &instruments,
                              double seconds, float volume, bool loop,
                              int sampleRate, bool stereo)
{
    double totalBeats = 0.0;
    const QVector<SongNote> notes = songSchedule(model, &totalBeats);
    const double bpm = model.tempo > 0.0 ? model.tempo : 120.0;
    const double songSeconds = totalBeats * 60.0 / bpm;
    if (seconds <= 0.0) seconds = songSeconds;
    const int64_t frames = std::max<int64_t>(0, std::llround(seconds * sampleRate));
    std::vector<float> out(static_cast<size_t>(frames) * (stereo ? 2 : 1), 0.0f);
    if (frames == 0) return out;

    Engine scratch(sampleRate);
    const int stage = scratch.addGainStage(std::clamp(volume, 0.0f, 1.0f));

    struct Bound { int id = -1; const InstrumentSpec *spec = nullptr; };
    QHash<QString, Bound> byName;
    for (auto it = instruments.begin(); it != instruments.end(); ++it)
        byName.insert(it.key(), {addInstrument(scratch, it.value()), &it.value()});

    // Each pass of the song starts where the last one ended; without
    // loop there is one pass.
    const int passes = (loop && songSeconds > 0.0)
        ? static_cast<int>(std::ceil(seconds / songSeconds)) : 1;
    for (int pass = 0; pass < passes; ++pass) {
        for (const SongNote &n : notes) {
            const Bound b = byName.value(model.tracks.value(n.track).instrument);
            if (!b.spec) continue;
            const double at = (pass * totalBeats + n.beat) * 60.0 / bpm;
            const int64_t atFrame = std::llround(at * sampleRate);
            if (atFrame >= frames) continue;
            scheduleNote(scratch, b.id, *scratch.instrumentAt(b.id), *b.spec,
                         midiToHz(n.midi), n.vel, n.durBeats * 60.0 / bpm, atFrame, stage);
        }
    }

    // In passes of the size the live sink pulls, though the samples do
    // not depend on it.
    constexpr int kPass = 882;
    for (int64_t at = 0; at < frames; at += kPass) {
        const int n = static_cast<int>(std::min<int64_t>(kPass, frames - at));
        if (stereo) scratch.renderStereo(out.data() + 2 * at, n);
        else        scratch.renderOffline(out.data() + at, n);
    }
    for (float &s : out) s = std::clamp(s, -1.0f, 1.0f);
    return out;
}

} // namespace clay::sound
