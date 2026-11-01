// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The files around an offline render, for a program without QML: an
// effect recipe with its samples, the design file it is compiled from, a
// song, and the wav a render becomes.
// They read the way SfxPlayer and SongPlayer read a local file, so a
// recipe loaded here renders what the QML player renders.

#ifndef CLAY_SOUND_SOUND_FILES_H
#define CLAY_SOUND_SOUND_FILES_H

#include "sfx/sfx_design.h"
#include "sfx/sfx_recipe.h"
#include "sfx/sfx_render.h"
#include "song/song_model.h"

#include <string>
#include <vector>

namespace clay::sound {

// The rate the live sink plays at (AudioOutput::sampleRate()).
constexpr int kSampleRate = 44100;

struct RecipeFile
{
    SfxRecipe  recipe;
    SfxSamples samples;     // decoded sample of each sample layer
};

// Parse the recipe at `path` and decode its sample layers, each path
// relative to the recipe file. False with `error` set on the first
// thing that fails.
bool loadRecipe(const std::string &path, RecipeFile *out, std::string *error = nullptr);

// Compile the design file at `designPath` against the template at
// `templatePath` (sfx/sfx_design.h) into `out`; with a `recipePath`,
// write out->json there. False with `error` set - the failing file's
// path first - when either file does not read or the design does not
// compile; a clamped drive is not an error, out->clampMessages() lists
// it. A sample layer's path is copied as the template writes it, and so
// is relative to the recipe file it ends up in.
bool compileDesignFile(const std::string &designPath, const std::string &templatePath,
                       const std::string &recipePath, SfxCompileResult *out,
                       std::string *error = nullptr);

// Parse the song (song/song_parser.h) at `path`; a version 2 song's
// sample instruments get their files decoded, each relative to the song.
bool loadSong(const std::string &path, SongModel *out, std::string *error = nullptr);

enum class WavFormat {
    Float32,    // the rendered samples exactly
    Pcm16       // 16-bit signed, rounded from the samples clamped to [-1, 1]
};

// Write `samples` (interleaved when channels is 2) as a wav file.
bool writeWav(const std::string &path, const std::vector<float> &samples,
              int channels, int sampleRate, WavFormat format = WavFormat::Float32,
              std::string *error = nullptr);

} // namespace clay::sound

#endif // CLAY_SOUND_SOUND_FILES_H
