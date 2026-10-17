// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The clay_sound engine for a C++ program without QML: link
// Clayground::SoundEngine (Qt Core only) and include this header.
//
//   clay::sound::RecipeFile detent;
//   clay::sound::loadRecipe("wheel-detent.sfx.json", &detent);
//   auto mono = clay::sound::renderRecipe(detent.recipe, detent.samples,
//                                         seed, 1.0f, 1.0f, 0.0f,
//                                         clay::sound::kSampleRate, false);
//   clay::sound::writeWav("detent.wav", mono, 1, clay::sound::kSampleRate);
//
// A song binds its tracks to instruments by name; without QML each is
// an InstrumentSpec (a SynthInstrument's patch, volume, pan, ...):
//
//   clay::sound::SongModel song;
//   clay::sound::loadSong("demo.song.json", &song);
//   clay::sound::SongInstruments inst;
//   inst["demoLead"].synth.waveform = clay::sound::OscillatorVoice::Waveform::Triangle;
//   auto pcm = clay::sound::renderSong(song, inst, 10.0, 1.0f, false,
//                                      clay::sound::kSampleRate, false);
//
// A render here is the one SfxPlayer.renderOffline(seed) and
// SongPlayer.renderOffline(seconds) return for the same input.

#ifndef CLAY_SOUND_ENGINE_API_H
#define CLAY_SOUND_ENGINE_API_H

#include "engine/engine.h"
#include "engine/instrument_spec.h"
#include "offline/sound_files.h"
#include "sfx/sfx_render.h"
#include "song/song_render.h"

#endif // CLAY_SOUND_ENGINE_API_H
