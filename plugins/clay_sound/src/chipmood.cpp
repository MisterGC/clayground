// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "chipmood.h"
#include "softsynth.h"
#include "engine/pcm_buffer.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <cmath>


int ChipMood::nextInstanceId_ = 0;

ChipMood::ChipMood(QObject *parent)
    : QObject(parent)
{
    instanceId_ = nextInstanceId_++;
    initAudio();

    connect(&sectionTimer_, &QTimer::timeout, this, &ChipMood::updateSectionInfo);
    sectionTimer_.setInterval(100);
}

ChipMood::~ChipMood()
{
    stop();
}

void ChipMood::initAudio()
{
    synth_ = new SoftSynth(this);
    ready_ = true;
    emit readyChanged();
}

void ChipMood::applyConfiguration()
{
    if (preset_.isEmpty()) return;
    totalSections_ = 4;
    emit totalSectionsChanged();
    emit shareCodeChanged();
    if (synth_) {
        buildComposition();
        // Composition is swapped in-place; if already playing, continues seamlessly
    }
}

void ChipMood::setPreset(const QVariantMap &preset)
{
    if (preset_ == preset) return;
    preset_ = preset;
    emit presetChanged();
    applyConfiguration();
}

void ChipMood::setPresetName(const QString &name)
{
    if (presetName_ == name) return;
    presetName_ = name;
    emit presetNameChanged();
    emit shareCodeChanged();
}

void ChipMood::setScale(const QString &scale)
{
    if (scale_ == scale) return;
    scale_ = scale;
    emit scaleChanged();
    applyConfiguration();
}

void ChipMood::setLayers(const QStringList &layers)
{
    if (layers_ == layers) return;
    layers_ = layers;
    emit layersChanged();
    applyConfiguration();
}

void ChipMood::setSeed(int seed)
{
    if (seed_ == seed) return;
    seed_ = seed;
    emit seedChanged();
    applyConfiguration();
}

void ChipMood::setVolume(qreal volume)
{
    volume = qBound(0.0, volume, 1.0);
    if (qFuzzyCompare(volume_, volume)) return;
    volume_ = volume;
    emit volumeChanged();
    emit shareCodeChanged();
    if (synth_) synth_->setVolume(volume);
}

void ChipMood::setIntensity(qreal intensity)
{
    intensity = qBound(0.0, intensity, 1.0);
    if (qFuzzyCompare(intensity_, intensity)) return;
    intensity_ = intensity;
    emit intensityChanged();
    emit shareCodeChanged();
    if (synth_ && !preset_.isEmpty()) buildComposition();
}

void ChipMood::setTempo(int tempo)
{
    tempo = qBound(60, tempo, 180);
    if (tempo_ == tempo) return;
    tempo_ = tempo;
    emit tempoChanged();
    emit shareCodeChanged();
    if (synth_ && !preset_.isEmpty()) buildComposition();
}

void ChipMood::setSwing(qreal swing)
{
    swing = qBound(0.0, swing, 1.0);
    if (qFuzzyCompare(swing_, swing)) return;
    swing_ = swing;
    emit swingChanged();
    emit shareCodeChanged();
    if (synth_ && !preset_.isEmpty()) buildComposition();
}

void ChipMood::setVariation(qreal variation)
{
    variation = qBound(0.0, variation, 1.0);
    if (qFuzzyCompare(variation_, variation)) return;
    variation_ = variation;
    emit variationChanged();
    emit shareCodeChanged();
    if (synth_ && !preset_.isEmpty()) buildComposition();
}

void ChipMood::setOctaveShift(int shift)
{
    shift = qBound(-2, shift, 2);
    if (octaveShift_ == shift) return;
    octaveShift_ = shift;
    emit octaveShiftChanged();
    emit shareCodeChanged();
    if (synth_ && !preset_.isEmpty()) buildComposition();
}

void ChipMood::setBrightness(qreal brightness)
{
    brightness = qBound(0.0, brightness, 1.0);
    if (qFuzzyCompare(brightness_, brightness)) return;
    brightness_ = brightness;
    emit brightnessChanged();
    emit shareCodeChanged();
    if (synth_) {
        double warmth = preset_.value("warmth", 0.5).toDouble();
        double filterHz = 4000.0 + (1.0 - warmth) * 12000.0;
        filterHz *= (0.5 + brightness_ * 0.5);
        synth_->setFilterCutoff(filterHz);
    }
}

QString ChipMood::shareCode() const
{
    // Format: env-scale-layers-intensity-variation-tempo-seed
    // Example: cave-dor-ampb-50-30-85-42

    // Scale abbreviations
    QMap<QString, QString> scaleAbbr;
    scaleAbbr["major"] = "maj";
    scaleAbbr["minor"] = "min";
    scaleAbbr["dorian"] = "dor";
    scaleAbbr["phrygian"] = "phr";
    scaleAbbr["lydian"] = "lyd";
    scaleAbbr["mixolydian"] = "mix";
    scaleAbbr["pentatonic"] = "pent";
    scaleAbbr["blues"] = "blu";

    QString scaleCode = scaleAbbr.value(scale_, scale_.left(3));

    // Layer encoding: a=arp, m=melody, p=pad, b=bass
    QString layerCode;
    if (layers_.contains("arp")) layerCode += "a";
    if (layers_.contains("melody")) layerCode += "m";
    if (layers_.contains("pad")) layerCode += "p";
    if (layers_.contains("bass")) layerCode += "b";
    if (layerCode.isEmpty()) layerCode = "none";

    return QString("%1-%2-%3-%4-%5-%6-%7")
        .arg(presetName_.isEmpty() ? QStringLiteral("custom") : presetName_)
        .arg(scaleCode)
        .arg(layerCode)
        .arg(qRound(intensity_ * 100))
        .arg(qRound(variation_ * 100))
        .arg(tempo_)
        .arg(seed_);
}

void ChipMood::setShareCode(const QString &code)
{
    QStringList parts = code.split('-');
    if (parts.size() < 7) return;

    // Parse preset name (actual preset config must be set separately by the caller)
    QString pName = parts[0];

    // Parse scale
    QMap<QString, QString> scaleExpand;
    scaleExpand["maj"] = "major";
    scaleExpand["min"] = "minor";
    scaleExpand["dor"] = "dorian";
    scaleExpand["phr"] = "phrygian";
    scaleExpand["lyd"] = "lydian";
    scaleExpand["mix"] = "mixolydian";
    scaleExpand["pent"] = "pentatonic";
    scaleExpand["blu"] = "blues";
    QString scl = scaleExpand.value(parts[1], parts[1]);

    // Parse layers
    QStringList lyrs;
    QString layerCode = parts[2];
    if (layerCode.contains('a')) lyrs << "arp";
    if (layerCode.contains('m')) lyrs << "melody";
    if (layerCode.contains('p')) lyrs << "pad";
    if (layerCode.contains('b')) lyrs << "bass";

    // Parse numeric values
    bool ok;
    int intensityPct = parts[3].toInt(&ok);
    if (!ok) return;
    int variationPct = parts[4].toInt(&ok);
    if (!ok) return;
    int tempoVal = parts[5].toInt(&ok);
    if (!ok) return;
    int seedVal = parts[6].toInt(&ok);
    if (!ok) return;

    // Apply all values (without triggering multiple reconfigurations)
    bool wasBlocked = blockSignals(true);

    presetName_ = pName;
    scale_ = scl;
    layers_ = lyrs;
    seed_ = seedVal;
    intensity_ = intensityPct / 100.0;
    variation_ = variationPct / 100.0;
    tempo_ = tempoVal;

    blockSignals(wasBlocked);

    // Apply configuration once (only if preset config is already set)
    applyConfiguration();

    // Emit all signals
    emit presetNameChanged();
    emit scaleChanged();
    emit layersChanged();
    emit seedChanged();
    emit intensityChanged();
    emit variationChanged();
    emit tempoChanged();
    emit shareCodeChanged();
}

QStringList ChipMood::availableScales() const
{
    return QStringList() << "major" << "minor" << "dorian" << "phrygian"
                         << "lydian" << "mixolydian" << "pentatonic" << "blues";
}

QStringList ChipMood::availableLayers() const
{
    return QStringList() << "arp" << "melody" << "pad" << "bass";
}

void ChipMood::play()
{
    if (synth_) {
        buildComposition();
        synth_->play();
    }
    playing_ = true;
    emit playingChanged();
    sectionTimer_.start();
}

void ChipMood::stop()
{
    if (synth_) synth_->stop();
    sectionTimer_.stop();
    playing_ = false;
    emit playingChanged();
}

void ChipMood::pause()
{
    if (synth_) synth_->pause();
    playing_ = false;
    emit playingChanged();
}

void ChipMood::resume()
{
    if (synth_) synth_->resume();
    playing_ = true;
    emit playingChanged();
}

void ChipMood::randomize()
{
    // Bump the seed and rebuild so playback jumps to a fresh composition.
    seed_ = static_cast<int>(QRandomGenerator::global()->generate());
    emit seedChanged();
    emit shareCodeChanged();
    if (synth_ && !preset_.isEmpty()) buildComposition();
}

QString ChipMood::sectionName() const
{
    static const QStringList names = {"A", "B", "A'", "C", "D", "E", "F", "G"};
    if (currentSection_ >= 0 && currentSection_ < names.size())
        return names[currentSection_];
    return QString::number(currentSection_ + 1);
}

void ChipMood::updateSectionInfo()
{
    // Section tracking on top of SoftSynth's loop position.
    if (!synth_ || totalSections_ <= 0) return;
    const double loop = synth_->loopDuration();
    if (loop <= 0.0) return;
    const double pos = std::fmod(synth_->position(), loop);
    const double sectionLen = loop / totalSections_;
    if (sectionLen <= 0.0) return;
    const int sect = std::min(totalSections_ - 1,
                              static_cast<int>(pos / sectionLen));
    const double prog = (pos - sect * sectionLen) / sectionLen;
    if (sect != currentSection_) {
        currentSection_ = sect;
        emit currentSectionChanged();
    }
    if (!qFuzzyCompare(prog, sectionProgress_)) {
        sectionProgress_ = prog;
        emit sectionProgressChanged();
    }
}

void ChipMood::exportWav(const QString &path)
{
    if (!synth_ || preset_.isEmpty() || path.isEmpty()) return;

    // Rebuild the composition and render it offline via a scratch
    // SoftSynth (live synth state is preserved).
    buildComposition();
    const int sampleRate = 44100;
    const int totalSamples = static_cast<int>(synth_->loopDuration() * sampleRate);
    if (totalSamples <= 0) return;

    SoftSynth renderer;
    const double warmth = preset_.value("warmth", 0.5).toDouble();
    double filterHz = (4000.0 + (1.0 - warmth) * 12000.0) * (0.5 + brightness_ * 0.5);
    renderer.setFilterCutoff(filterHz);
    renderer.setEchoMix(preset_.value("echo", 0.3).toDouble());
    renderer.setVolume(volume_);
    renderer.loadComposition(synth_->compositionData(), synth_->loopDuration());

    std::vector<float> samples(totalSamples);
    renderer.renderOffline(samples.data(), totalSamples);

    const auto pcm = clay::sound::PcmBuffer::fromFloats(std::move(samples), sampleRate);
    std::string err;
    if (!pcm.saveWav(path.toStdString(), &err)) {
        qWarning() << "ChipMood: failed to write WAV to" << path
                   << "reason:" << QString::fromStdString(err);
        return;
    }

    qDebug() << "[ChipMood] WAV exported to:" << path;
    emit exportFinished(path);
}

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
    int oct = degree / scale.size();
    int idx = ((degree % scale.size()) + scale.size()) % scale.size();
    return midiToFreq(root + scale[idx] + oct * 12 + octaveOff * 12);
}

// Simple seeded PRNG (mulberry32)
static uint32_t mulberry32(uint32_t &state) {
    state += 0x6D2B79F5;
    uint32_t t = state;
    t = (t ^ (t >> 15)) * (t | 1);
    t ^= t + (t ^ (t >> 7)) * (t | 61);
    return t ^ (t >> 14);
}

static double rngFloat(uint32_t &state) {
    return mulberry32(state) / 4294967296.0;
}

// Map arpStyle to a base pattern
static QList<int> arpPattern(const QString &style) {
    if (style == "flowing")     return {0,2,4,6, 0,2,4,7, 0,2,5,6, 0,2,4,6};
    if (style == "pulsing")     return {0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,2,0};
    if (style == "bright")      return {0,2,4,2, 0,2,4,5, 0,2,4,2, 0,4,2,0};
    if (style == "sparse")      return {0,-1,-1,-1, 2,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1};
    if (style == "majestic")    return {0,-1,4,-1, 0,-1,7,-1, 0,-1,4,-1, 0,-1,5,-1};
    if (style == "wave")        return {0,1,2,3, 4,3,2,1, 0,1,2,3, 4,5,4,3};
    if (style == "exotic")      return {0,1,4,1, 0,1,5,1, 0,1,4,1, 0,3,1,0};
    if (style == "crystalline") return {0,-1,4,-1, 7,-1,4,-1, 0,-1,5,-1, 7,-1,5,-1};
    return {0,2,4,6, 0,2,4,7};
}

static QList<int> melodyPattern(const QString &style) {
    if (style == "flowing")     return {4,3,2,1, 2,-1,-1,-1, 4,5,4,3, 2,-1,-1,-1};
    if (style == "pulsing")     return {0,-1,1,-1, 0,-1,-1,-1, -1,-1,2,-1, 1,-1,-1,-1};
    if (style == "bright")      return {4,2,0,2, 4,4,4,-1, 5,4,2,4, 5,5,5,-1};
    if (style == "sparse")      return {2,-1,-1,-1, -1,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1};
    if (style == "majestic")    return {4,-1,5,-1, 7,-1,-1,-1, 5,-1,4,-1, 2,-1,-1,-1};
    if (style == "wave")        return {2,3,4,5, 4,3,2,-1, 3,4,5,6, 5,4,3,-1};
    if (style == "exotic")      return {0,1,3,-1, 5,-1,-1,-1, 3,1,0,-1, -1,-1,-1,-1};
    if (style == "crystalline") return {7,-1,-1,-1, 5,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1};
    return {4,3,2,1, 2,-1,-1,-1};
}

void ChipMood::buildComposition()
{
    if (!synth_ || preset_.isEmpty()) return;

    const auto scale = kScales.value(scale_, kScales["dorian"]);
    const auto tempoRange = preset_["tempoRange"].toList();
    const auto rootRange = preset_["rootRange"].toList();
    const double echo = preset_.value("echo", 0.3).toDouble();
    const double warmth = preset_.value("warmth", 0.5).toDouble();
    const QString arpStyle = preset_.value("arpStyle", "flowing").toString();
    const auto sectionPat = preset_.value("sectionPattern", QVariantList{16,16,16,8}).toList();

    uint32_t rng = static_cast<uint32_t>(seed_);

    // Derive tempo and root from seed within ranges
    int tLo = tempoRange.size() >= 2 ? tempoRange[0].toInt() : 80;
    int tHi = tempoRange.size() >= 2 ? tempoRange[1].toInt() : 100;
    tempo_ = tLo + static_cast<int>(rngFloat(rng) * (tHi - tLo));
    int rLo = rootRange.size() >= 2 ? rootRange[0].toInt() : 48;
    int rHi = rootRange.size() >= 2 ? rootRange[1].toInt() : 55;
    int root = rLo + static_cast<int>(rngFloat(rng) * (rHi - rLo));

    const double secPerBeat = 60.0 / tempo_;
    const double stepDur = 0.25 * secPerBeat; // 16th note

    // Calculate total beats across all sections
    int totalBeats = 0;
    for (const auto &s : sectionPat) totalBeats += s.toInt();
    int totalSteps = totalBeats * 4; // 16th notes
    double loopDuration = totalSteps * stepDur;

    // Get patterns
    auto arp = arpPattern(arpStyle);
    auto mel = melodyPattern(arpStyle); // use same style for melody

    std::vector<NoteEvent> notes;

    for (int step = 0; step < totalSteps; ++step) {
        double t = step * stepDur;

        // Swing: offset every other 16th note for shuffle feel
        if (step % 2 == 1)
            t += swing_ * stepDur * 0.33;

        // Per-step variation RNG (deterministic, independent of composition seed)
        uint32_t varRng = static_cast<uint32_t>(seed_ * 7 + step);

        // Arpeggio layer
        if (layers_.contains("arp") && !arp.isEmpty()) {
            int deg = arp[step % arp.size()];
            if (deg >= 0) {
                if (variation_ > 0 && rngFloat(varRng) < variation_ * 0.15)
                    deg += (rngFloat(varRng) < 0.5) ? 1 : -1;
                double noteT = t;
                if (variation_ > 0)
                    noteT += (rngFloat(varRng) - 0.5) * variation_ * stepDur * 0.1;
                double freq = scaleNote(scale, deg, root, 1 + octaveShift_);
                double vol = 0.3 * (0.5 + intensity_ * 0.5);
                notes.push_back({noteT, freq, stepDur * 0.9, vol, Voice::Triangle});
            }
        }

        // Melody layer (half-note resolution)
        if (layers_.contains("melody") && (step % 2 == 0) && !mel.isEmpty()) {
            int deg = mel[(step / 2) % mel.size()];
            if (deg >= 0) {
                if (variation_ > 0 && rngFloat(varRng) < variation_ * 0.1)
                    deg += (rngFloat(varRng) < 0.5) ? 1 : -1;
                double noteT = t;
                if (variation_ > 0)
                    noteT += (rngFloat(varRng) - 0.5) * variation_ * stepDur * 0.05;
                double freq = scaleNote(scale, deg, root, 0 + octaveShift_);
                double vol = 0.25 * (0.5 + intensity_ * 0.5);
                notes.push_back({noteT, freq, stepDur * 1.8, vol, Voice::Sine});
            }
        }

        // Pad layer (whole-note resolution)
        if (layers_.contains("pad") && (step % 16 == 0)) {
            double freq = scaleNote(scale, 0, root, -1 + octaveShift_);
            double vol = 0.15 * (0.5 + intensity_ * 0.5);
            notes.push_back({t, freq, stepDur * 16, vol, Voice::Sine});
        }

        // Bass layer (half-note resolution)
        if (layers_.contains("bass") && (step % 2 == 0)) {
            int bassPattern[] = {0, -1, 0, -1, 2, -1, 0, -1};
            int deg = bassPattern[(step / 2) % 8];
            if (deg >= 0) {
                double noteT = t;
                if (variation_ > 0)
                    noteT += (rngFloat(varRng) - 0.5) * variation_ * stepDur * 0.08;
                double freq = scaleNote(scale, deg, root, -2 + octaveShift_);
                double vol = 0.2 * (0.5 + intensity_ * 0.5);
                notes.push_back({noteT, freq, stepDur * 1.8, vol, Voice::Triangle});
            }
        }
    }

    // Configure synth effects
    double filterHz = 4000.0 + (1.0 - warmth) * 12000.0;
    filterHz *= (0.5 + brightness_ * 0.5);
    synth_->setFilterCutoff(filterHz);
    synth_->setEchoMix(echo);
    synth_->setVolume(volume_);

    synth_->loadComposition(notes, loopDuration);
}
