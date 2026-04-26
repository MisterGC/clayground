// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SynthInstrument — public QML-facing oscillator instrument.
// Registers a clay::sound::OscillatorInstrument with the shared
// clay::sound::AudioOutput singleton, exposes a patch via QProperties,
// and fires one-shot notes via trigger()/triggerNote(). Used for SFX
// (jumps, pickups, explosions) and simple procedural music beds.
//
// Multiple SynthInstruments coexist by sharing the same Engine + sink;
// each is identified by an instrument id and its voices are mixed
// together at the engine level scaled by per-instrument gain.

#ifndef SYNTH_INSTRUMENT_H
#define SYNTH_INSTRUMENT_H

#include "engine/oscillator_voice.h"

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVector>

namespace clay::sound { class OscillatorInstrument; }

class SynthInstrument : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString waveform    READ waveform    WRITE setWaveform    NOTIFY waveformChanged)
    Q_PROPERTY(qreal   attack      READ attack      WRITE setAttack      NOTIFY attackChanged)
    Q_PROPERTY(qreal   decay       READ decay       WRITE setDecay       NOTIFY decayChanged)
    Q_PROPERTY(qreal   sustain     READ sustain     WRITE setSustain     NOTIFY sustainChanged)
    Q_PROPERTY(qreal   release     READ release     WRITE setRelease     NOTIFY releaseChanged)
    Q_PROPERTY(qreal   pitchStart  READ pitchStart  WRITE setPitchStart  NOTIFY pitchStartChanged)
    Q_PROPERTY(qreal   pitchEnd    READ pitchEnd    WRITE setPitchEnd    NOTIFY pitchEndChanged)
    Q_PROPERTY(qreal   pitchTime   READ pitchTime   WRITE setPitchTime   NOTIFY pitchTimeChanged)
    Q_PROPERTY(qreal   lfoRate     READ lfoRate     WRITE setLfoRate     NOTIFY lfoRateChanged)
    Q_PROPERTY(qreal   lfoDepth    READ lfoDepth    WRITE setLfoDepth    NOTIFY lfoDepthChanged)
    Q_PROPERTY(QString lfoTarget   READ lfoTarget   WRITE setLfoTarget   NOTIFY lfoTargetChanged)
    Q_PROPERTY(qreal   volume      READ volume      WRITE setVolume      NOTIFY volumeChanged)

    Q_PROPERTY(int activeVoices READ activeVoices NOTIFY activeVoicesChanged)

public:
    explicit SynthInstrument(QObject *parent = nullptr);
    ~SynthInstrument() override;

    QString waveform() const { return waveformName_; }
    void setWaveform(const QString &w);
    qreal attack() const  { return patch_.attack; }
    void  setAttack(qreal v);
    qreal decay() const   { return patch_.decay; }
    void  setDecay(qreal v);
    qreal sustain() const { return patch_.sustain; }
    void  setSustain(qreal v);
    qreal release() const { return patch_.release; }
    void  setRelease(qreal v);
    qreal pitchStart() const { return patch_.pitchStart; }
    void  setPitchStart(qreal v);
    qreal pitchEnd() const   { return patch_.pitchEnd; }
    void  setPitchEnd(qreal v);
    qreal pitchTime() const  { return patch_.pitchTime; }
    void  setPitchTime(qreal v);
    qreal lfoRate() const  { return patch_.lfoRate; }
    void  setLfoRate(qreal v);
    qreal lfoDepth() const { return patch_.lfoDepth; }
    void  setLfoDepth(qreal v);
    QString lfoTarget() const { return lfoTargetName_; }
    void    setLfoTarget(const QString &t);

    qreal volume() const { return volume_; }
    void  setVolume(qreal v);

    int activeVoices() const;

    // Fire-and-forget oneshot. freq in Hz, velocity 0..1,
    // duration in seconds. Returns true on success.
    Q_INVOKABLE bool trigger(qreal freqHz,
                             qreal velocity = 1.0,
                             qreal durationSeconds = 0.2);

    // Convenience: trigger by MIDI note number (A4 = 69 = 440 Hz).
    Q_INVOKABLE bool triggerNote(int midiNote,
                                 qreal velocity = 1.0,
                                 qreal durationSeconds = 0.2);

    // Offline render of `durationSeconds` seconds of audio from the
    // current engine state. Produces a mono float buffer at the engine
    // sample rate. Destructive: advances engine time and consumes
    // scheduled events. Used for tests and (later) synth-to-sample
    // baking.
    Q_INVOKABLE QVector<float> renderOffline(qreal durationSeconds);

    // Synth-to-sample bounce. Renders one note with the current patch
    // into a WAV under QStandardPaths::CacheLocation/clay_sound and
    // returns its absolute path. Repeated bakes of the same patch+note
    // produce the same filename so the cache stays bounded. Returns an
    // empty string on failure (e.g. cache dir uncreatable).
    Q_INVOKABLE QString bake(int midiNote,
                             qreal durationSeconds = 1.0,
                             qreal velocity = 1.0);

    // Renders one note through a *scratch* engine with the current
    // patch and returns the resulting mono float buffer. Does NOT
    // touch the live audio sink — safe to call while the synth is
    // actively playing. Used by the Studio UI to draw per-slot
    // oscilloscope previews.
    Q_INVOKABLE QVector<float> renderPatchPreview(int midiNote = 60,
                                                  qreal durationSeconds = 0.25,
                                                  qreal velocity = 1.0);

signals:
    void waveformChanged();
    void attackChanged();
    void decayChanged();
    void sustainChanged();
    void releaseChanged();
    void pitchStartChanged();
    void pitchEndChanged();
    void pitchTimeChanged();
    void lfoRateChanged();
    void lfoDepthChanged();
    void lfoTargetChanged();
    void volumeChanged();
    void activeVoicesChanged();

private slots:
    void onAfterPull();

private:
    static constexpr int SAMPLE_RATE = 44100;

    // Render one note on a scratch engine using the current patch.
    // Returns a vector of `frames` mono samples (post-volume) so UI
    // previews and bakes share a single code path.
    std::vector<float> renderScratch(int midiNote,
                                     qreal durationSeconds,
                                     qreal velocity) const;

    // Raw ptr to the OscillatorInstrument we registered with the
    // shared AudioOutput's engine. Owned by the engine; not deleted
    // here.
    clay::sound::OscillatorInstrument *oscInst_ = nullptr;
    int oscInstId_ = -1;

    // Live patch (stamped onto each triggered voice via the engine's
    // per-event patch queue).
    clay::sound::OscillatorVoice::Patch patch_{};
    QString waveformName_  = "sine";
    QString lfoTargetName_ = "none";

    qreal volume_ = 0.8;
    int   lastActive_ = 0;
};

#endif // SYNTH_INSTRUMENT_H
