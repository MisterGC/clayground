// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "audio_output.h"

#include "engine/instrument.h"

#include <QAudioDevice>
#include <QAudioFormat>
#include <QAudioSink>
#include <QCoreApplication>
#include <QDebug>
#include <QIODevice>
#include <QMediaDevices>

#include <algorithm>
#include <vector>

namespace clay::sound {

AudioOutput& AudioOutput::instance()
{
    // Process-lifetime singleton. Constructed on first use; never
    // explicitly destroyed (Qt cleans up children on app shutdown).
    static AudioOutput* sInst = nullptr;
    if (!sInst) sInst = new AudioOutput();
    return *sInst;
}

AudioOutput::AudioOutput()
    : QObject(nullptr)
{
    pullTimer_.setTimerType(Qt::PreciseTimer);
    connect(&pullTimer_, &QTimer::timeout, this, &AudioOutput::onPull);
}

AudioOutput::~AudioOutput()
{
    stop();
}

int AudioOutput::registerInstrument(std::unique_ptr<IInstrument> inst)
{
    return engine_.addInstrument(std::move(inst));
}

void AudioOutput::unregisterInstrument(int id)
{
    engine_.removeInstrument(id);
}

void AudioOutput::start()
{
    if (sinkRunning_) return;
    if (!QCoreApplication::instance()) {
        // QtMultimedia requires a QCoreApplication; fail quietly so unit
        // tests that just exercise the offline engine can construct
        // instruments without spinning up Qt's event loop.
        return;
    }

    QAudioFormat fmt;
    fmt.setSampleRate(SAMPLE_RATE);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Float);

    const QAudioDevice outputDevice = QMediaDevices::defaultAudioOutput();
    if (outputDevice.isNull()) {
        qWarning() << "clay::sound::AudioOutput: no default audio output device";
        return;
    }

    delete sink_;
    sink_ = new QAudioSink(outputDevice, fmt, this);
    sink_->setBufferSize(SAMPLE_RATE * sizeof(float) / 5); // ~200ms
    device_ = sink_->start();
    if (!device_) {
        qWarning() << "clay::sound::AudioOutput: failed to start audio sink";
        delete sink_;
        sink_ = nullptr;
        return;
    }

    sinkRunning_ = true;
    pullTimer_.start(BUFFER_MS);
}

void AudioOutput::stop()
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

void AudioOutput::onPull()
{
    if (!sinkRunning_ || !sink_ || !device_) return;

    const int bytesFree = sink_->bytesFree();
    int frames = bytesFree / static_cast<int>(sizeof(float));
    if (frames <= 0) return;
    frames = std::min(frames, SAMPLE_RATE); // cap 1s

    std::vector<float> buf(static_cast<size_t>(frames), 0.0f);
    engine_.renderOffline(buf.data(), frames);

    // Per-instrument gain is applied inside the engine. Final master
    // clamp here protects the output from sums of multiple loud
    // instruments saturating the float-to-int conversion in the sink.
    for (auto& s : buf) s = std::clamp(s, -1.0f, 1.0f);

    const char* data = reinterpret_cast<const char*>(buf.data());
    qint64 bytesToWrite = frames * static_cast<qint64>(sizeof(float));
    qint64 written = 0;
    while (written < bytesToWrite) {
        qint64 c = device_->write(data + written, bytesToWrite - written);
        if (c <= 0) break;
        written += c;
    }

    emit afterPull();
}

} // namespace clay::sound
