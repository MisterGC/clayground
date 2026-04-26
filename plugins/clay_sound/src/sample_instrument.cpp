// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sample_instrument.h"

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/note_event.h"
#include "engine/pcm_buffer.h"
#include "engine/sampler_instrument.h"

#include <QDebug>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QQmlContext>
#include <QQmlEngine>

#include <algorithm>
#include <cmath>
#include <vector>

namespace cs = clay::sound;

namespace {

bool isLocalScheme(const QUrl &url)
{
    if (url.isEmpty()) return true;
    if (url.isLocalFile()) return true;
    const auto s = url.scheme();
    return s.isEmpty()
        || s == QLatin1String("file")
        || s == QLatin1String("qrc");
}

QString urlToLocalPath(const QUrl &url)
{
    if (url.isLocalFile()) return url.toLocalFile();
    if (url.scheme() == QLatin1String("qrc")) return QStringLiteral(":") + url.path();
    return url.toString();
}

} // namespace

SampleInstrument::SampleInstrument(QObject *parent)
    : QObject(parent)
{
    auto core = std::make_unique<cs::SamplerInstrument>();
    core_ = core.get();
    coreId_ = cs::AudioOutput::instance().registerInstrument(std::move(core));
    if (core_) core_->setGain(static_cast<float>(volume_));

    connect(&cs::AudioOutput::instance(), &cs::AudioOutput::afterPull,
            this, &SampleInstrument::onAfterPull);
}

SampleInstrument::~SampleInstrument()
{
    cancelInFlightReply();
    if (coreId_ >= 0) {
        cs::AudioOutput::instance().unregisterInstrument(coreId_);
        core_ = nullptr;
        coreId_ = -1;
    }
}

// --- property setters --------------------------------------------------

void SampleInstrument::setSource(const QUrl &url)
{
    // QML auto-resolves relative URLs for C++ Q_PROPERTY QUrl — but
    // only in some type-binding paths. Inherited properties and
    // property-aliased paths can slip through with relative URLs.
    // Resolve defensively using the object's QML context.
    QUrl resolved = url;
    if (resolved.isRelative()) {
        if (QQmlContext *ctx = QQmlEngine::contextForObject(this))
            resolved = ctx->resolvedUrl(url);
    }
    if (source_ == resolved) return;
    source_ = resolved;
    emit sourceChanged();
    loadSource();
}

void SampleInstrument::setRootNote(int n)
{
    n = std::clamp(n, 0, 127);
    if (rootMidiNote_ == n) return;
    rootMidiNote_ = n;
    if (core_) core_->setRootMidiNote(n);
    emit rootNoteChanged();
}

void SampleInstrument::setLooping(bool v)
{
    if (patch_.looping == v) return;
    patch_.looping = v;
    applyPatchToCore();
    emit loopingChanged();
}

void SampleInstrument::setLoopStart(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (patch_.loopStartFrac == v) return;
    patch_.loopStartFrac = v;
    applyPatchToCore();
    emit loopStartChanged();
}

void SampleInstrument::setLoopEnd(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (patch_.loopEndFrac == v) return;
    patch_.loopEndFrac = v;
    applyPatchToCore();
    emit loopEndChanged();
}

void SampleInstrument::setAttack(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.attack == v) return;
    patch_.attack = v;
    applyPatchToCore();
    emit attackChanged();
}

void SampleInstrument::setRelease(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.release == v) return;
    patch_.release = v;
    applyPatchToCore();
    emit releaseChanged();
}

void SampleInstrument::setVolume(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (volume_ == v) return;
    volume_ = v;
    if (core_) core_->setGain(static_cast<float>(v));
    emit volumeChanged();
}

int SampleInstrument::activeVoices() const
{
    if (coreId_ < 0) return 0;
    return static_cast<int>(
        cs::AudioOutput::instance().engine().activeVoices(coreId_));
}

void SampleInstrument::onAfterPull()
{
    const int av = activeVoices();
    if (av != lastActive_) {
        if (av == 0 && lastActive_ > 0)
            emit playbackFinished();
        lastActive_ = av;
        emit activeVoicesChanged();
    }
}

void SampleInstrument::applyPatchToCore()
{
    if (core_) core_->setDefaultPatch(patch_);
}

void SampleInstrument::loadSource()
{
    cancelInFlightReply();

    if (source_.isEmpty()) {
        buffer_.reset();
        if (core_) core_->setSource(nullptr);
        if (loaded_) { loaded_ = false; emit loadedChanged(); }
        return;
    }

    if (isLocalScheme(source_)) {
        // Synchronous file/qrc read keeps prior desktop semantics —
        // load completes before this function returns.
        const QString path = urlToLocalPath(source_);
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) {
            buffer_.reset();
            if (core_) core_->setSource(nullptr);
            error_ = QStringLiteral("cannot open %1").arg(path);
            emit errorStringChanged();
            if (loaded_) { loaded_ = false; emit loadedChanged(); }
            return;
        }
        applyLoadedBytes(f.readAll());
    } else {
        // http(s) (or any non-local) — fetch via QNetworkAccessManager.
        // Required on WASM where the source URL points at the dev/CDN
        // origin and QFile can't open it. While the fetch is in flight
        // `loaded_` stays false, mirroring lazyLoading semantics.
        beginRemoteFetch(source_);
    }
}

bool SampleInstrument::applyLoadedBytes(const QByteArray &bytes)
{
    std::string err;
    auto buf = cs::PcmBuffer::loadWavFromBytes(
        reinterpret_cast<const std::uint8_t *>(bytes.constData()),
        static_cast<std::size_t>(bytes.size()),
        &err);
    if (!buf) {
        buffer_.reset();
        if (core_) core_->setSource(nullptr);
        error_ = QString::fromStdString(err.empty() ? "load failed" : err);
        emit errorStringChanged();
        if (loaded_) { loaded_ = false; emit loadedChanged(); }
        return false;
    }

    buffer_ = std::make_shared<cs::PcmBuffer>(std::move(*buf));
    if (core_) {
        core_->setSource(buffer_);
        core_->setRootMidiNote(rootMidiNote_);
    }
    applyPatchToCore();
    if (!loaded_) { loaded_ = true; emit loadedChanged(); }
    if (!error_.isEmpty()) { error_.clear(); emit errorStringChanged(); }
    return true;
}

void SampleInstrument::beginRemoteFetch(const QUrl &url)
{
    if (!nam_) nam_ = new QNetworkAccessManager(this);
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = nam_->get(req);
    activeReply_ = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        // A newer fetch (e.g. setSource() called again) may have superseded
        // this one — drop the stale reply silently.
        if (activeReply_.data() != reply) { reply->deleteLater(); return; }
        activeReply_.clear();
        if (reply->error() != QNetworkReply::NoError) {
            buffer_.reset();
            if (core_) core_->setSource(nullptr);
            error_ = QStringLiteral("network error: %1").arg(reply->errorString());
            emit errorStringChanged();
            if (loaded_) { loaded_ = false; emit loadedChanged(); }
            reply->deleteLater();
            return;
        }
        const QByteArray bytes = reply->readAll();
        reply->deleteLater();
        applyLoadedBytes(bytes);
    });
}

void SampleInstrument::cancelInFlightReply()
{
    if (activeReply_) {
        QNetworkReply *r = activeReply_.data();
        activeReply_.clear();
        r->abort();
        r->deleteLater();
    }
}

// --- triggering --------------------------------------------------------

bool SampleInstrument::trigger(qreal freqHz, qreal velocity, qreal durationSeconds)
{
    if (!loaded_ || !buffer_ || freqHz <= 0.0) return false;
    if (!core_ || coreId_ < 0) return false;

    auto& output = cs::AudioOutput::instance();
    output.start(); // idempotent; opens sink on first triggered note

    // If durationSeconds is 0, derive from the sample length (adjusted
    // for playback rate). For looping voices we still cap at 60s so
    // the scheduler has an end frame; loops can be retriggered beyond.
    double dur = durationSeconds;
    if (dur <= 0.0) {
        if (patch_.looping) {
            dur = 60.0;
        } else {
            const double rootFreq = 440.0 * std::pow(2.0, (rootMidiNote_ - 69) / 12.0);
            const double rate = (buffer_->sampleRate / static_cast<double>(SAMPLE_RATE))
                                * (freqHz / (rootFreq > 0.0 ? rootFreq : 1.0));
            const double frames = static_cast<double>(buffer_->frames())
                                  / (rate > 0.0 ? rate : 1.0);
            dur = frames / static_cast<double>(SAMPLE_RATE);
        }
    }

    auto& eng = output.engine();
    cs::NoteEvent ev;
    ev.timeFrames     = eng.currentFrame();
    ev.durationFrames = static_cast<int64_t>(std::llround(dur * SAMPLE_RATE));
    ev.freqHz         = freqHz;
    ev.velocity       = static_cast<float>(std::clamp(velocity, 0.0, 1.0));
    ev.instrumentId   = coreId_;

    const cs::EventId id = eng.schedule(ev);
    core_->pushPatch(id, patch_);
    return true;
}

bool SampleInstrument::triggerNote(int midiNote, qreal velocity, qreal durationSeconds)
{
    const qreal freq = 440.0 * std::pow(2.0, (midiNote - 69) / 12.0);
    return trigger(freq, velocity, durationSeconds);
}

bool SampleInstrument::triggerOneShot(qreal velocity)
{
    const qreal rootFreq = 440.0 * std::pow(2.0, (rootMidiNote_ - 69) / 12.0);
    return trigger(rootFreq, velocity, 0.0);
}

void SampleInstrument::stopAll()
{
    // Clear schedule + drop voices for THIS instrument only. The shared
    // engine's schedule is global, but voices are reaped if their owning
    // instrument is unregistered/re-registered. Cheaper here: just drop
    // the patches we still have queued and re-register the SamplerInstrument
    // to drop active voices.
    if (core_) core_->clearPatches();
    if (coreId_ >= 0) {
        // unregister/register cycle drops active voices for this instrument
        // without disturbing the shared engine clock.
        cs::AudioOutput::instance().unregisterInstrument(coreId_);
        auto core = std::make_unique<cs::SamplerInstrument>();
        core_ = core.get();
        coreId_ = cs::AudioOutput::instance().registerInstrument(std::move(core));
        if (core_) {
            core_->setGain(static_cast<float>(volume_));
            if (buffer_) {
                core_->setSource(buffer_);
                core_->setRootMidiNote(rootMidiNote_);
            }
            core_->setDefaultPatch(patch_);
        }
    }
}

QVector<float> SampleInstrument::renderOffline(qreal durationSeconds)
{
    const int frames = std::max(0, static_cast<int>(std::llround(durationSeconds * SAMPLE_RATE)));
    QVector<float> out(frames, 0.0f);
    if (frames == 0) return out;
    // Per-instrument gain is applied inside the engine; we only need a
    // final master clamp. See note in SynthInstrument::renderOffline.
    cs::AudioOutput::instance().engine().renderOffline(out.data(), frames);
    for (auto &s : out) s = std::clamp(s, -1.0f, 1.0f);
    return out;
}

