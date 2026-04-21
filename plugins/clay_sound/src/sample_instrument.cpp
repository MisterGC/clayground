// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sample_instrument.h"

#include "engine/note_event.h"
#include "engine/pcm_buffer.h"
#include "engine/sampler_instrument.h"

#include <QAudioSink>
#include <QAudioDevice>
#include <QAudioFormat>
#include <QDebug>
#include <QMediaDevices>
#include <QQmlContext>
#include <QQmlEngine>

#include <algorithm>
#include <cmath>

namespace cs = clay::sound;

SampleInstrument::SampleInstrument(QObject *parent)
    : QObject(parent)
{
    auto core = std::make_unique<cs::SamplerInstrument>();
    core_ = core.get();
    coreId_ = engine_.addInstrument(std::move(core));

    connect(&pullTimer_, &QTimer::timeout, this, &SampleInstrument::pullBuffer);
}

SampleInstrument::~SampleInstrument()
{
    stopSink();
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
    emit volumeChanged();
}

int SampleInstrument::activeVoices() const
{
    return static_cast<int>(engine_.activeVoices());
}

void SampleInstrument::applyPatchToCore()
{
    if (core_) core_->setDefaultPatch(patch_);
}

void SampleInstrument::loadSource()
{
    if (source_.isEmpty()) {
        buffer_.reset();
        if (core_) core_->setSource(nullptr);
        if (loaded_) { loaded_ = false; emit loadedChanged(); }
        return;
    }

    std::string path = source_.isLocalFile()
                           ? source_.toLocalFile().toStdString()
                           : source_.toString().toStdString();

    std::string err;
    auto buf = cs::PcmBuffer::loadWav(path, &err);
    if (!buf) {
        buffer_.reset();
        if (core_) core_->setSource(nullptr);
        error_ = QString::fromStdString(err.empty() ? "load failed" : err);
        emit errorStringChanged();
        if (loaded_) { loaded_ = false; emit loadedChanged(); }
        return;
    }

    buffer_ = std::make_shared<cs::PcmBuffer>(std::move(*buf));
    if (core_) {
        core_->setSource(buffer_);
        core_->setRootMidiNote(rootMidiNote_);
    }
    applyPatchToCore();
    if (!loaded_) { loaded_ = true; emit loadedChanged(); }
    if (!error_.isEmpty()) { error_.clear(); emit errorStringChanged(); }
}

// --- triggering --------------------------------------------------------

bool SampleInstrument::trigger(qreal freqHz, qreal velocity, qreal durationSeconds)
{
    if (!loaded_ || !buffer_ || freqHz <= 0.0) return false;

    ensureSinkRunning();

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

    cs::NoteEvent ev;
    ev.timeFrames     = engine_.currentFrame();
    ev.durationFrames = static_cast<int64_t>(std::llround(dur * SAMPLE_RATE));
    ev.freqHz         = freqHz;
    ev.velocity       = static_cast<float>(std::clamp(velocity, 0.0, 1.0));
    ev.instrumentId   = coreId_;

    const cs::EventId id = engine_.schedule(ev);
    if (core_) core_->pushPatch(id, patch_);
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
    engine_.clearSchedule();
    engine_.resetVoices();
}

QVector<float> SampleInstrument::renderOffline(qreal durationSeconds)
{
    const int frames = std::max(0, static_cast<int>(std::llround(durationSeconds * SAMPLE_RATE)));
    QVector<float> out(frames, 0.0f);
    if (frames == 0) return out;
    engine_.renderOffline(out.data(), frames);
    const float v = static_cast<float>(volume_);
    for (auto &s : out) s = std::clamp(s * v, -1.0f, 1.0f);
    return out;
}

// --- audio plumbing ----------------------------------------------------

void SampleInstrument::ensureSinkRunning()
{
    if (sinkRunning_) return;

    QAudioFormat fmt;
    fmt.setSampleRate(SAMPLE_RATE);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Float);

    QAudioDevice outputDevice = QMediaDevices::defaultAudioOutput();
    if (outputDevice.isNull()) {
        qWarning() << "SampleInstrument: no audio output device";
        return;
    }

    delete sink_;
    sink_ = new QAudioSink(outputDevice, fmt, this);
    sink_->setBufferSize(SAMPLE_RATE * sizeof(float) / 5);
    device_ = sink_->start();
    if (!device_) {
        qWarning() << "SampleInstrument: failed to start audio sink";
        delete sink_;
        sink_ = nullptr;
        return;
    }

    sinkRunning_ = true;
    pullTimer_.start(BUFFER_MS);
}

void SampleInstrument::stopSink()
{
    if (!sinkRunning_) return;
    sinkRunning_ = false;
    pullTimer_.stop();
    if (sink_) {
        sink_->stop();
        delete sink_;
        sink_ = nullptr;
        device_ = nullptr;
    }
}

void SampleInstrument::pullBuffer()
{
    if (!sinkRunning_ || !sink_ || !device_) return;

    const int bytesFree = sink_->bytesFree();
    int frames = bytesFree / static_cast<int>(sizeof(float));
    if (frames <= 0) return;
    frames = std::min(frames, SAMPLE_RATE);

    QVector<float> buf(frames, 0.0f);
    engine_.renderOffline(buf.data(), frames);

    const float v = static_cast<float>(volume_);
    for (auto &s : buf) s = std::clamp(s * v, -1.0f, 1.0f);

    const char *data = reinterpret_cast<const char *>(buf.data());
    qint64 bytesToWrite = frames * static_cast<qint64>(sizeof(float));
    qint64 written = 0;
    while (written < bytesToWrite) {
        qint64 c = device_->write(data + written, bytesToWrite - written);
        if (c <= 0) break;
        written += c;
    }

    const int av = activeVoices();
    if (av != lastActive_) {
        // Edge-detect finish: went from >0 to 0.
        if (av == 0 && lastActive_ > 0)
            emit playbackFinished();
        lastActive_ = av;
        emit activeVoicesChanged();
    }
}
