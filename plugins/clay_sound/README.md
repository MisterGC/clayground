# Clay Sound Plugin

Audio playback plugin for Clayground games. Currently supports WASM builds only,
using the Web Audio API via Emscripten bindings.

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

## Platform Support

- **WASM**: Full support via Web Audio API (Emscripten)
- **Desktop/Mobile**: Full support via Qt Multimedia

## Technical Notes

- Audio is fully preloaded before playback (no streaming)
- **WASM**: Web Audio API requires user gesture to start AudioContext
- **WASM**: Remote URLs must be CORS-enabled
- **Desktop**: Uses `QSoundEffect` for Sound (low-latency) and `QMediaPlayer` for Music
