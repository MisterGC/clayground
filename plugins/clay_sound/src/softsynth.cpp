// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "softsynth.h"

#ifndef __EMSCRIPTEN__

#include <QAudioSink>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QDebug>
#include <algorithm>
#include <cstring>

SoftSynth::SoftSynth(QObject *parent)
    : QObject(parent)
{
    // Allocate delay buffer (1 second at sample rate)
    delayBuffer_.resize(SAMPLE_RATE, 0.0f);

    // Initialize all voices as inactive
    for (int i = 0; i < MAX_VOICES; ++i)
        voices_[i].active = false;

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
    // Insert sorted by time
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
        // Store pending and start fade-out; swap happens at fade midpoint
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

void SoftSynth::applyPendingComposition()
{
    composition_ = std::move(pendingComposition_);
    loopDuration_ = pendingLoopDuration_;
    pendingComposition_.clear();

    // Seek to current time position
    nextNoteIndex_ = 0;
    while (nextNoteIndex_ < composition_.size()
           && composition_[nextNoteIndex_].time < currentTime_)
        ++nextNoteIndex_;

    // Kill active voices for clean transition
    for (int i = 0; i < MAX_VOICES; ++i)
        voices_[i].active = false;
}

void SoftSynth::play()
{
    if (playing_ && !paused_)
        return;

    // Reset playback state
    currentTime_ = 0.0;
    nextNoteIndex_ = 0;
    paused_ = false;
    filterState_ = 0.0;
    delayWritePos_ = 0;
    std::fill(delayBuffer_.begin(), delayBuffer_.end(), 0.0f);

    for (int i = 0; i < MAX_VOICES; ++i)
        voices_[i].active = false;

    // Set up audio format: 44100 Hz, mono, float
    QAudioFormat format;
    format.setSampleRate(SAMPLE_RATE);
    format.setChannelCount(CHANNELS);
    format.setSampleFormat(QAudioFormat::Float);

    QAudioDevice outputDevice = QMediaDevices::defaultAudioOutput();
    if (outputDevice.isNull()) {
        qWarning() << "SoftSynth: No audio output device available";
        return;
    }

    if (!outputDevice.isFormatSupported(format)) {
        qWarning() << "SoftSynth: Default audio format not supported, trying closest match";
        // Attempt to proceed anyway - Qt may do conversion
    }

    delete audioSink_;
    audioSink_ = new QAudioSink(outputDevice, format, this);
    audioDevice_ = audioSink_->start();

    if (!audioDevice_) {
        qWarning() << "SoftSynth: Failed to start audio sink";
        delete audioSink_;
        audioSink_ = nullptr;
        return;
    }

    // Use a larger internal buffer to absorb timer jitter
    audioSink_->setBufferSize(SAMPLE_RATE * sizeof(float) / 5); // 200ms buffer

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

    for (int i = 0; i < MAX_VOICES; ++i)
        voices_[i].active = false;
}

void SoftSynth::pause()
{
    if (!playing_ || paused_)
        return;

    paused_ = true;
    renderTimer_.stop();

    if (audioSink_)
        audioSink_->suspend();
}

void SoftSynth::resume()
{
    if (!playing_ || !paused_)
        return;

    paused_ = false;

    if (audioSink_)
        audioSink_->resume();

    renderTimer_.start(BUFFER_MS);
}

double SoftSynth::position() const
{
    return currentTime_;
}

double SoftSynth::generateWaveform(Voice &voice, double currentTime)
{
    double sample = 0.0;

    switch (voice.waveform) {
    case Voice::Sine:
        sample = std::sin(2.0 * M_PI * voice.phase);
        break;

    case Voice::Square: {
        // Slight smoothing at edges to reduce aliasing
        const double edge = 0.02;
        if (voice.phase < edge)
            sample = voice.phase / edge;
        else if (voice.phase < 0.5 - edge)
            sample = 1.0;
        else if (voice.phase < 0.5 + edge)
            sample = 1.0 - 2.0 * (voice.phase - (0.5 - edge)) / (2.0 * edge);
        else if (voice.phase < 1.0 - edge)
            sample = -1.0;
        else
            sample = -1.0 + (voice.phase - (1.0 - edge)) / edge;
        break;
    }

    case Voice::Triangle:
        sample = 4.0 * std::abs(voice.phase - 0.5) - 1.0;
        break;

    case Voice::Sawtooth:
        sample = 2.0 * voice.phase - 1.0;
        break;

    case Voice::Noise: {
        // Simple xorshift noise
        voice.noiseSeed ^= voice.noiseSeed << 13;
        voice.noiseSeed ^= voice.noiseSeed >> 17;
        voice.noiseSeed ^= voice.noiseSeed << 5;
        sample = static_cast<double>(voice.noiseSeed) / static_cast<double>(0xFFFFFFFF) * 2.0 - 1.0;
        break;
    }
    }

    // Compute effective frequency (base + pitch envelope + LFO)
    double effFreq = voice.frequency;
    double elapsed = currentTime - voice.startTime;

    if (voice.pitchTime > 0.0) {
        double p = std::min(elapsed / voice.pitchTime, 1.0);
        double semitones = voice.pitchStart + (voice.pitchEnd - voice.pitchStart) * p;
        effFreq *= std::pow(2.0, semitones / 12.0);
    }

    if (voice.lfoRate > 0.0 && voice.lfoDepth > 0.0 && voice.lfoTarget == 1) {
        double lfo = std::sin(2.0 * M_PI * elapsed * voice.lfoRate);
        effFreq *= std::pow(2.0, lfo * voice.lfoDepth / 12.0);
    }

    // Advance phase with effective frequency
    voice.phase += effFreq / static_cast<double>(SAMPLE_RATE);
    if (voice.phase >= 1.0)
        voice.phase -= 1.0;

    return sample;
}

double SoftSynth::applyEnvelope(const Voice &voice, double currentTime)
{
    double t = currentTime - voice.startTime;

    if (t < 0.0)
        return 0.0;

    double noteEnd = voice.duration;
    double releaseStart = noteEnd - voice.release;

    // Attack phase: linear ramp 0 -> 1
    if (t < voice.attack) {
        return (voice.attack > 0.0) ? (t / voice.attack) : 1.0;
    }

    // Decay phase: linear ramp 1 -> sustain
    if (t < voice.attack + voice.decay) {
        double decayProgress = (voice.decay > 0.0)
            ? (t - voice.attack) / voice.decay
            : 1.0;
        return 1.0 - (1.0 - voice.sustain) * decayProgress;
    }

    // Sustain phase
    if (t < releaseStart) {
        return voice.sustain;
    }

    // Release phase: linear ramp sustain -> 0
    if (t < noteEnd) {
        double releaseProgress = (voice.release > 0.0)
            ? (t - releaseStart) / voice.release
            : 1.0;
        return voice.sustain * (1.0 - releaseProgress);
    }

    // Note finished
    return 0.0;
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

        // Write input + attenuated feedback into delay line
        delayBuffer_[delayWritePos_] = buffer[i] + delayed * static_cast<float>(echoMix_) * 0.5f;
        delayWritePos_ = (delayWritePos_ + 1) % bufSize;

        buffer[i] = output;
    }
}

Voice *SoftSynth::allocateVoice()
{
    // Find first inactive voice
    for (int i = 0; i < MAX_VOICES; ++i) {
        if (!voices_[i].active)
            return &voices_[i];
    }

    // All active: steal the oldest (earliest startTime)
    Voice *oldest = &voices_[0];
    for (int i = 1; i < MAX_VOICES; ++i) {
        if (voices_[i].startTime < oldest->startTime)
            oldest = &voices_[i];
    }
    return oldest;
}

void SoftSynth::activateScheduledNotes()
{
    while (nextNoteIndex_ < composition_.size()
           && composition_[nextNoteIndex_].time <= currentTime_) {
        const NoteEvent &note = composition_[nextNoteIndex_];

        Voice *v = allocateVoice();
        v->waveform = note.waveform;
        v->frequency = note.frequency;
        v->gain = note.gain;
        v->duration = note.duration;
        v->startTime = currentTime_;
        v->phase = 0.0;
        v->active = true;

        // Per-note ADSR from patch
        v->attack = note.attack;
        v->decay = note.decay;
        v->sustain = note.sustain;
        v->release = note.release;

        // Per-note pitch envelope
        v->pitchStart = note.pitchStart;
        v->pitchEnd = note.pitchEnd;
        v->pitchTime = note.pitchTime;

        // Per-note LFO
        v->lfoRate = note.lfoRate;
        v->lfoDepth = note.lfoDepth;
        v->lfoTarget = note.lfoTarget;

        // Reset noise seed for noise voices
        if (v->waveform == Voice::Noise)
            v->noiseSeed = 12345 + static_cast<unsigned int>(nextNoteIndex_);

        ++nextNoteIndex_;
    }
}

void SoftSynth::generateSamples()
{
    if (!playing_ || !audioDevice_ || !audioSink_)
        return;

    // Write as many samples as the sink can accept
    int bytesFree = audioSink_->bytesFree();
    int samplesToWrite = bytesFree / static_cast<int>(sizeof(float));
    if (samplesToWrite <= 0)
        return;
    samplesToWrite = std::min(samplesToWrite, SAMPLE_RATE); // cap at 1s

    std::vector<float> buffer(samplesToWrite);

    for (int i = 0; i < samplesToWrite; ++i) {
        // Activate notes whose scheduled time has arrived
        activateScheduledNotes();

        // Sum all active voices
        double mixSample = 0.0;
        for (int v = 0; v < MAX_VOICES; ++v) {
            if (!voices_[v].active)
                continue;

            double elapsed = currentTime_ - voices_[v].startTime;
            if (elapsed >= voices_[v].duration) {
                voices_[v].active = false;
                continue;
            }
            double envelope = applyEnvelope(voices_[v], currentTime_);

            // Volume LFO
            if (voices_[v].lfoTarget == 2 && voices_[v].lfoRate > 0.0) {
                double el = currentTime_ - voices_[v].startTime;
                double lfo = std::sin(2.0 * M_PI * el * voices_[v].lfoRate);
                envelope *= 1.0 - voices_[v].lfoDepth * 0.5 * (1.0 - lfo);
            }

            double wave = generateWaveform(voices_[v], currentTime_);
            mixSample += wave * envelope * voices_[v].gain;
        }

        // Apply master volume
        mixSample *= volume_;

        // Apply crossfade envelope
        double fadeMul = 1.0;
        if (fadeState_ == FadingOut) {
            fadeMul = 1.0 - fadeProgress_;
            fadeProgress_ += 1.0 / (FADE_DURATION * SAMPLE_RATE);
            if (fadeProgress_ >= 1.0) {
                applyPendingComposition();
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
        mixSample *= fadeMul;

        // Clamp to [-1.0, 1.0]
        mixSample = std::clamp(mixSample, -1.0, 1.0);

        buffer[i] = static_cast<float>(mixSample);

        // Advance time
        currentTime_ += 1.0 / static_cast<double>(SAMPLE_RATE);

        // Handle loop
        if (loopDuration_ > 0.0 && currentTime_ >= loopDuration_) {
            currentTime_ -= loopDuration_;
            nextNoteIndex_ = 0;

            // Deactivate all voices on loop boundary for clean restart
            for (int v = 0; v < MAX_VOICES; ++v)
                voices_[v].active = false;
        }
    }

    // Apply lowpass filter
    processFilter(buffer.data(), samplesToWrite);

    // Apply echo/delay
    processDelay(buffer.data(), samplesToWrite);

    // Final clamp after effects processing
    for (int i = 0; i < samplesToWrite; ++i)
        buffer[i] = std::clamp(buffer[i], -1.0f, 1.0f);

    // Write to audio device
    const char *data = reinterpret_cast<const char *>(buffer.data());
    qint64 bytesToWrite = samplesToWrite * static_cast<qint64>(sizeof(float));
    qint64 written = 0;
    while (written < bytesToWrite) {
        qint64 chunk = audioDevice_->write(data + written, bytesToWrite - written);
        if (chunk <= 0)
            break;
        written += chunk;
    }
}

void SoftSynth::renderOffline(float *output, int sampleCount)
{
    // Reset state for clean offline render
    currentTime_ = 0.0;
    nextNoteIndex_ = 0;
    filterState_ = 0.0;
    delayWritePos_ = 0;
    std::fill(delayBuffer_.begin(), delayBuffer_.end(), 0.0f);
    for (int i = 0; i < MAX_VOICES; ++i)
        voices_[i].active = false;

    for (int i = 0; i < sampleCount; ++i) {
        activateScheduledNotes();

        double mix = 0.0;
        for (int v = 0; v < MAX_VOICES; ++v) {
            if (!voices_[v].active) continue;
            if (currentTime_ - voices_[v].startTime >= voices_[v].duration) {
                voices_[v].active = false;
                continue;
            }
            double env = applyEnvelope(voices_[v], currentTime_);
            if (voices_[v].lfoTarget == 2 && voices_[v].lfoRate > 0.0) {
                double el = currentTime_ - voices_[v].startTime;
                double lfo = std::sin(2.0 * M_PI * el * voices_[v].lfoRate);
                env *= 1.0 - voices_[v].lfoDepth * 0.5 * (1.0 - lfo);
            }
            mix += generateWaveform(voices_[v], currentTime_) * env * voices_[v].gain;
        }

        mix *= volume_;
        output[i] = static_cast<float>(std::clamp(mix, -1.0, 1.0));
        currentTime_ += 1.0 / SAMPLE_RATE;
    }

    // Apply filter and delay
    processFilter(output, sampleCount);
    processDelay(output, sampleCount);

    for (int i = 0; i < sampleCount; ++i)
        output[i] = std::clamp(output[i], -1.0f, 1.0f);
}

#endif // !__EMSCRIPTEN__
