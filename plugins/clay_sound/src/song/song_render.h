// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A song (song_model.h) as notes in time, and its offline render:
//
//   1. songSchedule(model) lays the sections out: every note of every
//      repeat at its beat, sorted by beat. SongPlayer plays this list
//      live; renderSong() schedules it on a scratch engine.
//   2. renderSong() gives each track's instrument (by the name the song
//      binds, an InstrumentSpec) an engine instrument and schedules
//      every note at its frame through scheduleNote(), the same call a
//      live SynthInstrument or SampleInstrument makes.
//
// Live, SongPlayer fires a note on the tick it falls into, so its notes
// start up to a tick late; offline, every note starts on its exact
// frame. What the buses do afterwards (volume, echo, reverb) is not
// part of an offline render, as for an effect recipe.

#ifndef CLAY_SOUND_SONG_RENDER_H
#define CLAY_SOUND_SONG_RENDER_H

#include "engine/instrument_spec.h"
#include "song_model.h"

#include <QMap>
#include <QString>
#include <QVector>

#include <vector>

namespace clay::sound {

struct SongNote
{
    double  beat = 0.0;
    double  durBeats = 0.0;
    double  vel = 0.8;
    int     midi = 60;
    QString track;
};

// Every note of the song in playing order; `totalBeats` (if non-null)
// gets the song's length, each pattern rounded up to a whole beat.
QVector<SongNote> songSchedule(const SongModel &model, double *totalBeats = nullptr);

// Instrument name (a track's "instrument") -> how it plays.
using SongInstruments = QMap<QString, InstrumentSpec>;

// `seconds` of `model` from its start (<= 0: the song's length), every
// note scaled by `volume` (0..1), played again from the start while
// `loop`. Notes of a track whose instrument is missing stay silent.
// Interleaved stereo, or the (L + R) / 2 downmix when !stereo, clamped
// to [-1, 1] like the live sink.
std::vector<float> renderSong(const SongModel &model, const SongInstruments &instruments,
                              double seconds, float volume, bool loop,
                              int sampleRate, bool stereo);

} // namespace clay::sound

#endif // CLAY_SOUND_SONG_RENDER_H
