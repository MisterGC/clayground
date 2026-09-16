// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// primeAudioDevices() — one-time workaround for a self-deadlock in Qt's
// WebAssembly audio-device backend. Call it before the first use of
// QMediaDevices, QAudioSink, QAudioOutput or QMediaPlayer in a process.
// No-op on every platform except WASM.

#ifndef CLAY_SOUND_AUDIO_DEVICES_H
#define CLAY_SOUND_AUDIO_DEVICES_H

namespace clay::sound {

// On Qt 6.11 for WebAssembly the first audio-device query hangs the
// browser's main thread for good (#216): QPlatformAudioDevices::audioOutputs()
// takes the write lock of its QCachedValue and calls findAudioOutputs(),
// which constructs the QWasmMediaDevices singleton; that constructor calls
// onAudioOutputsChanged(), which re-enters the same non-recursive
// QReadWriteLock. Nothing ever releases it, so the tab freezes with no
// error - both `Music` (QAudioOutput in its constructor) and the first
// Sound.play() (QMediaDevices::defaultAudioOutput() in AudioOutput::start())
// died there.
//
// Connecting to QMediaDevices::audioOutputsChanged builds QWasmMediaDevices
// through QWasmAudioDevices::connectNotify() instead - outside the cache
// lock. The later device query then finds the singleton already initialised
// and never re-enters. Idempotent; safe to call from any of the entry points.
void primeAudioDevices();

} // namespace clay::sound

#endif // CLAY_SOUND_AUDIO_DEVICES_H
