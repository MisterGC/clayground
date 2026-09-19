// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "audio_output.h"

#include "audio_devices.h"
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

    // Every open attempt costs a browser AudioContext and a page only
    // tolerates a handful of those, so a page where nothing opens must not
    // try again on every triggered note. Only a failed attempt arms this.
    if (sinceFailedOpen_.isValid() && sinceFailedOpen_.elapsed() < RETRY_MIN_MS)
        return;

    // Must come before any QMediaDevices/QAudioSink use - see #216.
    primeAudioDevices();

    // The default output device is not always one the platform can open,
    // so try the others before giving up. On WASM the device list holds
    // both the OpenAL device - the only one Qt's sink can open - and every
    // device the browser enumerates asynchronously, each flagged default;
    // which one QMediaDevices reports therefore depends on timing, and on
    // the browser devices the open fails (#262).
    QList<QAudioDevice> candidates;
    const QAudioDevice preferred = QMediaDevices::defaultAudioOutput();
    if (!preferred.isNull()) candidates.append(preferred);
    for (const QAudioDevice& dev : QMediaDevices::audioOutputs())
        if (dev != preferred) candidates.append(dev);

    if (candidates.isEmpty()) {
        qWarning() << "clay::sound::AudioOutput: no audio output device";
        return;
    }

    for (const QAudioDevice& dev : candidates) {
        if (!openSink(dev)) continue;
        if (dev != preferred)
            qWarning() << "clay::sound::AudioOutput: playing on"
                       << dev.description() << "- the default device did not open";
        sinceFailedOpen_.invalidate();
        sinkRunning_ = true;
        pullTimer_.start(BUFFER_MS);
        return;
    }

    // Leave the sink closed rather than writing into a dead one: the next
    // triggered note calls start() again, by which time the device list
    // may have settled.
    sinceFailedOpen_.start();
    qWarning() << "clay::sound::AudioOutput: none of" << candidates.size()
               << "audio output devices could be opened; a later note retries";
}

bool AudioOutput::openSink(const QAudioDevice& device)
{
    QAudioFormat fmt;
    fmt.setSampleRate(SAMPLE_RATE);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Float);

    delete sink_;
    sink_ = new QAudioSink(device, fmt, this);
    sink_->setBufferSize(SAMPLE_RATE * sizeof(float) / 5); // ~200ms
    device_ = sink_->start();

    // A sink that failed to open still hands out a writable QIODevice, and
    // everything written to it is discarded without a word. The state is
    // what tells the two apart: an open sink idles waiting for data, a
    // failed one stays stopped (#262). Its error() is no use here - Qt's
    // WASM sink latches UnderrunError inside start() even when the open
    // succeeded, because a push-mode sink starts out with nothing queued.
    if (!device_ || sink_->state() == QAudio::StoppedState) {
        qWarning() << "clay::sound::AudioOutput: audio output device"
                   << device.description() << "did not open (error"
                   << sink_->error() << ", state" << sink_->state() << ")";
        delete sink_;
        sink_ = nullptr;
        device_ = nullptr;
        return false;
    }
    return true;
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
