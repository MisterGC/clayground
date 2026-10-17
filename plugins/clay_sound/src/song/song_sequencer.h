// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongSequencer — a version 2 song (song_model.h) as notes on frames,
// steered while it plays: the state names the segment the music moves
// to, the intensity fades the layers, a stinger plays on top.
//
// Time is the song's own: frame 0 is where it starts. advance(until)
// hands out every note starting before `until` that it has not handed
// out yet, each on its exact frame. A control (setState, setIntensity,
// playStinger) takes effect at scheduled(), the frame advanced to so
// far: whoever drives the sequencer advances to the frame a control
// belongs to first, then sends it. SongPlayer does that live, ahead of
// the engine; renderSong() does it offline for a list of cues, so the
// same controls at the same frames give the same notes.
//
// Pure data and arithmetic: no engine, no clock, no randomness.

#ifndef CLAY_SOUND_SONG_SEQUENCER_H
#define CLAY_SOUND_SONG_SEQUENCER_H

#include "song_model.h"

#include <QString>
#include <QVector>

#include <cstdint>
#include <vector>

namespace clay::sound {

struct SequencedNote
{
    int64_t frame = 0;          // song frame the note starts on
    double  durSeconds = 0.0;
    double  vel = 0.8;          // the song's velocity times its layer's level
    int     midi = 60;
    QString instrument;         // key of SongModel::instruments
    // A noise instrument's seed: from the note's frame within its
    // segment pass or stinger, so a pass hisses alike wherever it
    // starts. Never 0, which would fall back to the engine frame.
    uint32_t noiseSeed = 1;
};

class SongSequencer
{
public:
    // Starts in `segment` (empty or unknown: the song's start),
    // `beat` beats into it, at `intensity`.
    SongSequencer(const SongModel &model, int sampleRate, const QString &segment = {},
                  double beat = 0.0, double intensity = 0.0);

    // Every note starting in [scheduled(), until), in start order, is
    // appended to `out`; scheduled() becomes `until`.
    void advance(int64_t until, std::vector<SequencedNote> &out);
    int64_t scheduled() const { return cursor_; }

    // Move to `segment` at the sync point of the first transition that
    // matches (from the current segment to it), or on the next bar when
    // none does. A later state replaces one not reached yet. False for
    // an unknown segment.
    bool setState(const QString &segment);
    // 0..1; each layer's level moves to what it gives over its fade.
    void setIntensity(double intensity);
    // Play the stinger on its sync point. False for an unknown name.
    bool playStinger(const QString &name);

    // A segment without a next (a song without segments) ends the song,
    // unless it loops.
    void setLoop(bool loop) { loop_ = loop; }

    // The segment playing at song frame `frame` (<= scheduled()) and
    // how many beats into it.
    QString segmentAt(int64_t frame) const;
    double  beatAt(int64_t frame) const;
    // Once true, no note follows; endFrame() is where the song ended.
    bool    ended() const { return ended_; }
    int64_t endFrame() const;

    double framesPerBeat() const { return framesPerBeat_; }

private:
    struct SegNote
    {
        double  beat;           // into the segment (or stinger)
        double  durBeats;
        double  vel;
        int     midi;
        QString instrument;
        int     layer;          // index into layers_, -1: always full
    };
    struct Run                  // one pass of a segment
    {
        QString name;
        double  startBeat;      // song beat it starts on
        double  lengthBeats;
        int     next = 0;       // first note not handed out
    };
    struct StingerRun
    {
        QString name;
        double  startBeat;
        int     next = 0;
    };
    struct Ramp                 // a layer's level from `from` on
    {
        int64_t from = 0;
        double  start = 0.0, target = 0.0;
        int64_t frames = 0;
    };

    int64_t frameOf(double beat) const;
    double  syncPoint(SongSync sync) const;
    double  levelAt(int layer, int64_t frame) const;
    double  layerLevel(const Layer &layer, double intensity) const;
    void    startRun(const QString &segment, double startBeat);
    void    emitNotes(const QVector<SegNote> &notes, double startBeat, int64_t endFrame,
                      int &next, int64_t until, std::vector<SequencedNote> &out) const;

    SongModel model_;
    double framesPerBeat_ = 0.0;
    QMap<QString, QVector<SegNote>> segmentNotes_;
    QMap<QString, QVector<SegNote>> stingerNotes_;
    QVector<Layer> layers_;
    QVector<Ramp>  ramps_;
    double intensity_ = 0.0;

    QVector<Run> runs_;         // the current one last; earlier ones for segmentAt()
    QVector<StingerRun> stingers_;
    bool    pending_ = false;   // a transition waits for its sync point
    QString pendingTo_;
    QString pendingStinger_;
    double  pendingBeat_ = 0.0;

    int64_t cursor_ = 0;
    bool   loop_ = false;
    bool   ended_ = false;
    double endBeat_ = 0.0;
};

} // namespace clay::sound

#endif // CLAY_SOUND_SONG_SEQUENCER_H
