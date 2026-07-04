// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "speech.h"

#include <QAudioBuffer>
#include <QAudioDecoder>
#include <QAudioOutput>
#include <QFileInfo>
#include <QMediaPlayer>
#include <QtMath>

#ifdef CLAY_CHARACTER3D_HAS_TTS
#include <QTextToSpeech>
#endif

namespace {

constexpr int TICK_MS = 16;
// Smoothing factors per tick: mouth snaps open, relaxes closed.
constexpr qreal ATTACK = 0.45;
constexpr qreal RELEASE = 0.25;

struct LetterShape
{
    float open, wide, round;
    int   durMs;
};

// Rough letter-class visemes; good enough for a boxy toon face. Digraphs
// are matched first so "oo"/"ee"/"th" etc. get one shape, not two.
LetterShape shapeForDigraph(QChar a, QChar b, bool &matched)
{
    matched = true;
    const QString d = QString(a) + b;
    if (d == u"oo" || d == u"ou" || d == u"ow")
        return {0.45f, 0.0f, 0.95f, 150};
    if (d == u"ee" || d == u"ea" || d == u"ie" || d == u"ei")
        return {0.4f, 0.9f, 0.0f, 140};
    if (d == u"au" || d == u"ao")
        return {0.85f, 0.1f, 0.4f, 150};
    if (d == u"th" || d == u"sh" || d == u"ch" || d == u"ph")
        return {0.2f, 0.5f, 0.0f, 90};
    if (d == u"qu")
        return {0.35f, 0.0f, 0.85f, 110};
    matched = false;
    return {};
}

LetterShape shapeForLetter(QChar c)
{
    switch (c.unicode()) {
    // wide-open vowels
    case u'a': case u'ä':
        return {0.9f, 0.25f, 0.0f, 130};
    // spread vowels
    case u'e': case u'i': case u'y':
        return {0.45f, 0.85f, 0.0f, 120};
    // rounded vowels
    case u'o':
        return {0.7f, 0.0f, 0.85f, 130};
    case u'u': case u'ö': case u'ü':
        return {0.35f, 0.0f, 0.95f, 120};
    // bilabial closure
    case u'm': case u'b': case u'p':
        return {0.02f, 0.1f, 0.0f, 80};
    // labiodental
    case u'f': case u'v': case u'w':
        return {0.15f, 0.3f, 0.4f, 80};
    // everything else that makes sound: neutral consonant
    case u'c': case u'd': case u'g': case u'h': case u'j': case u'k':
    case u'l': case u'n': case u'q': case u'r': case u's': case u't':
    case u'x': case u'z': case u'ß':
        return {0.25f, 0.4f, 0.0f, 65};
    default:
        return {0.f, 0.f, 0.f, 0};
    }
}

} // namespace

Speech::Speech(QObject *parent)
    : QObject(parent)
{
    ticker_.setInterval(TICK_MS);
    ticker_.setTimerType(Qt::PreciseTimer);
    connect(&ticker_, &QTimer::timeout, this, &Speech::tick);
}

Speech::~Speech() = default;

void Speech::setVolume(qreal v)
{
    v = qBound(0.0, v, 1.0);
    if (qFuzzyCompare(volume_, v))
        return;
    volume_ = v;
    if (audioOut_)
        audioOut_->setVolume(volume_);
#ifdef CLAY_CHARACTER3D_HAS_TTS
    if (tts_)
        tts_->setVolume(volume_);
#endif
    emit volumeChanged();
}

void Speech::setRate(qreal r)
{
    r = qBound(-1.0, r, 1.0);
    if (qFuzzyCompare(rate_, r))
        return;
    rate_ = r;
#ifdef CLAY_CHARACTER3D_HAS_TTS
    if (tts_)
        tts_->setRate(rate_);
#endif
    emit rateChanged();
}

void Speech::setPitch(qreal p)
{
    p = qBound(-1.0, p, 1.0);
    if (qFuzzyCompare(pitch_, p))
        return;
    pitch_ = p;
#ifdef CLAY_CHARACTER3D_HAS_TTS
    if (tts_)
        tts_->setPitch(pitch_);
#endif
    emit pitchChanged();
}

bool Speech::ttsAvailable() const
{
#ifdef CLAY_CHARACTER3D_HAS_TTS
    return !QTextToSpeech::availableEngines().isEmpty();
#else
    return false;
#endif
}

void Speech::say(const QString &what)
{
    const QString trimmed = what.trimmed();
    const QString lower = trimmed.toLower();
    const bool looksLikeAudio = lower.endsWith(u".wav") || lower.endsWith(u".mp3")
            || lower.endsWith(u".ogg") || lower.endsWith(u".m4a")
            || lower.endsWith(u".flac");
    if (looksLikeAudio) {
        const QUrl url(trimmed);
        if (url.isValid() && !url.scheme().isEmpty())
            sayAudio(url);
        else
            sayAudio(QUrl::fromLocalFile(QFileInfo(trimmed).absoluteFilePath()));
    } else {
        sayText(trimmed);
    }
}

VisemeTimeline Speech::timelineForText(const QString &text, qreal paceScale)
{
    VisemeTimeline tl;
    if (paceScale <= 0.0)
        paceScale = 1.0;

    const QString lower = text.toLower();
    qint64 t = 0;
    bool inWord = false;

    auto addKey = [&](const LetterShape &s) {
        tl.keys.append({t, s.open, s.wide, s.round});
        t += qMax(20, int(s.durMs * paceScale));
    };

    for (qsizetype i = 0; i < lower.size(); ++i) {
        const QChar c = lower.at(i);

        if (c.isLetter()) {
            if (!inWord) {
                tl.wordMarks.append({i, t});
                inWord = true;
            }
            if (i + 1 < lower.size()) {
                bool matched = false;
                const LetterShape ds = shapeForDigraph(c, lower.at(i + 1), matched);
                if (matched) {
                    addKey(ds);
                    ++i;
                    continue;
                }
            }
            const LetterShape s = shapeForLetter(c);
            if (s.durMs > 0)
                addKey(s);
            continue;
        }

        inWord = false;
        if (c == u' ' || c == u'\n' || c == u'\t') {
            tl.keys.append({t, 0.05f, 0.f, 0.f});
            t += int(70 * paceScale);
        } else if (c == u',' || c == u';' || c == u':') {
            tl.keys.append({t, 0.f, 0.f, 0.f});
            t += int(220 * paceScale);
        } else if (c == u'.' || c == u'!' || c == u'?') {
            tl.keys.append({t, 0.f, 0.f, 0.f});
            t += int(350 * paceScale);
        }
    }

    tl.keys.append({t, 0.f, 0.f, 0.f});
    tl.durationMs = t;
    return tl;
}

void Speech::sayText(const QString &text)
{
    stop();
    if (text.isEmpty())
        return;

    // rate -1..1 => pace scale 1.6 .. 0.6 (slower rate = longer visemes)
    timeline_ = timelineForText(text, 1.0 - 0.4 * rate_);
    if (timeline_.keys.isEmpty())
        return;

    beginSpeaking(Mode::Text);

#ifdef CLAY_CHARACTER3D_HAS_TTS
    ensureTts();
    if (tts_) {
        ttsDrivesClock_ = false;
        ttsSawSpeaking_ = false;
        tts_->say(text);
        return;
    }
#endif
    // Silent fallback: timeline runs against the wall clock.
}

#ifdef CLAY_CHARACTER3D_HAS_TTS
void Speech::ensureTts()
{
    if (tts_)
        return;
    if (QTextToSpeech::availableEngines().isEmpty())
        return;

    tts_ = new QTextToSpeech(this);
    tts_->setVolume(volume_);
    tts_->setRate(rate_);
    tts_->setPitch(pitch_);

    connect(tts_, &QTextToSpeech::sayingWord, this,
            [this](const QString &word, qsizetype, qsizetype start, qsizetype) {
        if (mode_ != Mode::Text)
            return;
        // Re-sync the timeline clock to the word the engine just started.
        for (const auto &mark : std::as_const(timeline_.wordMarks)) {
            if (mark.first == start) {
                clockBaseMs_ = mark.second;
                clock_.restart();
                break;
            }
        }
        ttsDrivesClock_ = true;
        setCurrentWord(word);
    });

    connect(tts_, &QTextToSpeech::stateChanged, this,
            [this](QTextToSpeech::State state) {
        if (mode_ != Mode::Text)
            return;
        if (state == QTextToSpeech::Speaking)
            ttsSawSpeaking_ = true;
        // Only a Ready that follows Speaking of THIS utterance ends the
        // speech - say() right after a previous utterance can produce a
        // stale Ready transition that must not cut the new speech short.
        if ((state == QTextToSpeech::Ready && ttsSawSpeaking_)
                || state == QTextToSpeech::Error)
            finishSpeaking();
    });
}
#endif

void Speech::startAudio(const QUrl &source)
{
    if (!player_) {
        player_ = new QMediaPlayer(this);
        audioOut_ = new QAudioOutput(this);
        audioOut_->setVolume(volume_);
        player_->setAudioOutput(audioOut_);

        connect(player_, &QMediaPlayer::mediaStatusChanged, this,
                [this](QMediaPlayer::MediaStatus status) {
            if (mode_ != Mode::Audio)
                return;
            if (status == QMediaPlayer::EndOfMedia
                    || status == QMediaPlayer::InvalidMedia)
                finishSpeaking();
        });
        connect(player_, &QMediaPlayer::errorOccurred, this,
                [this](QMediaPlayer::Error, const QString &errorString) {
            qWarning() << "Speech: audio playback failed:" << errorString;
            if (mode_ == Mode::Audio)
                finishSpeaking();
        });
    }

    if (!decoder_) {
        decoder_ = new QAudioDecoder(this);
        connect(decoder_, &QAudioDecoder::bufferReady,
                this, &Speech::onDecoderBufferReady);
        connect(decoder_, &QAudioDecoder::finished,
                this, &Speech::onDecoderFinished);
        connect(decoder_, qOverload<QAudioDecoder::Error>(&QAudioDecoder::error),
                this, [this]() {
            if (mode_ != Mode::Audio || analysisReady_)
                return;
            qWarning() << "Speech: audio analysis failed ("
                       << decoder_->errorString()
                       << ") - falling back to babble envelope";
            babbleMode_ = true;
            analysisReady_ = true;
            player_->play();
        });
    }

    rmsWindows_.clear();
    zcrWindows_.clear();
    maxRms_ = 0.f;
    winSumSquares_ = 0.0;
    winSampleCount_ = 0;
    winZeroCrossings_ = 0;
    lastSample_ = 0.f;
    samplesPerWindow_ = 0;
    analysisReady_ = false;
    babbleMode_ = false;

    beginSpeaking(Mode::Audio);
    player_->setSource(source);
    decoder_->setSource(source);
    decoder_->start();
}

void Speech::sayAudio(const QUrl &source)
{
    stop();
    if (source.isEmpty())
        return;
    startAudio(source);
}

void Speech::onDecoderBufferReady()
{
    const QAudioBuffer buffer = decoder_->read();
    if (!buffer.isValid())
        return;

    const QAudioFormat fmt = buffer.format();
    if (samplesPerWindow_ == 0)
        samplesPerWindow_ = qMax(1, fmt.sampleRate() * windowMs_ / 1000);

    const int channels = qMax(1, fmt.channelCount());
    const int frames = buffer.frameCount();

    auto processSample = [this](float mono) {
        winSumSquares_ += double(mono) * mono;
        if ((lastSample_ < 0.f) != (mono < 0.f))
            ++winZeroCrossings_;
        lastSample_ = mono;
        if (++winSampleCount_ >= samplesPerWindow_) {
            const float rms = float(qSqrt(winSumSquares_ / winSampleCount_));
            const float zcr = float(winZeroCrossings_) / winSampleCount_;
            rmsWindows_.append(rms);
            zcrWindows_.append(zcr);
            maxRms_ = qMax(maxRms_, rms);
            winSumSquares_ = 0.0;
            winSampleCount_ = 0;
            winZeroCrossings_ = 0;
        }
    };

    switch (fmt.sampleFormat()) {
    case QAudioFormat::Int16: {
        const qint16 *data = buffer.constData<qint16>();
        for (int f = 0; f < frames; ++f) {
            qint32 acc = 0;
            for (int ch = 0; ch < channels; ++ch)
                acc += data[f * channels + ch];
            processSample(float(acc) / (channels * 32768.f));
        }
        break;
    }
    case QAudioFormat::Int32: {
        const qint32 *data = buffer.constData<qint32>();
        for (int f = 0; f < frames; ++f) {
            double acc = 0;
            for (int ch = 0; ch < channels; ++ch)
                acc += data[f * channels + ch];
            processSample(float(acc / (double(channels) * 2147483648.0)));
        }
        break;
    }
    case QAudioFormat::Float: {
        const float *data = buffer.constData<float>();
        for (int f = 0; f < frames; ++f) {
            float acc = 0.f;
            for (int ch = 0; ch < channels; ++ch)
                acc += data[f * channels + ch];
            processSample(acc / channels);
        }
        break;
    }
    case QAudioFormat::UInt8: {
        const quint8 *data = buffer.constData<quint8>();
        for (int f = 0; f < frames; ++f) {
            int acc = 0;
            for (int ch = 0; ch < channels; ++ch)
                acc += int(data[f * channels + ch]) - 128;
            processSample(float(acc) / (channels * 128.f));
        }
        break;
    }
    default:
        break;
    }
}

void Speech::onDecoderFinished()
{
    if (mode_ != Mode::Audio || analysisReady_)
        return;

    timeline_.keys.clear();
    timeline_.wordMarks.clear();

    if (maxRms_ > 0.f && !rmsWindows_.isEmpty()) {
        const float gate = 0.06f * maxRms_;
        for (int i = 0; i < rmsWindows_.size(); ++i) {
            const float rms = rmsWindows_.at(i);
            float open = 0.f, wide = 0.f, round = 0.f;
            if (rms > gate) {
                open = qPow(rms / maxRms_, 0.6f);
                // High zero-crossing rate hints at sibilants/fricatives:
                // narrow the mouth instead of opening it wide.
                const float zcrNorm = qBound(0.f, (zcrWindows_.at(i) - 0.05f) / 0.25f, 1.f);
                wide = 0.55f * zcrNorm;
                open *= (1.f - 0.45f * zcrNorm);
                round = 0.25f * (1.f - zcrNorm) * open;
            }
            timeline_.keys.append({qint64(i) * windowMs_, open, wide, round});
        }
        timeline_.durationMs = qint64(rmsWindows_.size()) * windowMs_;
        analysisReady_ = true;
        player_->play();
    } else {
        babbleMode_ = true;
        analysisReady_ = true;
        player_->play();
    }
}

void Speech::buildBabbleTimeline(qint64 durationMs)
{
    // Deterministic pseudo-syllables at ~5 Hz; used when the audio could
    // not be analyzed but still plays.
    timeline_.keys.clear();
    timeline_.wordMarks.clear();
    qint64 t = 0;
    quint32 seed = 0x9e3779b9u;
    while (t < durationMs) {
        seed = seed * 1664525u + 1013904223u;
        const float open = 0.25f + 0.65f * ((seed >> 8) % 1000) / 1000.f;
        seed = seed * 1664525u + 1013904223u;
        const float round = 0.5f * ((seed >> 8) % 1000) / 1000.f;
        timeline_.keys.append({t, open, 0.2f, round});
        t += 90;
        timeline_.keys.append({t, 0.1f, 0.1f, 0.f});
        t += 90;
    }
    timeline_.durationMs = durationMs;
}

void Speech::beginSpeaking(Mode mode)
{
    mode_ = mode;
    settling_ = false;
    clockBaseMs_ = 0;
    clock_.restart();
    if (!speaking_) {
        speaking_ = true;
        emit speakingChanged();
    }
    emit started();
    ticker_.start();
}

void Speech::finishSpeaking()
{
    if (mode_ == Mode::None && !speaking_)
        return;
    mode_ = Mode::None;
    settling_ = true; // ticker keeps running until the mouth is closed
    setCurrentWord(QString());
    if (speaking_) {
        speaking_ = false;
        emit speakingChanged();
    }
    emit finished();
}

void Speech::stop()
{
#ifdef CLAY_CHARACTER3D_HAS_TTS
    // Always silence the engine - it may still be speaking a previous
    // utterance even when our mode already moved on (e.g. watchdog end).
    if (tts_)
        tts_->stop();
#endif
    if (player_ && mode_ == Mode::Audio) {
        player_->stop();
        decoder_->stop();
    }
    finishSpeaking();
}

qint64 Speech::clockMs() const
{
    if (mode_ == Mode::Audio && player_ && !babbleMode_)
        return player_->position();
    return clockBaseMs_ + clock_.elapsed();
}

void Speech::sampleTimeline(qint64 ms, float &open, float &wide, float &round) const
{
    open = wide = round = 0.f;
    if (timeline_.keys.isEmpty())
        return;
    // Timelines are short (a few hundred keys); linear scan from the back
    // finds the active key without bookkeeping across re-syncs.
    for (qsizetype i = timeline_.keys.size() - 1; i >= 0; --i) {
        const VisemeKey &k = timeline_.keys.at(i);
        if (k.ms <= ms) {
            open = k.open;
            wide = k.wide;
            round = k.round;
            return;
        }
    }
}

void Speech::setCurrentWord(const QString &word)
{
    if (currentWord_ == word)
        return;
    currentWord_ = word;
    emit currentWordChanged();
}

void Speech::tick()
{
    float tOpen = 0.f, tWide = 0.f, tRound = 0.f;

    if (mode_ == Mode::Audio && babbleMode_ && timeline_.keys.isEmpty()
            && player_ && player_->duration() > 0) {
        buildBabbleTimeline(player_->duration());
    }

    if (mode_ != Mode::None)
        sampleTimeline(clockMs(), tOpen, tWide, tRound);

    auto approach = [](qreal current, qreal target) {
        const qreal alpha = target > current ? ATTACK : RELEASE;
        return current + (target - current) * alpha;
    };

    const qreal newOpen = approach(mouthOpen_, tOpen);
    const qreal newWide = approach(mouthWide_, tWide);
    const qreal newRound = approach(mouthRound_, tRound);

    const bool changed = qAbs(newOpen - mouthOpen_) > 0.001
            || qAbs(newWide - mouthWide_) > 0.001
            || qAbs(newRound - mouthRound_) > 0.001;

    mouthOpen_ = newOpen;
    mouthWide_ = newWide;
    mouthRound_ = newRound;

    if (changed) {
        emit mouthChanged();
    } else if (settling_) {
        // Mouth has settled after speech ended - snap shut and stop.
        settling_ = false;
        mouthOpen_ = mouthWide_ = mouthRound_ = 0.0;
        emit mouthChanged();
        ticker_.stop();
    }

    // End text mode when the timeline runs out. Without TTS this is the
    // regular end condition; with TTS it acts as a watchdog for engines
    // that never report Ready (word callbacks keep re-syncing the clock,
    // so a healthy engine stays below the limit until it finishes).
    if (mode_ == Mode::Text) {
        qint64 limit = timeline_.durationMs;
#ifdef CLAY_CHARACTER3D_HAS_TTS
        if (tts_)
            limit += 2000;
#endif
        if (clockMs() > limit)
            finishSpeaking();
    }
}
