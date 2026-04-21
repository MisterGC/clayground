// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "synth_instrument.h"

#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "engine/pcm_buffer.h"

#include <QAudioSink>
#include <QAudioDevice>
#include <QAudioFormat>
#include <QCryptographicHash>
#include <QDebug>
#include <QDir>
#include <QMediaDevices>
#include <QStandardPaths>

#include <algorithm>
#include <cmath>
#include <vector>

namespace cs = clay::sound;

static cs::OscillatorVoice::Waveform mapWaveform(const QString &name)
{
    using W = cs::OscillatorVoice::Waveform;
    if (name == "sine")     return W::Sine;
    if (name == "square")   return W::Square;
    if (name == "triangle") return W::Triangle;
    if (name == "sawtooth") return W::Sawtooth;
    if (name == "noise")    return W::Noise;
    return W::Sine;
}

static int mapLfoTarget(const QString &name)
{
    if (name == "pitch")  return 1;
    if (name == "volume") return 2;
    return 0;
}

SynthInstrument::SynthInstrument(QObject *parent)
    : QObject(parent)
{
    // Register an OscillatorInstrument with the engine; keep a raw
    // pointer so we can push per-event patches.
    auto osc = std::make_unique<cs::OscillatorInstrument>();
    oscInst_ = osc.get();
    oscInstId_ = engine_.addInstrument(std::move(osc));

    // Sensible default patch: short organ-like ping.
    patch_.waveform = cs::OscillatorVoice::Waveform::Sine;
    patch_.attack   = 0.005;
    patch_.decay    = 0.05;
    patch_.sustain  = 0.6;
    patch_.release  = 0.1;
    oscInst_->setDefaultPatch(patch_);

    connect(&pullTimer_, &QTimer::timeout, this, &SynthInstrument::pullBuffer);
}

SynthInstrument::~SynthInstrument()
{
    stopSink();
}

// --- property setters --------------------------------------------------

void SynthInstrument::setWaveform(const QString &w)
{
    if (w == waveformName_) return;
    waveformName_ = w;
    patch_.waveform = mapWaveform(w);
    oscInst_->setDefaultPatch(patch_);
    emit waveformChanged();
}

void SynthInstrument::setAttack(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.attack == v) return;
    patch_.attack = v;
    oscInst_->setDefaultPatch(patch_);
    emit attackChanged();
}

void SynthInstrument::setDecay(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.decay == v) return;
    patch_.decay = v;
    oscInst_->setDefaultPatch(patch_);
    emit decayChanged();
}

void SynthInstrument::setSustain(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (patch_.sustain == v) return;
    patch_.sustain = v;
    oscInst_->setDefaultPatch(patch_);
    emit sustainChanged();
}

void SynthInstrument::setRelease(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.release == v) return;
    patch_.release = v;
    oscInst_->setDefaultPatch(patch_);
    emit releaseChanged();
}

void SynthInstrument::setPitchStart(qreal v)
{
    if (patch_.pitchStart == v) return;
    patch_.pitchStart = v;
    oscInst_->setDefaultPatch(patch_);
    emit pitchStartChanged();
}

void SynthInstrument::setPitchEnd(qreal v)
{
    if (patch_.pitchEnd == v) return;
    patch_.pitchEnd = v;
    oscInst_->setDefaultPatch(patch_);
    emit pitchEndChanged();
}

void SynthInstrument::setPitchTime(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.pitchTime == v) return;
    patch_.pitchTime = v;
    oscInst_->setDefaultPatch(patch_);
    emit pitchTimeChanged();
}

void SynthInstrument::setLfoRate(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.lfoRate == v) return;
    patch_.lfoRate = v;
    oscInst_->setDefaultPatch(patch_);
    emit lfoRateChanged();
}

void SynthInstrument::setLfoDepth(qreal v)
{
    v = std::max(0.0, v);
    if (patch_.lfoDepth == v) return;
    patch_.lfoDepth = v;
    oscInst_->setDefaultPatch(patch_);
    emit lfoDepthChanged();
}

void SynthInstrument::setLfoTarget(const QString &t)
{
    if (t == lfoTargetName_) return;
    lfoTargetName_ = t;
    patch_.lfoTarget = mapLfoTarget(t);
    oscInst_->setDefaultPatch(patch_);
    emit lfoTargetChanged();
}

void SynthInstrument::setVolume(qreal v)
{
    v = std::clamp(v, 0.0, 1.0);
    if (volume_ == v) return;
    volume_ = v;
    emit volumeChanged();
}

int SynthInstrument::activeVoices() const
{
    return static_cast<int>(engine_.activeVoices());
}

// --- triggering --------------------------------------------------------

bool SynthInstrument::trigger(qreal freqHz, qreal velocity, qreal durationSeconds)
{
    if (freqHz <= 0.0 || durationSeconds <= 0.0) return false;

    ensureSinkRunning();

    cs::NoteEvent ev;
    ev.timeFrames     = engine_.currentFrame();  // fire on the next render pass
    ev.durationFrames = static_cast<int64_t>(std::llround(durationSeconds * SAMPLE_RATE));
    ev.freqHz         = freqHz;
    ev.velocity       = static_cast<float>(std::clamp(velocity, 0.0, 1.0));
    ev.instrumentId   = oscInstId_;

    const cs::EventId id = engine_.schedule(ev);
    oscInst_->pushPatch(id, patch_);
    return true;
}

bool SynthInstrument::triggerNote(int midiNote, qreal velocity, qreal durationSeconds)
{
    const qreal freq = 440.0 * std::pow(2.0, (midiNote - 69) / 12.0);
    return trigger(freq, velocity, durationSeconds);
}

QVector<float> SynthInstrument::renderOffline(qreal durationSeconds)
{
    const int frames = std::max(0, static_cast<int>(std::llround(durationSeconds * SAMPLE_RATE)));
    QVector<float> out(frames, 0.0f);
    if (frames == 0) return out;
    engine_.renderOffline(out.data(), frames);
    const float v = static_cast<float>(volume_);
    for (auto &s : out) s = std::clamp(s * v, -1.0f, 1.0f);
    return out;
}

std::vector<float> SynthInstrument::renderScratch(int midiNote,
                                                  qreal durationSeconds,
                                                  qreal velocity) const
{
    const int frames = std::max(0, static_cast<int>(std::llround(durationSeconds * SAMPLE_RATE)));
    std::vector<float> out(static_cast<size_t>(frames), 0.0f);
    if (frames == 0) return out;
    if (midiNote < 0 || midiNote > 127) return out;

    cs::Engine scratch(SAMPLE_RATE);
    auto osc = std::make_unique<cs::OscillatorInstrument>();
    auto *oscPtr = osc.get();
    const int instId = scratch.addInstrument(std::move(osc));

    cs::NoteEvent ev;
    ev.instrumentId   = instId;
    ev.timeFrames     = scratch.currentFrame();
    ev.durationFrames = static_cast<int64_t>(std::llround(durationSeconds * SAMPLE_RATE));
    ev.freqHz         = 440.0 * std::pow(2.0, (midiNote - 69) / 12.0);
    ev.velocity       = static_cast<float>(std::clamp<qreal>(velocity, 0.0, 1.0));
    const cs::EventId id = scratch.schedule(ev);
    oscPtr->pushPatch(id, patch_);

    scratch.renderOffline(out.data(), frames);
    const float v = static_cast<float>(volume_);
    for (auto &s : out) s = std::clamp(s * v, -1.0f, 1.0f);
    return out;
}

QVector<float> SynthInstrument::renderPatchPreview(int midiNote,
                                                   qreal durationSeconds,
                                                   qreal velocity)
{
    const auto vec = renderScratch(midiNote, durationSeconds, velocity);
    QVector<float> out;
    out.reserve(static_cast<int>(vec.size()));
    for (float s : vec) out.append(s);
    return out;
}

QString SynthInstrument::bake(int midiNote, qreal durationSeconds, qreal velocity)
{
    if (durationSeconds <= 0.0) return {};
    if (midiNote < 0 || midiNote > 127) return {};

    // Deterministic filename from patch + note + duration so repeated
    // bakes of the same inputs reuse the same cached WAV.
    QByteArray signature;
    signature += waveformName_.toUtf8() + '|';
    signature += QByteArray::number(patch_.attack,     'g', 6) + '|';
    signature += QByteArray::number(patch_.decay,      'g', 6) + '|';
    signature += QByteArray::number(patch_.sustain,    'g', 6) + '|';
    signature += QByteArray::number(patch_.release,    'g', 6) + '|';
    signature += QByteArray::number(patch_.pitchStart, 'g', 6) + '|';
    signature += QByteArray::number(patch_.pitchEnd,   'g', 6) + '|';
    signature += QByteArray::number(patch_.pitchTime,  'g', 6) + '|';
    signature += QByteArray::number(patch_.lfoRate,    'g', 6) + '|';
    signature += QByteArray::number(patch_.lfoDepth,   'g', 6) + '|';
    signature += lfoTargetName_.toUtf8() + '|';
    signature += QByteArray::number(midiNote) + '|';
    signature += QByteArray::number(durationSeconds, 'g', 6) + '|';
    signature += QByteArray::number(velocity, 'g', 6);
    const QString hash = QCryptographicHash::hash(
        signature, QCryptographicHash::Sha1).toHex().left(16);

    const QString cacheRoot = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    const QString cacheDir  = QDir(cacheRoot).filePath("clay_sound/bakes");
    if (!QDir().mkpath(cacheDir)) {
        qWarning() << "SynthInstrument::bake: cannot create" << cacheDir;
        return {};
    }
    const QString path = QDir(cacheDir).filePath(QStringLiteral("%1.wav").arg(hash));
    if (QFileInfo::exists(path)) return path; // cache hit

    auto samples = renderScratch(midiNote, durationSeconds, velocity);
    if (samples.empty()) return {};

    const auto pcm = cs::PcmBuffer::fromFloats(std::move(samples), SAMPLE_RATE);
    std::string err;
    if (!pcm.saveWav(path.toStdString(), &err)) {
        qWarning() << "SynthInstrument::bake: saveWav failed:" << QString::fromStdString(err);
        return {};
    }
    return path;
}

// --- audio plumbing ----------------------------------------------------

void SynthInstrument::ensureSinkRunning()
{
    if (sinkRunning_) return;

    QAudioFormat fmt;
    fmt.setSampleRate(SAMPLE_RATE);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Float);

    QAudioDevice outputDevice = QMediaDevices::defaultAudioOutput();
    if (outputDevice.isNull()) {
        qWarning() << "SynthInstrument: no audio output device";
        return;
    }

    delete sink_;
    sink_ = new QAudioSink(outputDevice, fmt, this);
    sink_->setBufferSize(SAMPLE_RATE * sizeof(float) / 5); // 200ms
    device_ = sink_->start();
    if (!device_) {
        qWarning() << "SynthInstrument: failed to start audio sink";
        delete sink_;
        sink_ = nullptr;
        return;
    }

    sinkRunning_ = true;
    pullTimer_.start(BUFFER_MS);
}

void SynthInstrument::stopSink()
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

void SynthInstrument::pullBuffer()
{
    if (!sinkRunning_ || !sink_ || !device_) return;

    const int bytesFree = sink_->bytesFree();
    int frames = bytesFree / static_cast<int>(sizeof(float));
    if (frames <= 0) return;
    frames = std::min(frames, SAMPLE_RATE); // cap 1s

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
        lastActive_ = av;
        emit activeVoicesChanged();
    }
}
