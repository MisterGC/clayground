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
//    analyzes the samples (RMS envelope for openness, zero-crossing rate
//    as a crude sibilance hint for wideness). If decoding fails, a
//    synthetic babble envelope keeps the mouth moving during playback.
//
// A ~60 Hz ticker smooths the raw viseme targets with asymmetric
// attack/release so the mouth snaps open and relaxes closed.

#ifndef CLAY_CHARACTER3D_SPEECH_H
#define CLAY_CHARACTER3D_SPEECH_H

#include <QElapsedTimer>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTimer>
#include <QUrl>
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

// One step on the mouth-shape timeline; values are targets in [0,1].
struct VisemeKey
{
    qint64 ms = 0;
    float  open = 0.f;
    float  wide = 0.f;
    float  round = 0.f;
};

// Timeline plus the mapping from character offsets in the source text to
// timeline positions (used to re-sync on TTS word callbacks).
struct VisemeTimeline
{
    QVector<VisemeKey> keys;
    QVector<QPair<qsizetype, qint64>> wordMarks; // (char offset, ms)
    qint64 durationMs = 0;
};

class Speech : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool    speaking    READ speaking    NOTIFY speakingChanged)
    Q_PROPERTY(qreal   mouthOpen   READ mouthOpen   NOTIFY mouthChanged)
    Q_PROPERTY(qreal   mouthWide   READ mouthWide   NOTIFY mouthChanged)
    Q_PROPERTY(qreal   mouthRound  READ mouthRound  NOTIFY mouthChanged)
    Q_PROPERTY(QString currentWord READ currentWord NOTIFY currentWordChanged)
    Q_PROPERTY(qreal   volume      READ volume      WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qreal   rate        READ rate        WRITE setRate   NOTIFY rateChanged)
    Q_PROPERTY(qreal   pitch       READ pitch       WRITE setPitch  NOTIFY pitchChanged)
    Q_PROPERTY(bool    ttsAvailable READ ttsAvailable CONSTANT)

public:
    explicit Speech(QObject *parent = nullptr);
    ~Speech() override;

    bool    speaking() const { return speaking_; }
    qreal   mouthOpen() const { return mouthOpen_; }
    qreal   mouthWide() const { return mouthWide_; }
    qreal   mouthRound() const { return mouthRound_; }
    QString currentWord() const { return currentWord_; }

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

    // Says text or plays an audio file, depending on what the string
    // looks like (existing file / url / known audio extension => audio).
    Q_INVOKABLE void say(const QString &what);
    Q_INVOKABLE void sayText(const QString &text);
    Q_INVOKABLE void sayAudio(const QUrl &source);
    Q_INVOKABLE void stop();

    // Pure timeline construction, exposed for unit testing.
    static VisemeTimeline timelineForText(const QString &text, qreal paceScale = 1.0);

signals:
    void speakingChanged();
    void mouthChanged();
    void currentWordChanged();
    void volumeChanged();
    void rateChanged();
    void pitchChanged();
    void started();
    void finished();

private:
    enum class Mode { None, Text, Audio };

    void beginSpeaking(Mode mode);
    void finishSpeaking();
    void tick();
    void setCurrentWord(const QString &word);
    qint64 clockMs() const;
    void sampleTimeline(qint64 ms, float &open, float &wide, float &round) const;

    void startAudio(const QUrl &source);
    void onDecoderBufferReady();
    void onDecoderFinished();
    void buildBabbleTimeline(qint64 durationMs);

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
