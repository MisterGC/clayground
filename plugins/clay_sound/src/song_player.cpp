// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song_player.h"

#include "audio_output.h"
#include "engine/pcm_buffer.h"
#include "sample_instrument.h"
#include "synth_instrument.h"
#include "song/song_parser.h"
#include "source_url.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QVariant>

#include <algorithm>
#include <cmath>
#include <optional>

namespace {

constexpr int kTickMs = 10;

} // namespace

SongPlayer::SongPlayer(QObject *parent)
    : QObject(parent)
{
    gainStage_ = clay::sound::AudioOutput::instance().engine().addGainStage();
    tickTimer_.setInterval(kTickMs);
    connect(&tickTimer_, &QTimer::timeout, this, &SongPlayer::tick);
    connect(&watcher_, &QFileSystemWatcher::fileChanged,
            this, &SongPlayer::onWatchedFileChanged);
}

void SongPlayer::setVolume(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (volume_ == v) return;
    volume_ = v;
    clay::sound::AudioOutput::instance().engine()
        .setGainStage(gainStage_, static_cast<float>(v));
    emit volumeChanged();
}

SongPlayer::~SongPlayer()
{
    cancelPendingNotes();
    voices_.detach(clay::sound::AudioOutput::instance().engine());
}

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
    if (seq_) seq_->setLoop(v);
    emit loopChanged();
}

void SongPlayer::setState(const QString &s)
{
    if (state_ == s) return;
    state_ = s;
    emit stateChanged();
    if (!loaded_ || !isV2() || !seq_) return;
    if (!model_.segments.contains(s)) {
        setError(QStringLiteral("state '%1' is not a segment of the song").arg(s));
        return;
    }
    if (!anchored_) {
        restartSequencer(s, 0.0);       // not played yet: it starts there
        return;
    }
    if (playing_) scheduleAhead();
    seq_->setState(s);
}

void SongPlayer::setIntensity(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (intensity_ == v) return;
    intensity_ = v;
    emit intensityChanged();
    if (!loaded_ || !isV2() || !seq_) return;
    if (!anchored_) {
        restartSequencer(segment_, 0.0);
        return;
    }
    if (playing_) scheduleAhead();
    seq_->setIntensity(v);
}

bool SongPlayer::playStinger(const QString &name)
{
    if (!loaded_ || !isV2() || !seq_ || !model_.stingers.contains(name)) return false;
    if (!anchored_) return false;       // nothing plays to put it on
    if (playing_) scheduleAhead();
    return seq_->playStinger(name);
}

void SongPlayer::play()
{
    if (!loaded_) {
        if (error_.isEmpty()) setError(QStringLiteral("no song loaded"));
        return;
    }
    if (playing_) return;
    playing_ = true;
    if (isV2()) {
        auto &output = clay::sound::AudioOutput::instance();
        output.start();
        if (seq_->ended()) restartSequencer(state_, 0.0);
        // Resume where the notes handed out end; a pause shorter than
        // the look-ahead keeps them, so nothing jumps.
        const int64_t now = output.engine().currentFrame();
        if (!anchored_ || anchor_ + seq_->scheduled() < now) {
            anchor_ = now - seq_->scheduled();
            anchored_ = true;
        }
        scheduleAhead();
        tickTimer_.start();
        emit playingChanged();
        return;
    }
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
    if (isV2() && seq_) {
        // Notes handed out ahead do not sound; ringing ones ring out.
        cancelPendingNotes();
        restartSequencer(state_, 0.0);
    }
    if (wasPlaying) emit playingChanged();
    emit positionChanged();
}

void SongPlayer::seek(qreal beats)
{
    if (isV2() && seq_) {
        // Beats into the segment playing now.
        cancelPendingNotes();
        restartSequencer(segment_, std::clamp(beats, 0.0, totalBeats_));
        if (playing_) scheduleAhead();
        return;
    }
    if (beats < 0.0) beats = 0.0;
    if (beats > totalBeats_) beats = totalBeats_;
    position_ = beats;
    // Find next scheduled event at or after this beat.
    auto it = std::lower_bound(
        schedule_.begin(), schedule_.end(), beats,
        [](const clay::sound::SongNote &e, double b) { return e.beat < b; });
    nextIdx_ = static_cast<int>(it - schedule_.begin());
    emit positionChanged();
}

QVector<float> SongPlayer::renderOffline(qreal seconds, const QVariantList &cues) const
{
    if (!loaded_) return {};
    const int rate = clay::sound::AudioOutput::instance().sampleRate();
    if (isV2()) {
        using Cue = clay::sound::SongCue;
        clay::sound::SongPerformance perf;
        perf.start = state_;
        perf.intensity = intensity_;
        for (const QVariant &v : cues) {
            const QVariantMap m = v.toMap();
            Cue c;
            c.frame = std::llround(m.value(QStringLiteral("at")).toDouble() * rate);
            if (m.contains(QStringLiteral("state"))) {
                c.kind = Cue::Kind::State;
                c.name = m.value(QStringLiteral("state")).toString();
            } else if (m.contains(QStringLiteral("intensity"))) {
                c.kind = Cue::Kind::Intensity;
                c.value = m.value(QStringLiteral("intensity")).toDouble();
            } else if (m.contains(QStringLiteral("stinger"))) {
                c.kind = Cue::Kind::Stinger;
                c.name = m.value(QStringLiteral("stinger")).toString();
            } else {
                continue;
            }
            perf.cues.append(c);
        }
        std::stable_sort(perf.cues.begin(), perf.cues.end(),
                         [](const Cue &a, const Cue &b) { return a.frame < b.frame; });
        const auto samples = clay::sound::renderSong(model_, perf, seconds, static_cast<float>(volume_),
                                                     loop_, rate, /*stereo=*/false);
        return QVector<float>(samples.begin(), samples.end());
    }
    // Every instrument the player can resolve, as the engine plays it.
    clay::sound::SongInstruments specs;
    for (auto it = nameToInstrument_.begin(); it != nameToInstrument_.end(); ++it) {
        if (auto *synth = qobject_cast<SynthInstrument *>(it.value()))
            specs.insert(it.key(), synth->spec());
        else if (auto *sampler = qobject_cast<SampleInstrument *>(it.value()))
            specs.insert(it.key(), sampler->spec());
    }
    const auto samples = clay::sound::renderSong(
        model_, specs, seconds, static_cast<float>(volume_), loop_, rate, /*stereo=*/false);
    return QVector<float>(samples.begin(), samples.end());
}

void SongPlayer::tick()
{
    if (!playing_) return;
    if (isV2()) {
        tickV2();
        return;
    }

    const qint64 nowMs  = wallClock_.elapsed();
    const qint64 dtMs   = nowMs - lastWallMs_;
    lastWallMs_ = nowMs;
    if (dtMs <= 0) return;

    const double bpm = model_.tempo > 0.0 ? model_.tempo : 120.0;
    const double beatsPerMs = bpm / 60000.0;
    const double newPos = position_ + static_cast<double>(dtMs) * beatsPerMs;

    while (nextIdx_ < schedule_.size() && schedule_[nextIdx_].beat < newPos) {
        const clay::sound::SongNote &ev = schedule_[nextIdx_];
        QObject *inst = resolveInstrument(model_.tracks.value(ev.track).instrument);
        if (inst) {
            const double durSeconds = ev.durBeats * 60.0 / bpm;
            const clay::sound::AudioOutput::TriggerGainStage stage(gainStage_);
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
    cancelInFlightReply();
    ++loadGeneration_;      // samples of an earlier load no longer count
    cancelPendingNotes();
    voices_.detach(clay::sound::AudioOutput::instance().engine());
    seq_.reset();
    anchored_ = false;
    if (!segment_.isEmpty()) {
        segment_.clear();
        emit segmentChanged();
    }

    loaded_ = false;
    schedule_.clear();
    totalBeats_ = 0.0;
    position_ = 0.0;
    nextIdx_ = 0;
    const double prevTempo = model_.tempo;
    model_ = {};

    const QUrl url = clay::sound::resolveSourceUrl(this, source_);
    if (url.isEmpty()) {
        setError(QString());
        updateWatchedFile({});
        emit loadedChanged();
        emit totalBeatsChanged();
        if (model_.tempo != prevTempo) emit tempoChanged();
        emit positionChanged();
        return;
    }

    if (clay::sound::isLocalSourceUrl(url)) {
        const QString path = clay::sound::sourceUrlToLocalPath(url);
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) {
            setError(QStringLiteral("cannot open %1").arg(path));
            updateWatchedFile({});
            emit parseError(error_);
            emit loadedChanged();
            return;
        }
        applyParsedBytes(f.readAll(), path, /*hot=*/false);
    } else {
        // Remote (http/https): async fetch. No filesystem watcher on remote.
        updateWatchedFile({});
        beginRemoteFetch(url, /*hot=*/false);
    }
}

void SongPlayer::hotReload()
{
    // Used when the source content changed (file watcher on disk, or a
    // dev-server SSE push for remote URLs). Keeps position_, rebuilds
    // schedule, clamps into new range. On parse failure keeps the
    // previous model intact so playback survives typos mid-edit.
    cancelInFlightReply();

    const QUrl url = clay::sound::resolveSourceUrl(this, source_);
    if (url.isEmpty()) return;

    if (clay::sound::isLocalSourceUrl(url)) {
        const QString path = clay::sound::sourceUrlToLocalPath(url);
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) {
            setError(QStringLiteral("cannot open %1").arg(path));
            emit parseError(error_);
            return;
        }
        applyParsedBytes(f.readAll(), path, /*hot=*/true);
    } else {
        beginRemoteFetch(url, /*hot=*/true);
    }
}

bool SongPlayer::applyParsedBytes(const QByteArray &bytes, const QString &watchPath, bool hot)
{
    const auto res = clay::sound::SongParser::parse(bytes);
    if (!res.ok) {
        setError(res.error);
        if (!hot) updateWatchedFile(watchPath);
        emit parseError(error_);
        if (!hot) emit loadedChanged();
        return false;
    }

    if (!hot) updateWatchedFile(watchPath);
    if (res.model.version >= 2) loadSamples(res.model, hot);
    else                        commitModel(res.model, hot);
    return true;
}

void SongPlayer::commitModel(const clay::sound::SongModel &model, bool hot)
{
    auto &engine = clay::sound::AudioOutput::instance().engine();
    // Where a v2 song is, so a hot reload goes on from there.
    QString keepSegment = state_;
    double keepBeat = 0.0;
    if (isV2() && seq_) {
        if (hot && anchored_) {
            const int64_t at = engine.currentFrame() - anchor_;
            keepSegment = seq_->segmentAt(at);
            keepBeat = seq_->beatAt(at);
        }
        cancelPendingNotes();
        voices_.detach(engine);
    }

    const double prevTempo = model_.tempo;
    model_ = model;
    if (isV2()) {
        schedule_.clear();
        nextIdx_ = 0;
        voices_.attach(engine, model_);
        if (!hot || !model_.segments.contains(keepSegment)) keepBeat = 0.0;
        restartSequencer(keepSegment, keepBeat);
        if (playing_) scheduleAhead();
    } else {
        seq_.reset();
        rebuildSchedule();
        if (hot) {
            // Clamp position to the new range; re-seek the cursor.
            if (position_ > totalBeats_) position_ = totalBeats_;
            auto it = std::lower_bound(
                schedule_.begin(), schedule_.end(), position_,
                [](const clay::sound::SongNote &e, double b) { return e.beat < b; });
            nextIdx_ = static_cast<int>(it - schedule_.begin());
        }
    }

    setError(QString());

    if (!loaded_) {
        loaded_ = true;
        emit loadedChanged();
    } else if (!hot) {
        // Cold reload preserves prior behavior of always emitting.
        emit loadedChanged();
    }
    if (model_.tempo != prevTempo) emit tempoChanged();
    emit totalBeatsChanged();
    emit positionChanged();
    if (hot) emit hotReloaded();
}

void SongPlayer::loadSamples(const clay::sound::SongModel &model, bool hot)
{
    const int generation = ++loadGeneration_;
    loading_ = model;
    loadHot_ = hot;
    QStringList names;
    for (auto it = model.instruments.begin(); it != model.instruments.end(); ++it)
        if (!it->sample.isEmpty()) names << it.key();
    samplesLeft_ = static_cast<int>(names.size());
    if (samplesLeft_ == 0) {
        commitModel(loading_, hot);
        return;
    }

    // A sample's file is relative to the song's.
    const QUrl base = clay::sound::resolveSourceUrl(this, source_);
    for (const QString &name : std::as_const(names)) {
        const QUrl url = base.resolved(QUrl(model.instruments.value(name).sample));
        if (clay::sound::isLocalSourceUrl(url)) {
            QFile f(clay::sound::sourceUrlToLocalPath(url));
            if (!f.open(QIODevice::ReadOnly))
                sampleArrived(generation, name, QByteArray());
            else
                sampleArrived(generation, name, f.readAll());
            if (generation != loadGeneration_) return;  // it failed, or the song is in
            continue;
        }
        if (!nam_) nam_ = new QNetworkAccessManager(this);
        QNetworkRequest req(url);
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
        QNetworkReply *reply = nam_->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, generation, name] {
            reply->deleteLater();
            sampleArrived(generation, name,
                          reply->error() == QNetworkReply::NoError ? reply->readAll() : QByteArray());
        });
    }
}

void SongPlayer::sampleArrived(int generation, const QString &instrument, const QByteArray &bytes)
{
    if (generation != loadGeneration_) return;
    std::string why = "cannot read the file";
    std::optional<clay::sound::PcmBuffer> pcm;
    if (!bytes.isEmpty())
        pcm = clay::sound::PcmBuffer::loadWavFromBytes(
            reinterpret_cast<const std::uint8_t *>(bytes.constData()),
            static_cast<std::size_t>(bytes.size()), &why);
    if (!pcm) {
        ++loadGeneration_;      // the other samples no longer matter
        setError(QStringLiteral("instruments.%1.sample: %2")
                     .arg(instrument, QString::fromStdString(why)));
        emit parseError(error_);
        if (!loadHot_) emit loadedChanged();
        return;
    }
    loading_.instruments[instrument].spec.sample =
        std::make_shared<const clay::sound::PcmBuffer>(std::move(*pcm));
    if (--samplesLeft_ == 0) commitModel(loading_, loadHot_);
}

void SongPlayer::restartSequencer(const QString &segment, double beat)
{
    const int rate = clay::sound::AudioOutput::instance().sampleRate();
    seq_ = std::make_unique<clay::sound::SongSequencer>(model_, rate, segment, beat, intensity_);
    seq_->setLoop(loop_);
    // Song frame 0 is now while it plays; otherwise play() sets it.
    anchored_ = playing_;
    if (playing_) anchor_ = clay::sound::AudioOutput::instance().engine().currentFrame();
    updateSegment(0);
}

void SongPlayer::scheduleAhead()
{
    if (!seq_ || !anchored_) return;
    auto &output = clay::sound::AudioOutput::instance();
    auto &engine = output.engine();
    const int64_t now = engine.currentFrame();
    // A note before the engine's frame has started; its ticket is spent.
    while (!pendingNotes_.empty() && pendingNotes_.front().second < now)
        pendingNotes_.pop_front();

    std::vector<clay::sound::SequencedNote> notes;
    seq_->advance(now + kScheduleAheadFrames - anchor_, notes);
    // As a v1 song's triggerNote() does, every note retries the sink.
    if (!notes.empty() && !output.isRunning()) output.start();
    for (const auto &n : notes) {
        const int64_t at = anchor_ + n.frame;
        if (const auto ticket = voices_.play(engine, n, at, gainStage_))
            pendingNotes_.emplace_back(ticket, at);
    }
}

void SongPlayer::cancelPendingNotes()
{
    // A cancelled note leaves its patch queued in its instrument until
    // the instrument goes (voices_.detach): a few entries per stop.
    auto &engine = clay::sound::AudioOutput::instance().engine();
    for (const auto &p : pendingNotes_) engine.cancel(p.first);
    pendingNotes_.clear();
}

void SongPlayer::tickV2()
{
    if (!seq_) return;
    scheduleAhead();
    const int64_t at = clay::sound::AudioOutput::instance().engine().currentFrame() - anchor_;
    updateSegment(at);
    if (seq_->ended() && at >= seq_->endFrame()) {
        playing_ = false;
        tickTimer_.stop();
        emit playingChanged();
        emit finished();
    }
}

void SongPlayer::updateSegment(int64_t songFrame)
{
    const QString segment = seq_->segmentAt(songFrame);
    const double total = clay::sound::segmentBeats(model_, segment);
    position_ = seq_->beatAt(songFrame);
    if (segment != segment_) {
        segment_ = segment;
        emit segmentChanged();
    }
    if (total != totalBeats_) {
        totalBeats_ = total;
        emit totalBeatsChanged();
    }
    emit positionChanged();
}

void SongPlayer::beginRemoteFetch(const QUrl &url, bool hot)
{
    if (!nam_) nam_ = new QNetworkAccessManager(this);
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = nam_->get(req);
    activeReply_ = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, hot] {
        // A newer fetch may have superseded this one.
        if (activeReply_.data() != reply) { reply->deleteLater(); return; }
        activeReply_.clear();
        if (reply->error() != QNetworkReply::NoError) {
            setError(QStringLiteral("network error: %1").arg(reply->errorString()));
            emit parseError(error_);
            if (!hot) emit loadedChanged();
            reply->deleteLater();
            return;
        }
        const QByteArray bytes = reply->readAll();
        reply->deleteLater();
        applyParsedBytes(bytes, /*watchPath=*/{}, hot);
    });
}

void SongPlayer::cancelInFlightReply()
{
    if (activeReply_) {
        QNetworkReply *r = activeReply_.data();
        activeReply_.clear();
        r->abort();
        r->deleteLater();
    }
}

void SongPlayer::onWatchedFileChanged(const QString &path)
{
    // Editors that save atomically remove the file; re-add after the
    // event (Qt's watcher drops the path on removal).
    updateWatchedFile(path);
    hotReload();
}

void SongPlayer::updateWatchedFile(const QString &path)
{
    if (!watchedPath_.isEmpty())
        watcher_.removePath(watchedPath_);
    watchedPath_ = path;
    if (!watchedPath_.isEmpty() && QFileInfo::exists(watchedPath_))
        watcher_.addPath(watchedPath_);
}

void SongPlayer::rebuildSchedule()
{
    schedule_ = clay::sound::songSchedule(model_, &totalBeats_);
    nextIdx_ = 0;
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
