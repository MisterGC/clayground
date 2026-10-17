// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongModel — pure data: tempo, tracks, patterns, sections.
// Built by SongParser from JSON, consumed by SongPlayer (stage 4c).
//
// A version 2 song adds what makes it complete on its own and what
// adaptive game music needs: the instruments its tracks play (as
// InstrumentSpecs), segments the music moves between, layers that an
// intensity 0..1 fades in, transitions synced to beat, bar or a
// segment's exit cues, and stingers played on top.

#ifndef CLAY_SOUND_SONG_MODEL_H
#define CLAY_SOUND_SONG_MODEL_H

#include "engine/instrument_spec.h"

#include <QMap>
#include <QString>
#include <QStringList>
#include <QVector>

#include <algorithm>
#include <cmath>

namespace clay::sound {

struct NoteCell
{
    double t   = 0.0;   // start time in beats
    int    midi = 60;   // MIDI note number (0..127)
    double dur = 0.5;   // duration in beats
    double vel = 0.8;   // velocity (0..1)
};

struct Pattern
{
    // Track name -> ordered note events. Events are stored in the order
    // written by the author; SongPlayer sorts by `t` when scheduling.
    QMap<QString, QVector<NoteCell>> trackEvents;
};

struct SectionRef
{
    QString patternName;
    int     repeat = 1;
};

struct TrackRef
{
    // v1: name of the QML Instrument to bind at play time (matched
    // against its `objectName`). v2: a key of SongModel::instruments.
    QString instrument;
};

// Where a transition or a stinger starts: on the next beat, the next
// bar, the current segment's next exit cue, or the segment's end.
enum class SongSync { Beat, Bar, Exit, End };

// v2: an instrument the song defines. `spec.sample` stays null in the
// model; whoever loads the song decodes `sample` (relative to the song
// file) into it.
struct SongInstrument
{
    InstrumentSpec spec;
    QString        sample;
};

// v2: a part of the song the music stays in until a state change moves
// it on. It plays its sections and then `next` (itself by default).
struct Segment
{
    QVector<SectionRef> sections;
    QVector<double>     exits;      // beats into the segment, ascending
    QString             next;       // empty: the song ends here (or loops)
};

// v2: tracks that sound only as loud as the intensity lets them: silent
// at or below `low`, full at or above `high`, linear between. A change
// of intensity moves the level over `fade` beats. A note takes the
// level its start falls on.
struct Layer
{
    QStringList tracks;
    double      low  = 0.0;
    double      high = 0.0;
    double      fade = 0.0;         // beats
};

// v2: how the music moves from segment `from` to `to` (empty: any).
struct Transition
{
    QString  from;
    QString  to;
    SongSync sync = SongSync::Bar;
    QString  stinger;               // played where the new segment starts
};

// v2: a pattern played once on top of the music.
struct Stinger
{
    QString  pattern;
    SongSync sync = SongSync::Beat;
};

struct SongModel
{
    int    version = 1;
    double tempo = 120.0;
    QMap<QString, TrackRef>   tracks;     // trackName  -> instrument ref
    QMap<QString, Pattern>    patterns;   // patternName -> pattern
    QVector<SectionRef>       sections;   // playback order (v1)

    // v2 only.
    int beatsPerBar = 4;
    QMap<QString, SongInstrument> instruments;
    QMap<QString, Segment>        segments;
    QString                       start;  // the segment play() starts in
    QMap<QString, Layer>          layers;
    QVector<Transition>           transitions;  // the first match wins
    QMap<QString, Stinger>        stingers;

    bool isValid() const { return tempo > 0.0 && !tracks.isEmpty(); }
};

// How long a pattern plays: until its last note ends, rounded up to a
// whole beat (v1) or a whole bar, at least one (v2), so every segment
// of a v2 song starts on a bar.
inline double patternBeats(const SongModel &model, const QString &pattern)
{
    double end = 0.0;
    const Pattern p = model.patterns.value(pattern);
    for (auto it = p.trackEvents.begin(); it != p.trackEvents.end(); ++it)
        for (const NoteCell &n : it.value()) end = std::max(end, n.t + n.dur);
    if (model.version < 2) return std::ceil(end);
    const double bar = model.beatsPerBar;
    return std::max(1.0, std::ceil(end / bar - 1e-9)) * bar;
}

inline double segmentBeats(const SongModel &model, const QString &segment)
{
    double beats = 0.0;
    for (const SectionRef &s : model.segments.value(segment).sections)
        beats += s.repeat * patternBeats(model, s.patternName);
    return beats;
}

} // namespace clay::sound

#endif // CLAY_SOUND_SONG_MODEL_H
