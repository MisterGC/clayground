// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SoftSynth — Lightweight software synthesizer for ChipMood desktop playback
// Generates audio samples using basic oscillators, ADSR envelopes, filters, and delay.

#ifndef SOFTSYNTH_H
#define SOFTSYNTH_H

#ifndef __EMSCRIPTEN__

#include <QObject>
#include <QAudioSink>
#include <QAudioFormat>
#include <QIODevice>
#include <QTimer>
#include <vector>
#include <cmath>
#include <functional>

class QAudioSink;

struct Voice {
    enum Waveform { Sine, Square, Triangle, Sawtooth, Noise };
    Waveform waveform = Sine;
    double frequency = 440.0;
    double gain = 0.5;
    double phase = 0.0;

    // ADSR envelope
    double attack = 0.01;   // seconds
    double decay = 0.1;
    double sustain = 0.6;   // level (0-1)
    double release = 0.3;

    double startTime = 0.0;
    double duration = 0.5;  // total note duration
    bool active = false;

    // For noise generation
    unsigned int noiseSeed = 12345;
};

struct NoteEvent {
    double time;        // seconds from start
    double frequency;
    double duration;
    double gain;
    Voice::Waveform waveform;
};

class SoftSynth : public QObject
{
    Q_OBJECT

public:
    explicit SoftSynth(QObject *parent = nullptr);
    ~SoftSynth();

    void setVolume(double volume);
    void setFilterCutoff(double hz);     // lowpass cutoff
    void setEchoMix(double mix);         // 0-1 echo wet level
    void setEchoDelay(double seconds);   // echo delay time

    // Schedule a note to play at a specific time (relative to playback start)
    void scheduleNote(const NoteEvent &note);

    // Load an entire composition (list of note events)
    void loadComposition(const std::vector<NoteEvent> &notes, double loopDuration);

    void play();
    void stop();
    void pause();
    void resume();
    bool isPlaying() const { return playing_; }

    // Current playback position in seconds
    double position() const;

private slots:
    void generateSamples();

private:
    static constexpr int SAMPLE_RATE = 44100;
    static constexpr int CHANNELS = 1;
    static constexpr int BUFFER_MS = 20;
    static constexpr int BUFFER_SAMPLES = SAMPLE_RATE * BUFFER_MS / 1000;
    static constexpr int MAX_VOICES = 32;

    double generateWaveform(Voice &voice);
    double applyEnvelope(const Voice &voice, double currentTime);
    void processFilter(float *buffer, int count);
    void processDelay(float *buffer, int count);
    Voice *allocateVoice();
    void activateScheduledNotes();

    // Audio output
    QAudioSink *audioSink_ = nullptr;
    QIODevice *audioDevice_ = nullptr;
    QTimer renderTimer_;

    // Synth state
    Voice voices_[MAX_VOICES];
    double currentTime_ = 0.0;
    double volume_ = 0.7;
    bool playing_ = false;
    bool paused_ = false;

    // Lowpass filter state (simple one-pole)
    double filterCutoff_ = 8000.0;
    double filterState_ = 0.0;

    // Echo delay line
    std::vector<float> delayBuffer_;
    int delayWritePos_ = 0;
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
    void applyPendingComposition();
};

#endif // !__EMSCRIPTEN__
#endif // SOFTSYNTH_H
