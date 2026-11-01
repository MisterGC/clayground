// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Renders the plugin demo's effect recipe and song to wav without QML:
//
//   clay_sound_render_demo <out-dir> <recipe.sfx.json> <song.song.json> <seed>...
//
// writes <out-dir>/recipe-<seed>.wav for every seed and <out-dir>/song.wav,
// mono 32-bit float at 44.1 kHz. The song's two instruments are the
// demo's SynthInstruments demoLead and demoBass at a volume of 0.8
// (demo/Sandbox.qml), spelled out as InstrumentSpecs.
// tst_clay_sound_outside compares the files with SfxPlayer's and
// SongPlayer's renderOffline().

#include "clay_sound_engine.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <string>
#include <vector>

namespace cs = clay::sound;

static int failed(const std::string &what, const std::string &why)
{
    std::fprintf(stderr, "clay_sound_render_demo: %s: %s\n", what.c_str(), why.c_str());
    return 1;
}

static bool write(const std::string &path, const std::vector<float> &mono, std::string *why)
{
    if (mono.empty()) { *why = "rendered no samples"; return false; }
    if (!cs::writeWav(path, mono, 1, cs::kSampleRate, cs::WavFormat::Float32, why)) return false;
    std::printf("%s: %zu frames\n", path.c_str(), mono.size());
    return true;
}

int main(int argc, char **argv)
{
    if (argc < 5) {
        std::fprintf(stderr, "usage: %s <out-dir> <recipe.sfx.json> <song.song.json> <seed>...\n", argv[0]);
        return 2;
    }
    const std::string outDir = argv[1];
    std::string why;
    std::error_code ec;
    std::filesystem::create_directories(outDir, ec);
    if (ec) return failed(outDir, ec.message());

    cs::RecipeFile recipe;
    if (!cs::loadRecipe(argv[2], &recipe, &why)) return failed(argv[2], why);
    for (int i = 4; i < argc; ++i) {
        const uint32_t seed = static_cast<uint32_t>(std::strtoul(argv[i], nullptr, 10));
        const auto mono = cs::renderRecipe(recipe.recipe, recipe.samples, seed,
                                           1.0f, 1.0f, 0.0f, cs::kSampleRate, false);
        const std::string path = outDir + "/recipe-" + argv[i] + ".wav";
        if (!write(path, mono, &why)) return failed(path, why);
    }

    cs::SongModel song;
    if (!cs::loadSong(argv[3], &song, &why)) return failed(argv[3], why);

    using W = cs::OscillatorVoice::Waveform;
    cs::InstrumentSpec lead;
    lead.synth.waveform = W::Triangle;
    lead.synth.attack = 0.005;
    lead.synth.decay = 0.08;
    lead.synth.sustain = 0.5;
    lead.synth.release = 0.15;
    lead.gain = 0.8f;
    cs::InstrumentSpec bass;
    bass.synth.waveform = W::Sawtooth;
    bass.synth.attack = 0.01;
    bass.synth.decay = 0.1;
    bass.synth.sustain = 0.6;
    bass.synth.release = 0.2;
    bass.gain = static_cast<float>(0.8 * 0.6);     // as QML computes `volume: 0.8 * 0.6`
    const cs::SongInstruments instruments{ { "demoLead", lead }, { "demoBass", bass } };

    const auto mono = cs::renderSong(song, instruments, 0.0, 1.0f, false, cs::kSampleRate, false);
    const std::string path = outDir + "/song.wav";
    if (!write(path, mono, &why)) return failed(path, why);
    return 0;
}
