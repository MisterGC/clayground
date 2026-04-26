// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "synth_instrument.h"

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "engine/pcm_buffer.h"

#include <QCryptographicHash>
#include <QDebug>
#include <QDir>
#include <QStandardPaths>

#include <algorithm>
#include <cmath>
#include <memory>
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
    // Register an OscillatorInstrument with the shared AudioOutput;
    // keep a raw pointer so we can push per-event patches. The engine
    // owns the instrument and will drop it (plus any active voices)
    // when we unregister in the destructor.
    auto osc = std::make_unique<cs::OscillatorInstrument>();
    oscInst_ = osc.get();
    oscInstId_ = cs::AudioOutput::instance().registerInstrument(std::move(osc));

    // Sensible default patch: short organ-like ping.
    patch_.waveform = cs::OscillatorVoice::Waveform::Sine;
    patch_.attack   = 0.005;
    patch_.decay    = 0.05;
    patch_.sustain  = 0.6;
    patch_.release  = 0.1;
    oscInst_->setDefaultPatch(patch_);
    oscInst_->setGain(static_cast<float>(volume_));

    connect(&cs::AudioOutput::instance(), &cs::AudioOutput::afterPull,
            this, &SynthInstrument::onAfterPull);
}

SynthInstrument::~SynthInstrument()
{
    if (oscInstId_ >= 0) {
        cs::AudioOutput::instance().unregisterInstrument(oscInstId_);
        oscInst_ = nullptr;
        oscInstId_ = -1;
    }
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
    if (oscInst_) oscInst_->setGain(static_cast<float>(v));
    emit volumeChanged();
}

int SynthInstrument::activeVoices() const
{
    if (oscInstId_ < 0) return 0;
    return static_cast<int>(
        cs::AudioOutput::instance().engine().activeVoices(oscInstId_));
}

void SynthInstrument::onAfterPull()
{
    const int av = activeVoices();
    if (av != lastActive_) {
        lastActive_ = av;
        emit activeVoicesChanged();
    }
}

// --- triggering --------------------------------------------------------

bool SynthInstrument::trigger(qreal freqHz, qreal velocity, qreal durationSeconds)
{
    if (freqHz <= 0.0 || durationSeconds <= 0.0) return false;
    if (!oscInst_ || oscInstId_ < 0) return false;

    auto& output = cs::AudioOutput::instance();
    output.start(); // idempotent; opens the sink on first triggered note

    auto& eng = output.engine();
    cs::NoteEvent ev;
    ev.timeFrames     = eng.currentFrame();  // fire on the next render pass
    ev.durationFrames = static_cast<int64_t>(std::llround(durationSeconds * SAMPLE_RATE));
    ev.freqHz         = freqHz;
    ev.velocity       = static_cast<float>(std::clamp(velocity, 0.0, 1.0));
    ev.instrumentId   = oscInstId_;

    const cs::EventId id = eng.schedule(ev);
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
    // Render the shared engine. Per-instrument gain is already applied
    // inside the engine; we only need a final master clamp to mirror
    // what the live sink does. Note: this is destructive — it advances
    // the shared engine's clock and consumes scheduled events. Intended
    // for tests and headless preview; production playback goes through
    // AudioOutput's pull timer, which is the only other caller.
    cs::AudioOutput::instance().engine().renderOffline(out.data(), frames);
    for (auto &s : out) s = std::clamp(s, -1.0f, 1.0f);
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

