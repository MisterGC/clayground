// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Speech — gives a character a voice with approximate lip-sync.
//
// Two input paths produce one output: a small set of continuous mouth
// shape parameters (open/wide/round, all 0..1) that QML binds to the
// character's mouth geometry:
//
//  * sayText(): speaks via QTextToSpeech (if built with it and an engine
//    is available) and derives a viseme timeline from the text's letters.
//    Word-progress callbacks from the TTS engine re-sync the timeline so
//    mouth and audio stay aligned. Without TTS the same timeline plays
//    silently at an estimated pace.
//
//  * sayAudio(): plays a wav/mp3 via QMediaPlayer while QAudioDecoder
//    analyzes the samples. How closely it looks is set by accuracy - see
//    the Accuracy enum. If decoding fails, a synthetic babble envelope
//    keeps the mouth moving during playback.
//
// A ~60 Hz ticker smooths the raw viseme targets with asymmetric
// attack/release so the mouth snaps open and relaxes closed.

#ifndef CLAY_CHARACTER3D_SPEECH_H
#define CLAY_CHARACTER3D_SPEECH_H

#include "visemetimeline.h"

#include <QElapsedTimer>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVariant>
#include <QVector>

QT_BEGIN_NAMESPACE
class QAudioDecoder;
class QAudioOutput;
class QMediaPlayer;
QT_END_NAMESPACE

#ifdef CLAY_CHARACTER3D_HAS_TTS
QT_BEGIN_NAMESPACE
class QTextToSpeech;
QT_END_NAMESPACE
#endif

class Speech : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool    speaking    READ speaking    NOTIFY speakingChanged)
    Q_PROPERTY(qreal   mouthOpen   READ mouthOpen   NOTIFY mouthChanged)
    Q_PROPERTY(qreal   mouthWide   READ mouthWide   NOTIFY mouthChanged)
    Q_PROPERTY(qreal   mouthRound  READ mouthRound  NOTIFY mouthChanged)
    Q_PROPERTY(QString currentWord READ currentWord NOTIFY currentWordChanged)
    // How long the line currently being said lasts. Scheduling anything
    // alongside speech needs this number, and the engine has always known it.
    Q_PROPERTY(int     durationMs  READ durationMs  NOTIFY durationMsChanged)
    Q_PROPERTY(qreal   volume      READ volume      WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qreal   rate        READ rate        WRITE setRate   NOTIFY rateChanged)
    Q_PROPERTY(qreal   pitch       READ pitch       WRITE setPitch  NOTIFY pitchChanged)
    Q_PROPERTY(bool    ttsAvailable READ ttsAvailable CONSTANT)
    Q_PROPERTY(Accuracy accuracy READ accuracy WRITE setAccuracy NOTIFY accuracyChanged)
    Q_PROPERTY(Accuracy effectiveAccuracy READ effectiveAccuracy NOTIFY effectiveAccuracyChanged)

public:
    // How hard the audio path works at reading a mouth out of a recording.
    //
    // The tiers are NOT about CPU. A 512-point transform every 16 ms is a few
    // hundred thousand flops for a whole line, well under the decode that
    // produced the samples. What separates them is latency (analysis finishes
    // before playback starts, so it is time-to-first-sound), retained memory,
    // and - for anything above Spectral - whether the caller had a transcript
    // to give.
    //
    // Whatever is asked for, no tier leaves the mouth dead: each falls back to
    // the one below when its input is missing or unreadable, and Envelope is
    // the floor. Read effectiveAccuracy for what actually ran.
    enum Accuracy
    {
        // Loudness and zero crossings, streamed, nothing retained. Says how
        // far the jaw dropped and nothing about the shape of the mouth.
        Envelope,
        // Formant bands: an open vowel opens further than a closed one, a
        // front vowel spreads, a back vowel rounds, a fricative narrows.
        Spectral,
        // The script's own shapes, on the recording's clock. Needs a
        // transcript, and falls back to Spectral without one - which is why
        // this tier is an authoring decision rather than a runtime one.
        Aligned
    };
    Q_ENUM(Accuracy)

    explicit Speech(QObject *parent = nullptr);
    ~Speech() override;

    bool    speaking() const { return speaking_; }
    qreal   mouthOpen() const { return mouthOpen_; }
    qreal   mouthWide() const { return mouthWide_; }
    qreal   mouthRound() const { return mouthRound_; }
    QString currentWord() const { return currentWord_; }
    int     durationMs() const { return int(timeline_.durationMs); }

    qreal volume() const { return volume_; }
    void  setVolume(qreal v);

    // -1 (slow) .. 0 (normal) .. 1 (fast); forwarded to TTS and used to
    // scale the estimated pace of text-only timelines.
    qreal rate() const { return rate_; }
    void  setRate(qreal r);

    // -1 .. 1; TTS voice pitch (no effect on audio files).
    qreal pitch() const { return pitch_; }
    void  setPitch(qreal p);

    bool ttsAvailable() const;

    Accuracy accuracy() const { return accuracy_; }
    void setAccuracy(Accuracy a);
    // What the last line actually got, which is only the same thing when the
    // audio could carry it.
    Accuracy effectiveAccuracy() const { return effectiveAccuracy_; }

    // Says text or plays an audio file, depending on what the string
    // looks like (existing file / url / known audio extension => audio).
    Q_INVOKABLE void say(const QString &what, const QString &transcript = QString());
    Q_INVOKABLE void sayText(const QString &text);
    // The transcript is what a line was recorded saying. Given one, and with
    // accuracy at Aligned, the mouth takes its SHAPES from it and only its
    // timing from the audio - so a /m/ closes because the script says there
    // is one, with nothing left for the acoustics to get wrong.
    Q_INVOKABLE void sayAudio(const QUrl &source, const QString &transcript = QString());
    Q_INVOKABLE void stop();

    // How long this engine would take over the text, at the current rate,
    // without saying it. The same number the mouth is driven by, so anything
    // scheduling around a line stops having to guess a speech rate of its own.
    Q_INVOKABLE int estimateDurationMs(const QString &text) const;

    // The current line's words as {offset, ms} - the char offset in the source
    // text and when that word starts. Empty before the first line.
    Q_INVOKABLE QVariantList wordMarks() const;

    // Pure timeline construction, exposed for unit testing.
    static VisemeTimeline timelineForText(const QString &text, qreal paceScale = 1.0);

signals:
    void speakingChanged();
    void mouthChanged();
    void currentWordChanged();
    void durationMsChanged();
    void volumeChanged();
    void rateChanged();
    void pitchChanged();
    void accuracyChanged();
    void effectiveAccuracyChanged();
    void started();
    void finished();

private:
    enum class Mode { None, Text, Audio };
    // What the next event-loop turn is going to start. A say() records a
    // request instead of starting it on the spot - see scheduleStart().
    enum class Pending { None, Text, Audio };

    void scheduleStart();
    void startPending();
    void startText(const QString &text);
    void setTimeline(const VisemeTimeline &tl);

    void beginSpeaking(Mode mode);
    void finishSpeaking();
    void tick();
    void setCurrentWord(const QString &word);
    qint64 clockMs() const;
    void sampleTimeline(qint64 ms, float &open, float &wide, float &round) const;

    void startAudio(const QUrl &source, const QString &transcript);
    void onDecoderBufferReady();
    void onDecoderFinished();
    void buildBabbleTimeline(qint64 durationMs);
    VisemeTimeline envelopeTimeline() const;
    void setEffectiveAccuracy(Accuracy a);

#ifdef CLAY_CHARACTER3D_HAS_TTS
    void ensureTts();
    QTextToSpeech *tts_ = nullptr;
    bool ttsDrivesClock_ = false;
    bool ttsSawSpeaking_ = false;
#endif

    QTimer        ticker_;
    QElapsedTimer clock_;
    qint64        clockBaseMs_ = 0; // timeline pos when clock_ was (re)started

    VisemeTimeline timeline_;

    Pending pendingKind_ = Pending::None;
    QString pendingText_;
    QUrl    pendingSource_;
    QString pendingTranscript_;
    QString transcript_;
    bool    startScheduled_ = false;

    Mode  mode_ = Mode::None;
    bool  speaking_ = false;
    bool  settling_ = false; // speech done, mouth still easing to closed

    qreal mouthOpen_ = 0.0;
    qreal mouthWide_ = 0.0;
    qreal mouthRound_ = 0.0;
    QString currentWord_;

    qreal volume_ = 1.0;
    qreal rate_ = 0.0;
    qreal pitch_ = 0.0;

    // Audio playback + analysis
    QMediaPlayer  *player_ = nullptr;
    QAudioOutput  *audioOut_ = nullptr;
    QAudioDecoder *decoder_ = nullptr;
    QVector<float> rmsWindows_;
    QVector<float> zcrWindows_;
    // Retained only above Envelope, so the cheap tier keeps exactly the memory
    // profile it always had. Capped: a line of dialogue is seconds, and the
    // cap is what stops a music track handed over by mistake from costing
    // hundreds of megabytes before anyone notices the mistake.
    QVector<float> analysisSamples_;
    int    analysisRate_ = 0;
    bool   analysisTruncated_ = false;
    Accuracy accuracy_ = Speech::Spectral;
    Accuracy effectiveAccuracy_ = Speech::Envelope;
    float  maxRms_ = 0.f;
    int    windowMs_ = 33;
    // carry state between decoder buffers
    double winSumSquares_ = 0.0;
    int    winSampleCount_ = 0;
    int    winZeroCrossings_ = 0;
    float  lastSample_ = 0.f;
    int    samplesPerWindow_ = 0;
    bool   analysisReady_ = false;
    bool   babbleMode_ = false;
};

#endif // CLAY_CHARACTER3D_SPEECH_H
