// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SoftSynth — lightweight software synthesizer used by ChipMood.
// As of Stage 1, the per-note DSP lives in clay::sound::OscillatorVoice
// under src/engine/; SoftSynth is now the timing/mixer/filter/delay host
// that drives those voices. The public API is unchanged.

#ifndef SOFTSYNTH_H
#define SOFTSYNTH_H

#include "voice_waveform.h"

#include <QObject>
#include <QAudioFormat>
#include <QIODevice>
#include <QTimer>
#include <memory>
#include <vector>

class QAudioSink;

// Per-note input format. Time/duration in seconds.
struct NoteEvent
{
    double time;
    double frequency;
    double duration;
    double gain;
    Voice::Waveform waveform;

    // Per-note ADSR (patch-driven)
    double attack  = 0.01;
    double decay   = 0.1;
    double sustain = 0.6;
    double release = 0.3;

    // Per-note pitch envelope
    double pitchStart = 0.0;
    double pitchEnd   = 0.0;
    double pitchTime  = 0.0;

    // Per-note LFO
    double lfoRate   = 0.0;
    double lfoDepth  = 0.0;
    int    lfoTarget = 0;
};

namespace clay::sound { class OscillatorVoice; struct NoteEvent; }

class SoftSynth : public QObject
{
    Q_OBJECT

public:
    explicit SoftSynth(QObject *parent = nullptr);
    ~SoftSynth();

    void setVolume(double volume);
    void setFilterCutoff(double hz);
    void setEchoMix(double mix);
    void setEchoDelay(double seconds);

    void scheduleNote(const NoteEvent &note);
    void loadComposition(const std::vector<NoteEvent> &notes, double loopDuration);

    void play();
    void stop();
    void pause();
    void resume();
    bool isPlaying() const { return playing_; }

    double position() const;
    double loopDuration() const { return loopDuration_; }
    const std::vector<NoteEvent> &compositionData() const { return composition_; }

    void renderOffline(float *buffer, int sampleCount);

private slots:
    void generateSamples();

private:
    static constexpr int SAMPLE_RATE = 44100;
    static constexpr int CHANNELS = 1;
    static constexpr int BUFFER_MS = 20;
    static constexpr int BUFFER_SAMPLES = SAMPLE_RATE * BUFFER_MS / 1000;
    static constexpr int MAX_VOICES = 32;

    void activateScheduledNotes(int64_t currentFrame);
    void pruneFinishedVoices(int64_t currentFrame);
    void mixActiveVoices(float *out, int frames, int64_t startFrame);
    void processFilter(float *buffer, int count);
    void processDelay(float *buffer, int count);
    void applyPendingComposition(int64_t currentFrame);

    // Audio output
    QAudioSink *audioSink_ = nullptr;
    QIODevice *audioDevice_ = nullptr;
    QTimer renderTimer_;

    // Synth state
    std::vector<std::unique_ptr<clay::sound::OscillatorVoice>> voices_;
    int64_t currentFrame_ = 0;
    double  volume_ = 0.7;
    bool    playing_ = false;
    bool    paused_ = false;

    // Lowpass filter state (simple one-pole)
    double filterCutoff_ = 8000.0;
    double filterState_ = 0.0;

    // Echo delay line
    std::vector<float> delayBuffer_;
    int    delayWritePos_ = 0;
    double echoDelay_ = 0.15;
    double echoMix_ = 0.3;

    // Composition / scheduling
    std::vector<NoteEvent> composition_;
    double loopDuration_ = 0.0;
    size_t nextNoteIndex_ = 0;

    // Crossfade on composition swap
    enum FadeState { FadeNone, FadingOut, FadingIn };
    static constexpr double FADE_DURATION = 0.15; // 150ms
    FadeState fadeState_ = FadeNone;
    double fadeProgress_ = 0.0;
    std::vector<NoteEvent> pendingComposition_;
    double pendingLoopDuration_ = 0.0;
};

#endif // SOFTSYNTH_H
