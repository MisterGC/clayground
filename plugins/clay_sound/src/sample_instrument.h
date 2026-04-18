// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SampleInstrument — public QML-facing PCM sample player.
// Mirrors SynthInstrument: owns an Engine + SamplerInstrument (core)
// + QAudioSink. WAV loaded on source change; one-shot triggers via
// trigger()/triggerNote()/triggerOneShot().

#ifndef SAMPLE_INSTRUMENT_H
#define SAMPLE_INSTRUMENT_H

#ifndef __EMSCRIPTEN__

#include "engine/engine.h"
#include "engine/sample_voice.h"

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVector>

#include <memory>

class QAudioSink;
class QIODevice;

namespace clay::sound {
struct PcmBuffer;
class  SamplerInstrument;
}

class SampleInstrument : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl    source     READ source     WRITE setSource     NOTIFY sourceChanged)
    Q_PROPERTY(int     rootNote   READ rootNote   WRITE setRootNote   NOTIFY rootNoteChanged)
    Q_PROPERTY(bool    looping    READ looping    WRITE setLooping    NOTIFY loopingChanged)
    Q_PROPERTY(qreal   loopStart  READ loopStart  WRITE setLoopStart  NOTIFY loopStartChanged)
    Q_PROPERTY(qreal   loopEnd    READ loopEnd    WRITE setLoopEnd    NOTIFY loopEndChanged)
    Q_PROPERTY(qreal   attack     READ attack     WRITE setAttack     NOTIFY attackChanged)
    Q_PROPERTY(qreal   release    READ release    WRITE setRelease    NOTIFY releaseChanged)
    Q_PROPERTY(qreal   volume     READ volume     WRITE setVolume     NOTIFY volumeChanged)
    Q_PROPERTY(bool    loaded     READ loaded     NOTIFY loadedChanged)
    Q_PROPERTY(int     activeVoices READ activeVoices NOTIFY activeVoicesChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit SampleInstrument(QObject *parent = nullptr);
    ~SampleInstrument() override;

    QUrl source() const { return source_; }
    void setSource(const QUrl &url);

    int  rootNote() const { return rootMidiNote_; }
    void setRootNote(int n);

    bool  looping() const { return patch_.looping; }
    void  setLooping(bool v);
    qreal loopStart() const { return patch_.loopStartFrac; }
    void  setLoopStart(qreal v);
    qreal loopEnd() const   { return patch_.loopEndFrac; }
    void  setLoopEnd(qreal v);
    qreal attack() const  { return patch_.attack; }
    void  setAttack(qreal v);
    qreal release() const { return patch_.release; }
    void  setRelease(qreal v);

    qreal volume() const { return volume_; }
    void  setVolume(qreal v);

    bool   loaded() const { return loaded_; }
    int    activeVoices() const;
    QString errorString() const { return error_; }

    // Trigger by frequency (Hz); dur 0 = play until sample / loop ends.
    Q_INVOKABLE bool trigger(qreal freqHz,
                             qreal velocity = 1.0,
                             qreal durationSeconds = 0.0);

    // Trigger by MIDI note number.
    Q_INVOKABLE bool triggerNote(int midiNote,
                                 qreal velocity = 1.0,
                                 qreal durationSeconds = 0.0);

    // Trigger at root pitch; used by Sound's play() path.
    Q_INVOKABLE bool triggerOneShot(qreal velocity = 1.0);

    // Stop all currently playing voices at their next render step.
    Q_INVOKABLE void stopAll();

    // Offline mono render of the engine state for `durationSeconds`.
    Q_INVOKABLE QVector<float> renderOffline(qreal durationSeconds);

signals:
    void sourceChanged();
    void rootNoteChanged();
    void loopingChanged();
    void loopStartChanged();
    void loopEndChanged();
    void attackChanged();
    void releaseChanged();
    void volumeChanged();
    void loadedChanged();
    void activeVoicesChanged();
    void errorStringChanged();
    // Emitted once all voices from a trigger() call have ended (used
    // by Sound's `finished` facade).
    void playbackFinished();

private slots:
    void pullBuffer();

private:
    static constexpr int SAMPLE_RATE = 44100;
    static constexpr int BUFFER_MS   = 20;

    void loadSource();
    void applyPatchToCore();
    void ensureSinkRunning();
    void stopSink();

    clay::sound::Engine engine_{SAMPLE_RATE};
    clay::sound::SamplerInstrument *core_ = nullptr; // owned by engine
    int  coreId_ = -1;

    std::shared_ptr<const clay::sound::PcmBuffer> buffer_;
    clay::sound::SampleVoice::Patch patch_{};

    QUrl    source_;
    int     rootMidiNote_ = 60;
    QString error_;
    bool    loaded_ = false;

    QAudioSink *sink_   = nullptr;
    QIODevice  *device_ = nullptr;
    QTimer      pullTimer_;
    bool        sinkRunning_ = false;

    qreal volume_     = 1.0;
    int   lastActive_ = 0;
};

#endif // !__EMSCRIPTEN__
#endif // SAMPLE_INSTRUMENT_H
