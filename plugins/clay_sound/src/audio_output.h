// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// AudioOutput — process-wide owner of the single QAudioSink and the
// shared clay::sound::Engine. Every QML-facing instrument (SynthInstrument,
// SampleInstrument) registers a clay::sound::IInstrument with this
// singleton; the singleton owns the sink and the pull-timer, and on each
// pull renders the engine (which mixes all registered instruments'
// voices) into the sink.
//
// On desktop this just removes per-instrument duplication. On WASM it is
// load-bearing: Qt's WebAudio backend effectively allows only one active
// QAudioSink per page, so per-instrument sinks fail to open with
// "Invalid Operation" the moment a second instrument is alive. A single
// shared sink avoids that limit.
//
// User-gesture gating: in WASM the AudioContext is created suspended
// until a user-initiated event resumes it. registerInstrument() does
// NOT start the sink; the sink is started lazily on the first triggered
// note (which itself is almost always the result of a user click or key
// press). QML can also call start() explicitly from a button handler if
// it wants the sink open before the first note.
//
// start() only reports itself running once a sink actually opened, and
// tries every output device for that: a sink that failed to open still
// accepts writes and drops them, so trusting the default device silenced
// whole sessions on the web (#262).
//
// The sink is stereo. A device that reports it cannot take two channels
// gets the engine's mono downmix instead, so it still plays everything.

#ifndef CLAY_SOUND_AUDIO_OUTPUT_H
#define CLAY_SOUND_AUDIO_OUTPUT_H

#include "engine/engine.h"

#include <QAudioDevice>
#include <QElapsedTimer>
#include <QObject>
#include <QString>
#include <QTimer>

#include <memory>

class QAudioSink;
class QIODevice;

namespace clay::sound {

class AudioOutput : public QObject
{
    Q_OBJECT
public:
    static AudioOutput& instance();

    // Register an IInstrument with the shared engine. Takes ownership.
    // Returns the engine instrument id; the caller can keep a non-owning
    // pointer to the instrument via engine().instrumentAt(id) if it needs
    // to call type-specific methods (e.g. pushPatch).
    // Does NOT start the audio sink — that happens lazily on first
    // trigger or explicit start().
    int registerInstrument(std::unique_ptr<IInstrument> inst);

    // Drop an instrument and any of its still-active voices. Idempotent.
    void unregisterInstrument(int id);

    // Direct access to the shared engine. Used by instrument adapters
    // to schedule events and push patches.
    Engine& engine() { return engine_; }
    const Engine& engine() const { return engine_; }

    // The gain stage (Engine::addGainStage) that notes triggered right
    // now play through, -1 for none. SongPlayer sets it around each
    // triggerNote() it sends and the instruments stamp it on the note,
    // so a song's volume reaches its notes whatever plays them - also
    // through a QML object that wraps an instrument. GUI thread only.
    int triggerGainStage() const { return triggerGainStage_; }
    class TriggerGainStage
    {
    public:
        explicit TriggerGainStage(int id) : prev_(instance().triggerGainStage_)
        { instance().triggerGainStage_ = id; }
        ~TriggerGainStage() { instance().triggerGainStage_ = prev_; }
        TriggerGainStage(const TriggerGainStage&) = delete;
        TriggerGainStage& operator=(const TriggerGainStage&) = delete;
    private:
        int prev_;
    };

    // The QML names of the buses: "sfx", "music", "voice". busFromName
    // returns false and leaves `bus` alone for any other name.
    static bool busFromName(const QString& name, Bus& bus);
    static QString busName(Bus bus);

    int sampleRate() const { return engine_.sampleRate(); }
    bool isRunning() const { return sinkRunning_; }

    // Open the audio sink and start the pull timer. Safe to call from a
    // user-gesture handler in QML (e.g. a Play button) so subsequent
    // triggers play immediately. Idempotent.
    Q_INVOKABLE void start();

    // Set a bus volume, clamped to [0, 1], and emit busGainChanged when
    // it moved. The way QML changes a bus (SoundMixer), so a player that
    // does not play on the engine (Music) can follow the music bus.
    void setBusGain(Bus bus, float g);

    // Close the sink and stop the pull timer. Active scheduled notes
    // are not cancelled; calling start() again resumes mixing.
    Q_INVOKABLE void stop();

signals:
    // Emitted at the end of every pull cycle. Used by instrument
    // adapters to update QML-visible derived state (activeVoices,
    // playbackFinished) without each owning its own timer.
    void afterPull();

    // A bus volume changed through setBusGain().
    void busGainChanged(clay::sound::Bus bus);

private:
    AudioOutput();
    ~AudioOutput() override;
    AudioOutput(const AudioOutput&) = delete;
    AudioOutput& operator=(const AudioOutput&) = delete;

    void onPull();

    // Open the sink on one specific device. Returns false (and leaves no
    // sink behind) when the device cannot be opened.
    bool openSink(const QAudioDevice& device);

    static constexpr int SAMPLE_RATE = 44100;
    static constexpr int BUFFER_MS   = 20;
    // Shortest gap between a failed attempt to open the sink and the next.
    static constexpr int RETRY_MIN_MS = 500;

    Engine      engine_{SAMPLE_RATE};
    QAudioSink* sink_     = nullptr;
    QIODevice*  device_   = nullptr;
    int         channels_ = 2;      // of the open sink: 2, or 1 on a mono-only device
    int         triggerGainStage_ = -1;
    QTimer      pullTimer_;
    bool        sinkRunning_ = false;
    QElapsedTimer sinceFailedOpen_;
};

} // namespace clay::sound

#endif // CLAY_SOUND_AUDIO_OUTPUT_H
