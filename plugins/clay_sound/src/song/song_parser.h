// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongParser — strict JSON -> SongModel translator.
//
// Top-level format (v1):
//   {
//     "tempo": 120,
//     "tracks":   { "lead": { "instrument": "leadSynth" }, ... },
//     "patterns": { "A": { "lead": [ { "t": 0, "note": "C4",
//                                      "dur": 0.5, "vel": 0.8 }, ... ] } },
//     "sections": [ { "pattern": "A", "repeat": 2 }, ... ]
//   }
//
// Notes may be given as MIDI numbers (0..127) or scientific pitch
// strings like "C4", "F#3", "Bb5". `vel` defaults to 0.8; `dur` to 0.5
// beats. `sections` may be omitted; playback then visits each pattern
// once in JSON-insertion order.
//
// Unknown top-level or note-object keys are rejected — we want
// typo-surfacing, not silent data drop.

#ifndef CLAY_SOUND_SONG_PARSER_H
#define CLAY_SOUND_SONG_PARSER_H

#include "song_model.h"

#include <QByteArray>
#include <QString>

namespace clay::sound {

struct SongParseResult
{
    SongModel model;
    bool      ok = false;
    QString   error;        // empty when ok
    int       line = -1;    // best-effort; -1 if not available
};

class SongParser
{
public:
    static SongParseResult parse(const QByteArray &json);

    // Exposed for tests / direct use by SongPlayer when authoring UI
    // feeds a single note string.
    static bool parseNote(const QString &s, int *midiOut, QString *errorOut = nullptr);
};

} // namespace clay::sound

#endif // CLAY_SOUND_SONG_PARSER_H
