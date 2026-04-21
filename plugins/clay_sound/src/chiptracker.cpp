// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "chiptracker.h"
#include "voice_waveform.h"
#include <QDebug>
#include <algorithm>
#include <cmath>

#ifndef __EMSCRIPTEN__
#include "softsynth.h"
#include <QFileDialog>
#include <QDir>
#include <QFile>
#endif

// Scale definitions (semitone offsets from root)
static const QMap<QString, QList<int>> kScales = {
    {"major",      {0, 2, 4, 5, 7, 9, 11}},
    {"minor",      {0, 2, 3, 5, 7, 8, 10}},
    {"dorian",     {0, 2, 3, 5, 7, 9, 10}},
    {"phrygian",   {0, 1, 3, 5, 7, 8, 10}},
    {"lydian",     {0, 2, 4, 6, 7, 9, 11}},
    {"mixolydian", {0, 2, 4, 5, 7, 9, 10}},
    {"pentatonic", {0, 2, 4, 7, 9}},
    {"blues",      {0, 3, 5, 6, 7, 10}}
};

static double midiToFreq(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

static double scaleNote(const QList<int> &scale, int degree, int root, int octaveOff) {
    int sz = scale.size();
    int oct = degree >= 0 ? degree / sz : -((-degree - 1) / sz + 1);
    int idx = ((degree % sz) + sz) % sz;
    return midiToFreq(root + scale[idx] + oct * 12 + octaveOff * 12);
}

static Voice::Waveform waveformFromString(const QString &s) {
    if (s == "sine")     return Voice::Sine;
    if (s == "square")   return Voice::Square;
    if (s == "triangle") return Voice::Triangle;
    if (s == "sawtooth") return Voice::Sawtooth;
    if (s == "noise")    return Voice::Noise;
    return Voice::Triangle;
}

static int lfoTargetFromString(const QString &s) {
    if (s == "pitch")  return 1;
    if (s == "volume") return 2;
    return 0;
}

ChipTracker::ChipTracker(QObject *parent)
    : QObject(parent)
{
#ifndef __EMSCRIPTEN__
    synth_ = new SoftSynth(this);
#endif
    ready_ = true;
    emit readyChanged();

    // Default: 4 channels
    setChannelCount(4);

    connect(&stepTimer_, &QTimer::timeout, this, &ChipTracker::updatePlaybackStep);
    stepTimer_.setInterval(50);
}

ChipTracker::~ChipTracker()
{
    stop();
}

void ChipTracker::setSteps(int steps)
{
    steps = qBound(4, steps, 64);
    if (steps_ == steps) return;
    steps_ = steps;
    for (auto &ch : channels_)
        ch.cells.resize(steps_);
    emit stepsChanged();
    emit gridChanged();
}

void ChipTracker::setChannelCount(int count)
{
    count = qBound(1, count, 8);
    if (channels_.size() == count) return;
    channels_.resize(count);
    for (auto &ch : channels_)
        ch.cells.resize(steps_);
    emit channelCountChanged();
    emit channelsChanged();
    emit gridChanged();
}

void ChipTracker::setScale(const QString &scale)
{
    if (scale_ == scale) return;
    scale_ = scale;
    emit scaleChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::setRootNote(int note)
{
    note = qBound(24, note, 84);
    if (rootNote_ == note) return;
    rootNote_ = note;
    emit rootNoteChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::setTempo(int tempo)
{
    tempo = qBound(40, tempo, 240);
    if (tempo_ == tempo) return;
    tempo_ = tempo;
    emit tempoChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::setVolume(qreal volume)
{
    volume = qBound(0.0, volume, 1.0);
    if (qFuzzyCompare(volume_, volume)) return;
    volume_ = volume;
    emit volumeChanged();
#ifndef __EMSCRIPTEN__
    if (synth_) synth_->setVolume(volume);
#endif
}

void ChipTracker::setSwing(qreal swing)
{
    swing = qBound(0.0, swing, 1.0);
    if (qFuzzyCompare(swing_, swing)) return;
    swing_ = swing;
    emit swingChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::setBrightness(qreal brightness)
{
    brightness = qBound(0.0, brightness, 1.0);
    if (qFuzzyCompare(brightness_, brightness)) return;
    brightness_ = brightness;
    emit brightnessChanged();
#ifndef __EMSCRIPTEN__
    if (synth_) {
        double filterHz = 4000.0 + brightness_ * 12000.0;
        synth_->setFilterCutoff(filterHz);
    }
#endif
}

void ChipTracker::setEchoMix(qreal mix)
{
    mix = qBound(0.0, mix, 1.0);
    if (qFuzzyCompare(echoMix_, mix)) return;
    echoMix_ = mix;
    emit echoMixChanged();
#ifndef __EMSCRIPTEN__
    if (synth_) synth_->setEchoMix(mix);
#endif
}

QVariantList ChipTracker::grid() const
{
    QVariantList result;
    result.reserve(channels_.size() * steps_);
    for (const auto &ch : channels_) {
        for (int s = 0; s < steps_; ++s) {
            QVariantMap cell;
            cell["note"] = ch.cells[s].note;
            cell["velocity"] = ch.cells[s].velocity;
            result.append(cell);
        }
    }
    return result;
}

QStringList ChipTracker::availableScales() const
{
    return QStringList() << "major" << "minor" << "dorian" << "phrygian"
                         << "lydian" << "mixolydian" << "pentatonic" << "blues";
}

QVariantMap ChipTracker::cell(int ch, int step) const
{
    QVariantMap result;
    if (ch < 0 || ch >= channels_.size() || step < 0 || step >= steps_) {
        result["note"] = -1;
        result["velocity"] = 0.0;
        return result;
    }
    result["note"] = channels_[ch].cells[step].note;
    result["velocity"] = channels_[ch].cells[step].velocity;
    return result;
}

void ChipTracker::setCell(int ch, int step, int note, qreal velocity)
{
    if (ch < 0 || ch >= channels_.size() || step < 0 || step >= steps_)
        return;
    channels_[ch].cells[step].note = note;
    channels_[ch].cells[step].velocity = qBound(0.0, velocity, 1.0);
    emit gridChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::clearCell(int ch, int step)
{
    setCell(ch, step, -1, 0.0);
}

void ChipTracker::setChannelPatch(int ch, QVariantMap patch)
{
    if (ch < 0 || ch >= channels_.size()) return;

    Channel &c = channels_[ch];
    c.patchName = patch.value("name", "").toString();
    c.waveform = static_cast<int>(waveformFromString(
        patch.value("waveform", "triangle").toString()));
    c.attack = patch.value("attack", 0.01).toDouble();
    c.decay = patch.value("decay", 0.1).toDouble();
    c.sustain = patch.value("sustain", 0.6).toDouble();
    c.release = patch.value("release", 0.3).toDouble();
    c.gain = patch.value("gain", 0.25).toDouble();
    c.pitchStart = patch.value("pitchStart", 0.0).toDouble();
    c.pitchEnd = patch.value("pitchEnd", 0.0).toDouble();
    c.pitchTime = patch.value("pitchTime", 0.0).toDouble();
    c.lfoRate = patch.value("lfoRate", 0.0).toDouble();
    c.lfoDepth = patch.value("lfoDepth", 0.0).toDouble();
    c.lfoTarget = lfoTargetFromString(
        patch.value("lfoTarget", "none").toString());

    emit channelsChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::setChannelOctave(int ch, int octave)
{
    if (ch < 0 || ch >= channels_.size()) return;
    octave = qBound(-3, octave, 3);
    if (channels_[ch].octave == octave) return;
    channels_[ch].octave = octave;
    emit channelsChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::setChannelMuted(int ch, bool muted)
{
    if (ch < 0 || ch >= channels_.size()) return;
    if (channels_[ch].muted == muted) return;
    channels_[ch].muted = muted;
    emit channelsChanged();
    if (playing_) buildNoteEvents();
}

QVariantMap ChipTracker::channelInfo(int ch) const
{
    QVariantMap info;
    if (ch < 0 || ch >= channels_.size()) return info;

    const Channel &c = channels_[ch];
    info["patchName"] = c.patchName;
    info["octave"] = c.octave;
    info["muted"] = c.muted;

    static const QStringList waveNames = {"sine","square","triangle","sawtooth","noise"};
    info["waveform"] = (c.waveform >= 0 && c.waveform < waveNames.size())
                           ? waveNames[c.waveform] : "triangle";
    return info;
}

void ChipTracker::setChannelPattern(int ch, QVariantList pattern)
{
    if (ch < 0 || ch >= channels_.size()) return;
    for (int s = 0; s < steps_ && s < pattern.size(); ++s) {
        QVariant v = pattern[s];
        if (v.typeId() == QMetaType::QVariantMap) {
            QVariantMap m = v.toMap();
            channels_[ch].cells[s].note = m.value("note", -1).toInt();
            channels_[ch].cells[s].velocity = m.value("velocity", 0.8).toDouble();
        } else {
            // Simple integer array: value is the scale degree, -1 = rest
            int note = v.toInt();
            channels_[ch].cells[s].note = note;
            channels_[ch].cells[s].velocity = (note >= 0) ? 0.8 : 0.0;
        }
    }
    emit gridChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::clearChannel(int ch)
{
    if (ch < 0 || ch >= channels_.size()) return;
    for (auto &cell : channels_[ch].cells) {
        cell.note = -1;
        cell.velocity = 0.0;
    }
    emit gridChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::clearAll()
{
    for (auto &ch : channels_)
        for (auto &cell : ch.cells) {
            cell.note = -1;
            cell.velocity = 0.0;
        }
    emit gridChanged();
    if (playing_) buildNoteEvents();
}

void ChipTracker::play()
{
#ifndef __EMSCRIPTEN__
    if (!synth_) return;
    buildNoteEvents();
    synth_->play();
#endif
    playing_ = true;
    playbackStep_ = 0;
    emit playingChanged();
    emit playbackStepChanged();
    stepTimer_.start();
}

void ChipTracker::stop()
{
#ifndef __EMSCRIPTEN__
    if (synth_) synth_->stop();
#endif
    stepTimer_.stop();
    playing_ = false;
    playbackStep_ = -1;
    emit playingChanged();
    emit playbackStepChanged();
}

void ChipTracker::updatePlaybackStep()
{
#ifndef __EMSCRIPTEN__
    if (!synth_ || !playing_) return;
    double secPerBeat = 60.0 / tempo_;
    double stepDur = secPerBeat * 0.25;
    if (stepDur <= 0.0) return;
    int step = static_cast<int>(synth_->position() / stepDur) % steps_;
    if (step != playbackStep_) {
        playbackStep_ = step;
        emit playbackStepChanged();
    }
#endif
}

#ifndef __EMSCRIPTEN__

void ChipTracker::buildNoteEvents()
{
    if (!synth_) return;

    const auto scaleNotes = kScales.value(scale_, kScales["dorian"]);
    double secPerBeat = 60.0 / tempo_;
    double stepDur = secPerBeat * 0.25; // 16th note

    std::vector<NoteEvent> notes;

    for (int ch = 0; ch < channels_.size(); ++ch) {
        const Channel &channel = channels_[ch];
        if (channel.muted) continue;

        for (int s = 0; s < steps_; ++s) {
            const Cell &cell = channel.cells[s];
            if (cell.note < 0) continue;

            double t = s * stepDur;
            // Swing: offset every other 16th note
            if (s % 2 == 1)
                t += swing_ * stepDur * 0.33;

            double freq = scaleNote(scaleNotes, cell.note, rootNote_,
                                    channel.octave);

            NoteEvent ne;
            ne.time = t;
            ne.frequency = freq;
            ne.duration = stepDur * 0.9;
            ne.gain = channel.gain * cell.velocity;
            ne.waveform = static_cast<Voice::Waveform>(channel.waveform);

            // Patch ADSR
            ne.attack = channel.attack;
            ne.decay = channel.decay;
            ne.sustain = channel.sustain;
            ne.release = channel.release;

            // Patch pitch envelope
            ne.pitchStart = channel.pitchStart;
            ne.pitchEnd = channel.pitchEnd;
            ne.pitchTime = channel.pitchTime;

            // Patch LFO
            ne.lfoRate = channel.lfoRate;
            ne.lfoDepth = channel.lfoDepth;
            ne.lfoTarget = channel.lfoTarget;

            notes.push_back(ne);
        }
    }

    double loopDuration = steps_ * stepDur;

    // Apply effects
    double filterHz = 4000.0 + brightness_ * 12000.0;
    synth_->setFilterCutoff(filterHz);
    synth_->setEchoMix(echoMix_);
    synth_->setVolume(volume_);

    synth_->loadComposition(notes, loopDuration);
}

void ChipTracker::exportWav(const QString &path)
{
    if (!synth_) return;

    buildNoteEvents();

    QString filePath = path;
    if (filePath.isEmpty()) {
        QString defaultName = QString("chiptracker_%1_%2bpm.wav")
            .arg(scale_).arg(tempo_);
        filePath = QFileDialog::getSaveFileName(nullptr, "Save WAV",
            QDir::homePath() + "/" + defaultName, "WAV files (*.wav)");
        if (filePath.isEmpty()) return;
    }

    int totalSamples = static_cast<int>(synth_->loopDuration() * 44100);
    if (totalSamples <= 0) return;

    SoftSynth renderer;
    double filterHz = 4000.0 + brightness_ * 12000.0;
    renderer.setFilterCutoff(filterHz);
    renderer.setEchoMix(echoMix_);
    renderer.setVolume(volume_);
    renderer.loadComposition(synth_->compositionData(), synth_->loopDuration());

    std::vector<float> samples(totalSamples);
    renderer.renderOffline(samples.data(), totalSamples);

    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "ChipTracker: Cannot write to" << filePath;
        return;
    }

    int dataSize = totalSamples * 2;
    int fileSize = 36 + dataSize;
    auto writeU32 = [&](uint32_t v) { f.write(reinterpret_cast<char*>(&v), 4); };
    auto writeU16 = [&](uint16_t v) { f.write(reinterpret_cast<char*>(&v), 2); };

    f.write("RIFF", 4); writeU32(fileSize);
    f.write("WAVEfmt ", 8); writeU32(16);
    writeU16(1); writeU16(1); writeU32(44100);
    writeU32(44100 * 2); writeU16(2); writeU16(16);
    f.write("data", 4); writeU32(dataSize);

    for (int i = 0; i < totalSamples; ++i) {
        int16_t s = static_cast<int16_t>(std::clamp(samples[i], -1.0f, 1.0f) * 32767);
        f.write(reinterpret_cast<char*>(&s), 2);
    }
    f.close();

    qDebug() << "[ChipTracker] WAV exported to:" << filePath;
    emit exportFinished(filePath);
}

#endif // !__EMSCRIPTEN__
