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
//
// Version 2 ("version": 2; a file without "version" is v1) defines its
// instruments and adds the structure adaptive music needs:
//   {
//     "version": 2, "tempo": 120, "beatsPerBar": 4,
//     "instruments": { "lead": { "source": "square", "pulseWidth": 0.25,
//                                "envelope": { "attack": 5, "release": 80 },
//                                "filter": { "type": "lowpass", "cutoff": 2400 },
//                                "gain": -6, "pan": 0, "bus": "music" },
//                      "kick": { "source": "sample", "sample": "kick.wav", "root": "C2" } },
//     "tracks":   { "melody": { "instrument": "lead" }, ... },
//     "patterns": { ... as v1 ... },
//     "segments": { "explore": { "sections": [ { "pattern": "A" } ], "exits": [8] },
//                   "combat":  { "sections": [ { "pattern": "C" } ], "next": "combat" } },
//     "start": "explore",
//     "layers": { "drums": { "tracks": ["perc"], "intensity": [0.3, 0.6], "fade": 4 } },
//     "transitions": [ { "from": "explore", "to": "combat", "sync": "bar", "stinger": "alarm" } ],
//     "stingers": { "alarm": { "pattern": "S", "sync": "beat" } }
//   }
// An instrument takes an effect recipe layer's fields and units (ms, dB,
// Hz, semitones) plus "bus" (default music) and "maxVoices"; a sample
// instrument takes "sample" (relative to the song file), "root",
// "interpolation" and "loop". Every track plays a defined instrument.
// A v2 pattern lasts whole bars. Without "segments" the sections (at
// least one) are one segment, "main", after which the song ends (or
// loops); a segment goes on to "next", itself by default. song_model.h
// says what layers, transitions and stingers mean.

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
