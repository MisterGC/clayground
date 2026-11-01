// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// writeSfxRecipe — the one way a recipe (*.sfx.json) is written as bytes.
//
// The keys come in the README's order (version, name, variation, layers;
// in a layer: name, role, source, ... vary) rather than QJsonDocument's
// alphabetical one, one layer field per line and the small objects of a
// layer (envelope, pitch, filter, lfo, vary) on one line, so a compiled
// recipe diffs like a hand-written one. A number is written as an
// integer when it is one, else as the shortest form that reads back to
// the same double. The same object gives the same bytes on every
// platform.

#ifndef CLAY_SOUND_SFX_WRITER_H
#define CLAY_SOUND_SFX_WRITER_H

#include <QByteArray>
#include <QJsonObject>

namespace clay::sound {

// `recipe` as written JSON, ending in a newline. Keys a recipe does not
// know follow the known ones of their object, in alphabetical order.
QByteArray writeSfxRecipe(const QJsonObject &recipe);

} // namespace clay::sound

#endif // CLAY_SOUND_SFX_WRITER_H
