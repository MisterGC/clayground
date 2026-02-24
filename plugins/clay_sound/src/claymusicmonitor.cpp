// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claymusicmonitor.h"
#include <QtMath>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>

EM_JS(void, js_monitor_create_analyser, (int fftSize), {
    if (!Module.clayAudioCtx) return;
    var analyser = Module.clayAudioCtx.createAnalyser();
    analyser.fftSize = fftSize;
    analyser.smoothingTimeConstant = 0.8;
    Module.clayMusicAnalyser = analyser;
});

EM_JS(void, js_monitor_destroy_analyser, (), {
    if (Module.clayMusicAnalyser) {
        try { Module.clayMusicAnalyser.disconnect(); } catch (e) {}
        Module.clayMusicAnalyser = null;
    }
});

EM_JS(void, js_monitor_get_frequency_data, (uint8_t *ptr, int len), {
    if (!Module.clayMusicAnalyser) return;
    var data = new Uint8Array(Module.HEAPU8.buffer, ptr, len);
    Module.clayMusicAnalyser.getByteFrequencyData(data);
});

EM_JS(void, js_monitor_get_time_domain_data, (uint8_t *ptr, int len), {
    if (!Module.clayMusicAnalyser) return;
    var data = new Uint8Array(Module.HEAPU8.buffer, ptr, len);
    Module.clayMusicAnalyser.getByteTimeDomainData(data);
});
#endif

ClayMusicMonitor::ClayMusicMonitor(QObject *parent)
    : QObject(parent)
{
    connect(&timer_, &QTimer::timeout, this, &ClayMusicMonitor::update);
}

ClayMusicMonitor::~ClayMusicMonitor()
{
    stopMonitoring();
}

QObject* ClayMusicMonitor::music() const
{
    return music_;
}

void ClayMusicMonitor::setMusic(QObject *music)
{
    if (music_ == music)
        return;

    stopMonitoring();
    music_ = music;
    emit musicChanged();

    if (music_)
        startMonitoring();
}

int ClayMusicMonitor::fftSize() const
{
    return fftSize_;
}

void ClayMusicMonitor::setFftSize(int size)
{
    // Must be power of 2, clamp to reasonable range
    int clamped = qBound(32, size, 2048);
    // Round to nearest power of 2
    int p = 1;
    while (p < clamped) p <<= 1;
    if (p == fftSize_)
        return;

    fftSize_ = p;
    emit fftSizeChanged();

    // Reinitialize if already monitoring
    if (music_) {
        stopMonitoring();
        startMonitoring();
    }
}

int ClayMusicMonitor::updateInterval() const
{
    return updateInterval_;
}

void ClayMusicMonitor::setUpdateInterval(int ms)
{
    ms = qBound(16, ms, 1000);
    if (updateInterval_ == ms)
        return;

    updateInterval_ = ms;
    emit updateIntervalChanged();

    if (timer_.isActive())
        timer_.setInterval(updateInterval_);
}

QList<qreal> ClayMusicMonitor::spectrum() const
{
    return spectrum_;
}

qreal ClayMusicMonitor::level() const
{
    return level_;
}

void ClayMusicMonitor::startMonitoring()
{
    const int binCount = fftSize_ / 2;

    spectrum_.clear();
    spectrum_.fill(0.0, binCount);
    level_ = 0.0;

#ifdef __EMSCRIPTEN__
    js_monitor_create_analyser(fftSize_);
    analyserCreated_ = true;
    freqData_.resize(binCount, 0);
#else
    player_ = qobject_cast<QMediaPlayer*>(music_);
    if (!player_)
        return;

    pcmBuffer_.resize(fftSize_, 0.0f);
    pcmWritePos_ = 0;
    pcmFilled_ = false;

    bufferOutput_ = new QAudioBufferOutput(this);
    connect(bufferOutput_, &QAudioBufferOutput::audioBufferReceived,
            this, &ClayMusicMonitor::processAudioBuffer);
    player_->setAudioBufferOutput(bufferOutput_);
#endif

    timer_.start(updateInterval_);
}

void ClayMusicMonitor::stopMonitoring()
{
    timer_.stop();

#ifdef __EMSCRIPTEN__
    if (analyserCreated_) {
        js_monitor_destroy_analyser();
        analyserCreated_ = false;
    }
    freqData_.clear();
#else
    if (player_ && bufferOutput_) {
        player_->setAudioBufferOutput(nullptr);
    }
    delete bufferOutput_;
    bufferOutput_ = nullptr;
    player_ = nullptr;
    pcmBuffer_.clear();
    pcmWritePos_ = 0;
    pcmFilled_ = false;
#endif

    if (!spectrum_.isEmpty()) {
        spectrum_.fill(0.0);
        level_ = 0.0;
        emit spectrumChanged();
        emit levelChanged();
    }
}

#ifndef __EMSCRIPTEN__
void ClayMusicMonitor::processAudioBuffer(const QAudioBuffer &buffer)
{
    const auto format = buffer.format();
    const int frames = buffer.frameCount();
    const int channels = format.channelCount();

    for (int i = 0; i < frames; ++i) {
        float sample = 0.0f;

        if (format.sampleFormat() == QAudioFormat::Float) {
            const float *data = buffer.constData<float>();
            for (int ch = 0; ch < channels; ++ch)
                sample += data[i * channels + ch];
        } else if (format.sampleFormat() == QAudioFormat::Int16) {
            const qint16 *data = buffer.constData<qint16>();
            for (int ch = 0; ch < channels; ++ch)
                sample += data[i * channels + ch] / 32768.0f;
        } else if (format.sampleFormat() == QAudioFormat::Int32) {
            const qint32 *data = buffer.constData<qint32>();
            for (int ch = 0; ch < channels; ++ch)
                sample += data[i * channels + ch] / 2147483648.0f;
        }

        sample /= channels;
        pcmBuffer_[pcmWritePos_] = sample;
        pcmWritePos_ = (pcmWritePos_ + 1) % fftSize_;
        if (pcmWritePos_ == 0)
            pcmFilled_ = true;
    }
}

void ClayMusicMonitor::fftRadix2(std::vector<std::complex<float>> &data)
{
    const int n = static_cast<int>(data.size());
    if (n <= 1) return;

    // Bit-reversal permutation
    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j)
            std::swap(data[i], data[j]);
    }

    // Butterfly stages
    for (int len = 2; len <= n; len <<= 1) {
        const float angle = -2.0f * static_cast<float>(M_PI) / len;
        std::complex<float> wn(std::cos(angle), std::sin(angle));
        for (int i = 0; i < n; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (int j = 0; j < len / 2; ++j) {
                auto u = data[i + j];
                auto v = data[i + j + len / 2] * w;
                data[i + j] = u + v;
                data[i + j + len / 2] = u - v;
                w *= wn;
            }
        }
    }
}
#endif

void ClayMusicMonitor::update()
{
    const int binCount = fftSize_ / 2;
    bool spectrumDirty = false;
    qreal newLevel = 0.0;

#ifdef __EMSCRIPTEN__
    if (!analyserCreated_ || freqData_.empty())
        return;

    js_monitor_get_frequency_data(freqData_.data(), binCount);

    // Normalize uint8 (0-255) → qreal (0.0-1.0)
    for (int i = 0; i < binCount; ++i) {
        qreal val = freqData_[i] / 255.0;
        if (!qFuzzyCompare(spectrum_[i], val)) {
            spectrum_[i] = val;
            spectrumDirty = true;
        }
    }

    // Compute RMS from time-domain data
    std::vector<uint8_t> timeData(fftSize_, 128);
    js_monitor_get_time_domain_data(timeData.data(), fftSize_);
    double sumSq = 0.0;
    for (int i = 0; i < fftSize_; ++i) {
        double s = (timeData[i] - 128.0) / 128.0;
        sumSq += s * s;
    }
    newLevel = qBound(0.0, std::sqrt(sumSq / fftSize_), 1.0);
#else
    if (!pcmFilled_ && pcmWritePos_ < fftSize_)
        return;

    // Copy last fftSize_ samples in order
    std::vector<std::complex<float>> fftData(fftSize_);
    double sumSq = 0.0;
    for (int i = 0; i < fftSize_; ++i) {
        int idx = (pcmWritePos_ + i) % fftSize_;
        float sample = pcmBuffer_[idx];

        // Hann window
        float w = 0.5f * (1.0f - std::cos(2.0f * static_cast<float>(M_PI) * i / (fftSize_ - 1)));
        fftData[i] = std::complex<float>(sample * w, 0.0f);
        sumSq += sample * sample;
    }

    newLevel = qBound(0.0, std::sqrt(sumSq / fftSize_), 1.0);

    fftRadix2(fftData);

    // Compute magnitudes with log-scale dB mapping
    const float minDb = -60.0f;
    for (int i = 0; i < binCount; ++i) {
        float mag = std::abs(fftData[i]) / (fftSize_ / 2.0f);
        float db = (mag > 0.0f) ? 20.0f * std::log10(mag) : minDb;
        qreal val = qBound(0.0, static_cast<qreal>((db - minDb) / (-minDb)), 1.0);
        if (!qFuzzyCompare(spectrum_[i], val)) {
            spectrum_[i] = val;
            spectrumDirty = true;
        }
    }
#endif

    if (spectrumDirty)
        emit spectrumChanged();

    if (!qFuzzyCompare(level_, newLevel)) {
        level_ = newLevel;
        emit levelChanged();
    }
}
