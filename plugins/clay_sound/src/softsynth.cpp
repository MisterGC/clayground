// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "softsynth.h"

#include "engine/note_event.h"
#include "engine/oscillator_voice.h"

#include <QAudioSink>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QDebug>
#include <algorithm>
#include <cmath>
#include <cstring>

namespace cs = clay::sound;

// Translate the legacy Voice::Waveform enum (public API) into the
// engine's OscillatorVoice::Waveform (internal DSP type).
static cs::OscillatorVoice::Waveform mapWaveform(Voice::Waveform w)
{
    using W = cs::OscillatorVoice::Waveform;
    switch (w) {
    case Voice::Sine:     return W::Sine;
    case Voice::Square:   return W::Square;
    case Voice::Triangle: return W::Triangle;
    case Voice::Sawtooth: return W::Sawtooth;
    case Voice::Noise:    return W::Noise;
    }
    return W::Triangle;
}

SoftSynth::SoftSynth(QObject *parent)
    : QObject(parent)
{
    delayBuffer_.resize(SAMPLE_RATE, 0.0f);
    connect(&renderTimer_, &QTimer::timeout, this, &SoftSynth::generateSamples);
}

SoftSynth::~SoftSynth()
{
    stop();
}

void SoftSynth::setVolume(double volume)
{
    volume_ = std::clamp(volume, 0.0, 1.0);
}

void SoftSynth::setFilterCutoff(double hz)
{
    filterCutoff_ = std::clamp(hz, 20.0, 20000.0);
}

void SoftSynth::setEchoMix(double mix)
{
    echoMix_ = std::clamp(mix, 0.0, 1.0);
}

void SoftSynth::setEchoDelay(double seconds)
{
    echoDelay_ = std::clamp(seconds, 0.0, 1.0);
}

void SoftSynth::scheduleNote(const NoteEvent &note)
{
    auto it = std::lower_bound(
        composition_.begin(), composition_.end(), note,
        [](const NoteEvent &a, const NoteEvent &b) { return a.time < b.time; });
    composition_.insert(it, note);
}

void SoftSynth::loadComposition(const std::vector<NoteEvent> &notes, double loopDuration)
{
    auto sorted = notes;
    std::sort(sorted.begin(), sorted.end(),
              [](const NoteEvent &a, const NoteEvent &b) { return a.time < b.time; });

    if (playing_) {
        pendingComposition_ = std::move(sorted);
        pendingLoopDuration_ = loopDuration;
        if (fadeState_ == FadeNone) {
            fadeState_ = FadingOut;
            fadeProgress_ = 0.0;
        }
    } else {
        composition_ = std::move(sorted);
        loopDuration_ = loopDuration;
        nextNoteIndex_ = 0;
    }
}

void SoftSynth::applyPendingComposition(int64_t currentFrame)
{
    composition_ = std::move(pendingComposition_);
    loopDuration_ = pendingLoopDuration_;
    pendingComposition_.clear();

    // Seek nextNoteIndex_ to the first unfired note relative to the
    // current frame.
    const double currentTime = static_cast<double>(currentFrame) / SAMPLE_RATE;
    nextNoteIndex_ = 0;
    while (nextNoteIndex_ < composition_.size()
           && composition_[nextNoteIndex_].time < currentTime)
        ++nextNoteIndex_;

    voices_.clear();
}

void SoftSynth::play()
{
    if (playing_ && !paused_) return;

    currentFrame_ = 0;
    nextNoteIndex_ = 0;
    paused_ = false;
    filterState_ = 0.0;
    delayWritePos_ = 0;
    std::fill(delayBuffer_.begin(), delayBuffer_.end(), 0.0f);
    voices_.clear();

    QAudioFormat format;
    format.setSampleRate(SAMPLE_RATE);
    format.setChannelCount(CHANNELS);
    format.setSampleFormat(QAudioFormat::Float);

    QAudioDevice outputDevice = QMediaDevices::defaultAudioOutput();
    if (outputDevice.isNull()) {
        qWarning() << "SoftSynth: No audio output device available";
        return;
    }

    if (!outputDevice.isFormatSupported(format))
        qWarning() << "SoftSynth: Default audio format not supported, trying closest match";

    delete audioSink_;
    audioSink_ = new QAudioSink(outputDevice, format, this);
    audioDevice_ = audioSink_->start();

    if (!audioDevice_) {
        qWarning() << "SoftSynth: Failed to start audio sink";
        delete audioSink_;
        audioSink_ = nullptr;
        return;
    }

    audioSink_->setBufferSize(SAMPLE_RATE * sizeof(float) / 5); // 200ms

    playing_ = true;
    renderTimer_.start(BUFFER_MS);
}

void SoftSynth::stop()
{
    playing_ = false;
    paused_ = false;
    renderTimer_.stop();

    if (audioSink_) {
        audioSink_->stop();
        delete audioSink_;
        audioSink_ = nullptr;
        audioDevice_ = nullptr;
    }

    voices_.clear();
}

void SoftSynth::pause()
{
    if (!playing_ || paused_) return;
    paused_ = true;
    renderTimer_.stop();
    if (audioSink_) audioSink_->suspend();
}

void SoftSynth::resume()
{
    if (!playing_ || !paused_) return;
    paused_ = false;
    if (audioSink_) audioSink_->resume();
    renderTimer_.start(BUFFER_MS);
}

double SoftSynth::position() const
{
    return static_cast<double>(currentFrame_) / SAMPLE_RATE;
}

void SoftSynth::activateScheduledNotes(int64_t currentFrame)
{
    const double currentTime = static_cast<double>(currentFrame) / SAMPLE_RATE;

    while (nextNoteIndex_ < composition_.size()
           && composition_[nextNoteIndex_].time <= currentTime) {
        const NoteEvent &note = composition_[nextNoteIndex_];

        if (voices_.size() >= MAX_VOICES) {
            // Steal the voice with the earliest isFinished() window —
            // approximated by the front of the deque (oldest insertion).
            voices_.erase(voices_.begin());
        }

        auto voice = std::make_unique<cs::OscillatorVoice>();

        cs::OscillatorVoice::Patch p;
        p.waveform   = mapWaveform(note.waveform);
        p.attack     = note.attack;
        p.decay      = note.decay;
        p.sustain    = note.sustain;
        p.release    = note.release;
        p.pitchStart = note.pitchStart;
        p.pitchEnd   = note.pitchEnd;
        p.pitchTime  = note.pitchTime;
        p.lfoRate    = note.lfoRate;
        p.lfoDepth   = note.lfoDepth;
        p.lfoTarget  = note.lfoTarget;
        voice->setPatch(p);

        cs::NoteEvent ev;
        ev.timeFrames     = currentFrame;
        ev.durationFrames = static_cast<int64_t>(std::llround(note.duration * SAMPLE_RATE));
        ev.freqHz         = note.frequency;
        ev.velocity       = static_cast<float>(note.gain);
        voice->onNoteOn(ev, SAMPLE_RATE);

        voices_.push_back(std::move(voice));
        ++nextNoteIndex_;
    }
}

void SoftSynth::pruneFinishedVoices(int64_t currentFrame)
{
    voices_.erase(
        std::remove_if(voices_.begin(), voices_.end(),
                       [currentFrame](const std::unique_ptr<cs::OscillatorVoice>& v) {
                           return v->isFinished(currentFrame);
                       }),
        voices_.end());
}

void SoftSynth::mixActiveVoices(float *out, int frames, int64_t startFrame)
{
    // Per-sample activation keeps sample-accurate trigger timing;
    // voices then render one sample into `out[i]` each.
    for (int i = 0; i < frames; ++i) {
        const int64_t f = startFrame + i;
        activateScheduledNotes(f);
        for (auto &v : voices_) {
            float s = 0.0f;
            v->render(&s, 1, f);
            out[i] += s;
        }
        // Master volume applied after mix.
        out[i] = static_cast<float>(out[i] * volume_);

        // Reap finished voices one per frame (bounded work).
        if (!voices_.empty() && voices_.front()->isFinished(f + 1))
            pruneFinishedVoices(f + 1);
    }
}

void SoftSynth::processFilter(float *buffer, int count)
{
    double rc = 1.0 / (2.0 * M_PI * filterCutoff_);
    double dt = 1.0 / static_cast<double>(SAMPLE_RATE);
    double alpha = dt / (rc + dt);

    for (int i = 0; i < count; ++i) {
        filterState_ += alpha * (static_cast<double>(buffer[i]) - filterState_);
        buffer[i] = static_cast<float>(filterState_);
    }
}

void SoftSynth::processDelay(float *buffer, int count)
{
    int delaySamples = static_cast<int>(echoDelay_ * SAMPLE_RATE);
    if (delaySamples <= 0 || delaySamples >= static_cast<int>(delayBuffer_.size()))
        return;

    int bufSize = static_cast<int>(delayBuffer_.size());

    for (int i = 0; i < count; ++i) {
        int readPos = (delayWritePos_ - delaySamples + bufSize) % bufSize;
        float delayed = delayBuffer_[readPos];
        float output = buffer[i] + delayed * static_cast<float>(echoMix_);

        delayBuffer_[delayWritePos_] = buffer[i] + delayed * static_cast<float>(echoMix_) * 0.5f;
        delayWritePos_ = (delayWritePos_ + 1) % bufSize;

        buffer[i] = output;
    }
}

void SoftSynth::generateSamples()
{
    if (!playing_ || !audioDevice_ || !audioSink_)
        return;

    int bytesFree = audioSink_->bytesFree();
    int samplesToWrite = bytesFree / static_cast<int>(sizeof(float));
    if (samplesToWrite <= 0) return;
    samplesToWrite = std::min(samplesToWrite, SAMPLE_RATE);

    std::vector<float> buffer(samplesToWrite, 0.0f);

    const int64_t loopFrames =
        static_cast<int64_t>(std::llround(loopDuration_ * SAMPLE_RATE));

    int written = 0;
    while (written < samplesToWrite) {
        // Respect the loop boundary: render up to it, then roll over.
        int chunk = samplesToWrite - written;
        if (loopFrames > 0) {
            const int64_t untilLoop = loopFrames - currentFrame_;
            if (untilLoop > 0 && untilLoop < chunk)
                chunk = static_cast<int>(untilLoop);
        }

        mixActiveVoices(buffer.data() + written, chunk, currentFrame_);

        // Per-sample crossfade pass (operates on what mixActiveVoices
        // just wrote).
        for (int i = 0; i < chunk; ++i) {
            double fadeMul = 1.0;
            if (fadeState_ == FadingOut) {
                fadeMul = 1.0 - fadeProgress_;
                fadeProgress_ += 1.0 / (FADE_DURATION * SAMPLE_RATE);
                if (fadeProgress_ >= 1.0) {
                    applyPendingComposition(currentFrame_ + i);
                    fadeState_ = FadingIn;
                    fadeProgress_ = 0.0;
                    fadeMul = 0.0;
                }
            } else if (fadeState_ == FadingIn) {
                fadeMul = fadeProgress_;
                fadeProgress_ += 1.0 / (FADE_DURATION * SAMPLE_RATE);
                if (fadeProgress_ >= 1.0) {
                    fadeState_ = FadeNone;
                    fadeMul = 1.0;
                }
            }
            float s = buffer[written + i] * static_cast<float>(fadeMul);
            buffer[written + i] = std::clamp(s, -1.0f, 1.0f);
        }

        currentFrame_ += chunk;
        written += chunk;

        // Loop rollover.
        if (loopFrames > 0 && currentFrame_ >= loopFrames) {
            currentFrame_ = 0;
            nextNoteIndex_ = 0;
            voices_.clear();
        }
    }

    processFilter(buffer.data(), samplesToWrite);
    processDelay(buffer.data(), samplesToWrite);
    for (int i = 0; i < samplesToWrite; ++i)
        buffer[i] = std::clamp(buffer[i], -1.0f, 1.0f);

    const char *data = reinterpret_cast<const char *>(buffer.data());
    qint64 bytesToWrite = samplesToWrite * static_cast<qint64>(sizeof(float));
    qint64 writtenBytes = 0;
    while (writtenBytes < bytesToWrite) {
        qint64 c = audioDevice_->write(data + writtenBytes, bytesToWrite - writtenBytes);
        if (c <= 0) break;
        writtenBytes += c;
    }
}

void SoftSynth::renderOffline(float *output, int sampleCount)
{
    currentFrame_ = 0;
    nextNoteIndex_ = 0;
    filterState_ = 0.0;
    delayWritePos_ = 0;
    std::fill(delayBuffer_.begin(), delayBuffer_.end(), 0.0f);
    voices_.clear();

    std::memset(output, 0, sizeof(float) * static_cast<size_t>(sampleCount));
    mixActiveVoices(output, sampleCount, currentFrame_);
    currentFrame_ += sampleCount;

    processFilter(output, sampleCount);
    processDelay(output, sampleCount);
    for (int i = 0; i < sampleCount; ++i)
        output[i] = std::clamp(output[i], -1.0f, 1.0f);
}
