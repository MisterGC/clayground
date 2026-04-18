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

- **WASM**: `Sound` / `Music` today; full hybrid engine coming in the next
  stage (AudioWorklet backend).
- **Desktop/Mobile**: Full support — all types above work end-to-end.

## Technical Notes

- Audio is fully preloaded before playback (no streaming)
- **WASM**: Web Audio API requires user gesture to start AudioContext
- **WASM**: Remote URLs must be CORS-enabled
- **Desktop**: Uses `QAudioSink` for all in-engine types, `QMediaPlayer` for `Music`
- **Hot-reload**: `SongPlayer` watches its source file; drop a `.dojoignore`
  (`songs/` or `*.song.json`) next to your `Sandbox.qml` to prevent the
  dojo from reloading the whole scene on song edits
