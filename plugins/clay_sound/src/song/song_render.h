// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A song (song_model.h) as notes in time, and its offline render.
//
// Version 1:
//   1. songSchedule(model) lays the sections out: every note of every
//      repeat at its beat, sorted by beat. SongPlayer plays this list
//      live; renderSong() schedules it on a scratch engine.
//   2. renderSong() gives each track's instrument (by the name the song
//      binds, an InstrumentSpec) an engine instrument and schedules
//      every note at its frame through scheduleNote(), the same call a
//      live SynthInstrument or SampleInstrument makes.
//
//   Live, SongPlayer fires a v1 note on the tick it falls into, so its
//   notes start up to a tick late; offline, every note starts on its
//   exact frame.
//
// Version 2, live and offline alike:
//   1. SongSequencer (song_sequencer.h) turns the song and the controls
//      it gets (state, intensity, stingers) into notes on song frames.
//   2. SongVoices holds the song's own instruments in one engine and
//      schedules each such note at its frame, through scheduleNote().
//   SongPlayer runs both on the shared engine ahead of what it plays;
//   renderSong() with a SongPerformance runs them on a scratch engine,
//   each cue at its frame. The same cues at the same frames give the
//   same samples, noise included: a noise note carries its own seed
//   (SequencedNote::noiseSeed), not the engine frame it starts on.
//
// What the buses do afterwards (volume, echo, reverb) is not part of an
// offline render, as for an effect recipe.

#ifndef CLAY_SOUND_SONG_RENDER_H
#define CLAY_SOUND_SONG_RENDER_H

#include "engine/instrument_spec.h"
#include "song_model.h"
#include "song_sequencer.h"

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
// A version 2 model renders through the overload below with the
// default performance; `instruments` is not read then.
std::vector<float> renderSong(const SongModel &model, const SongInstruments &instruments,
                              double seconds, float volume, bool loop,
                              int sampleRate, bool stereo);

// --- version 2 -------------------------------------------------------

// The instruments of a v2 song (each spec's sample decoded) on one
// engine. The engine owns them; detach() drops them and every voice
// still ringing.
class SongVoices
{
public:
    void attach(Engine &engine, const SongModel &model);
    void detach(Engine &engine);

    // Schedule `note` to start at engine frame `at`, through gain stage
    // `gainStage`. Returns the scheduler ticket, 0 when it cannot sound
    // (an instrument without its sample).
    EventId play(Engine &engine, const SequencedNote &note, int64_t at, int gainStage = -1) const;

private:
    struct Bound { int id = -1; InstrumentSpec spec; };
    QMap<QString, Bound> bound_;
};

// What a game does to a playing v2 song, at a song frame.
struct SongCue
{
    enum class Kind { State, Intensity, Stinger };
    int64_t frame = 0;
    Kind    kind = Kind::State;
    QString name;           // the segment, or the stinger
    double  value = 0.0;    // the intensity
};

struct SongPerformance
{
    QString start;          // segment to start in; empty: the song's start
    double  intensity = 0.0;
    QVector<SongCue> cues;  // in frame order
};

// `seconds` of a v2 song played as `performance` says (<= 0: one pass
// of the segment it starts in), on the song's own instruments, every
// note scaled by `volume`; `loop` repeats a song without segments.
// Interleaved stereo or the mono downmix, clamped like the live sink.
std::vector<float> renderSong(const SongModel &model, const SongPerformance &performance,
                              double seconds, float volume, bool loop,
                              int sampleRate, bool stereo);

} // namespace clay::sound

#endif // CLAY_SOUND_SONG_RENDER_H
