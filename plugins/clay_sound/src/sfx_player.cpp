// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sfx_player.h"

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/pcm_buffer.h"
#include "sfx/sfx_parser.h"
#include "source_url.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

#include <algorithm>

namespace cs = clay::sound;

namespace {

// How far ahead of the engine a loop's passes are scheduled, and how
// often that is topped up: a pass is in the engine long before its
// frame comes, so a busy GUI thread does not open a gap at the seam.
constexpr double kLoopAheadSeconds = 1.0;
constexpr int    kLoopTopUpMs = 100;

} // namespace

SfxPlayer::SfxPlayer(QObject *parent)
    : QObject(parent)
{
    connect(&watcher_, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) {
        // Editors that save atomically remove the file; re-add after the
        // event (Qt's watcher drops the path on removal).
        updateWatchedFile(path);
        load(/*hot=*/true);
    });
    loopTimer_.setInterval(kLoopTopUpMs);
    connect(&loopTimer_, &QTimer::timeout, this, &SfxPlayer::scheduleLoopPasses);
}

SfxPlayer::~SfxPlayer()
{
    cancelFetches();
    voices_.detach(cs::AudioOutput::instance().engine());
}

void SfxPlayer::setSource(const QUrl &url)
{
    if (source_ == url) return;
    source_ = url;
    emit sourceChanged();
    load(/*hot=*/false);
}

void SfxPlayer::setVolume(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (volume_ == v) return;
    volume_ = v;
    voices_.setGain(static_cast<float>(v));
    emit volumeChanged();
}

void SfxPlayer::setPan(qreal v)
{
    v = std::clamp(v, -1.0, 1.0);
    if (pan_ == v) return;
    pan_ = v;
    voices_.setPan(static_cast<float>(v));
    emit panChanged();
}

QString SfxPlayer::bus() const
{
    return cs::AudioOutput::busName(bus_);
}

void SfxPlayer::setBus(const QString &name)
{
    cs::Bus b = bus_;
    if (!cs::AudioOutput::busFromName(name, b)) {
        qWarning() << "SfxPlayer: unknown bus" << name << "- use sfx, music or voice";
        return;
    }
    if (b == bus_) return;
    bus_ = b;
    voices_.setBus(b);
    emit busChanged();
}

void SfxPlayer::setLoop(bool on)
{
    if (loop_ == on) return;
    loop_ = on;
    emit loopChanged();
}

// --- playing -------------------------------------------------------------

int SfxPlayer::play(qreal velocity, qreal detune)
{
    if (!loaded_) return -1;
    const int seed = variationSeed(plays_++);
    playSeed(seed, velocity, detune);
    return seed;
}

bool SfxPlayer::playSeed(int seed, qreal velocity, qreal detune)
{
    if (!loaded_) return false;
    auto &output = cs::AudioOutput::instance();
    output.start(); // idempotent; opens the sink on the first played effect
    auto &eng = output.engine();
    // A new play of a looping player replaces the loop that plays.
    if (looping_) stop();
    auto notes = cs::realizeSfx(recipe_, static_cast<uint32_t>(seed), detune);
    const float v = static_cast<float>(std::clamp(velocity, 0.0, 1.0));
    const int64_t at = eng.currentFrame();
    const auto span = voices_.play(eng, notes, at, v, output.triggerGainStage());
    if (loop_ && span.period > 0) {
        looping_ = true;
        loopNotes_ = std::move(notes);
        loopVelocity_ = v;
        loopDetune_ = detune;
        loopGainStage_ = output.triggerGainStage();
        loopPeriod_ = span.period;
        loopNext_ = at + span.period;
        scheduleLoopPasses();
        loopTimer_.start();
    }
    if (lastSeed_ != seed) {
        lastSeed_ = seed;
        emit lastSeedChanged();
    }
    return true;
}

void SfxPlayer::stop()
{
    endLoop();
    voices_.stop(cs::AudioOutput::instance().engine());
}

void SfxPlayer::endLoop()
{
    looping_ = false;
    loopTimer_.stop();
    loopNotes_.clear();
}

void SfxPlayer::scheduleLoopPasses()
{
    if (!looping_) return;
    auto &eng = cs::AudioOutput::instance().engine();
    const int64_t now = eng.currentFrame();
    const int64_t ahead = now + std::llround(kLoopAheadSeconds * eng.sampleRate());
    // A pass whose frame has gone by (the engine outran the timer) is
    // skipped, never played late: the loop stays on its grid.
    if (loopNext_ < now)
        loopNext_ += (now - loopNext_ + loopPeriod_ - 1) / loopPeriod_ * loopPeriod_;
    for (; loopNext_ <= ahead; loopNext_ += loopPeriod_)
        voices_.play(eng, loopNotes_, loopNext_, loopVelocity_, loopGainStage_);
}

int SfxPlayer::variationSeed(int index) const
{
    return static_cast<int>(cs::sfxVariationSeed(recipe_, std::max(0, index)));
}

QVector<float> SfxPlayer::renderOffline(int seed, qreal velocity, qreal detune, int passes) const
{
    if (!loaded_) return {};
    const auto samples = cs::renderRecipe(recipe_, samples_, static_cast<uint32_t>(seed),
                                          static_cast<float>(std::clamp(velocity, 0.0, 1.0)),
                                          static_cast<float>(volume_), static_cast<float>(pan_),
                                          cs::AudioOutput::instance().sampleRate(), /*stereo=*/false,
                                          /*seconds=*/0.0, detune,
                                          loop_ ? std::max(1, passes) : 0);
    return QVector<float>(samples.begin(), samples.end());
}

// --- loading -------------------------------------------------------------

void SfxPlayer::load(bool hot)
{
    cancelFetches();
    const int generation = ++generation_;
    pending_ = {};

    const QUrl url = cs::resolveSourceUrl(this, source_);
    if (url.isEmpty()) {
        endLoop();
        voices_.detach(cs::AudioOutput::instance().engine());
        recipe_ = {};
        samples_.clear();
        updateWatchedFile({});
        setError({});
        if (loaded_) { loaded_ = false; emit loadedChanged(); }
        emit recipeChanged();
        return;
    }

    if (cs::isLocalSourceUrl(url)) {
        const QString path = cs::sourceUrlToLocalPath(url);
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) {
            failLoad(QStringLiteral("cannot open %1").arg(path), hot, hot ? QString() : path);
            return;
        }
        onRecipeBytes(f.readAll(), url, path, hot);
        return;
    }

    // Remote (http/https): async fetch, nothing to watch.
    if (!hot) updateWatchedFile({});
    QNetworkReply *reply = fetch(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply, url, hot, generation] {
        reply->deleteLater();
        if (generation != generation_) return;
        if (reply->error() != QNetworkReply::NoError) {
            failLoad(QStringLiteral("network error: %1").arg(reply->errorString()), hot, {});
            return;
        }
        onRecipeBytes(reply->readAll(), url, {}, hot);
    });
}

void SfxPlayer::onRecipeBytes(const QByteArray &bytes, const QUrl &baseUrl,
                              const QString &watchPath, bool hot)
{
    const auto res = cs::SfxParser::parse(bytes);
    if (!res.ok) {
        failLoad(res.error, hot, watchPath);
        return;
    }

    pending_ = {};
    pending_.generation = generation_;
    pending_.hot = hot;
    pending_.watchPath = watchPath;
    pending_.recipe = res.recipe;
    pending_.samples.resize(res.recipe.layers.size());

    // A sample path is relative to the recipe file.
    QList<int> sampleLayers;
    for (int i = 0; i < res.recipe.layers.size(); ++i)
        if (res.recipe.layers[i].source == cs::SfxSource::Sample) sampleLayers << i;
    pending_.remaining = static_cast<int>(sampleLayers.size());

    const int generation = generation_;
    for (int i : std::as_const(sampleLayers)) {
        const QUrl url = baseUrl.resolved(QUrl(res.recipe.layers[i].sample));
        const QString what = QStringLiteral("layers[%1].sample").arg(i);
        if (cs::isLocalSourceUrl(url)) {
            QFile f(cs::sourceUrlToLocalPath(url));
            if (!f.open(QIODevice::ReadOnly)) {
                failLoad(QStringLiteral("%1: cannot open %2").arg(what, f.fileName()), hot, watchPath);
                return;
            }
            sampleArrived(generation, i, f.readAll(), what);
            if (generation != generation_ || pending_.generation != generation) return;
        } else {
            QNetworkReply *reply = fetch(url);
            connect(reply, &QNetworkReply::finished, this, [this, reply, generation, i, what, hot, watchPath] {
                reply->deleteLater();
                if (generation != generation_) return;
                if (reply->error() != QNetworkReply::NoError) {
                    failLoad(QStringLiteral("%1: network error: %2").arg(what, reply->errorString()),
                             hot, watchPath);
                    return;
                }
                sampleArrived(generation, i, reply->readAll(), what);
                if (pending_.generation == generation && pending_.remaining == 0) finishLoad();
            });
        }
    }
    if (pending_.generation == generation && pending_.remaining == 0) finishLoad();
}

void SfxPlayer::sampleArrived(int generation, int layer, const QByteArray &bytes, const QString &what)
{
    if (generation != generation_ || pending_.generation != generation) return;
    std::string why;
    auto pcm = cs::PcmBuffer::loadWavFromBytes(reinterpret_cast<const std::uint8_t *>(bytes.constData()),
                                               static_cast<std::size_t>(bytes.size()), &why);
    if (!pcm) {
        failLoad(QStringLiteral("%1: %2").arg(what, QString::fromStdString(why)),
                 pending_.hot, pending_.watchPath);
        return;
    }
    pending_.samples[layer] = std::make_shared<const cs::PcmBuffer>(std::move(*pcm));
    --pending_.remaining;
}

void SfxPlayer::finishLoad()
{
    const Pending done = std::move(pending_);
    pending_ = {};

    auto &eng = cs::AudioOutput::instance().engine();
    // The loop's notes belong to the recipe it drew them from; a new
    // source starts silent, a hot reload of a looping player is heard
    // below as the new recipe looping on.
    const bool relooping = looping_ && done.hot;
    const qreal velocity = loopVelocity_;
    const qreal detune = loopDetune_;
    endLoop();
    recipe_ = done.recipe;
    samples_ = done.samples;
    voices_.attach(eng, recipe_, samples_);
    voices_.setGain(static_cast<float>(volume_));
    voices_.setPan(static_cast<float>(pan_));
    voices_.setBus(bus_);
    if (!done.hot) {
        plays_ = 0;
        updateWatchedFile(done.watchPath);
    }

    setError({});
    emit recipeChanged();
    if (!loaded_) {
        loaded_ = true;
        emit loadedChanged();
    }
    if (relooping && loop_) playSeed(lastSeed_, velocity, detune);
    if (done.hot) emit hotReloaded();
}

void SfxPlayer::failLoad(const QString &message, bool hot, const QString &watchPath)
{
    // A hot reload that fails keeps playing the last good recipe; a
    // cold one has none.
    cancelFetches();
    ++generation_;
    pending_ = {};
    setError(message);
    if (!hot) {
        updateWatchedFile(watchPath);
        endLoop();
        voices_.detach(cs::AudioOutput::instance().engine());
        recipe_ = {};
        samples_.clear();
        emit recipeChanged();
        if (loaded_) { loaded_ = false; emit loadedChanged(); }
    }
    emit parseError(message);
}

QNetworkReply *SfxPlayer::fetch(const QUrl &url)
{
    if (!nam_) nam_ = new QNetworkAccessManager(this);
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = nam_->get(req);
    replies_.append(reply);
    return reply;
}

void SfxPlayer::cancelFetches()
{
    const auto replies = std::exchange(replies_, {});
    for (const auto &r : replies) {
        if (!r) continue;
        r->disconnect(this);
        r->abort();
        r->deleteLater();
    }
}

void SfxPlayer::setError(const QString &err)
{
    if (error_ == err) return;
    error_ = err;
    emit errorChanged();
}

void SfxPlayer::updateWatchedFile(const QString &path)
{
    if (!watchedPath_.isEmpty())
        watcher_.removePath(watchedPath_);
    watchedPath_ = path;
    if (!watchedPath_.isEmpty() && QFileInfo::exists(watchedPath_))
        watcher_.addPath(watchedPath_);
}
