// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Effect recipes (#428): the parser rejects an unknown field by its
// name, one seed renders the same samples every time and live playback
// renders the samples renderOffline() does, a play transposed by n
// semitones is the recipe with every layer's detune raised by n (#439),
// and the values other seeds play with stay inside the declared ranges
// - drawn and measured on the render (pitch by zero crossings, gain by
// RMS, pan by the channel ratio, offset by the onset). Sample equality is only asserted between
// renders on the same machine.

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/note_event.h"
#include "engine/oscillator_instrument.h"
#include "engine/pcm_buffer.h"
#include "sfx/sfx_parser.h"
#include "sfx/sfx_render.h"
#include "sfx_player.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <cmath>
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

class SfxRecipeTest : public QObject
{
    Q_OBJECT
private slots:
    void parsesTheDemoRecipe();
    void rejectsAnUnknownFieldByName_data();
    void rejectsAnUnknownFieldByName();
    void rejectsValuesOutsideTheirRange_data();
    void rejectsValuesOutsideTheirRange();
    void seededNoiseIgnoresTheStartFrame();
    void sameSeedRendersSameSamples();
    void otherSeedsStayInsideTheDeclaredRanges();
    void poolCyclesItsVariations();
    void sampleLayerPlaysTheWav();
    void livePlaybackRendersWhatRenderOfflineReturns();
    void playerResolvesSamplesNextToTheRecipe();
    void detuneTransposesEveryLayer();
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
}

void SfxRecipeTest::rejectsValuesOutsideTheirRange()
{
    QFETCH(QByteArray, layer);
    QFETCH(QString, error);
    const auto res = cs::SfxParser::parse("{\"layers\": [{" + layer + "}]}");
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
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
