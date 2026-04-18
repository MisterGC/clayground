// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song_player.h"

#include "song/song_parser.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QQmlContext>
#include <QQmlEngine>
#include <QVariant>

#include <algorithm>
#include <cmath>

namespace {

constexpr int kTickMs = 10;

QUrl resolveUrl(QObject *ctx, const QUrl &url)
{
    if (url.isEmpty() || url.isLocalFile() || url.scheme() == QLatin1String("file"))
        return url;
    if (auto *qctx = ctx ? QQmlEngine::contextForObject(ctx) : nullptr)
        return qctx->resolvedUrl(url);
    return url;
}

QString urlToLocalPath(const QUrl &url)
{
    if (url.isLocalFile()) return url.toLocalFile();
    if (url.scheme() == QLatin1String("qrc")) return QStringLiteral(":") + url.path();
    return url.toString();
}

} // namespace

SongPlayer::SongPlayer(QObject *parent)
    : QObject(parent)
{
    tickTimer_.setInterval(kTickMs);
    connect(&tickTimer_, &QTimer::timeout, this, &SongPlayer::tick);
}

SongPlayer::~SongPlayer() = default;

void SongPlayer::setSource(const QUrl &url)
{
    if (source_ == url) return;
    source_ = url;
    emit sourceChanged();
    reload();
}

void SongPlayer::setInstruments(const QVariantList &list)
{
    instrumentsVar_ = list;
    rebuildInstrumentMap();
    emit instrumentsChanged();
}

void SongPlayer::setLoop(bool v)
{
    if (loop_ == v) return;
    loop_ = v;
    emit loopChanged();
}

void SongPlayer::play()
{
    if (!loaded_) {
        if (error_.isEmpty()) setError(QStringLiteral("no song loaded"));
        return;
    }
    if (playing_) return;
    playing_ = true;
    wallClock_.start();
    lastWallMs_ = 0;
    tickTimer_.start();
    emit playingChanged();
}

void SongPlayer::pause()
{
    if (!playing_) return;
    playing_ = false;
    tickTimer_.stop();
    emit playingChanged();
}

void SongPlayer::stop()
{
    const bool wasPlaying = playing_;
    playing_ = false;
    tickTimer_.stop();
    position_ = 0.0;
    nextIdx_ = 0;
    if (wasPlaying) emit playingChanged();
    emit positionChanged();
}

void SongPlayer::seek(qreal beats)
{
    if (beats < 0.0) beats = 0.0;
    if (beats > totalBeats_) beats = totalBeats_;
    position_ = beats;
    // Find next scheduled event at or after this beat.
    auto it = std::lower_bound(
        schedule_.begin(), schedule_.end(), beats,
        [](const ScheduledEvent &e, double b) { return e.beat < b; });
    nextIdx_ = static_cast<int>(it - schedule_.begin());
    emit positionChanged();
}

void SongPlayer::tick()
{
    if (!playing_) return;

    const qint64 nowMs  = wallClock_.elapsed();
    const qint64 dtMs   = nowMs - lastWallMs_;
    lastWallMs_ = nowMs;
    if (dtMs <= 0) return;

    const double bpm = model_.tempo > 0.0 ? model_.tempo : 120.0;
    const double beatsPerMs = bpm / 60000.0;
    const double newPos = position_ + static_cast<double>(dtMs) * beatsPerMs;

    while (nextIdx_ < schedule_.size() && schedule_[nextIdx_].beat < newPos) {
        const ScheduledEvent &ev = schedule_[nextIdx_];
        QObject *inst = resolveInstrument(model_.tracks.value(ev.track).instrument);
        if (inst) {
            const double durSeconds = ev.durBeats * 60.0 / bpm;
            QMetaObject::invokeMethod(inst, "triggerNote",
                                      Q_ARG(int,   ev.midi),
                                      Q_ARG(qreal, ev.vel),
                                      Q_ARG(qreal, durSeconds));
        }
        ++nextIdx_;
    }

    position_ = newPos;
    emit positionChanged();

    if (position_ >= totalBeats_) {
        if (loop_) {
            position_ = std::fmod(position_, totalBeats_);
            nextIdx_ = 0;
            emit positionChanged();
        } else {
            playing_ = false;
            tickTimer_.stop();
            emit playingChanged();
            emit finished();
        }
    }
}

void SongPlayer::reload()
{
    loaded_ = false;
    schedule_.clear();
    totalBeats_ = 0.0;
    position_ = 0.0;
    nextIdx_ = 0;
    const double prevTempo = model_.tempo;
    model_ = {};

    const QUrl url = resolveUrl(this, source_);
    if (url.isEmpty()) {
        setError(QString());
        emit loadedChanged();
        emit totalBeatsChanged();
        if (model_.tempo != prevTempo) emit tempoChanged();
        emit positionChanged();
        return;
    }

    const QString path = urlToLocalPath(url);
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("cannot open %1").arg(path));
        emit parseError(error_);
        emit loadedChanged();
        return;
    }
    const auto res = clay::sound::SongParser::parse(f.readAll());
    if (!res.ok) {
        setError(res.error);
        emit parseError(error_);
        emit loadedChanged();
        return;
    }
    model_ = res.model;
    rebuildSchedule();
    setError(QString());
    loaded_ = true;
    emit loadedChanged();
    emit tempoChanged();
    emit totalBeatsChanged();
    emit positionChanged();
}

void SongPlayer::rebuildSchedule()
{
    schedule_.clear();
    totalBeats_ = 0.0;
    nextIdx_ = 0;

    // Compute pattern lengths (rounded up to next full beat).
    QHash<QString, double> patternLength;
    for (auto it = model_.patterns.begin(); it != model_.patterns.end(); ++it) {
        double endBeat = 0.0;
        for (auto tit = it->trackEvents.begin(); tit != it->trackEvents.end(); ++tit) {
            for (const auto &n : tit.value())
                endBeat = std::max(endBeat, n.t + n.dur);
        }
        patternLength.insert(it.key(), std::ceil(endBeat));
    }

    double cursor = 0.0;
    for (const auto &sec : std::as_const(model_.sections)) {
        if (!model_.patterns.contains(sec.patternName)) continue;
        const auto pattern = model_.patterns.value(sec.patternName);
        const double len = patternLength.value(sec.patternName, 1.0);
        for (int rep = 0; rep < sec.repeat; ++rep) {
            for (auto tit = pattern.trackEvents.begin(); tit != pattern.trackEvents.end(); ++tit) {
                const QString &track = tit.key();
                for (const auto &n : tit.value()) {
                    ScheduledEvent se;
                    se.beat     = cursor + n.t;
                    se.durBeats = n.dur;
                    se.vel      = n.vel;
                    se.midi     = n.midi;
                    se.track    = track;
                    schedule_.append(se);
                }
            }
            cursor += len;
        }
    }

    std::sort(schedule_.begin(), schedule_.end(),
              [](const ScheduledEvent &a, const ScheduledEvent &b) {
                  return a.beat < b.beat;
              });
    totalBeats_ = cursor;
}

void SongPlayer::rebuildInstrumentMap()
{
    nameToInstrument_.clear();
    for (const QVariant &v : std::as_const(instrumentsVar_)) {
        QObject *obj = qvariant_cast<QObject *>(v);
        if (!obj) continue;
        const QString name = obj->objectName();
        if (name.isEmpty()) continue;
        nameToInstrument_.insert(name, obj);
    }
}

void SongPlayer::setError(const QString &err)
{
    if (error_ == err) return;
    error_ = err;
    emit errorChanged();
}

QObject *SongPlayer::resolveInstrument(const QString &name) const
{
    return nameToInstrument_.value(name, nullptr);
}
