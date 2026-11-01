// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Effect recipes (#428): the parser rejects an unknown field by its
// name, one seed renders the same samples every time and live playback
// renders the samples renderOffline() does, a play transposed by n
// semitones is the recipe with every layer's detune raised by n (#439),
// stop() ends a playing recipe within its layers' release (#441), a
// looped recipe plays on pass after pass with no gap and no jump at the
// seam, live as offline (#442), an exponential decay renders a straight
// line in dB and an exponential pitch sweep settles into its end (#447),
// a burst of 40 grains starts 40 times inside its duration, the same seed
// on the same grains and another seed on others, and the recipe's voice
// cap bounds the grains that ring at once and no other layer, and a
// grain's jitter keeps it inside its fields' ranges (#448), white noise
// drawn every sample is the noise of before, pink and brown fall 3 and 6
// dB per octave, and a noise clocked by its freq moves its spectrum down
// with a lower freq and with a play's detune (#449), FM at 1:2.76 puts
// its sidebands where the Bessel functions say, ring modulation leaves
// the sum and the difference alone, and an FM index on a decay narrows
// the spectrum with it (#450), a sine lfo is the lfo of before, a
// random lfo renders the same samples for the same seed, sample-and-hold
// holds one level a period while smooth random glides through the same
// levels, and a cutoff lfo moves the cutoff by its depth in octaves
// (#451), a layer without drive or crush, or with a crush at its
// defaults, sounds as before, drive adds the odd harmonics tanh puts on a
// sine and no even ones, crush rounds to steps of its bits and holds each
// value for a period of its rate, an oscillator and a sample layer alike,
// before the layer's gain (#452), and the values other seeds play with stay inside the declared ranges
// - drawn and measured on the render (pitch by zero crossings, gain by
// RMS, pan by the channel ratio, offset by the onset). Sample equality is only asserted between
// renders on the same machine.

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "engine/pcm_buffer.h"
#include "offline/sound_files.h"
#include "sfx/sfx_parser.h"
#include "sfx/sfx_render.h"
#include "sfx_player.h"

#include <QtTest/QtTest>
#include <QDir>
#include <QFile>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <algorithm>
#include <cmath>
#include <complex>
#include <memory>
#include <vector>

namespace cs = clay::sound;
using P = cs::SfxParam;

static constexpr int kRate = 44100;

static QByteArray readFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.readAll();
}

static cs::SfxRecipe parseOk(const QByteArray &json)
{
    const auto res = cs::SfxParser::parse(json);
    if (!res.ok) qWarning() << "parse failed:" << res.error;
    return res.recipe;
}

static double rms(const std::vector<float> &buf, size_t from, size_t n, size_t stride = 1, size_t ch = 0)
{
    double acc = 0.0;
    for (size_t i = from; i < from + n; ++i) {
        const double s = buf[i * stride + ch];
        acc += s * s;
    }
    return std::sqrt(acc / n);
}

// Frequency of a steady tone in buf[from, from + n): the span between
// the first and the last rising zero crossing over the periods between.
static double zeroCrossingFreq(const std::vector<float> &buf, size_t from, size_t n)
{
    double first = -1.0, last = -1.0;
    int periods = -1;
    for (size_t i = from + 1; i < from + n; ++i) {
        if (buf[i - 1] < 0.0f && buf[i] >= 0.0f) {
            const double t = (i - 1) + buf[i - 1] / (buf[i - 1] - buf[i]);
            if (first < 0.0) first = t;
            last = t;
            ++periods;
        }
    }
    return periods > 0 ? periods * kRate / (last - first) : 0.0;
}

// One long flat sine whose pitch, gain, pan and offset all vary.
static const char *kRangesRecipe = R"({
  "variation": { "seed": 42 },
  "layers": [ {
    "source": "sine", "freq": 440, "length": 300,
    "vary": { "detune": [-2, 2], "gain": [-6, 0], "pan": [-0.5, 0.5], "offset": [0, 20] }
  } ]
})";

// The level in dB of each `win`-frame window of buf[from, to).
static std::vector<double> dbSeries(const std::vector<float> &buf, size_t from, size_t to, size_t win)
{
    std::vector<double> db;
    for (size_t i = from; i + win <= to; i += win)
        db.push_back(20.0 * std::log10(rms(buf, i, win)));
    return db;
}

// The least-squares line through (i, y[i]): its slope per step, and the
// largest distance of a point from it.
static std::pair<double, double> lineFit(const std::vector<double> &y)
{
    const double n = static_cast<double>(y.size());
    double sx = 0, sy = 0, sxx = 0, sxy = 0;
    for (size_t i = 0; i < y.size(); ++i) {
        const double x = static_cast<double>(i);
        sx += x; sy += y[i]; sxx += x * x; sxy += x * y[i];
    }
    const double slope = (n * sxy - sx * sy) / (n * sxx - sx * sx);
    const double icept = (sy - slope * sx) / n;
    double worst = 0.0;
    for (size_t i = 0; i < y.size(); ++i)
        worst = std::max(worst, std::abs(y[i] - (icept + slope * static_cast<double>(i))));
    return {slope, worst};
}

// The power spectrum of buf, averaged over 4096-frame Hann windows:
// bin k is k * kRate / 4096 Hz, up to the Nyquist frequency.
static constexpr size_t kFft = 4096;
static std::vector<double> powerSpectrum(const std::vector<float> &buf)
{
    std::vector<double> power(kFft / 2 + 1, 0.0);
    std::vector<std::complex<double>> x(kFft);
    for (size_t at = 0; at + kFft <= buf.size(); at += kFft) {
        for (size_t i = 0; i < kFft; ++i)
            x[i] = buf[at + i] * (0.5 - 0.5 * std::cos(2.0 * M_PI * i / kFft));
        // Iterative radix-2 FFT.
        for (size_t i = 1, j = 0; i < kFft; ++i) {
            size_t bit = kFft >> 1;
            for (; j & bit; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) std::swap(x[i], x[j]);
        }
        for (size_t len = 2; len <= kFft; len <<= 1) {
            const std::complex<double> w(std::cos(2.0 * M_PI / len), -std::sin(2.0 * M_PI / len));
            for (size_t i = 0; i < kFft; i += len) {
                std::complex<double> wk(1.0, 0.0);
                for (size_t k = 0; k < len / 2; ++k) {
                    const auto u = x[i + k], v = x[i + k + len / 2] * wk;
                    x[i + k] = u + v;
                    x[i + k + len / 2] = u - v;
                    wk *= w;
                }
            }
        }
        for (size_t k = 0; k < power.size(); ++k) power[k] += std::norm(x[k]);
    }
    return power;
}

// The mean power in dB of each octave from `lowest` Hz, `octaves` of them.
static std::vector<double> octaveLevels(const std::vector<double> &power, double lowest, int octaves)
{
    std::vector<double> db;
    for (int o = 0; o < octaves; ++o) {
        const double lo = lowest * std::pow(2.0, o);
        double sum = 0.0;
        int n = 0;
        for (size_t k = 0; k < power.size(); ++k) {
            const double f = static_cast<double>(k) * kRate / kFft;
            if (f >= lo && f < 2.0 * lo) { sum += power[k]; ++n; }
        }
        db.push_back(10.0 * std::log10(sum / n));
    }
    return db;
}

// The frequency below which half of the power lies.
static double medianFrequency(const std::vector<double> &power)
{
    double total = 0.0;
    for (size_t k = 1; k < power.size(); ++k) total += power[k];
    double acc = 0.0;
    for (size_t k = 1; k < power.size(); ++k) {
        acc += power[k];
        if (acc >= total / 2.0) return static_cast<double>(k) * kRate / kFft;
    }
    return kRate / 2.0;
}

// Four seconds of one flat noise layer with `noise` as its noise group.
static QByteArray noiseRecipe(const QByteArray &noise, double freq = 440.0)
{
    return R"({"variation": {"seed": 3}, "layers": [{"source": "noise", "length": 4000, "freq": )"
           + QByteArray::number(freq) + (noise.isEmpty() ? QByteArray() : ", \"noise\": " + noise)
           + "}]}";
}

static std::vector<float> renderNoise(const QByteArray &noise, double freq = 440.0, double detune = 0.0)
{
    const auto r = parseOk(noiseRecipe(noise, freq));
    return cs::renderSfx(r, {}, 1, 1.0f, 1.0f, 0.0f, kRate, false, -1, detune);
}

// The amplitude of the sine at `freq` Hz in buf[from, from + n): a
// Hann-windowed DFT at that one frequency.
static double toneAmplitude(const std::vector<float> &buf, size_t from, size_t n, double freq)
{
    std::complex<double> acc(0.0, 0.0);
    double weight = 0.0;
    for (size_t i = 0; i < n; ++i) {
        const double w = 0.5 - 0.5 * std::cos(2.0 * M_PI * i / n);
        acc += w * buf[from + i] * std::polar(1.0, -2.0 * M_PI * freq * (from + i) / kRate);
        weight += w;
    }
    return 2.0 * std::abs(acc) / weight;
}

// J_n(x), the Bessel function of the first kind, by its power series
// (libc++ has no std::cyl_bessel_j).
static double besselJ(int n, double x)
{
    double term = std::pow(x / 2.0, n) / std::tgamma(n + 1.0);
    double sum = term;
    for (int k = 1; k < 40; ++k) {
        term *= -(x / 2.0) * (x / 2.0) / (k * (k + n));
        sum += term;
    }
    return sum;
}

// One second of one flat sine layer at 500 Hz; `group` goes into it.
static std::vector<float> renderTone(const QByteArray &group)
{
    const auto r = parseOk(R"({"layers": [{"source": "sine", "freq": 500, "length": 1000)"
                           + (group.isEmpty() ? QByteArray() : ", " + group) + "}]}");
    return cs::renderSfx(r, {}, 1, 1.0f, 1.0f, 0.0f, kRate, false, -1, 0.0);
}

// The n-th harmonic's amplitude of tanh(g sin x): its Fourier sine
// coefficient, summed over one period.
static double tanhHarmonic(double g, int n)
{
    const int steps = 1 << 16;
    double sum = 0.0;
    for (int i = 0; i < steps; ++i) {
        const double x = 2.0 * M_PI * i / steps;
        sum += std::tanh(g * std::sin(x)) * std::sin(n * x);
    }
    return std::abs(2.0 * sum / steps);
}

// A one-second 500 Hz sine at full scale, as a sample layer's source.
static cs::SfxSamples sineSample()
{
    std::vector<float> mono(kRate);
    for (int i = 0; i < kRate; ++i) mono[i] = float(std::sin(2.0 * M_PI * 500.0 * i / kRate));
    return {std::make_shared<const cs::PcmBuffer>(cs::PcmBuffer::fromFloats(std::move(mono), kRate))};
}

// That sine played by a sample layer; `fields` go into it.
static std::vector<float> renderSampleLayer(const QByteArray &fields)
{
    const auto r = parseOk(R"({"layers": [{"source": "sample", "sample": "sine.wav")"
                           + (fields.isEmpty() ? QByteArray() : ", " + fields) + "}]}");
    return cs::renderSfx(r, sineSample(), 1, 1.0f, 1.0f, 0.0f, kRate, false, -1, 0.0);
}

// The lengths of the runs of equal samples in buf[from, from + n).
static std::vector<int> runLengths(const std::vector<float> &buf, size_t from, size_t n)
{
    std::vector<int> runs{1};
    for (size_t i = from + 1; i < from + n; ++i) {
        if (buf[i] == buf[i - 1]) ++runs.back();
        else runs.push_back(1);
    }
    return runs;
}

// One mono render of the recipe `json` at `seed`.
static std::vector<float> renderRecipe(const QByteArray &json, uint32_t seed = 1)
{
    return cs::renderSfx(parseOk(json), {}, seed, 1.0f, 1.0f, 0.0f, kRate, false, -1, 0.0);
}

// Two seconds of a 500 Hz sine whose volume follows an lfo of `shape`
// at 10 Hz: one lfo period is 4410 frames.
static QByteArray volumeLfoRecipe(const QByteArray &shape, double depth = 1.0)
{
    return R"({"layers": [{"source": "sine", "freq": 500, "length": 2000,
               "lfo": {"target": "volume", "shape": ")" + shape + R"(", "rate": 10, "depth": )"
           + QByteArray::number(depth) + "}}]}";
}

class SfxRecipeTest : public QObject
{
    Q_OBJECT
private slots:
    void parsesTheDemoRecipe();
    void rejectsAnUnknownFieldByName_data();
    void rejectsAnUnknownFieldByName();
    void rejectsValuesOutsideTheirRange_data();
    void rejectsValuesOutsideTheirRange();
    void segmentCurvesAreLayerNumbers();
    void exponentialDecayIsAStraightLineInDb();
    void exponentialPitchSweepSettlesIntoItsEnd();
    void burstIsALayerGroup();
    void burstOf40GrainsStarts40TimesInsideItsDuration();
    void sameSeedPlaysTheSameGrains();
    void voiceCapBoundsTheGrainsThatRingAtOnce();
    void grainsStayInsideTheFieldRanges();
    void noiseIsALayerGroup();
    void whiteNoiseDrawnEverySampleIsTheNoiseOfBefore();
    void pinkAndBrownFall3And6DbPerOctave();
    void aLowerRateMovesTheSpectrumDown();
    void detuneMovesAClockedNoiseLayer();
    void seededNoiseIgnoresTheStartFrame();
    void fmAndRingAreLayerGroups();
    void fmOfIndexZeroIsNoFm();
    void fmAt1To276PutsTheSidebandsWhereBesselSays();
    void ringLeavesTheSumAndTheDifference();
    void theIndexEnvelopeNarrowsTheSpectrumAsItDecays();
    void lfoShapeAndCutoffTargetAreLfoFields();
    void aSineLfoIsTheLfoOfBefore();
    void aSeededRandomLfoRendersTheSameSamplesForTheSameSeed();
    void seededLfoIgnoresTheStartFrame();
    void squareAndSampleHoldHoldALevelAndSmoothRandomGlides();
    void aCutoffLfoMovesTheCutoffByItsDepthInOctaves();
    void driveAndCrushAreLayerFields();
    void withoutDriveOrCrushALayerSoundsAsBefore();
    void driveAddsTheOddHarmonicsOfTanh();
    void crushRoundsToTheStepsOfItsBits();
    void crushHoldsEachValueForAPeriodOfItsRate();
    void aSampleLayerIsDrivenAndCrushedBeforeItsGain();
    void sameSeedRendersSameSamples();
    void otherSeedsStayInsideTheDeclaredRanges();
    void poolCyclesItsVariations();
    void sampleLayerPlaysTheWav();
    void livePlaybackRendersWhatRenderOfflineReturns();
    void playerResolvesSamplesNextToTheRecipe();
    void detuneTransposesEveryLayer();
    void stopEndsTheVoicesWithinTheirRelease();
    void loopPlaysOnWithoutASeam();
    void hotReloadKeepsTheLastGoodRecipe();
};

void SfxRecipeTest::parsesTheDemoRecipe()
{
    const auto res = cs::SfxParser::parse(readFile(CLAY_SOUND_DEMO_SFX));
    QVERIFY2(res.ok, qPrintable(res.error));
    const auto &r = res.recipe;
    QCOMPARE(r.name, QStringLiteral("wheel-detent"));
    QCOMPARE(r.seed, 1u);
    QCOMPARE(r.pool, 6);
    QCOMPARE(r.layers.size(), 4);
    QCOMPARE(r.layers[0].source, cs::SfxSource::Noise);
    QCOMPARE(r.layers[0].role, QStringLiteral("transient"));
    QCOMPARE(r.layers[1].get(P::Freq), 783.99);
    QCOMPARE(r.layers[1].get(P::PitchStart), 12.0);
    QCOMPARE(r.layers[1].get(P::PitchTime), 12.0);
    QVERIFY(r.layers[1].vary[int(P::Detune)].on);
    QCOMPARE(r.layers[1].vary[int(P::Detune)].lo, -1.0);
    QCOMPARE(r.layers[3].get(P::Gain), -13.0);
    // Unset values keep their defaults.
    QCOMPARE(r.layers[3].get(P::Pan), 0.0);
    QCOMPARE(r.layers[3].get(P::Offset), 0.0);
}

void SfxRecipeTest::rejectsAnUnknownFieldByName_data()
{
    QTest::addColumn<QByteArray>("json");
    QTest::addColumn<QString>("error");
    const QByteArray layer = R"("source": "sine", "length": 10)";
    QTest::newRow("top level") << QByteArray(R"({"layer": []})")
                               << "unknown field 'layer'";
    QTest::newRow("variation") << QByteArray(R"({"variation": {"sed": 1}, "layers": [{)" + layer + "}]}")
                               << "variation: unknown field 'sed'";
    QTest::newRow("layer") << QByteArray(R"({"layers": [{)" + layer + R"(, "gian": -3}]})")
                           << "layers[0]: unknown field 'gian'";
    QTest::newRow("envelope") << QByteArray(R"({"layers": [{)" + layer + R"(}, {)" + layer
                                            + R"(, "envelope": {"decya": 5}}]})")
                              << "layers[1].envelope: unknown field 'decya'";
    QTest::newRow("pitch") << QByteArray(R"({"layers": [{)" + layer + R"(, "pitch": {"from": 5}}]})")
                           << "layers[0].pitch: unknown field 'from'";
    QTest::newRow("filter") << QByteArray(R"({"layers": [{)" + layer
                                          + R"(, "filter": {"type": "lowpass", "cutof": 500}}]})")
                            << "layers[0].filter: unknown field 'cutof'";
    QTest::newRow("vary") << QByteArray(R"({"layers": [{)" + layer + R"(, "vary": {"detnue": [0, 1]}}]})")
                          << "layers[0].vary: unknown field 'detnue'";
    QTest::newRow("burst") << QByteArray(R"({"layers": [{)" + layer
                                         + R"(, "burst": {"count": 4, "duration": 50, "rate": 2}}]})")
                           << "layers[0].burst: unknown field 'rate'";
    QTest::newRow("jitter") << QByteArray(R"({"layers": [{)" + layer
                                          + R"(, "burst": {"count": 4, "duration": 50, "jitter": {"pitch": 2}}}]})")
                            << "layers[0].burst.jitter: unknown field 'pitch'";
}

void SfxRecipeTest::rejectsAnUnknownFieldByName()
{
    QFETCH(QByteArray, json);
    QFETCH(QString, error);
    const auto res = cs::SfxParser::parse(json);
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
}

void SfxRecipeTest::rejectsValuesOutsideTheirRange_data()
{
    QTest::addColumn<QByteArray>("layer");
    QTest::addColumn<QString>("error");
    QTest::newRow("gain") << QByteArray(R"("source": "sine", "length": 10, "gain": 20)")
                          << "layers[0].gain: 20 is outside -96..12";
    QTest::newRow("no length") << QByteArray(R"("source": "noise")")
                               << "layers[0]: needs a 'length' in ms";
    QTest::newRow("unknown source") << QByteArray(R"("source": "fm", "length": 10)")
                                    << "layers[0].source: unknown source 'fm'";
    QTest::newRow("range below 0") << QByteArray(R"("source": "sine", "length": 10,
                                                   "envelope": {"attack": 1}, "vary": {"envelope.attack": [-2, 0]})")
                                   << "layers[0].vary.envelope.attack: reaches -1..1, outside 0..10000";
    QTest::newRow("min above max") << QByteArray(R"("source": "sine", "length": 10, "vary": {"gain": [0, -3]})")
                                   << "layers[0].vary.gain: min 0 is above max -3";
    QTest::newRow("filter on a sample") << QByteArray(R"("source": "sample", "sample": "a.wav",
                                                        "filter": {"type": "lowpass"})")
                                        << "layers[0].filter: does not apply to a sample layer";
    QTest::newRow("cutoff without filter") << QByteArray(R"("source": "sine", "length": 10,
                                                           "vary": {"filter.cutoff": [0, 100]})")
                                           << "layers[0].vary.filter.cutoff: needs a 'filter' with a 'type'";
    QTest::newRow("pulse width on a sine") << QByteArray(R"("source": "sine", "length": 10, "pulseWidth": 0.3)")
                                           << "layers[0].pulseWidth: applies to a square layer only";
    QTest::newRow("volume lfo above 1") << QByteArray(R"("source": "sine", "length": 10,
                                                        "lfo": {"target": "volume", "depth": 0.8},
                                                        "vary": {"lfo.depth": [0, 0.5]})")
                                        << "layers[0].lfo.depth: a volume lfo reaches at most 1";
    QTest::newRow("curve beyond exponential") << QByteArray(R"("source": "sine", "length": 10,
                                                              "envelope": {"releaseCurve": 2})")
                                              << "layers[0].envelope.releaseCurve: 2 is outside 0..1";
    QTest::newRow("decay curve on a sample") << QByteArray(R"("source": "sample", "sample": "a.wav",
                                                             "envelope": {"decayCurve": 1})")
                                             << "layers[0].envelope.decayCurve: does not apply to a sample layer";
    QTest::newRow("filter curve without filter") << QByteArray(R"("source": "sine", "length": 10,
                                                                 "vary": {"filter.decayCurve": [0, 0.5]})")
                                                 << "layers[0].vary.filter.decayCurve: needs a 'filter' with a 'type'";
    QTest::newRow("burst on a sample") << QByteArray(R"("source": "sample", "sample": "a.wav",
                                                       "burst": {"count": 4, "duration": 50})")
                                       << "layers[0].burst: does not apply to a sample layer";
    QTest::newRow("burst without duration") << QByteArray(R"("source": "noise", "length": 2, "burst": {"count": 4})")
                                            << "layers[0].burst: needs a 'duration'";
    QTest::newRow("no grains") << QByteArray(R"("source": "noise", "length": 2, "burst": {"count": 0, "duration": 50})")
                               << "layers[0].burst.count: 0 is outside 1..256";
    QTest::newRow("density 0") << QByteArray(R"("source": "noise", "length": 2,
                                               "burst": {"count": 4, "duration": 50, "density": 0})")
                               << "layers[0].burst.density: 0 is outside 0.01..100";
    QTest::newRow("cutoff jitter without filter") << QByteArray(R"("source": "noise", "length": 2,
                                                                  "burst": {"count": 4, "duration": 50,
                                                                            "jitter": {"cutoff": 1}})")
                                                  << "layers[0].burst.jitter.cutoff: needs a 'filter' with a 'type'";
    QTest::newRow("burst number without burst") << QByteArray(R"("source": "noise", "length": 2,
                                                                "vary": {"burst.count": [0, 4]})")
                                                << "layers[0].vary.burst.count: needs a 'burst'";
}

void SfxRecipeTest::rejectsValuesOutsideTheirRange()
{
    QFETCH(QByteArray, layer);
    QFETCH(QString, error);
    const auto res = cs::SfxParser::parse("{\"layers\": [{" + layer + "}]}");
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
}

void SfxRecipeTest::segmentCurvesAreLayerNumbers()
{
    const auto r = parseOk(R"({ "layers": [
      { "source": "sine", "length": 100,
        "envelope": { "attackCurve": 0.25, "decayCurve": 1, "releaseCurve": 0.5 },
        "pitch": { "start": 12, "time": 30, "curve": 1 },
        "filter": { "type": "lowpass", "attackCurve": 0.1, "decayCurve": 0.2, "releaseCurve": 0.3 },
        "vary": { "pitch.curve": [-0.5, 0] } },
      { "source": "sample", "sample": "a.wav",
        "envelope": { "attackCurve": 1, "releaseCurve": 1 } },
      { "source": "noise", "length": 100 } ] })");
    QCOMPARE(r.layers.size(), 3);
    const auto &l = r.layers[0];
    QCOMPARE(l.get(P::AttackCurve), 0.25);
    QCOMPARE(l.get(P::DecayCurve), 1.0);
    QCOMPARE(l.get(P::ReleaseCurve), 0.5);
    QCOMPARE(l.get(P::PitchCurve), 1.0);
    QCOMPARE(l.get(P::FilterAttackCurve), 0.1);
    QCOMPARE(l.get(P::FilterDecayCurve), 0.2);
    QCOMPARE(l.get(P::FilterReleaseCurve), 0.3);
    QVERIFY(l.vary[int(P::PitchCurve)].on);
    QCOMPARE(r.layers[1].get(P::AttackCurve), 1.0);
    QCOMPARE(r.layers[1].get(P::ReleaseCurve), 1.0);
    // Linear unless set.
    for (P p : {P::AttackCurve, P::DecayCurve, P::ReleaseCurve, P::PitchCurve,
                P::FilterAttackCurve, P::FilterDecayCurve, P::FilterReleaseCurve})
        QCOMPARE(r.layers[2].get(p), 0.0);
}

// A 1 kHz sine decays from full to nothing over 500 ms. With decayCurve
// 1 its level, measured in 10 ms windows (ten periods each), falls on a
// straight line in dB at 60 dB per decay time; linear, the same fit
// misses by more than 3 dB.
void SfxRecipeTest::exponentialDecayIsAStraightLineInDb()
{
    auto decay = [](const char *curve) {
        const auto r = parseOk(QByteArray(R"({ "layers": [ { "source": "sine", "freq": 1000, "length": 600,
            "envelope": { "decay": 500, "sustain": 0, "decayCurve": )") + curve + " } } ] }");
        const auto buf = cs::renderSfx(r, {}, 0, 1.0f, 1.0f, 0.0f, kRate, false);
        // From 10 ms to 450 ms: the first window lies past the onset, the
        // last before -60 dB, where the segment ends.
        return dbSeries(buf, kRate / 100, kRate * 45 / 100, kRate / 100);
    };

    const auto exponential = decay("1");
    QCOMPARE(exponential.size(), size_t{44});
    const auto [slope, worst] = lineFit(exponential);
    qInfo("exponential: %.4f dB per 10 ms, farthest point %.4f dB from the line", slope, worst);
    QVERIFY2(std::abs(slope - (-1.2)) < 0.01, qPrintable(QString::number(slope)));   // -60 dB / 50 windows
    QVERIFY2(worst < 0.05, qPrintable(QString::number(worst)));

    const auto linear = decay("0");
    const auto [linSlope, linWorst] = lineFit(linear);
    qInfo("linear: %.4f dB per 10 ms, farthest point %.2f dB from the line", linSlope, linWorst);
    QVERIFY2(linWorst > 3.0, qPrintable(QString::number(linWorst)));
}

// A sweep from +12 semitones to 0 over 200 ms, read halfway: linear it
// is at +6 (1414 Hz); exponential it has covered all but 10^-1.5 of the
// way, +0.38 semitones (1022 Hz); after the sweep it is at its end.
void SfxRecipeTest::exponentialPitchSweepSettlesIntoItsEnd()
{
    auto sweep = [](const char *curve) {
        const auto r = parseOk(QByteArray(R"({ "layers": [ { "source": "sine", "freq": 1000, "length": 400,
            "pitch": { "start": 12, "end": 0, "time": 200, "curve": )") + curve + " } } ] }");
        return cs::renderSfx(r, {}, 0, 1.0f, 1.0f, 0.0f, kRate, false);
    };
    const size_t halfway = kRate * 95 / 1000, ms10 = kRate / 100;

    const double linHz = zeroCrossingFreq(sweep("0"), halfway, ms10);
    const auto exp = sweep("1");
    const double expHz = zeroCrossingFreq(exp, halfway, ms10);
    const double expected = 1000.0 * std::pow(2.0, std::pow(10.0, -1.5));
    qInfo("halfway: linear %.1f Hz, exponential %.1f Hz (expected %.1f)", linHz, expHz, expected);
    QVERIFY2(std::abs(linHz / (1000.0 * std::sqrt(2.0)) - 1.0) < 0.01, qPrintable(QString::number(linHz)));
    QVERIFY2(std::abs(expHz / expected - 1.0) < 0.01, qPrintable(QString::number(expHz)));

    const double after = zeroCrossingFreq(exp, kRate * 250 / 1000, kRate / 10);
    QVERIFY2(std::abs(after / 1000.0 - 1.0) < 0.002, qPrintable(QString::number(after)));
}

void SfxRecipeTest::burstIsALayerGroup()
{
    const auto r = parseOk(R"({ "maxVoices": 6, "layers": [
      { "source": "noise", "length": 3, "filter": { "type": "bandpass", "cutoff": 1400 },
        "burst": { "count": 23, "duration": 420, "density": 0.2,
                   "jitter": { "time": 1, "gain": 3, "cutoff": 0.5, "freq": 2, "length": 1 } },
        "vary": { "burst.count": [-3, 3], "burst.jitter.gain": [0, 2] } },
      { "source": "sine", "length": 100 } ] })");
    QCOMPARE(r.maxVoices, 6);
    const auto &l = r.layers[0];
    QVERIFY(l.burst);
    QCOMPARE(l.get(P::BurstCount), 23.0);
    QCOMPARE(l.get(P::BurstDuration), 420.0);
    QCOMPARE(l.get(P::BurstDensity), 0.2);
    QCOMPARE(l.get(P::JitterTime), 1.0);
    QCOMPARE(l.get(P::JitterGain), 3.0);
    QCOMPARE(l.get(P::JitterCutoff), 0.5);
    QCOMPARE(l.get(P::JitterFreq), 2.0);
    QCOMPARE(l.get(P::JitterLength), 1.0);
    QVERIFY(l.vary[int(P::BurstCount)].on);
    QVERIFY(l.vary[int(P::JitterGain)].on);
    // A layer without one plays as one note, as before.
    QVERIFY(!r.layers[1].burst);
    QCOMPARE(cs::realizeSfx(r, 1).size(), size_t(cs::realizeSfx(r, 1)[0].get(P::BurstCount) + 0.5) + 1);

    // The cap is the grains'; with no burst there is nothing to cap.
    auto res = cs::SfxParser::parse(R"({"maxVoices": 4, "layers": [{"source": "sine", "length": 10}]})");
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith("maxVoices: caps the grains of a 'burst'"), qPrintable(res.error));
    res = cs::SfxParser::parse(R"({"maxVoices": 2.5, "layers": [{"source": "sine", "length": 10}]})");
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith("maxVoices: must be an integer in 0..256"), qPrintable(res.error));
}

// Grains of white noise: 40 within 600 ms after a 50 ms offset, each
// 1.5 to 2.5 ms long, placed anywhere in the middle half of its slot, the
// grain rate at the end a quarter of the one at the start. The slots are
// at least 8 ms wide, so there is silence before every grain.
static const char *kGritRecipe = R"({"variation": {"seed": 11}, "layers": [
  {"name": "grit", "source": "noise", "offset": 50, "length": 2, "gain": -6,
   "envelope": {"decay": 2, "sustain": 0},
   "burst": {"count": 40, "duration": 600, "density": 0.25,
             "jitter": {"time": 0.5, "gain": 6, "length": 0.5}}}]})";

// The frames where sound starts after at least `gap` frames of silence.
static std::vector<size_t> onsets(const std::vector<float> &mono, size_t gap)
{
    std::vector<size_t> out;
    size_t quiet = gap;
    for (size_t f = 0; f < mono.size(); ++f) {
        if (mono[f] == 0.0f) { ++quiet; continue; }
        if (quiet >= gap) out.push_back(f);
        quiet = 0;
    }
    return out;
}

void SfxRecipeTest::burstOf40GrainsStarts40TimesInsideItsDuration()
{
    const auto recipe = parseOk(kGritRecipe);
    const uint32_t seed = cs::sfxVariationSeed(recipe, 0);
    const auto notes = cs::realizeSfx(recipe, seed);
    QCOMPARE(notes.size(), size_t(40));
    QVERIFY(std::all_of(notes.cbegin(), notes.cend(), [](const cs::SfxNote &n) { return n.grain; }));

    const auto mono = cs::renderSfx(recipe, {}, seed, 1.0f, 1.0f, 0.0f, kRate, false);
    const auto found = onsets(mono, kRate / 2000);    // 0.5 ms of silence before each
    QCOMPARE(found.size(), size_t(40));
    const size_t begin = std::llround(0.050 * kRate), end = std::llround(0.650 * kRate);
    int firstHalf = 0;
    for (size_t i = 0; i < found.size(); ++i) {
        QVERIFY2(found[i] >= begin && found[i] < end, qPrintable(QString::number(found[i])));
        // Where the grain was placed, to the frame.
        const auto at = size_t(std::llround(notes[i].get(P::Offset) * kRate / 1000.0));
        QVERIFY2(found[i] >= at && found[i] <= at + 1, qPrintable(QString("%1 vs %2").arg(found[i]).arg(at)));
        if (found[i] < (begin + end) / 2) ++firstHalf;
    }
    qInfo("%zu onsets in %zu..%zu frames, %d of them in the first half", found.size(), begin, end, firstHalf);
    // A falling density: two thirds of an even spread in the first half.
    QVERIFY2(firstHalf >= 24 && firstHalf <= 30, qPrintable(QString::number(firstHalf)));
}

void SfxRecipeTest::sameSeedPlaysTheSameGrains()
{
    const auto recipe = parseOk(kGritRecipe);
    const auto render = [&recipe](uint32_t seed) {
        return cs::renderSfx(recipe, {}, seed, 1.0f, 1.0f, 0.0f, kRate, true);
    };
    const auto offsets = [&recipe](uint32_t seed) {
        std::vector<double> o;
        for (const auto &n : cs::realizeSfx(recipe, seed)) o.push_back(n.get(P::Offset));
        return o;
    };
    for (uint32_t seed : {1u, 2u, 0x7fffffffu}) {
        QCOMPARE(offsets(seed), offsets(seed));
        QCOMPARE(render(seed), render(seed));
    }
    // Another seed: the grains start elsewhere and sound otherwise.
    const auto a = offsets(1), b = offsets(2);
    QCOMPARE(a.size(), b.size());
    int moved = 0;
    for (size_t i = 0; i < a.size(); ++i)
        if (std::abs(a[i] - b[i]) > 0.1) ++moved;
    QVERIFY2(moved > 30, qPrintable(QString::number(moved)));
    QVERIFY(render(1) != render(2));

    // Without time jitter the grains sit in the middle of their slots,
    // the same for every seed.
    auto even = recipe;
    even.layers[0].at(P::JitterTime) = 0.0;
    const auto e1 = cs::realizeSfx(even, 1), e2 = cs::realizeSfx(even, 2);
    for (size_t i = 0; i < e1.size(); ++i) QCOMPARE(e1[i].get(P::Offset), e2[i].get(P::Offset));
}

// 40 grains of 200 ms within 100 ms under a low hum: with a cap of 4,
// four grains ring at most, and the hum rings beside them throughout.
// Without the cap all 40 would ring at once.
void SfxRecipeTest::voiceCapBoundsTheGrainsThatRingAtOnce()
{
    auto recipe = parseOk(R"({"maxVoices": 4, "layers": [
      {"name": "hum", "source": "sine", "freq": 80, "length": 500},
      {"name": "grit", "source": "noise", "length": 200, "burst": {"count": 40, "duration": 100}}]})");
    const auto mostAtOnce = [](const cs::SfxRecipe &r, size_t *atLastGrain) {
        cs::Engine eng(kRate);
        cs::SfxVoices voices;
        voices.attach(eng, r, {});
        voices.play(eng, cs::realizeSfx(r, 1), 0, 1.0f);
        std::vector<float> buf(2 * 32);
        size_t most = 0;
        for (int64_t f = 0; f < kRate * 2 / 5; f += 32) {
            eng.renderStereo(buf.data(), 32);
            most = std::max(most, eng.activeVoices());
            if (f <= kRate * 3 / 20 && f + 32 > kRate * 3 / 20) *atLastGrain = eng.activeVoices();
        }
        voices.detach(eng);
        return most;
    };
    size_t at150 = 0;
    qInfo("cap 4: at most %zu voices at once", mostAtOnce(recipe, &at150));
    QCOMPARE(mostAtOnce(recipe, &at150), size_t(4 + 1));
    QCOMPARE(at150, size_t(4 + 1));     // after the last grain started: the hum still rings
    recipe.maxVoices = 0;
    QCOMPARE(mostAtOnce(recipe, &at150), size_t(40 + 1));
}

// A layer at the top of its gain and far up in detune, with jitters
// that reach past both: every grain is held to the field's range, so
// none plays louder than 12 dB or further than 48 semitones up.
void SfxRecipeTest::grainsStayInsideTheFieldRanges()
{
    const auto recipe = parseOk(R"({"layers": [{"source": "sine", "freq": 440, "length": 5,
      "gain": 12, "detune": 40, "burst": {"count": 200, "duration": 100,
                                          "jitter": {"gain": 48, "freq": 48}}}]})");
    const auto notes = cs::realizeSfx(recipe, 1);
    QCOMPARE(notes.size(), size_t(200));
    double gainHi = -1e9, gainLo = 1e9, detuneHi = -1e9;
    for (const auto &n : notes) {
        gainHi = std::max(gainHi, n.get(P::Gain));
        gainLo = std::min(gainLo, n.get(P::Gain));
        detuneHi = std::max(detuneHi, n.get(P::Detune));
    }
    qInfo("grain gain %.2f..%.2f dB, detune up to %.2f semitones", gainLo, gainHi, detuneHi);
    QCOMPARE(gainHi, 12.0);         // grains that drew above it play at it
    QVERIFY(gainLo < -30.0);        // and the jitter still reaches down
    QCOMPARE(detuneHi, 48.0);
}

void SfxRecipeTest::noiseIsALayerGroup()
{
    using C = cs::OscillatorVoice::NoiseColor;
    using R = cs::OscillatorVoice::NoiseRate;
    const auto r = parseOk(R"({"layers": [
      {"source": "noise", "length": 10},
      {"source": "noise", "length": 10, "noise": {"color": "pink"}},
      {"source": "noise", "length": 10, "noise": {"color": "brown", "rate": "freq"}}]})");
    QCOMPARE(r.layers.size(), 3);
    QCOMPARE(r.layers[0].noiseColor, C::White);
    QCOMPARE(r.layers[0].noiseRate, R::Sample);
    QCOMPARE(r.layers[1].noiseColor, C::Pink);
    QCOMPARE(r.layers[1].noiseRate, R::Sample);
    QCOMPARE(r.layers[2].noiseColor, C::Brown);
    QCOMPARE(r.layers[2].noiseRate, R::Freq);

    const QList<QPair<QByteArray, QString>> bad = {
        {R"("source": "sine", "length": 10, "noise": {"color": "pink"})",
         "layers[0].noise: applies to a noise layer only"},
        {R"("source": "noise", "length": 10, "noise": {"colour": "pink"})",
         "layers[0].noise: unknown field 'colour'"},
        {R"("source": "noise", "length": 10, "noise": {"color": "blue"})",
         "layers[0].noise.color: unknown color 'blue' (white, pink, brown)"},
        {R"("source": "noise", "length": 10, "noise": {"rate": 2000})",
         "layers[0].noise.rate: must be a string"},
        {R"("source": "noise", "length": 10, "noise": {"rate": "pitch"})",
         "layers[0].noise.rate: unknown rate 'pitch' (sample, freq)"}};
    for (const auto &b : bad) {
        const auto res = cs::SfxParser::parse("{\"layers\": [{" + b.first + "}]}");
        QVERIFY(!res.ok);
        QVERIFY2(res.error.startsWith(b.second), qPrintable(res.error));
    }
}

void SfxRecipeTest::whiteNoiseDrawnEverySampleIsTheNoiseOfBefore()
{
    // The noise of before: one xorshift step per sample, mapped onto
    // -1..1, whatever the frequency - for the default patch, and for one
    // that names white and the sample rate.
    auto render = [](double freq, bool named) {
        cs::Engine eng(kRate);
        auto osc = std::make_unique<cs::OscillatorInstrument>();
        auto *o = osc.get();
        const int id = eng.addInstrument(std::move(osc));
        cs::NoteEvent ev;
        ev.instrumentId = id;
        ev.durationFrames = 4000;
        ev.freqHz = freq;
        cs::OscillatorVoice::Patch p;
        p.waveform = cs::OscillatorVoice::Waveform::Noise;
        p.attack = 0.0; p.decay = 0.0; p.sustain = 1.0; p.release = 0.0;
        p.noiseSeed = 77;
        if (named) {
            p.noiseColor = cs::OscillatorVoice::NoiseColor::White;
            p.noiseRate = cs::OscillatorVoice::NoiseRate::Sample;
        }
        o->pushPatch(eng.schedule(ev), p);
        std::vector<float> out(4000);
        eng.renderOffline(out.data(), 4000);
        return out;
    };
    std::vector<float> before(4000);
    uint32_t s = 77;
    for (auto &v : before) {
        s ^= s << 13; s ^= s >> 17; s ^= s << 5;
        v = static_cast<float>(static_cast<double>(s) / static_cast<double>(0xFFFFFFFFu) * 2.0 - 1.0);
    }
    for (double freq : {440.0, 55.0, 5000.0}) {
        QCOMPARE(render(freq, false), before);
        QCOMPARE(render(freq, true), before);
    }
}

void SfxRecipeTest::pinkAndBrownFall3And6DbPerOctave()
{
    // Six octaves from 250 Hz: the level falls by a straight line in dB
    // per octave, flat for white, about 3 dB for pink and 6 for brown.
    struct Colour { QByteArray noise; double slope; };
    const QList<Colour> colours = {{{}, 0.0},
                                   {R"({"color": "white"})", 0.0},
                                   {R"({"color": "pink"})", -3.0},
                                   {R"({"color": "brown"})", -6.0}};
    for (const auto &c : colours) {
        const auto levels = octaveLevels(powerSpectrum(renderNoise(c.noise)), 250.0, 6);
        const auto [slope, worst] = lineFit(levels);
        qInfo("%s: %.2f dB per octave, farthest octave %.2f dB from the line",
              c.noise.isEmpty() ? "default" : c.noise.constData(), slope, worst);
        QVERIFY2(std::abs(slope - c.slope) < 0.5,
                 qPrintable(QStringLiteral("%1: %2 dB per octave").arg(QString(c.noise)).arg(slope)));
        QVERIFY2(worst < 1.0, qPrintable(QStringLiteral("%1: %2 dB off the line").arg(QString(c.noise)).arg(worst)));
    }
    // Pink and brown sit about 6 dB below white, inside -1..1.
    const double white = rms(renderNoise({}), 0, 4 * kRate);
    for (const QByteArray &noise : {QByteArray(R"({"color": "pink"})"), QByteArray(R"({"color": "brown"})")}) {
        const auto buf = renderNoise(noise);
        const double db = 20.0 * std::log10(rms(buf, 0, buf.size()) / white);
        qInfo("%s: %.2f dB below white", noise.constData(), -db);
        QVERIFY2(db > -7.5 && db < -4.5, qPrintable(QStringLiteral("%1: %2 dB").arg(QString(noise)).arg(db)));
        for (float v : buf) QVERIFY(std::abs(v) <= 1.0f);
    }
}

void SfxRecipeTest::aLowerRateMovesTheSpectrumDown()
{
    // Clocked by its freq, the noise holds each value for one period, so
    // its power at a frequency depends on frequency / freq alone, scaled
    // by the hold: a quarter of the freq lays every octave two octaves
    // lower and 6.02 dB (4x) up - for every colour, over the five octaves
    // below each freq (above 8 kHz the images of the faster clock fold
    // back from the Nyquist frequency and add about 1 dB). Drawn every
    // sample, freq does nothing.
    for (const QByteArray color : {"white", "pink", "brown"}) {
        const QByteArray clocked = R"({"color": ")" + color + R"(", "rate": "freq"})";
        const auto high = octaveLevels(powerSpectrum(renderNoise(clocked, 8000)), 250.0, 5);  // to 8 kHz
        const auto low = octaveLevels(powerSpectrum(renderNoise(clocked, 2000)), 62.5, 5);    // to 2 kHz
        double worst = 0.0;
        for (size_t i = 0; i < high.size(); ++i)
            worst = std::max(worst, std::abs(low[i] - high[i] - 10.0 * std::log10(4.0)));
        qInfo("%s: two octaves down each octave is 6.02 dB up, give or take %.2f dB", color.constData(), worst);
        QVERIFY(worst < 1.0);
        const QByteArray unclocked = R"({"color": ")" + color + R"("})";
        QCOMPARE(renderNoise(unclocked, 8000), renderNoise(unclocked, 2000));
    }
    // For white the move is plain in one number: half of the power lies
    // below a quarter of the frequency.
    const double high = medianFrequency(powerSpectrum(renderNoise(R"({"rate": "freq"})", 8000)));
    const double low = medianFrequency(powerSpectrum(renderNoise(R"({"rate": "freq"})", 2000)));
    qInfo("white: half of the power below %.0f Hz at 8000, below %.0f Hz at 2000", high, low);
    QVERIFY(high / low > 3.0 && high / low < 5.0);
}

void SfxRecipeTest::detuneMovesAClockedNoiseLayer()
{
    // A play's detune moves a clocked noise layer as it moves its freq:
    // two octaves down puts half of the power a quarter as high.
    const QByteArray clocked = R"({"rate": "freq"})";
    const double plain = medianFrequency(powerSpectrum(renderNoise(clocked, 8000)));
    const double down = medianFrequency(powerSpectrum(renderNoise(clocked, 8000, -24)));
    QVERIFY2(plain / down > 3.0 && plain / down < 5.0,
             qPrintable(QStringLiteral("%1 Hz, %2 Hz two octaves down").arg(plain).arg(down)));
    QCOMPARE(renderNoise(clocked, 8000, -24), renderNoise(clocked, 2000));
    // Drawn every sample, it does not move.
    QCOMPARE(renderNoise({}, 8000, -24), renderNoise({}, 8000));
}

void SfxRecipeTest::fmAndRingAreLayerGroups()
{
    const auto r = parseOk(R"({"layers": [
      {"source": "sine", "length": 10},
      {"source": "sine", "length": 10, "fm": {"ratio": 2.76, "index": 2}},
      {"source": "triangle", "length": 10,
       "fm": {"ratio": 1.4, "index": 6, "decay": 300, "sustain": 0.2, "decayCurve": 1},
       "vary": {"fm.index": [-1, 1]}},
      {"source": "square", "length": 10, "ring": {"ratio": 1.5}}]})");
    QCOMPARE(r.layers.size(), 4);
    QVERIFY(!r.layers[0].fm);
    QVERIFY(!r.layers[0].ring);
    QVERIFY(r.layers[1].fm);
    QCOMPARE(r.layers[1].get(P::FmRatio), 2.76);
    QCOMPARE(r.layers[1].get(P::FmIndex), 2.0);
    QCOMPARE(r.layers[1].get(P::FmSustain), 1.0);   // a constant index
    QCOMPARE(r.layers[1].get(P::FmDecay), 0.0);
    QCOMPARE(r.layers[2].get(P::FmDecay), 300.0);
    QCOMPARE(r.layers[2].get(P::FmSustain), 0.2);
    QCOMPARE(r.layers[2].get(P::FmDecayCurve), 1.0);
    QVERIFY(r.layers[2].vary[int(P::FmIndex)].on);
    QVERIFY(r.layers[3].ring);
    QVERIFY(!r.layers[3].fm);
    QCOMPARE(r.layers[3].get(P::RingRatio), 1.5);

    const QList<QPair<QByteArray, QString>> bad = {
        {R"("source": "noise", "length": 10, "fm": {"ratio": 2, "index": 1})",
         "layers[0].fm: applies to a sine, square, triangle or sawtooth layer only"},
        {R"("source": "sample", "sample": "x.wav", "ring": {"ratio": 2})",
         "layers[0].ring: applies to a sine, square, triangle or sawtooth layer only"},
        {R"("source": "sine", "length": 10, "fm": {"ratio": 2})",
         "layers[0].fm: needs an 'index'"},
        {R"("source": "sine", "length": 10, "fm": {"index": 2})",
         "layers[0].fm: needs a 'ratio'"},
        {R"("source": "sine", "length": 10, "fm": {"ratio": 2, "index": 1, "depth": 3})",
         "layers[0].fm: unknown field 'depth'"},
        {R"("source": "sine", "length": 10, "fm": {"ratio": 2, "index": 40})",
         "layers[0].fm.index: 40 is outside 0..32"},
        {R"("source": "sine", "length": 10, "fm": {"ratio": 0, "index": 1})",
         "layers[0].fm.ratio: 0 is outside 0.01..64"},
        {R"("source": "sine", "length": 10, "ring": {})",
         "layers[0].ring: needs a 'ratio'"},
        {R"("source": "sine", "length": 10, "fm": {"ratio": 2, "index": 1}, "ring": {"ratio": 2})",
         "layers[0].ring: a layer has an 'fm' or a 'ring', not both"},
        {R"("source": "sine", "length": 10, "vary": {"fm.index": [0, 1]})",
         "layers[0].vary.fm.index: needs an 'fm'"},
        {R"("source": "sine", "length": 10, "vary": {"ring.ratio": [0, 1]})",
         "layers[0].vary.ring.ratio: needs a 'ring'"},
        {R"("source": "sine", "length": 10, "fm": {"ratio": 2, "index": 30}, "vary": {"fm.index": [0, 4]})",
         "layers[0].vary.fm.index: reaches 30..34, outside 0..32"}};
    for (const auto &b : bad) {
        const auto res = cs::SfxParser::parse("{\"layers\": [{" + b.first + "}]}");
        QVERIFY2(!res.ok, b.first.constData());
        QVERIFY2(res.error.startsWith(b.second), qPrintable(res.error));
    }
}

void SfxRecipeTest::fmOfIndexZeroIsNoFm()
{
    // Off by default: a voice's patch has neither, and FM of index 0
    // reads the wave where it is read without FM, to the last bit.
    const cs::OscillatorVoice::Patch patch;
    QCOMPARE(patch.fmRatio, 0.0);
    QCOMPARE(patch.ringRatio, 0.0);
    QCOMPARE(renderTone(R"("fm": {"ratio": 2.76, "index": 0})"), renderTone({}));
    QVERIFY(renderTone(R"("fm": {"ratio": 2.76, "index": 1})") != renderTone({}));
}

void SfxRecipeTest::fmAt1To276PutsTheSidebandsWhereBesselSays()
{
    // A 500 Hz carrier and a modulator at 2.76 x 500 = 1380 Hz: the n-th
    // sideband pair sits at 500 + n * 1380 and |500 - n * 1380| Hz (the
    // lower ones fold back over 0 Hz: 880, 2260, 3640), at |J_n(index)| of
    // the plain sine's level - and nothing at the modulator itself or at a
    // harmonic of either.
    const auto plain = renderTone({});
    const double carrier = toneAmplitude(plain, 0, kRate, 500.0);
    QVERIFY(carrier > 0.9);
    for (double index : {1.0, 2.0}) {
        const auto buf = renderTone(R"("fm": {"ratio": 2.76, "index": )" + QByteArray::number(index) + "}");
        double worst = 0.0;
        for (int n = 0; n <= 4; ++n) {
            const double expected = std::abs(besselJ(n, index));
            const QList<double> at = n == 0 ? QList<double>{500.0}
                                            : QList<double>{500.0 + n * 1380.0, std::abs(500.0 - n * 1380.0)};
            for (double f : at) {
                const double level = toneAmplitude(buf, 0, kRate, f) / carrier;
                qInfo("index %.0f: %4.0f Hz at %.4f of the carrier, |J_%d| %.4f", index, f, level, n, expected);
                worst = std::max(worst, std::abs(level - expected));
            }
        }
        QVERIFY2(worst < 0.005, qPrintable(QStringLiteral("index %1: %2 off Bessel").arg(index).arg(worst)));
        for (double f : {1380.0, 1000.0, 2760.0, 690.0}) {
            const double level = toneAmplitude(buf, 0, kRate, f) / carrier;
            QVERIFY2(level < 0.001, qPrintable(QStringLiteral("index %1: %2 Hz at %3").arg(index).arg(f).arg(level)));
        }
    }
}

void SfxRecipeTest::ringLeavesTheSumAndTheDifference()
{
    // 500 Hz times 1380 Hz is 880 Hz plus 1880 Hz, each at half the
    // level, and neither 500 nor 1380.
    const double carrier = toneAmplitude(renderTone({}), 0, kRate, 500.0);
    const auto buf = renderTone(R"("ring": {"ratio": 2.76})");
    for (double f : {880.0, 1880.0}) {
        const double level = toneAmplitude(buf, 0, kRate, f) / carrier;
        qInfo("%4.0f Hz at %.4f of the carrier", f, level);
        QVERIFY2(std::abs(level - 0.5) < 0.005, qPrintable(QStringLiteral("%1 Hz at %2").arg(f).arg(level)));
    }
    for (double f : {500.0, 1380.0, 1000.0, 2760.0}) {
        const double level = toneAmplitude(buf, 0, kRate, f) / carrier;
        QVERIFY2(level < 0.001, qPrintable(QStringLiteral("%1 Hz at %2").arg(f).arg(level)));
    }
}

void SfxRecipeTest::theIndexEnvelopeNarrowsTheSpectrumAsItDecays()
{
    // An 8 kHz carrier, its modulator at 1 kHz, the index falling from 5
    // to 0 over the two seconds. The power-weighted spread of the
    // spectrum around the carrier is index x 1000 / sqrt(2) Hz (the sum of
    // n^2 J_n^2 is index^2 / 2), so every 4096-frame window of the
    // offline render is narrower than the one before, by the index the
    // envelope has at its middle.
    const auto r = parseOk(R"({"layers": [{"source": "sine", "freq": 8000, "length": 2000,
        "fm": {"ratio": 0.125, "index": 5, "decay": 2000, "sustain": 0}}]})");
    const auto buf = cs::renderSfx(r, {}, 1, 1.0f, 1.0f, 0.0f, kRate, false, -1, 0.0);
    QCOMPARE(buf.size(), size_t(2 * kRate));
    double before = 1e9, worst = 0.0;
    int windows = 0;
    for (size_t at = 0; at + kFft <= buf.size(); at += kFft, ++windows) {
        const auto power = powerSpectrum(std::vector<float>(buf.begin() + at, buf.begin() + at + kFft));
        double total = 0.0, moment = 0.0;
        for (size_t k = 0; k < power.size(); ++k) {
            const double df = static_cast<double>(k) * kRate / kFft - 8000.0;
            total += power[k];
            moment += df * df * power[k];
        }
        const double spread = std::sqrt(moment / total);
        const double index = 5.0 * (1.0 - (at + kFft / 2.0) / (2.0 * kRate));
        const double expected = index * 1000.0 / std::sqrt(2.0);
        qInfo("%4.0f ms: index %.2f, spread %6.1f Hz, expected %6.1f Hz",
              (at + kFft / 2.0) * 1000.0 / kRate, index, spread, expected);
        QVERIFY2(spread < before, qPrintable(QStringLiteral("window %1 is not narrower").arg(windows)));
        before = spread;
        if (expected > 200.0) worst = std::max(worst, std::abs(spread / expected - 1.0));
    }
    QCOMPARE(windows, 21);
    QVERIFY2(worst < 0.03, qPrintable(QStringLiteral("spread %1 off index x 1000 / sqrt(2)").arg(worst)));
}

void SfxRecipeTest::lfoShapeAndCutoffTargetAreLfoFields()
{
    using S = cs::OscillatorVoice::LfoShape;
    const auto r = parseOk(R"({"layers": [
      {"source": "sine", "length": 10, "lfo": {"target": "pitch", "rate": 5, "depth": 1}},
      {"source": "square", "length": 10, "lfo": {"target": "pitch", "shape": "square", "rate": 5, "depth": 1}},
      {"source": "noise", "length": 10, "lfo": {"target": "volume", "shape": "sample_hold", "rate": 20, "depth": 0.5}},
      {"source": "sawtooth", "length": 10, "filter": {"type": "lowpass"},
       "lfo": {"target": "cutoff", "shape": "smooth_random", "rate": 3, "depth": 2},
       "vary": {"lfo.depth": [0, 1]}}]})");
    QCOMPARE(r.layers.size(), 4);
    QCOMPARE(r.layers[0].lfoTarget, 1);
    QCOMPARE(r.layers[0].lfoShape, S::Sine);
    QCOMPARE(r.layers[1].lfoShape, S::Square);
    QCOMPARE(r.layers[2].lfoTarget, 2);
    QCOMPARE(r.layers[2].lfoShape, S::SampleHold);
    QCOMPARE(r.layers[3].lfoTarget, 3);
    QCOMPARE(r.layers[3].lfoShape, S::SmoothRandom);
    QCOMPARE(r.layers[3].get(P::LfoDepth), 2.0);
    QVERIFY(r.layers[3].vary[int(P::LfoDepth)].on);

    const QList<QPair<QByteArray, QString>> bad = {
        {R"("source": "sine", "length": 10, "lfo": {"target": "pitch", "shape": "triangle"})",
         "layers[0].lfo.shape: unknown shape 'triangle' (sine, square, sample_hold, smooth_random)"},
        {R"("source": "sine", "length": 10, "lfo": {"target": "pitch", "shape": 2})",
         "layers[0].lfo.shape: must be a string"},
        {R"("source": "sine", "length": 10, "lfo": {"target": "filter"})",
         "layers[0].lfo.target: unknown target 'filter' (pitch, volume, cutoff)"},
        {R"("source": "sine", "length": 10, "lfo": {"target": "cutoff", "rate": 3, "depth": 1})",
         "layers[0].lfo.target: a cutoff lfo needs a 'filter' with a 'type'"},
        {R"("source": "sine", "length": 10, "lfo": {"target": "pitch", "seed": 4})",
         "layers[0].lfo: unknown field 'seed'"},
        {R"("source": "sample", "sample": "x.wav", "lfo": {"target": "volume", "shape": "sample_hold"})",
         "layers[0].lfo: does not apply to a sample layer"}};
    for (const auto &b : bad) {
        const auto res = cs::SfxParser::parse("{\"layers\": [{" + b.first + "}]}");
        QVERIFY2(!res.ok, b.first.constData());
        QVERIFY2(res.error.startsWith(b.second), qPrintable(res.error));
    }
}

void SfxRecipeTest::aSineLfoIsTheLfoOfBefore()
{
    // The default: a voice's patch has a sine lfo seeded from its start,
    // and a recipe's lfo without a shape renders what one naming the sine
    // does, to the last bit, on each target.
    const cs::OscillatorVoice::Patch patch;
    QCOMPARE(patch.lfoShape, cs::OscillatorVoice::LfoShape::Sine);
    QCOMPARE(patch.lfoSeed, 0u);
    const auto noShape = renderTone(R"("lfo": {"target": "pitch", "rate": 5, "depth": 2})");
    QCOMPARE(renderTone(R"("lfo": {"target": "pitch", "shape": "sine", "rate": 5, "depth": 2})"), noShape);
    QVERIFY(noShape != renderTone({}));
    QCOMPARE(renderTone(R"("lfo": {"target": "volume", "shape": "sine", "rate": 5, "depth": 0.5})"),
             renderTone(R"("lfo": {"target": "volume", "rate": 5, "depth": 0.5})"));
    QCOMPARE(renderTone(R"("filter": {"type": "lowpass"}, "lfo": {"target": "cutoff", "shape": "sine", "rate": 5, "depth": 1})"),
             renderTone(R"("filter": {"type": "lowpass"}, "lfo": {"target": "cutoff", "rate": 5, "depth": 1})"));
}

void SfxRecipeTest::aSeededRandomLfoRendersTheSameSamplesForTheSameSeed()
{
    // On every target: one seed renders the same samples every time,
    // another seed other ones.
    const QList<QByteArray> layers = {
        R"("source": "sine", "freq": 300, "lfo": {"target": "pitch", "rate": 12, "depth": 3)",
        R"("source": "sine", "freq": 300, "lfo": {"target": "volume", "rate": 12, "depth": 1)",
        R"("source": "noise", "filter": {"type": "lowpass", "cutoff": 900},
           "lfo": {"target": "cutoff", "rate": 12, "depth": 2)"};
    for (const QByteArray shape : {"sample_hold", "smooth_random"}) {
        for (const auto &layer : layers) {
            const QByteArray json = R"({"layers": [{"length": 500, )" + layer
                                    + R"(, "shape": ")" + shape + R"("}}]})";
            const auto a = renderRecipe(json, 7);
            QVERIFY(!a.empty());
            QCOMPARE(renderRecipe(json, 7), a);
            QVERIFY2(renderRecipe(json, 8) != a, json.constData());
        }
    }
    // The grains of a burst each draw their own lfo.
    const QByteArray grains = R"({"layers": [{"source": "sine", "freq": 300, "length": 40,
        "lfo": {"target": "pitch", "shape": "sample_hold", "rate": 100, "depth": 12},
        "burst": {"count": 2, "duration": 100}}]})";
    const auto g = renderRecipe(grains, 3);
    QCOMPARE(renderRecipe(grains, 3), g);
    const size_t at = std::llround(0.05 * kRate);   // the second grain's slot
    QVERIFY(std::vector<float>(g.begin(), g.begin() + 1700)
            != std::vector<float>(g.begin() + at, g.begin() + at + 1700));
}

void SfxRecipeTest::seededLfoIgnoresTheStartFrame()
{
    // A voice whose patch names an lfo seed wobbles the same wherever it
    // starts; seed 0 seeds it from the start frame, and differs.
    auto render = [](int64_t start, uint32_t seed) {
        cs::Engine eng(kRate);
        auto osc = std::make_unique<cs::OscillatorInstrument>();
        auto *o = osc.get();
        const int id = eng.addInstrument(std::move(osc));
        std::vector<float> skip(static_cast<size_t>(start));
        eng.renderOffline(skip.data(), static_cast<int>(start));
        cs::NoteEvent ev;
        ev.instrumentId = id;
        ev.timeFrames = start;
        ev.durationFrames = 8000;
        ev.freqHz = 440.0;
        cs::OscillatorVoice::Patch p;
        p.attack = 0.0; p.decay = 0.0; p.sustain = 1.0; p.release = 0.0;
        p.lfoTarget = 1; p.lfoRate = 30.0; p.lfoDepth = 4.0;
        p.lfoShape = cs::OscillatorVoice::LfoShape::SmoothRandom;
        p.lfoSeed = seed;
        o->pushPatch(eng.schedule(ev), p);
        std::vector<float> out(8000);
        eng.renderOffline(out.data(), 8000);
        return out;
    };
    QCOMPARE(render(100, 77), render(5000, 77));
    QVERIFY(render(100, 0) != render(5000, 0));
    QVERIFY(render(100, 77) != render(100, 78));
}

void SfxRecipeTest::squareAndSampleHoldHoldALevelAndSmoothRandomGlides()
{
    constexpr size_t kPeriod = kRate / 10;
    constexpr size_t kEdge = kPeriod / 10;    // left out around each step
    const double sineRms = std::sqrt(0.5);

    // Square at depth 0.5: full level the first half of each period,
    // half of it the second.
    const auto sq = renderRecipe(volumeLfoRecipe("square", 0.5));
    for (size_t k = 0; k < 19; ++k) {
        const size_t at = k * kPeriod;
        QVERIFY(std::abs(rms(sq, at + kEdge, kPeriod / 2 - 2 * kEdge) - sineRms) < 0.01);
        QVERIFY(std::abs(rms(sq, at + kPeriod / 2 + kEdge, kPeriod / 2 - 2 * kEdge) - 0.5 * sineRms) < 0.01);
    }

    // Sample-and-hold: one level through a period, the two halves of it
    // alike; from period to period it moves, inside 0..1 at depth 1.
    // Smooth random, at the same seed, passes through each of those levels
    // as its period starts and glides between them: no step between two
    // neighbouring windows comes near the largest step of the held one.
    const auto sh = renderRecipe(volumeLfoRecipe("sample_hold"));
    const auto sm = renderRecipe(volumeLfoRecipe("smooth_random"));
    std::vector<double> held;
    for (size_t k = 0; k < 19; ++k) {
        const size_t at = k * kPeriod + kEdge;
        const size_t half = (kPeriod - 2 * kEdge) / 2;
        const double a = rms(sh, at, half), b = rms(sh, at + half, half);
        QVERIFY2(std::abs(a - b) < 0.005, qPrintable(QStringLiteral("period %1: %2 vs %3").arg(k).arg(a).arg(b)));
        QVERIFY(a <= sineRms + 0.005);
        held.push_back(a);
        if (k > 0) {
            const double start = rms(sm, k * kPeriod - 220, 441);   // five periods of the sine
            QVERIFY2(std::abs(start - a) < 0.01,
                     qPrintable(QStringLiteral("period %1: smooth %2, held %3").arg(k).arg(start).arg(a)));
        }
    }
    const auto [lo, hi] = std::minmax_element(held.begin(), held.end());
    QVERIFY2(*hi - *lo > 0.2, "the held levels hardly move");
    double heldStep = 0.0, smoothStep = 0.0;
    constexpr size_t kWin = kPeriod / 10;
    for (size_t i = kWin; i + kWin <= 19 * kPeriod; i += kWin) {
        heldStep = std::max(heldStep, std::abs(rms(sh, i, kWin) - rms(sh, i - kWin, kWin)));
        smoothStep = std::max(smoothStep, std::abs(rms(sm, i, kWin) - rms(sm, i - kWin, kWin)));
    }
    QVERIFY2(smoothStep < 0.3 * heldStep, qPrintable(QStringLiteral("smooth %1, held %2").arg(smoothStep).arg(heldStep)));
}

void SfxRecipeTest::aCutoffLfoMovesTheCutoffByItsDepthInOctaves()
{
    // White noise through a 1000 Hz lowpass, its cutoff moved by a 1 Hz
    // square lfo of depth 2: the first half of each second sounds as a
    // fixed 4000 Hz lowpass does, the second half as a 250 Hz one.
    auto noise = [](const QByteArray &cutoff, const QByteArray &lfo) {
        return renderRecipe(R"({"layers": [{"source": "noise", "length": 1000,
                                 "filter": {"type": "lowpass", "cutoff": )" + cutoff + "}"
                            + (lfo.isEmpty() ? QByteArray() : ", \"lfo\": " + lfo) + "}]}");
    };
    auto median = [](const std::vector<float> &buf, size_t from, size_t to) {
        return medianFrequency(powerSpectrum(std::vector<float>(buf.begin() + from, buf.begin() + to)));
    };
    const auto moved = noise("1000", R"({"target": "cutoff", "shape": "square", "rate": 1, "depth": 2})");
    const size_t half = kRate / 2, settle = 1000;
    const double high = median(moved, settle, half);
    const double low = median(moved, half + settle, kRate);
    const double at4000 = median(noise("4000", {}), settle, half);
    const double at250 = median(noise("250", {}), half + settle, kRate);
    QVERIFY2(std::abs(high / at4000 - 1.0) < 0.1, qPrintable(QStringLiteral("%1 vs %2 Hz").arg(high).arg(at4000)));
    QVERIFY2(std::abs(low / at250 - 1.0) < 0.1, qPrintable(QStringLiteral("%1 vs %2 Hz").arg(low).arg(at250)));
    QVERIFY2(high / low > 8.0, qPrintable(QStringLiteral("%1 vs %2 Hz").arg(high).arg(low)));
}

void SfxRecipeTest::seededNoiseIgnoresTheStartFrame()
{
    // A noise note with a seed of its own hisses the same wherever it
    // starts; seed 0 keeps the old start-frame seed, and differs.
    auto render = [](int64_t start, uint32_t seed) {
        cs::Engine eng(kRate);
        auto osc = std::make_unique<cs::OscillatorInstrument>();
        auto *o = osc.get();
        const int id = eng.addInstrument(std::move(osc));
        std::vector<float> skip(static_cast<size_t>(start));
        eng.renderOffline(skip.data(), static_cast<int>(start));
        cs::NoteEvent ev;
        ev.instrumentId = id;
        ev.timeFrames = start;
        ev.durationFrames = 2000;
        cs::OscillatorVoice::Patch p;
        p.waveform = cs::OscillatorVoice::Waveform::Noise;
        p.attack = 0.0; p.decay = 0.0; p.sustain = 1.0; p.release = 0.0;
        p.noiseSeed = seed;
        o->pushPatch(eng.schedule(ev), p);
        std::vector<float> out(2000);
        eng.renderOffline(out.data(), 2000);
        return out;
    };
    QCOMPARE(render(100, 77), render(5000, 77));
    QVERIFY(render(100, 0) != render(5000, 0));
    QVERIFY(render(100, 77) != render(100, 78));
}

void SfxRecipeTest::driveAndCrushAreLayerFields()
{
    const auto r = parseOk(R"({"layers": [
      {"source": "sine", "length": 10},
      {"source": "sawtooth", "length": 10, "drive": 18, "vary": {"drive": [-6, 6]}},
      {"source": "noise", "length": 10, "crush": {"bits": 4}},
      {"source": "sample", "sample": "x.wav", "drive": 6, "crush": {"rate": 8000},
       "vary": {"crush.rate": [-2000, 0]}}]})");
    QCOMPARE(r.layers.size(), 4);
    QVERIFY(!r.layers[0].drive);
    QVERIFY(!r.layers[0].crush);
    QVERIFY(r.layers[1].drive);
    QCOMPARE(r.layers[1].get(P::Drive), 18.0);
    QVERIFY(r.layers[1].vary[int(P::Drive)].on);
    QVERIFY(r.layers[2].crush);
    QCOMPARE(r.layers[2].get(P::CrushBits), 4.0);
    QCOMPARE(r.layers[2].get(P::CrushRate), 192000.0);   // holds nothing
    QVERIFY(r.layers[3].drive);
    QVERIFY(r.layers[3].crush);
    QCOMPARE(r.layers[3].get(P::CrushBits), 24.0);       // rounds nothing
    QCOMPARE(r.layers[3].get(P::CrushRate), 8000.0);

    const QList<QPair<QByteArray, QString>> bad = {
        {R"("source": "sine", "length": 10, "drive": -3)",
         "layers[0].drive: -3 is outside 0..48"},
        {R"("source": "sine", "length": 10, "drive": "hot")",
         "layers[0].drive: must be a number"},
        {R"("source": "sine", "length": 10, "crush": {})",
         "layers[0].crush: needs a 'bits' or a 'rate'"},
        {R"("source": "sine", "length": 10, "crush": {"bits": 8, "depth": 2})",
         "layers[0].crush: unknown field 'depth'"},
        {R"("source": "sine", "length": 10, "crush": {"bits": 0})",
         "layers[0].crush.bits: 0 is outside 1..24"},
        {R"("source": "sine", "length": 10, "crush": {"rate": 10})",
         "layers[0].crush.rate: 10 is outside 20..192000"},
        {R"("source": "sine", "length": 10, "vary": {"drive": [0, 6]})",
         "layers[0].vary.drive: needs a 'drive'"},
        {R"("source": "sine", "length": 10, "vary": {"crush.bits": [-2, 0]})",
         "layers[0].vary.crush.bits: needs a 'crush'"},
        {R"("source": "sine", "length": 10, "crush": {"bits": 2}, "vary": {"crush.bits": [-2, 0]})",
         "layers[0].vary.crush.bits: reaches 0..2, outside 1..24"}};
    for (const auto &b : bad) {
        const auto res = cs::SfxParser::parse("{\"layers\": [{" + b.first + "}]}");
        QVERIFY2(!res.ok, b.first.constData());
        QVERIFY2(res.error.startsWith(b.second), qPrintable(res.error));
    }
}

void SfxRecipeTest::withoutDriveOrCrushALayerSoundsAsBefore()
{
    // Off in a voice's patch, and a crush at its defaults is no crush,
    // to the last bit, on an oscillator and on a sample layer.
    QVERIFY(!cs::OscillatorVoice::Patch{}.driveCrush.active());
    QVERIFY(!cs::SampleVoice::Patch{}.driveCrush.active());
    const auto tone = renderTone({});
    QCOMPARE(renderTone(R"("crush": {"bits": 24, "rate": 192000})"), tone);
    QVERIFY(renderTone(R"("drive": 0)") != tone);   // tanh even at 0 dB
    const auto sample = renderSampleLayer({});
    QCOMPARE(renderSampleLayer(R"("crush": {"bits": 24})"), sample);
    QVERIFY(rms(sample, 0, sample.size()) > 0.5);
}

void SfxRecipeTest::driveAddsTheOddHarmonicsOfTanh()
{
    // A 500 Hz sine at full scale, 4410 frames (50 periods) from 0.25 s:
    // the first, third and fifth harmonics at what tanh(g sin) puts
    // there, the even ones at nothing, and the peak inside -1..1.
    const size_t from = kRate / 4, n = 4410;
    const auto clean = renderTone({});
    QVERIFY(toneAmplitude(clean, from, n, 1500) < 1e-4);
    double last3 = 0.0;
    for (double db : {6.0, 12.0, 24.0}) {
        const auto driven = renderTone("\"drive\": " + QByteArray::number(db));
        const double g = std::pow(10.0, db / 20.0);
        for (int h : {1, 3, 5}) {
            const double want = tanhHarmonic(g, h);
            const double got = toneAmplitude(driven, from, n, 500.0 * h);
            QVERIFY2(std::abs(got - want) < 0.01 * want + 1e-4,
                     qPrintable(QStringLiteral("%1 dB, harmonic %2: %3, tanh says %4")
                                    .arg(db).arg(h).arg(got).arg(want)));
        }
        for (int h : {2, 4})
            QVERIFY(toneAmplitude(driven, from, n, 500.0 * h) < 1e-3);
        // More drive, more of the third harmonic.
        const double third = toneAmplitude(driven, from, n, 1500);
        QVERIFY2(third > last3 + 0.02, qPrintable(QString::number(third)));
        last3 = third;
        const auto [lo, hi] = std::minmax_element(driven.begin(), driven.end());
        QVERIFY(*hi <= 1.0f && *lo >= -1.0f);
    }
}

void SfxRecipeTest::crushRoundsToTheStepsOfItsBits()
{
    // `bits` rounds every sample to a multiple of 2^(1 - bits): a sine
    // at full scale takes each of the 2^bits + 1 levels from -1 to 1.
    for (int bits : {1, 2, 4, 6}) {
        const auto crushed = renderTone("\"crush\": {\"bits\": " + QByteArray::number(bits) + "}");
        const double step = std::pow(2.0, 1 - bits);
        QSet<int> levels;
        for (float v : crushed) {
            const double k = v / step;
            QVERIFY2(std::abs(k - std::round(k)) < 1e-5, qPrintable(QString::number(v)));
            levels.insert(int(std::lround(k)));
        }
        QCOMPARE(levels.size(), (1 << bits) + 1);
        QCOMPARE(*std::max_element(levels.begin(), levels.end()), 1 << (bits - 1));
    }
    // Between two depths the step is between theirs.
    const auto between = renderTone(R"("crush": {"bits": 3.5})");
    const QSet<float> levels(between.begin(), between.end());
    QVERIFY2(levels.size() > 9 && levels.size() < 17, qPrintable(QString::number(levels.size())));
}

void SfxRecipeTest::crushHoldsEachValueForAPeriodOfItsRate()
{
    // 11025 Hz holds each value four samples exactly ...
    const auto quarter = renderTone(R"("crush": {"rate": 11025})");
    const auto runs = runLengths(quarter, 0, kRate);
    QCOMPARE(int(runs.size()), 11025);
    QVERIFY(std::all_of(runs.begin(), runs.end(), [](int r) { return r == 4; }));
    // ... the one the plain tone has at each hold's start.
    const auto tone = renderTone({});
    for (int i = 0; i < kRate; i += 4) QCOMPARE(quarter[i], tone[i]);

    // 3000 Hz: 3000 values a second, each held 14 or 15 samples
    // (44100 / 3000 = 14.7).
    const auto chip = renderTone(R"("crush": {"rate": 3000})");
    const auto chipRuns = runLengths(chip, 0, kRate);
    QVERIFY2(std::abs(int(chipRuns.size()) - 3000) <= 1, qPrintable(QString::number(chipRuns.size())));
    QVERIFY(std::all_of(chipRuns.begin(), chipRuns.end(), [](int r) { return r == 14 || r == 15; }));

    // The held steps fold the tone back from the crush rate: an image
    // at 11025 - 500 Hz that the plain tone has none of, at the level a
    // four-sample hold leaves at each frequency,
    // |sin(4 pi f / rate) / (4 sin(pi f / rate))|.
    const auto hold4 = [](double f) {
        return std::abs(std::sin(4.0 * M_PI * f / kRate) / (4.0 * std::sin(M_PI * f / kRate)));
    };
    const size_t from = kRate / 4, n = 4410;
    QVERIFY(toneAmplitude(tone, from, n, 10525) < 1e-4);
    for (double f : {500.0, 10525.0, 11525.0}) {
        const double got = toneAmplitude(quarter, from, n, f);
        QVERIFY2(std::abs(got - hold4(f)) < 0.02 * hold4(f),
                 qPrintable(QStringLiteral("%1 Hz: %2, a hold leaves %3").arg(f).arg(got).arg(hold4(f))));
    }
}

void SfxRecipeTest::aSampleLayerIsDrivenAndCrushedBeforeItsGain()
{
    // At -6 dB the samples are 3-bit steps times the gain, not steps of
    // the quieter signal: the gain comes after the crush.
    const double gain = std::pow(10.0, -6.0 / 20.0);
    const auto crushed = renderSampleLayer(R"("gain": -6, "crush": {"bits": 3})");
    QSet<int> levels;
    for (float v : crushed) {
        const double k = v / gain / 0.25;
        QVERIFY2(std::abs(k - std::round(k)) < 1e-4, qPrintable(QString::number(v)));
        levels.insert(int(std::lround(k)));
    }
    QCOMPARE(levels.size(), 9);

    // The drive is the same at either gain, only scaled by it.
    const size_t from = kRate / 4, n = 4410;
    QVERIFY(toneAmplitude(renderSampleLayer({}), from, n, 1500) < 1e-4);
    const double want = tanhHarmonic(std::pow(10.0, 12.0 / 20.0), 3);
    const double third = toneAmplitude(renderSampleLayer(R"("drive": 12)"), from, n, 1500);
    QVERIFY2(std::abs(third - want) < 0.01 * want, qPrintable(QStringLiteral("%1 vs %2").arg(third).arg(want)));
    const double quiet = toneAmplitude(renderSampleLayer(R"("drive": 12, "gain": -6)"), from, n, 1500);
    QVERIFY2(std::abs(quiet - gain * third) < 0.01 * gain * third, qPrintable(QString::number(quiet)));

    // A held rate on a sample, too.
    const auto held = renderSampleLayer(R"("crush": {"rate": 11025})");
    const auto runs = runLengths(held, 0, 4000);
    QVERIFY(std::all_of(runs.begin(), runs.end(), [](int r) { return r == 4; }));
}

void SfxRecipeTest::sameSeedRendersSameSamples()
{
    const auto recipe = parseOk(readFile(CLAY_SOUND_DEMO_SFX));
    QCOMPARE(recipe.layers.size(), 4);
    for (uint32_t seed : {0u, 1u, 12345u, 0x7fffffffu}) {
        const auto a = cs::renderSfx(recipe, {}, seed, 1.0f, 1.0f, 0.0f, kRate, true);
        const auto b = cs::renderSfx(recipe, {}, seed, 1.0f, 1.0f, 0.0f, kRate, true);
        QVERIFY(!a.empty());
        QCOMPARE(a, b);
        // The longest layer (glint, 50 ms) sets the length.
        QCOMPARE(a.size(), size_t(2 * std::llround(0.05 * kRate)));
    }
    // Another seed is another variation.
    QVERIFY(cs::renderSfx(recipe, {}, 1, 1, 1, 0, kRate, false)
            != cs::renderSfx(recipe, {}, 2, 1, 1, 0, kRate, false));
}

void SfxRecipeTest::otherSeedsStayInsideTheDeclaredRanges()
{
    const auto recipe = parseOk(kRangesRecipe);
    QCOMPARE(recipe.layers.size(), 1);

    // The drawn values: inside [min, max) and spread across it.
    struct Span { P p; double lo, hi; double seenLo = 1e9, seenHi = -1e9; };
    Span spans[] = {{P::Detune, -2, 2}, {P::Gain, -6, 0}, {P::Pan, -0.5, 0.5}, {P::Offset, 0, 20}};
    for (int i = 0; i < 2000; ++i) {
        const auto notes = cs::realizeSfx(recipe, cs::sfxVariationSeed(recipe, i));
        for (auto &s : spans) {
            const double v = notes[0].get(s.p);
            QVERIFY2(v >= s.lo && v < s.hi, qPrintable(QString("%1 = %2").arg(cs::sfxParamInfo(s.p).path).arg(v)));
            s.seenLo = std::min(s.seenLo, v);
            s.seenHi = std::max(s.seenHi, v);
        }
        QCOMPARE(notes[0].get(P::Freq), 440.0);   // not varied, not moved
    }
    for (const auto &s : spans)
        QVERIFY2(s.seenHi - s.seenLo > 0.98 * (s.hi - s.lo), cs::sfxParamInfo(s.p).path);

    // And the same on the render: what plays is inside the ranges.
    const double fLo = 440.0 * std::pow(2.0, -2.0 / 12.0), fHi = 440.0 * std::pow(2.0, 2.0 / 12.0);
    for (int i = 0; i < 24; ++i) {
        const uint32_t seed = cs::sfxVariationSeed(recipe, i);
        const auto note = cs::realizeSfx(recipe, seed)[0];
        const auto st = cs::renderSfx(recipe, {}, seed, 1.0f, 1.0f, 0.0f, kRate, true);
        const size_t frames = st.size() / 2;
        std::vector<float> mono(frames);
        for (size_t f = 0; f < frames; ++f) mono[f] = (st[2 * f] + st[2 * f + 1]) * 0.5f;

        // Onset: a sine starts at phase 0, so its first non-zero frame
        // is the one after the note starts.
        size_t onset = 0;
        while (onset < frames && mono[onset] == 0.0f) ++onset;
        const double offsetMs = (onset - 1) * 1000.0 / kRate;
        QVERIFY2(offsetMs >= -0.03 && offsetMs <= 20.03, qPrintable(QString::number(offsetMs)));
        QVERIFY(std::abs(offsetMs - note.get(P::Offset)) < 0.03);

        const size_t from = onset + kRate / 20, n = kRate / 5;
        const double f = zeroCrossingFreq(mono, from, n);
        QVERIFY2(f > fLo * 0.999 && f < fHi * 1.001, qPrintable(QString::number(f)));
        QVERIFY(std::abs(f / (440.0 * std::pow(2.0, note.get(P::Detune) / 12.0)) - 1.0) < 1e-3);

        const double l = rms(st, from, n, 2, 0), r = rms(st, from, n, 2, 1);
        const double pan = l < r ? 1.0 - l / r : r / l - 1.0;
        QVERIFY2(pan >= -0.5 - 1e-4 && pan <= 0.5 + 1e-4, qPrintable(QString::number(pan)));
        QVERIFY(std::abs(pan - note.get(P::Pan)) < 1e-3);

        // Gain: the louder channel plays the sine at full amplitude A.
        const double gainDb = 20.0 * std::log10(std::max(l, r) * std::sqrt(2.0));
        QVERIFY2(gainDb > -6.05 && gainDb < 0.05, qPrintable(QString::number(gainDb)));
        QVERIFY(std::abs(gainDb - note.get(P::Gain)) < 0.05);
    }
}

void SfxRecipeTest::poolCyclesItsVariations()
{
    auto recipe = parseOk(kRangesRecipe);
    recipe.pool = 3;
    QSet<uint32_t> seen;
    for (int i = 0; i < 9; ++i) {
        QCOMPARE(cs::sfxVariationSeed(recipe, i), cs::sfxVariationSeed(recipe, i % 3));
        seen.insert(cs::sfxVariationSeed(recipe, i));
    }
    QCOMPARE(seen.size(), 3);
    for (uint32_t s : seen) QVERIFY(s <= 0x7fffffffu);

    // No pool: every play is a new variation; another base seed, others.
    recipe.pool = 0;
    QSet<uint32_t> fresh, other;
    for (int i = 0; i < 100; ++i) fresh.insert(cs::sfxVariationSeed(recipe, i));
    QCOMPARE(fresh.size(), 100);
    recipe.seed = 43;
    for (int i = 0; i < 100; ++i) other.insert(cs::sfxVariationSeed(recipe, i));
    QVERIFY(!fresh.intersects(other));
}

void SfxRecipeTest::sampleLayerPlaysTheWav()
{
    auto pcm = cs::PcmBuffer::loadWav(CLAY_SOUND_DEMO_WAV);
    QVERIFY(pcm.has_value());
    const auto buf = std::make_shared<const cs::PcmBuffer>(std::move(*pcm));
    const auto recipe = parseOk(R"({"layers": [
        {"source": "sample", "sample": "sound.wav", "interpolation": "gaussian",
         "vary": {"detune": [-12, -12]}}]})");
    const cs::SfxSamples samples{buf};

    // An octave down plays twice as long, and one seed the same samples.
    const auto a = cs::renderSfx(recipe, samples, 5, 1, 1, 0, kRate, false);
    const auto b = cs::renderSfx(recipe, samples, 5, 1, 1, 0, kRate, false);
    QCOMPARE(a, b);
    const double expected = 2.0 * (buf->frames() - 1) * kRate / buf->sampleRate;
    QVERIFY2(std::abs(double(a.size()) - expected) <= 2.0,
             qPrintable(QString("%1 vs %2").arg(a.size()).arg(expected)));
    QVERIFY(rms(a, 0, a.size()) > 0.01);
}

static QObject *createPlayer(QQmlEngine &qml, const QUrl &source)
{
    static bool registered = false;
    if (!registered) {
        // A URI of the test's own: Clayground.Sound would load the built
        // plugin, whose engine is not this binary's.
        qmlRegisterType<SfxPlayer>("ClaySfxTest", 1, 0, "SfxPlayer");
        registered = true;
    }
    QQmlComponent c(&qml);
    c.setData("import ClaySfxTest\nSfxPlayer { }", QUrl());
    QObject *p = c.create();
    if (!p) qWarning() << c.errorString();
    else p->setProperty("source", source);
    return p;
}

void SfxRecipeTest::livePlaybackRendersWhatRenderOfflineReturns()
{
    QQmlEngine qml;
    std::unique_ptr<QObject> player(createPlayer(qml, QUrl::fromLocalFile(CLAY_SOUND_DEMO_SFX)));
    QVERIFY(player);
    QVERIFY2(player->property("loaded").toBool(), qPrintable(player->property("error").toString()));
    QCOMPARE(player->property("layers").toInt(), 4);
    QCOMPARE(player->property("pool").toInt(), 6);
    player->setProperty("volume", 0.7);
    player->setProperty("pan", -0.25);

    auto &eng = cs::AudioOutput::instance().engine();
    for (int k = 0; k < 3; ++k) {
        // Start mid-pass and far from frame 0, as a game would.
        std::vector<float> skip(12345);
        eng.renderOffline(skip.data(), 12345);

        int seed = -1;
        QVERIFY(QMetaObject::invokeMethod(player.get(), "play", Q_RETURN_ARG(int, seed), Q_ARG(qreal, 0.8)));
        int expected = -1;
        QMetaObject::invokeMethod(player.get(), "variationSeed", Q_RETURN_ARG(int, expected), Q_ARG(int, k));
        QCOMPARE(seed, expected);
        QCOMPARE(player->property("lastSeed").toInt(), seed);

        QVector<float> offline;
        QMetaObject::invokeMethod(player.get(), "renderOffline", Q_RETURN_ARG(QVector<float>, offline),
                                  Q_ARG(int, seed), Q_ARG(qreal, 0.8));
        QCOMPARE(offline.size(), qsizetype(std::llround(0.05 * kRate)));

        std::vector<float> live(static_cast<size_t>(offline.size()));
        for (size_t at = 0; at < live.size(); at += 882) {
            const int n = static_cast<int>(std::min<size_t>(882, live.size() - at));
            eng.renderOffline(live.data() + at, n);
        }
        for (auto &s : live) s = std::clamp(s, -1.0f, 1.0f);
        QCOMPARE(QVector<float>(live.begin(), live.end()), offline);
        QVERIFY(rms(live, 0, live.size()) > 0.01);
        QCOMPARE(eng.activeVoices(), size_t(0));
    }
}

void SfxRecipeTest::playerResolvesSamplesNextToTheRecipe()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(QDir().mkpath(dir.filePath("wav")));
    QVERIFY(QFile::copy(CLAY_SOUND_DEMO_WAV, dir.filePath("wav/hit.wav")));
    QFile f(dir.filePath("hit.sfx.json"));
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(R"({"layers": [{"source": "sample", "sample": "wav/hit.wav", "gain": -6},
                           {"source": "sine", "freq": 220, "length": 20}]})");
    f.close();

    QQmlEngine qml;
    std::unique_ptr<QObject> player(createPlayer(qml, QUrl::fromLocalFile(f.fileName())));
    QVERIFY(player);
    QVERIFY2(player->property("loaded").toBool(), qPrintable(player->property("error").toString()));
    QVector<float> out;
    QMetaObject::invokeMethod(player.get(), "renderOffline", Q_RETURN_ARG(QVector<float>, out),
                              Q_ARG(int, 3), Q_ARG(qreal, 1.0));
    QVERIFY(out.size() > std::llround(0.02 * kRate));

    // A missing sample fails the load and names the layer.
    QFile g(dir.filePath("missing.sfx.json"));
    QVERIFY(g.open(QIODevice::WriteOnly));
    g.write(R"({"layers": [{"source": "sine", "length": 5}, {"source": "sample", "sample": "nope.wav"}]})");
    g.close();
    player->setProperty("source", QUrl::fromLocalFile(g.fileName()));
    QVERIFY(!player->property("loaded").toBool());
    QVERIFY2(player->property("error").toString().startsWith("layers[1].sample: cannot open"),
             qPrintable(player->property("error").toString()));
}

// One sine, one noise and one sample layer, each with a detune of its
// own and a varied one; %1 is added to every layer's detune.
static QByteArray detuneRecipe(int up)
{
    return QStringLiteral(R"({"variation": {"seed": 7}, "layers": [
        {"source": "sine", "freq": 330, "length": 40, "detune": %1,
         "vary": {"detune": [-1, 1]}},
        {"source": "noise", "length": 20, "detune": %2},
        {"source": "sample", "sample": "hit.wav", "detune": %3,
         "vary": {"detune": [-0.5, 0.5]}}]})")
        .arg(3 + up).arg(-2 + up).arg(-5 + up).toUtf8();
}

void SfxRecipeTest::detuneTransposesEveryLayer()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(QFile::copy(CLAY_SOUND_DEMO_WAV, dir.filePath("hit.wav")));
    auto write = [&dir](const QString &name, const QByteArray &json) {
        QFile f(dir.filePath(name));
        if (!f.open(QIODevice::WriteOnly)) return false;
        f.write(json);
        return true;
    };
    QVERIFY(write("base.sfx.json", detuneRecipe(0)));
    QVERIFY(write("up12.sfx.json", detuneRecipe(12)));

    QQmlEngine qml;
    std::unique_ptr<QObject> base(createPlayer(qml, QUrl::fromLocalFile(dir.filePath("base.sfx.json"))));
    std::unique_ptr<QObject> up(createPlayer(qml, QUrl::fromLocalFile(dir.filePath("up12.sfx.json"))));
    QVERIFY(base && up);
    QVERIFY2(base->property("loaded").toBool(), qPrintable(base->property("error").toString()));
    QVERIFY2(up->property("loaded").toBool(), qPrintable(up->property("error").toString()));

    auto offline = [](QObject *p, int seed, qreal velocity, qreal detune) {
        QVector<float> out;
        QMetaObject::invokeMethod(p, "renderOffline", Q_RETURN_ARG(QVector<float>, out),
                                  Q_ARG(int, seed), Q_ARG(qreal, velocity), Q_ARG(qreal, detune));
        return out;
    };
    for (int seed : {1, 2, 99}) {
        const auto shifted = offline(base.get(), seed, 1.0, 12.0);
        QVERIFY(!shifted.isEmpty());
        QCOMPARE(shifted, offline(up.get(), seed, 1.0, 0.0));
        QVERIFY(shifted != offline(base.get(), seed, 1.0, 0.0));

        // Without a detune nothing changes.
        QVector<float> plain;
        QMetaObject::invokeMethod(base.get(), "renderOffline", Q_RETURN_ARG(QVector<float>, plain),
                                  Q_ARG(int, seed), Q_ARG(qreal, 1.0));
        QCOMPARE(plain, offline(base.get(), seed, 1.0, 0.0));
    }

    // Live: play() and playSeed() with a detune render what renderOffline()
    // with it returns.
    auto &eng = cs::AudioOutput::instance().engine();
    auto listen = [&eng](qsizetype frames) {
        std::vector<float> live(static_cast<size_t>(frames));
        for (size_t at = 0; at < live.size(); at += 882) {
            const int n = static_cast<int>(std::min<size_t>(882, live.size() - at));
            eng.renderOffline(live.data() + at, n);
        }
        for (auto &s : live) s = std::clamp(s, -1.0f, 1.0f);
        return QVector<float>(live.begin(), live.end());
    };
    int seed = -1;
    QVERIFY(QMetaObject::invokeMethod(base.get(), "play", Q_RETURN_ARG(int, seed),
                                      Q_ARG(qreal, 0.8), Q_ARG(qreal, 7.0)));
    const auto expected = offline(base.get(), seed, 0.8, 7.0);
    QCOMPARE(listen(expected.size()), expected);
    QCOMPARE(eng.activeVoices(), size_t(0));

    bool played = false;
    QVERIFY(QMetaObject::invokeMethod(base.get(), "playSeed", Q_RETURN_ARG(bool, played),
                                      Q_ARG(int, 4), Q_ARG(qreal, 1.0), Q_ARG(qreal, -12.0)));
    QVERIFY(played);
    const auto down = offline(base.get(), 4, 1.0, -12.0);
    QCOMPARE(listen(down.size()), down);
    QCOMPARE(eng.activeVoices(), size_t(0));
}

// A held sine, a held square that starts later and a sample: the
// longest release is the square's 50 ms.
static const char *kHeldRecipe = R"({"variation": {"seed": 5}, "layers": [
    {"source": "sine", "freq": 220, "length": 2000,
     "envelope": {"attack": 5, "decay": 0, "sustain": 0.8, "release": 30}},
    {"source": "square", "freq": 330, "length": 1500, "offset": 400,
     "envelope": {"attack": 5, "decay": 0, "sustain": 0.6, "release": 50}},
    {"source": "sample", "sample": "hit.wav", "envelope": {"release": 10}}]})";

void SfxRecipeTest::stopEndsTheVoicesWithinTheirRelease()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QVERIFY(QFile::copy(CLAY_SOUND_DEMO_WAV, dir.filePath("hit.wav")));
    QFile f(dir.filePath("held.sfx.json"));
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(kHeldRecipe);
    f.close();

    QQmlEngine qml;
    std::unique_ptr<QObject> empty(createPlayer(qml, QUrl()));
    QVERIFY(empty);
    QVERIFY(QMetaObject::invokeMethod(empty.get(), "stop"));   // nothing loaded: nothing to end

    std::unique_ptr<QObject> player(createPlayer(qml, QUrl::fromLocalFile(f.fileName())));
    QVERIFY(player);
    QVERIFY2(player->property("loaded").toBool(), qPrintable(player->property("error").toString()));

    auto &eng = cs::AudioOutput::instance().engine();
    QCOMPARE(eng.activeVoices(), size_t(0));
    auto listen = [&eng](double seconds) {
        std::vector<float> live(static_cast<size_t>(std::llround(seconds * kRate)));
        for (size_t at = 0; at < live.size(); at += 882) {
            const int n = static_cast<int>(std::min<size_t>(882, live.size() - at));
            eng.renderOffline(live.data() + at, n);
        }
        return live;
    };
    auto peak = [](const std::vector<float> &buf) {
        float m = 0.0f;
        for (float s : buf) m = std::max(m, std::abs(s));
        return m;
    };

    int seed = -1;
    QVERIFY(QMetaObject::invokeMethod(player.get(), "play", Q_RETURN_ARG(int, seed)));
    QVERIFY(seed >= 0);
    QVERIFY(rms(listen(0.1), 0, 4410) > 0.05);
    QCOMPARE(eng.activeVoices(), size_t(2));   // the sine and the sample; the square is pending
    QCOMPARE(eng.pendingEvents(), size_t(1));

    QVERIFY(QMetaObject::invokeMethod(player.get(), "stop"));
    QCOMPARE(eng.pendingEvents(), size_t(0));
    // A release, not a cut: the first milliseconds still sound.
    const auto release = listen(0.05);
    QVERIFY(rms(release, 0, 220) > 0.05);
    QCOMPARE(eng.activeVoices(), size_t(0));
    // Once the longest release has passed, the player is silent: the
    // square that was to start at 400 ms never does.
    QCOMPARE(peak(listen(1.0)), 0.0f);
    QCOMPARE(eng.activeVoices(), size_t(0));

    // A new play() sounds again, the samples renderOffline() returns.
    QVERIFY(QMetaObject::invokeMethod(player.get(), "play", Q_RETURN_ARG(int, seed)));
    QVector<float> offline;
    QMetaObject::invokeMethod(player.get(), "renderOffline", Q_RETURN_ARG(QVector<float>, offline),
                              Q_ARG(int, seed), Q_ARG(qreal, 1.0));
    QCOMPARE(offline.size(), qsizetype(std::llround(2.0 * kRate)));
    auto live = listen(2.0);
    for (auto &s : live) s = std::clamp(s, -1.0f, 1.0f);
    QCOMPARE(QVector<float>(live.begin(), live.end()), offline);
    QVERIFY(rms(live, 0, live.size()) > 0.05);
    QCOMPARE(eng.activeVoices(), size_t(0));
}

// An ambience bed: a sine and a quieter noise, both one second long
// with a 100 ms fade at either end. A pass is 900 ms - the last layer's
// end less its release - so each fade-out crossfades into the next
// pass's fade-in; 220 Hz over 900 ms is 198 whole cycles, so the sine of
// one pass meets the next in phase.
static const char *kBedRecipe = R"({"variation": {"seed": 3}, "layers": [
    {"source": "sine", "freq": 220, "length": 1000, "gain": -6,
     "envelope": {"attack": 100, "decay": 0, "sustain": 1, "release": 100}},
    {"source": "noise", "length": 1000, "gain": -18,
     "envelope": {"attack": 100, "decay": 0, "sustain": 1, "release": 100}}]})";

// The loop seam check of `sp analyze --loop`: the step from buf[at - 1]
// to buf[at] (wrapping) is a click when it is more than four times the
// 99th percentile of the steps between neighbouring samples and above
// 0.01.
static bool seamless(const std::vector<float> &buf, size_t at, double *jump, double *typical)
{
    std::vector<double> steps;
    for (size_t i = 1; i < buf.size(); ++i)
        if (const double d = std::abs(buf[i] - buf[i - 1]); d > 0.0) steps.push_back(d);
    std::sort(steps.begin(), steps.end());
    *typical = steps.empty() ? 0.0 : steps[static_cast<size_t>(0.99 * (steps.size() - 1))];
    *jump = std::abs(buf[at % buf.size()] - buf[(at + buf.size() - 1) % buf.size()]);
    return *jump <= 4.0 * *typical || *jump <= 0.01;
}

void SfxRecipeTest::loopPlaysOnWithoutASeam()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    QFile f(dir.filePath("bed.sfx.json"));
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(kBedRecipe);
    f.close();

    QQmlEngine qml;
    std::unique_ptr<QObject> player(createPlayer(qml, QUrl::fromLocalFile(f.fileName())));
    QVERIFY(player);
    QVERIFY2(player->property("loaded").toBool(), qPrintable(player->property("error").toString()));
    const size_t period = static_cast<size_t>(std::llround(0.9 * kRate));
    auto offline = [&player](int seed, int passes) {
        QVector<float> out;
        QMetaObject::invokeMethod(player.get(), "renderOffline", Q_RETURN_ARG(QVector<float>, out),
                                  Q_ARG(int, seed), Q_ARG(qreal, 1.0), Q_ARG(qreal, 0.0),
                                  Q_ARG(int, passes));
        return std::vector<float>(out.begin(), out.end());
    };

    // Without loop the recipe plays once, passes or not.
    QCOMPARE(offline(7, 2).size(), size_t(kRate));
    player->setProperty("loop", true);
    QVERIFY(player->property("loop").toBool());

    // Two passes: 1.8 s, the level never drops at the seam and nothing
    // jumps there.
    const auto two = offline(7, 2);
    QCOMPARE(two.size(), 2 * period);
    const double steady = rms(two, period / 2 - 2205, 4410);
    QVERIFY(steady > 0.1);
    for (size_t at = period - 4410; at < period + 4410; at += 441)
        QVERIFY2(rms(two, at, 441) > 0.5 * steady,
                 qPrintable(QStringLiteral("10 ms at %1 ms: rms %2 of %3")
                                .arg(at * 1000.0 / kRate).arg(rms(two, at, 441)).arg(steady)));
    double jump = 0.0, typical = 0.0;
    QVERIFY2(seamless(two, period, &jump, &typical),
             qPrintable(QStringLiteral("seam jump %1, typical step %2").arg(jump).arg(typical)));
    // The second pass on its own is the loop as a file: from its last
    // sample back to its first is the seam it plays through.
    const std::vector<float> pass(two.begin() + period, two.end());
    QVERIFY2(seamless(pass, 0, &jump, &typical),
             qPrintable(QStringLiteral("wrap jump %1, typical step %2").arg(jump).arg(typical)));
    // For `sp analyze --loop` outside the test.
    if (const QString out = qEnvironmentVariable("CLAY_SFX_LOOP_WAV"); !out.isEmpty())
        QVERIFY(cs::writeWav(QDir::toNativeSeparators(out).toStdString(), pass, 1, kRate));

    // Live: a looped play goes on past the last layer's end, the samples
    // renderOffline() returns for as many passes, until stop().
    auto &eng = cs::AudioOutput::instance().engine();
    std::vector<float> skip(12345);
    eng.renderOffline(skip.data(), 12345);
    int seed = -1;
    QVERIFY(QMetaObject::invokeMethod(player.get(), "play", Q_RETURN_ARG(int, seed)));
    // play() opened the sink; closed, it pulls nothing while the event
    // loop runs and the engine renders only what the test takes.
    cs::AudioOutput::instance().stop();
    const auto expected = offline(seed, 3);
    std::vector<float> live(3 * period);
    for (size_t at = 0; at < live.size(); at += 882) {
        // The player tops its passes up from the event loop, the way the
        // sink's pull timer gives it time between buffers.
        if (at % (882 * 25) == 0) QTest::qWait(120);
        const int n = static_cast<int>(std::min<size_t>(882, live.size() - at));
        eng.renderOffline(live.data() + at, n);
    }
    for (auto &x : live) x = std::clamp(x, -1.0f, 1.0f);
    QCOMPARE(live, expected);
    QVERIFY(rms(live, 2 * period + period / 2, 4410) > 0.1);   // well past the 1 s recipe

    QVERIFY(QMetaObject::invokeMethod(player.get(), "stop"));
    QCOMPARE(eng.pendingEvents(), size_t(0));
    QTest::qWait(250);   // a top-up after stop() schedules nothing
    std::vector<float> after(2 * kRate);
    for (size_t at = 0; at < after.size(); at += 882)
        eng.renderOffline(after.data() + at, static_cast<int>(std::min<size_t>(882, after.size() - at)));
    QVERIFY(rms(after, 0, 220) > 0.01);                         // a release, not a cut
    QCOMPARE(rms(after, 4410, after.size() - 4410), 0.0);       // and nothing after it
    QCOMPARE(eng.activeVoices(), size_t(0));
}

void SfxRecipeTest::hotReloadKeepsTheLastGoodRecipe()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString path = dir.filePath("blip.sfx.json");
    auto write = [&path](const QByteArray &json) {
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
        f.write(json);
        return true;
    };
    QVERIFY(write(R"({"name": "one", "layers": [{"source": "sine", "length": 20}]})"));

    QQmlEngine qml;
    std::unique_ptr<QObject> player(createPlayer(qml, QUrl::fromLocalFile(path)));
    QVERIFY(player);
    QVERIFY(player->property("loaded").toBool());
    QCOMPARE(player->property("name").toString(), QStringLiteral("one"));

    QSignalSpy reloaded(player.get(), SIGNAL(hotReloaded()));
    QSignalSpy failed(player.get(), SIGNAL(parseError(QString)));
    QVERIFY(write(R"({"name": "two", "layers": [{"source": "sine", "length": 20},
                                               {"source": "noise", "length": 5}]})"));
    QVERIFY(reloaded.wait(5000));
    QCOMPARE(player->property("name").toString(), QStringLiteral("two"));
    QCOMPARE(player->property("layers").toInt(), 2);

    // A typo mid-edit: reported by name, and the last good recipe plays on.
    QVERIFY(write(R"({"name": "three", "layers": [{"source": "sine", "lenght": 20}]})"));
    QVERIFY(failed.wait(5000));
    QVERIFY2(failed.last().at(0).toString().startsWith("layers[0]: unknown field 'lenght'"),
             qPrintable(failed.last().at(0).toString()));
    QVERIFY(player->property("loaded").toBool());
    QCOMPARE(player->property("name").toString(), QStringLiteral("two"));
    QCOMPARE(player->property("error").toString(), failed.last().at(0).toString());
}

QTEST_MAIN(SfxRecipeTest)
#include "tst_sfx_recipe.moc"
