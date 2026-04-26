// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongModel — pure data: tempo, tracks, patterns, sections.
// Built by SongParser from JSON, consumed by SongPlayer (stage 4c).

#ifndef CLAY_SOUND_SONG_MODEL_H
#define CLAY_SOUND_SONG_MODEL_H

#include <QMap>
#include <QString>
#include <QVector>

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
    // Name of the QML Instrument to bind at play time (matched against
    // its `objectName`).
    QString instrument;
};

struct SongModel
{
    double tempo = 120.0;
    QMap<QString, TrackRef>   tracks;     // trackName  -> instrument ref
    QMap<QString, Pattern>    patterns;   // patternName -> pattern
    QVector<SectionRef>       sections;   // playback order

    bool isValid() const { return tempo > 0.0 && !tracks.isEmpty(); }
};

} // namespace clay::sound

#endif // CLAY_SOUND_SONG_MODEL_H
