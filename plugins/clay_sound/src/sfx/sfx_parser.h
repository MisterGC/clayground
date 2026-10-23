// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SfxParser — strict JSON -> SfxRecipe translator.
//
// Format (version 1):
//   {
//     "version": 1,
//     "name": "wheel-detent",
//     "variation": { "seed": 7, "pool": 4 },
//     "maxVoices": 6,
//     "layers": [
//       { "role": "body", "source": "triangle", "freq": 784,
//         "length": 40, "gain": -10,
//         "envelope": { "attack": 0.5, "decay": 55, "sustain": 0, "release": 20 },
//         "pitch": { "start": 12, "end": 0, "time": 12 },
//         "vary": { "detune": [-1, 1], "gain": [-2, 0] } },
//       { "role": "body", "source": "sine", "freq": 500, "length": 900,
//         "fm": { "ratio": 2.76, "index": 4, "decay": 600, "sustain": 0 } },
//       { "role": "body", "source": "noise", "length": 900,
//         "filter": { "type": "lowpass", "cutoff": 600 },
//         "lfo": { "target": "cutoff", "shape": "sample_hold", "rate": 9, "depth": 1 } },
//       { "role": "tail", "source": "noise", "length": 3,
//         "noise": { "color": "pink", "rate": "freq" },
//         "burst": { "count": 12, "duration": 200, "density": 0.3,
//                    "jitter": { "time": 1, "gain": 3 } } }
//     ]
//   }
//
// Every field is checked against its range (sfx_recipe.h), and so is
// every value a variation can reach. Unknown fields are rejected by
// name — a typo must surface, not drop a parameter silently.

#ifndef CLAY_SOUND_SFX_PARSER_H
#define CLAY_SOUND_SFX_PARSER_H

#include "sfx_recipe.h"

#include <QByteArray>
#include <QString>

namespace clay::sound {

struct SfxParseResult
{
    SfxRecipe recipe;
    bool      ok = false;
    QString   error;        // empty when ok; starts with the field's path
};

class SfxParser
{
public:
    static SfxParseResult parse(const QByteArray &json);
};

} // namespace clay::sound

#endif // CLAY_SOUND_SFX_PARSER_H
