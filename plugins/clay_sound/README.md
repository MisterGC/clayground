# Clay Sound Plugin

Hybrid synth + sampler + tracker audio plugin for Clayground. One coherent
engine, two wrappers for pre-existing assets (`Sound`, `Music`), and a
small instrument/sequencer layer on top (`SynthInstrument`,
`SampleInstrument`, `SongPlayer`, `SfxPlayer`, `ChipMood`/`MoodPlayer`). Offline render
is first-class and deterministic.

See `docs/docs/manual/dojo.md` for how to hot-reload song files without
resetting the playhead (`.dojoignore`).

## Getting Started

```qml
import Clayground.Sound
```

## Components

### Sound

For short sound effects (fire-and-forget). Supports overlapping playback with
instance pooling for efficiency.

```qml
Sound {
    id: jumpSound
    source: "sounds/jump.wav"
    volume: 0.8
    lazyLoading: false  // preload by default
}

// Usage
onJumped: jumpSound.play()
onReset: jumpSound.stop()  // stops all playing instances
```

### Music

For background music with full playback controls.

```qml
Music {
    id: bgMusic
    source: "music/theme.mp3"
    volume: 0.5
    loop: true
}

// Usage
onGameStarted: bgMusic.play()
onGamePaused: bgMusic.pause()
onGameOver: bgMusic.stop()
```

## Properties

### Sound

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | url | "" | Audio file URL (local or remote) |
| `volume` | real | 1.0 | Volume level (0.0-1.0) |
| `lazyLoading` | bool | false | If true, load on first play() |
| `loaded` | bool | readonly | Whether audio data is loaded |
| `status` | enum | readonly | Null/Loading/Ready/Error |

### Music

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | url | "" | Audio file URL |
| `volume` | real | 1.0 | Volume level (0.0-1.0) |
| `lazyLoading` | bool | false | If true, load on first play() |
| `loaded` | bool | readonly | Whether audio data is loaded |
| `playing` | bool | readonly | Currently playing |
| `paused` | bool | readonly | Currently paused |
| `loop` | bool | false | Loop playback |
| `position` | int | readonly | Current position (ms) |
| `duration` | int | readonly | Total duration (ms) |

### SynthInstrument

Real-time oscillator voice with ADSR, pitch envelope, LFO, a pulse width
for `square` and a resonant filter with its own cutoff envelope. Trigger
notes by MIDI number or Hz. Also bakes to WAV.

```qml
SynthInstrument {
    id: lead
    waveform: "square"      // sine | square | triangle | sawtooth | noise
    pulseWidth: 0.25        // square only, 0.05..0.95; 0.5 = plain square
    attack: 0.005; decay: 0.08; sustain: 0.5; release: 0.15
    // Filter, off by default: none | lowpass | highpass | bandpass
    filterType: "lowpass"; cutoff: 400; resonance: 0.3
    // Cutoff envelope: +3 octaves at its peak, decaying back to 400 Hz
    filterEnvAmount: 3; filterDecay: 0.2; filterSustain: 0
    volume: 0.8
    pan: -0.3               // -1 left .. +1 right; 0 = centred
    bus: "music"            // sfx (default) | music | voice
}
// Fire a note
lead.triggerNote(69, 0.9, 0.25)
// Synth-to-sample bounce
var wavPath = lead.bake(69, 0.4)
```

### SampleInstrument

PCM sample playback with loop points, root note, ADSR on top of samples.

```qml
SampleInstrument {
    id: drum
    source: "kick.wav"
    rootNote: 60
    volume: 0.9
    interpolation: "gaussian"  // nearest | linear (default) | gaussian (soft, SNES-like)
    maxVoices: 4               // a fifth note cuts the oldest; 0 (default) = no cap
}
drum.triggerOneShot(0.8)
```

`maxVoices` exists on `SynthInstrument` too.

### SongPlayer

Plays a `.song.json` against QML instruments resolved by `objectName`.
Supports play/pause/stop/seek/loop and hot-reload without playhead reset.

```qml
SynthInstrument { id: lead; objectName: "demoLead" }
SynthInstrument { id: bass; objectName: "demoBass" }

SongPlayer {
    source: "songs/demo.song.json"
    instruments: [lead, bass]
    loop: true
    onHotReloaded: console.log("song file changed, kept playing")
}
```

Song file format (v1):

```json
{
  "tempo": 110,
  "tracks": {
    "lead": { "instrument": "demoLead" },
    "bass": { "instrument": "demoBass" }
  },
  "patterns": {
    "A": {
      "lead": [
        { "t": 0,   "note": "C5", "dur": 0.5 },
        { "t": 0.5, "note": "E5", "dur": 0.5 }
      ],
      "bass": [{ "t": 0, "note": "C3", "dur": 2.0 }]
    }
  },
  "sections": [ { "pattern": "A", "repeat": 4 } ]
}
```

Notes can be MIDI numbers or scientific pitch strings (`C4`, `F#3`, `Bb5`).
Defaults: `dur=0.5` beats, `vel=0.8`.

`volume` (0..1, default 1) scales every note the player triggers, on
whichever instrument, also while the notes ring: animate it to fade a song.

`renderOffline(seconds)` renders the song on an engine of its own with the
instruments' current patches, the player's `volume` and `loop`: mono
samples at 44.1 kHz, every note on its exact frame (live, a note starts on
the 10 ms tick it falls into). `seconds` 0 renders the song's length.

#### Song v2: the instruments in the file, music that follows the game

A file with `"version": 2` is complete on its own - it defines the
instruments its tracks play - and has the structure adaptive game music
needs. `demo/songs/adaptive.song.json` uses all of it:

```json
{
  "version": 2, "tempo": 120, "beatsPerBar": 4,
  "instruments": {
    "lead": { "source": "triangle", "envelope": { "attack": 10, "release": 120 }, "gain": -10 },
    "bass": { "source": "sawtooth", "filter": { "type": "lowpass", "cutoff": 700 }, "gain": -12 },
    "kick": { "source": "sample", "sample": "kick.wav", "root": "C2", "bus": "music" }
  },
  "tracks":   { "melody": { "instrument": "lead" }, "bass": { "instrument": "bass" } },
  "patterns": { "Explore": { ... }, "Combat": { ... }, "Pickup": { ... } },
  "segments": {
    "explore": { "sections": [ { "pattern": "Explore" } ] },
    "combat":  { "sections": [ { "pattern": "Combat", "repeat": 2 } ], "exits": [4] }
  },
  "start": "explore",
  "layers": { "drive": { "tracks": ["arp", "hat"], "intensity": [0.25, 0.75], "fade": 4 } },
  "transitions": [
    { "from": "explore", "to": "combat", "sync": "bar" },
    { "from": "combat", "to": "explore", "sync": "exit", "stinger": "pickup" }
  ],
  "stingers": { "pickup": { "pattern": "Pickup", "sync": "beat" } }
}
```

- **Instruments** take an effect recipe layer's fields and units (`source`,
  `envelope` in ms, `pitch`, `filter`, `pulseWidth`, `lfo`, `gain` in dB up
  to 0, `pan`) plus `bus` (default `music`) and `maxVoices`, with a recipe
  layer's defaults for what is left out: no attack, decay or release, full
  sustain, 0 dB, centred. A sample
  instrument names its `sample` (a WAV relative to the song file), its
  `root` note, `interpolation` and `loop` (`true` or `{ "start", "end" }`
  as fractions). Every track plays a defined instrument; `instruments` on
  the player is not read.
- **Segments** are the parts the music moves between. A segment plays its
  sections, then `next` (itself by default). A v2 pattern lasts whole bars.
  Without `segments` the sections are one segment, `main`, after which the
  song ends, or starts again with `loop`; such a song needs at least one
  section.
- **Exits** are beats into a segment where a transition synced to `exit`
  may leave it.
- **Layers** are tracks that sound only as loud as the intensity lets them:
  silent at or below the first number, full at or above the second (one
  number: full from there). A change of intensity moves a layer's level
  over `fade` beats; each note plays at the level its start falls on.
- **Transitions** say how the music moves from one segment to another
  (`from` / `to` left out: any), synced to the next `beat`, `bar`, `exit`
  or the segment's `end`, optionally with a stinger where the new segment
  starts. The first that matches wins; without one, the next bar.
- **Stingers** play a pattern once on top of the music, on their sync.

```qml
SongPlayer {
    id: music
    source: "songs/adaptive.song.json"
    state: game.fighting ? "combat" : "explore"   // moves on its transition's sync
    intensity: game.danger                        // 0..1, fades the layers
}
// music.playStinger("pickup")
```

`segment` is the segment playing now, `position` the beats into it and
`totalBeats` its length. Set before `play()`, `state` and `intensity` are
where the song starts. A v2 song's notes are scheduled 0.25 s
(`kScheduleAheadFrames`) ahead of the engine on their exact frames, so a
control reaches the music that much later and its playhead moves while the
sink renders. `renderOffline(seconds, cues)` takes the same path: from the
player's state and intensity, steered by cues such as
`[{ at: 2, state: "combat" }, { at: 3, intensity: 1 }, { at: 4, stinger: "pickup" }]`
(`at` in seconds), it renders the samples live playback renders for the
same controls at the same song frames. A v1 song plays as before.

### SfxPlayer and effect recipes

An effect recipe (`*.sfx.json`) describes a sound effect as a stack of
layers - each one voice with a source, an envelope, a pitch curve, a filter
curve, a start offset, a gain and a pan - in physical units: Hz, ms,
semitones, dB. A variation spec makes every play a little different:

```qml
SfxPlayer {
    id: detent
    source: "sfx/wheel-detent.sfx.json"
}
var seed = detent.play()               // the next variation; returns its seed
detent.play(0.6)                       // the same at velocity 0.6 (all layers)
detent.play(1, 7)                      // a fifth up (all layers, semitones)
detent.playSeed(seed)                  // that variation again
var mono = detent.renderOffline(seed)  // what play() of that seed sounded like
detent.stop()                          // end what it still plays
```

The wheel detent of `demo/sfx/` (lock_picker's, four layers):

```json
{
  "version": 1,
  "name": "wheel-detent",
  "variation": { "seed": 1, "pool": 6 },
  "layers": [
    { "name": "tick", "role": "transient", "source": "noise",
      "length": 6, "gain": -10.46,
      "envelope": { "attack": 0.5, "decay": 9, "sustain": 0, "release": 4 } },
    { "name": "body", "role": "body", "source": "triangle",
      "freq": 783.99, "length": 40, "gain": -10.03,
      "envelope": { "attack": 0.5, "decay": 55, "sustain": 0, "release": 20 },
      "pitch": { "start": 12, "end": 0, "time": 12 },
      "vary": { "detune": [-1, 1] } },
    { "name": "glint", "role": "tail", "source": "sine",
      "freq": 2793.83, "length": 50, "gain": -21.94,
      "envelope": { "attack": 0.5, "decay": 70, "sustain": 0, "release": 30 },
      "vary": { "detune": [-1, 1] } },
    { "name": "weight", "role": "body", "source": "sine",
      "freq": 123.47, "length": 45, "gain": -13,
      "envelope": { "attack": 1, "decay": 55, "sustain": 0, "release": 20 },
      "pitch": { "start": 7, "end": 0, "time": 20 } }
  ]
}
```

Top level: `version` (1), `name`, `variation`, `layers` (required, at least
one). A layer:

| Field | Unit | Default | Meaning |
|-------|------|---------|---------|
| `source` | - | required | `sine`, `square`, `triangle`, `sawtooth`, `noise` or `sample` |
| `name`, `role` | - | - | a label; `role` is `transient`, `body` or `tail` |
| `freq` | Hz, 1..20000 | 440 | pitch of an oscillator layer |
| `detune` | semitones, -48..48 | 0 | shifts `freq`, or a sample's pitch |
| `gain` | dB, -96..12 | 0 | level of the layer |
| `pan` | -1..1 | 0 | added to the player's `pan` |
| `offset` | ms, 0..10000 | 0 | start after `play()` |
| `length` | ms, 0..10000 | required (oscillators) | the gate; the release runs inside it. A sample without one plays to its end |
| `envelope` | `attack`, `decay`, `release` in ms; `sustain` 0..1 | 0, 0, 0; 1 | ADSR; a sample layer takes `attack` and `release` only |
| `pitch` | `start`, `end` in semitones; `time` in ms | 0 | a linear sweep from `start` to `end` over `time` |
| `filter` | `type`; `cutoff` Hz; `resonance` 0..1; `attack`, `decay`, `release` ms; `sustain` 0..1; `amount` octaves | -, 1000, 0, 0, 0, 0, 1, 0 | `lowpass`, `highpass` or `bandpass`, with a cutoff envelope that moves the cutoff by `amount` octaves at its peak |
| `pulseWidth` | 0.05..0.95 | 0.5 | `square` only |
| `lfo` | `target`; `rate` Hz; `depth` semitones (pitch) or 0..1 (volume) | -, 0, 0 | `pitch` or `volume` |
| `sample`, `interpolation` | path; `nearest`, `linear`, `gaussian` | -, `linear` | the WAV of a `sample` layer, relative to the recipe file |
| `vary` | `{"<field>": [min, max]}` | - | per play, `min..max` is added to the field |

`vary` names a numeric field by its path: `detune`, `gain`, `envelope.decay`,
`filter.cutoff`, `pitch.start`, ... Every value a range can reach must be a
valid value of that field. The parser rejects an unknown field by name and
path (`layers[1].envelope: unknown field 'decya'`), and so does a hot reload,
which keeps playing the last good recipe.

Variation: `variation.seed` (default 0) is the base of every variation seed,
and `variation.pool` cycles `play()` through that many variations; without a
pool every `play()` is a new one. The `n`-th `play()` uses
`variationSeed(n)`, and a seed always draws the same values: each varied
field takes `min + (max - min) * u`, with `u` in [0, 1) hashed from the
seed, the layer and the field with integer arithmetic. Noise layers get a
seeded noise sequence the same way.

`play()` and `renderOffline()` schedule the same notes through the same
code, so `renderOffline(seed)` returns the samples `play()` of that seed
sends into its bus - at the player's `volume` and `pan`, as the mono
`(L + R) / 2` downmix, from the first layer's start to the last layer's end.
What the bus adds afterwards (its volume, echo and reverb) is not part of
it. `volume`, `pan` and `bus` work as on the instruments.

All three take a `detune` in semitones after the velocity - `play(velocity,
detune)`, `playSeed(seed, velocity, detune)`, `renderOffline(seed, velocity,
detune)` - which transposes every layer, oscillator and sample alike: the
play renders the samples of the same recipe with every layer's `detune`
raised by that much. An effect a game plays on a scale (rising coins, one
tone per tumbler) is one recipe.

`stop()` ends every voice the player started: a ringing layer runs its own
`envelope.release` from that moment and is freed, a layer whose `offset` has
not come yet does not start. A long recipe - an ambience bed when the level
changes - thus ends within its longest release, and the next `play()` works
as before.

`SfxPlayer` watches its recipe file and hot-reloads it; add `sfx/` (or
`*.sfx.json`) to the sandbox's `.dojoignore`.

### Stereo, pan and buses

The engine mixes in stereo. Every instrument (`SynthInstrument`,
`SampleInstrument`, `Sound`) has a `pan` from -1 (left) to +1 (right) and a
`bus`: `"sfx"` (default), `"music"` or `"voice"`. Centred, the default, plays
the same samples in both channels that the mono engine played; panning turns
the far channel down (at `pan: 0.5` the left plays at half level). The
`SoundMixer` singleton holds one volume per bus, on top of each instrument's
own:

```qml
SoundMixer.musicVolume = 0.4     // every instrument with bus: "music"
SoundMixer.sfxVolume = 1.0
SoundMixer.voiceVolume = 0.8
```

`Music` (the `QMediaPlayer`-based type) does not play on the engine, but it
follows the music bus: it plays at its `volume` times `SoundMixer.musicVolume`.

### Echo and reverb per bus

Every bus has an echo and a small reverb, both off by default; a bus with
neither on sounds exactly as before. The echo is the SNES one: a delay line
whose output runs through an 8-tap FIR filter, is added to the bus and is
fed back into the line. A low-pass FIR makes every repeat darker than the
one before - the warm SNES echo. The reverb is a small Schroeder reverb
(four damped combs and two allpasses per channel).

```qml
SoundMixer.musicEcho.enabled = true
SoundMixer.musicEcho.delay = 120          // ms, 1..1000
SoundMixer.musicEcho.feedback = 0.5       // -1..1, each repeat this times the last
SoundMixer.musicEcho.volume = 0.5         // 0..1, level of the echo on the bus
SoundMixer.musicEcho.fir = [0.25, 0.25, 0.25, 0.25]   // 8 taps, missing ones 0

SoundMixer.sfxReverb.enabled = true
SoundMixer.sfxReverb.roomSize = 0.5       // 0..1, length of the tail
SoundMixer.sfxReverb.damping = 0.5        // 0..1, how fast the highs die
SoundMixer.sfxReverb.volume = 0.3         // 0..1
```

The default taps `[1, 0, 0, 0, 0, 0, 0, 0]` pass the delayed signal as is,
so repeat *n* plays at `volume * feedback^(n-1)`, `n * delay` after the
note. The taps are consecutive samples at the engine's 44.1 kHz (the SNES
ran its FIR at 32 kHz), so a SNES coefficient set filters at somewhat
higher frequencies here. The echo runs before the reverb, and both before
the bus volume. Turning an effect off drops its tail; on again, it starts
from silence. The effects play the same way live and in an offline render.

## The engine without QML

A C++ program links the engine as `Clayground::SoundEngine` - a static
library that needs Qt Core only, no QML, no Multimedia, no audio device -
and includes `clay_sound_engine.h`. A project that builds clayground with
`add_subdirectory(../clayground ...)`, as shapes-and-stone does, gets the
target with it.

```cmake
target_link_libraries(my_renderer PRIVATE Clayground::SoundEngine)
```

```cpp
#include "clay_sound_engine.h"
namespace cs = clay::sound;

cs::RecipeFile detent;                          // the recipe and its samples
cs::loadRecipe("sfx/wheel-detent.sfx.json", &detent);
auto fx = cs::renderRecipe(detent.recipe, detent.samples, seed,
                           1.0f, 1.0f, 0.0f, cs::kSampleRate, false);
cs::writeWav("detent.wav", fx, 1, cs::kSampleRate);

cs::SongModel song;
cs::loadSong("songs/demo.song.json", &song);
cs::SongInstruments inst;                       // by the names the tracks bind
inst["demoLead"].synth.waveform = cs::OscillatorVoice::Waveform::Triangle;
inst["demoBass"].synth.waveform = cs::OscillatorVoice::Waveform::Sawtooth;
auto music = cs::renderSong(song, inst, 0.0, 1.0f, false, cs::kSampleRate, false);
cs::writeWav("song.wav", music, 1, cs::kSampleRate, cs::WavFormat::Pcm16);
```

| Call | Does |
|---|---|
| `loadRecipe(path, &file, &error)` | parses a `*.sfx.json` and decodes its sample layers, each relative to the recipe |
| `loadSong(path, &model, &error)` | parses a `.song.json`; a v2 song's sample instruments get their WAVs decoded, each relative to the song |
| `renderRecipe(recipe, samples, seed, velocity, gain, pan, rate, stereo, seconds, detune)` | the samples `SfxPlayer.renderOffline(seed, velocity, detune)` returns at that `volume` and `pan`; `seconds` 0 = until the last layer ends, `detune` 0 = as written |
| `renderSong(model, instruments, seconds, volume, loop, rate, stereo)` | the samples `SongPlayer.renderOffline(seconds)` returns; `seconds` 0 = the song's length |
| `renderSong(model, performance, seconds, volume, loop, rate, stereo)` | a v2 song on its own instruments, from `performance.start` at `performance.intensity`, each of `performance.cues` (state, intensity or stinger) at its song frame: what live playback renders for the same controls; `seconds` 0 = one pass of the start segment |
| `writeWav(path, samples, channels, rate, format, &error)` | 32-bit float (default, the samples exactly) or 16-bit wav; stereo samples interleaved |

A v1 song names its instruments but does not define them, so the program
gives each name an `InstrumentSpec`: the patch of a `SynthInstrument`
(`synth`, an `OscillatorVoice::Patch`) or the sample, root note and patch
of a `SampleInstrument`, with `gain` (the QML `volume`), `pan`, `bus` and
`maxVoices`. The same seed or the same song and instruments render the same
samples as the QML players on the same machine - `tst_clay_sound_outside`
compares the two sample for sample. A v2 song defines its instruments, so it
needs no `SongInstruments`; `SongSequencer` hands out its notes on frames
for a program that schedules them itself. As in the QML offline renders, the bus
volume, echo and reverb are not applied.

## Platform Support

- **WASM**: full support — the same QAudioSink-driven engine as desktop,
  through Qt Multimedia's emscripten backend. `Music` goes its own way
  there, see "`Music` on WASM" below.
- **Desktop/Mobile**: Full support — all types above work end-to-end.

### `Music` on WASM: it plays, and reports almost nothing

On the web a `Music` track **plays**: the bytes are fetched, written to the
browser's in-memory filesystem and handed to an HTML `<audio>` element.
Qt's WebAssembly media backend only ever plays what it can open as a local
file, so a `qrc:` or `http(s)` source has to take that detour — handing it
the URL directly routes it to a video output that does not exist and takes
the whole page down (#261).

What that costs, on the web and only there (measured with Qt 6.10.1 in
Chrome):

- **A user gesture is required first.** A `play()` before the first click or
  key press is refused by the browser, and Qt does not catch that refusal —
  it surfaces as an uncaught `play() failed because the user didn't
  interact with the document first` in the console.
- **`.mp3`, not `.wav`.** The backend labels a staged `.wav` blob
  `audio/vnd.wave`, a type Chrome declines, and the track stays silent.
- `position` and `duration` stay `0`
- `loop` has no effect — the track plays once, then `finished` fires
- `status` does reach `Ready`

A background loop on the web therefore needs the `finished` signal or a
`Sound` re-triggered by a `Timer` at the clip length (see #216).

Two of those points were re-measured on Qt 6.11.1 and did not move (#264):
`position` stays `0` through a 30 s track, and `status` reaches Ready. The
user-gesture rule, the `.wav` MIME refusal and `loop` were not re-tested on
6.11.1. Which Qt the web runtime is built with, and why, is pinned and
argued in `.github/workflows/main.yml`.

## Technical Notes

- Audio is fully preloaded before playback (no streaming)
- **WASM**: Web Audio API requires user gesture to start AudioContext
- **WASM**: Remote URLs must be CORS-enabled
- **Desktop**: Uses `QAudioSink` for all in-engine types, `QMediaPlayer` for `Music`
- **Hot-reload**: `SongPlayer` and `SfxPlayer` watch their source file; drop
  a `.dojoignore` (`songs/`, `sfx/` or `*.song.json`) next to your
  `Sandbox.qml` to prevent the dojo from reloading the whole scene on edits
