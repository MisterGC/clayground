# Clay Sound Plugin

Hybrid synth + sampler + tracker audio plugin for Clayground. One coherent
engine, two wrappers for pre-existing assets (`Sound`, `Music`), and a
small instrument/sequencer layer on top (`SynthInstrument`,
`SampleInstrument`, `SongPlayer`, `ChipMood`/`MoodPlayer`). Offline render
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

Real-time oscillator voice with ADSR, pitch envelope, LFO. Trigger notes
by MIDI number or Hz. Also bakes to WAV.

```qml
SynthInstrument {
    id: lead
    waveform: "square"      // sine | square | triangle | sawtooth | noise
    attack: 0.005; decay: 0.08; sustain: 0.5; release: 0.15
    volume: 0.8
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
}
drum.triggerOneShot(0.8)
```

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
- **Hot-reload**: `SongPlayer` watches its source file; drop a `.dojoignore`
  (`songs/` or `*.song.json`) next to your `Sandbox.qml` to prevent the
  dojo from reloading the whole scene on song edits
