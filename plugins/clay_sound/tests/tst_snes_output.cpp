// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The SNES-style output of a bus (#509): its response measured with
// tones against the gaussian it is built on, what it does above 16 kHz,
// its delay, and that its samples do not depend on the passes the sink
// pulls or the frame it starts on. A v2 song with "output": "snes"
// renders with less energy above 10 kHz than without, the same below
// 4 kHz, the same samples live and offline; without it, the samples of
// "output": "clean".

#include "audio_output.h"
#include "clay_sound_engine.h"
#include "song/song_parser.h"
#include "song_player.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>

#include <cmath>
#include <complex>
#include <functional>
#include <memory>
#include <vector>

namespace cs = clay::sound;

static constexpr int    kRate = 44100;
static constexpr double kPi   = 3.14159265358979323846;

static double dB(double ratio) { return 20.0 * std::log10(ratio); }

// The gaussian the stage resamples with, at `hz`: exp(-2 pi^2 v (f/32k)^2).
static double gaussDb(double hz)
{
    const double f = hz / cs::SnesOutput::kRate;
    return dB(std::exp(-2.0 * kPi * kPi * cs::SnesOutput::kGaussVariance * f * f));
}

// Interleaved stereo through a fresh stage started at `origin`, in
// passes of `pass` frames, the first at engine frame `first`.
static std::vector<float> colour(std::vector<float> mix, int pass, int64_t first = 0, int64_t origin = 0)
{
    cs::SnesOutput out;
    out.start(origin);
    const size_t frames = mix.size() / 2;
    for (size_t at = 0; at < frames; at += pass) {
        const int n = static_cast<int>(std::min<size_t>(pass, frames - at));
        out.process(mix.data() + 2 * at, n, first + static_cast<int64_t>(at), kRate);
    }
    return mix;
}

static std::vector<float> stereoSine(double hz, double seconds, float amp = 0.5f)
{
    std::vector<float> s(2 * static_cast<size_t>(std::lround(seconds * kRate)));
    for (size_t i = 0; i < s.size() / 2; ++i)
        s[2 * i] = s[2 * i + 1] = amp * static_cast<float>(std::sin(2.0 * kPi * hz * i / kRate));
    return s;
}

// Amplitude of `hz` in the left channel over [from, from + n), Hann-windowed.
static double amplitudeAt(const std::vector<float> &s, size_t from, size_t n, double hz)
{
    std::complex<double> acc = 0.0;
    for (size_t i = 0; i < n; ++i) {
        const double w = 0.5 - 0.5 * std::cos(2.0 * kPi * i / (n - 1));
        const double ph = 2.0 * kPi * hz * i / kRate;
        acc += w * s[2 * (from + i)] * std::complex<double>(std::cos(ph), -std::sin(ph));
    }
    return 4.0 * std::abs(acc) / n;     // the Hann window's gain is 0.5
}

static void fft(std::vector<std::complex<double>> &a)
{
    const size_t n = a.size();
    for (size_t i = 1, j = 0; i < n; ++i) {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(a[i], a[j]);
    }
    for (size_t len = 2; len <= n; len <<= 1) {
        const std::complex<double> wl = std::polar(1.0, -2.0 * kPi / len);
        for (size_t i = 0; i < n; i += len) {
            std::complex<double> w = 1.0;
            for (size_t k = 0; k < len / 2; ++k, w *= wl) {
                const auto u = a[i + k], v = a[i + k + len / 2] * w;
                a[i + k] = u + v;
                a[i + k + len / 2] = u - v;
            }
        }
    }
}

// Energy of the (L + R) / 2 downmix in [lo, hi) Hz: Hann-windowed
// 4096-frame blocks, half overlapping, their power spectra summed.
static double bandEnergy(const std::vector<float> &stereo, double lo, double hi)
{
    constexpr size_t kN = 4096;
    const size_t frames = stereo.size() / 2;
    double e = 0.0;
    std::vector<std::complex<double>> buf(kN);
    for (size_t at = 0; at + kN <= frames; at += kN / 2) {
        for (size_t i = 0; i < kN; ++i) {
            const double w = 0.5 - 0.5 * std::cos(2.0 * kPi * i / (kN - 1));
            buf[i] = w * 0.5 * (stereo[2 * (at + i)] + stereo[2 * (at + i) + 1]);
        }
        fft(buf);
        for (size_t k = 1; k < kN / 2; ++k) {
            const double hz = double(k) * kRate / kN;
            if (hz >= lo && hz < hi) e += std::norm(buf[k]);
        }
    }
    return e;
}

static QByteArray adaptiveWith(const char *output)
{
    QFile f(CLAY_SOUND_DEMO_ADAPTIVE);
    if (!f.open(QIODevice::ReadOnly)) return {};
    QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    if (output) root.insert("output", QString::fromLatin1(output));
    return QJsonDocument(root).toJson();
}

static cs::SongModel parsed(const QByteArray &json)
{
    const auto r = cs::SongParser::parse(json);
    if (!r.ok) qWarning() << r.error;
    return r.model;
}

// The adaptive demo song, 10 s with every instrument in: combat from
// 2 s, full intensity from 3 s, a stinger at 5 s.
static cs::SongPerformance busyPerformance()
{
    cs::SongPerformance perf;
    perf.intensity = 0.3;
    perf.cues = {{2 * kRate, cs::SongCue::Kind::State, "combat"},
                 {3 * kRate, cs::SongCue::Kind::Intensity, {}, 1.0},
                 {5 * kRate, cs::SongCue::Kind::Stinger, "pickup"}};
    return perf;
}

class SnesOutputTest : public QObject
{
    Q_OBJECT
private slots:
    void toneResponse_data();
    void toneResponse();
    void nothingAboveSixteenKilohertzAtItsOwnFrequency();
    void delayIsLatencyFrames();
    void samplesDoNotDependOnPassesOrStartFrame();
    void offLeavesTheBusDry();

    void parserReadsOutput();
    void songWithoutOutputRendersAsClean();
    void snesSongHasLessEnergyAboveTenKilohertz();
    void liveRendersWhatRenderOfflineReturns();
    void playerTurnsItsBusesOnAndOff();
    void playerGoneLeavesTheStageToTheOneStillPlaying();
    void playerSwitchedToAV1SongGivesTheStageUp();

    void cleanup();
};

void SnesOutputTest::cleanup()
{
    // The shared engine's buses outlive a test; leave them off.
    auto &eng = cs::AudioOutput::instance().engine();
    for (cs::Bus b : {cs::Bus::Sfx, cs::Bus::Music, cs::Bus::Voice}) eng.snesOutput(b).setEnabled(false);
}

void SnesOutputTest::toneResponse_data()
{
    QTest::addColumn<double>("hz");
    QTest::addColumn<double>("lowDb");      // the response in [lowDb, highDb]
    QTest::addColumn<double>("highDb");
    // Up to 10 kHz the response is the gaussian's; above, the band
    // limit takes more off, up to 6 dB at 14 kHz.
    for (double hz : {100.0, 1000.0, 4000.0, 8000.0, 10000.0})
        QTest::addRow("%.0f Hz", hz) << hz << gaussDb(hz) - 0.15 << gaussDb(hz) + 0.05;
    QTest::addRow("12000 Hz") << 12000.0 << gaussDb(12000.0) - 2.0 << gaussDb(12000.0);
    QTest::addRow("14000 Hz") << 14000.0 << gaussDb(14000.0) - 7.0 << gaussDb(14000.0) - 4.0;
}

void SnesOutputTest::toneResponse()
{
    QFETCH(double, hz);
    QFETCH(double, lowDb);
    QFETCH(double, highDb);
    const auto out = colour(stereoSine(hz, 1.0), 882);
    const double got = dB(amplitudeAt(out, kRate / 4, kRate / 2, hz) / 0.5);
    qDebug("%.0f Hz: %.2f dB (gaussian %.2f dB)", hz, got, gaussDb(hz));
    QVERIFY2(got >= lowDb && got <= highDb,
             qPrintable(QStringLiteral("%1 dB not in [%2, %3]").arg(got).arg(lowDb).arg(highDb)));
}

void SnesOutputTest::nothingAboveSixteenKilohertzAtItsOwnFrequency()
{
    // A 32 kHz stream holds nothing above 16 kHz. What lies above folds
    // down, as on the chip, quietly: 18 kHz comes out at 14 kHz.
    for (double hz : {16000.0, 18000.0, 20000.0}) {
        const auto out = colour(stereoSine(hz, 1.0), 882);
        const double own = dB(amplitudeAt(out, kRate / 4, kRate / 2, hz) / 0.5);
        qDebug("%.0f Hz: %.1f dB at its own frequency", hz, own);
        QVERIFY2(own < -55.0, qPrintable(QString::number(own)));
    }
    const auto out = colour(stereoSine(18000.0, 1.0), 882);
    const double folded = dB(amplitudeAt(out, kRate / 4, kRate / 2, 14000.0) / 0.5);
    qDebug("18000 Hz folds to 14000 Hz at %.1f dB", folded);
    QVERIFY(folded > -32.0 && folded < -24.0);
}

void SnesOutputTest::delayIsLatencyFrames()
{
    QCOMPARE(cs::SnesOutput::latencyFrames(44100), 16);
    QCOMPARE(cs::SnesOutput::latencyFrames(48000), 16);
    std::vector<float> impulse(2 * 256, 0.0f);
    impulse[0] = impulse[1] = 1.0f;
    const auto out = colour(impulse, 64);
    size_t peak = 0;
    for (size_t i = 0; i < 256; ++i)
        if (std::abs(out[2 * i]) > std::abs(out[2 * peak])) peak = i;
    QCOMPARE(int(peak), cs::SnesOutput::latencyFrames(kRate));
    // Unity at DC: a steady level comes out at that level once the
    // delay and the kernels have filled.
    const auto steady = colour(std::vector<float>(2 * 256, 0.5f), 64);
    for (size_t i = 64; i < 256; ++i) QVERIFY(std::abs(steady[2 * i] - 0.5f) < 1e-5f);
}

void SnesOutputTest::samplesDoNotDependOnPassesOrStartFrame()
{
    std::vector<float> noise(2 * static_cast<size_t>(kRate));
    uint32_t state = 1;
    for (float &s : noise) {
        state = state * 1664525u + 1013904223u;
        s = static_cast<float>(state >> 8) / 16777216.0f - 0.5f;
    }
    const auto ref = colour(noise, 882);
    QCOMPARE(colour(noise, 37), ref);
    QCOMPARE(colour(noise, 4096), ref);

    // The same mix after 12345 frames of something else, the stage
    // started at the frame it begins on: before it the bus stays as it
    // was, from it on the samples of a start at frame 0.
    const size_t lead = 12345;
    std::vector<float> later(2 * lead, 0.25f);
    later.insert(later.end(), noise.begin(), noise.end());
    const auto shifted = colour(later, 613, 1000000, 1000000 + lead);
    QCOMPARE(std::vector<float>(shifted.begin(), shifted.begin() + 2 * lead),
             std::vector<float>(later.begin(), later.begin() + 2 * lead));
    QCOMPARE(std::vector<float>(shifted.begin() + 2 * lead, shifted.end()), ref);
}

void SnesOutputTest::offLeavesTheBusDry()
{
    cs::Engine eng(kRate);
    QVERIFY(!eng.snesOutput(cs::Bus::Music).enabled());
    eng.snesOutput(cs::Bus::Music).setEnabled(true);
    QVERIFY(eng.snesOutput(cs::Bus::Music).enabled());
    eng.snesOutput(cs::Bus::Music).setEnabled(false);

    // A stage that was on and is off again passes the mix unchanged.
    cs::SnesOutput out;
    out.start(0);
    auto sine = stereoSine(1000.0, 0.1);
    out.process(sine.data(), 882, 0, kRate);
    out.setEnabled(false);
    const auto dry = stereoSine(1000.0, 0.1);
    auto rest = dry;
    out.process(rest.data() + 2 * 882, 882, 882, kRate);
    QCOMPARE(rest, dry);
}

void SnesOutputTest::parserReadsOutput()
{
    QCOMPARE(parsed(adaptiveWith(nullptr)).output, cs::SongOutput::Clean);
    QCOMPARE(parsed(adaptiveWith("clean")).output, cs::SongOutput::Clean);
    QCOMPARE(parsed(adaptiveWith("snes")).output, cs::SongOutput::Snes);

    const auto bad = cs::SongParser::parse(adaptiveWith("crt"));
    QVERIFY(!bad.ok);
    QVERIFY2(bad.error.contains("unknown output 'crt' (clean, snes)"), qPrintable(bad.error));

    const auto v1 = cs::SongParser::parse(R"({"tempo": 120, "output": "snes",
        "tracks": {"a": {"instrument": "x"}}, "patterns": {"P": {"a": [{"t": 0, "note": "C4"}]}}})");
    QVERIFY(!v1.ok);
    QVERIFY2(v1.error.contains("output"), qPrintable(v1.error));
}

void SnesOutputTest::songWithoutOutputRendersAsClean()
{
    const auto perf = busyPerformance();
    const auto none  = cs::renderSong(parsed(adaptiveWith(nullptr)), perf, 10.0, 1.0f, false, kRate, true);
    const auto clean = cs::renderSong(parsed(adaptiveWith("clean")), perf, 10.0, 1.0f, false, kRate, true);
    const auto snes  = cs::renderSong(parsed(adaptiveWith("snes")), perf, 10.0, 1.0f, false, kRate, true);
    QCOMPARE(clean, none);
    QVERIFY(snes != none);
}

void SnesOutputTest::snesSongHasLessEnergyAboveTenKilohertz()
{
    const auto perf = busyPerformance();
    const auto clean = cs::renderSong(parsed(adaptiveWith(nullptr)), perf, 10.0, 1.0f, false, kRate, true);
    const auto snes  = cs::renderSong(parsed(adaptiveWith("snes")), perf, 10.0, 1.0f, false, kRate, true);
    QCOMPARE(snes.size(), clean.size());

    const double highDb = 10.0 * std::log10(bandEnergy(snes, 10000.0, 1e9) / bandEnergy(clean, 10000.0, 1e9));
    const double lowDb  = 10.0 * std::log10(bandEnergy(snes, 0.0, 4000.0) / bandEnergy(clean, 0.0, 4000.0));
    const double topDb  = 10.0 * std::log10(bandEnergy(snes, 16000.0, 1e9) / bandEnergy(clean, 16000.0, 1e9));
    qDebug("SNES output against clean: %.2f dB above 10 kHz, %.2f dB above 16 kHz, %.2f dB below 4 kHz",
           highDb, topDb, lowDb);
    // The amount the PR names: at least 12 dB less above 10 kHz (15.0
    // measured), while below 4 kHz the song stays within half a dB.
    QVERIFY2(highDb <= -12.0, qPrintable(QString::number(highDb)));
    QVERIFY2(std::abs(lowDb) <= 0.5, qPrintable(QString::number(lowDb)));
    QVERIFY2(topDb <= -30.0, qPrintable(QString::number(topDb)));
}

void SnesOutputTest::liveRendersWhatRenderOfflineReturns()
{
    auto &eng = cs::AudioOutput::instance().engine();
    const int rate = cs::AudioOutput::instance().sampleRate();
    QTemporaryDir dir;
    const QString path = dir.filePath("snes.song.json");
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(adaptiveWith("snes"));
    }

    SongPlayer p;
    p.setSource(QUrl::fromLocalFile(path));
    QVERIFY2(p.loaded(), qPrintable(p.error()));
    p.setIntensity(0.3);

    // Start far from frame 0 and mid-pass, with nothing else ringing.
    std::vector<float> skip(rate + 12345);
    eng.renderOffline(skip.data(), static_cast<int>(skip.size()));
    QCOMPARE(eng.activeVoices(), size_t(0));

    p.play();
    QVERIFY(eng.snesOutput(cs::Bus::Music).enabled());
    const int64_t start = eng.currentFrame();

    struct Control { double at; std::function<void()> send; cs::SongCue cue; };
    QVector<Control> controls = {
        {1.3, [&] { p.setState("combat"); }, {0, cs::SongCue::Kind::State, "combat"}},
        {2.9, [&] { p.setIntensity(1.0); }, {0, cs::SongCue::Kind::Intensity, {}, 1.0}},
        {5.1, [&] { QVERIFY(p.playStinger("pickup")); }, {0, cs::SongCue::Kind::Stinger, "pickup"}},
    };
    const int64_t frames = 8 * rate;
    std::vector<float> live(2 * static_cast<size_t>(frames));
    const int passes[] = {256, 1000, 441, 1777, 882, 613};
    int next = 0;
    for (int64_t at = 0, k = 0; at < frames; ++k) {
        while (next < controls.size() && eng.currentFrame() - start >= controls[next].at * rate) {
            controls[next].cue.frame = eng.currentFrame() - start + SongPlayer::kScheduleAheadFrames;
            controls[next].send();
            ++next;
        }
        const int n = static_cast<int>(std::min<int64_t>(passes[k % 6], frames - at));
        eng.renderStereo(live.data() + 2 * at, n);
        at += n;
        QMetaObject::invokeMethod(&p, "tick");
    }
    p.stop();
    for (auto &s : live) s = std::clamp(s, -1.0f, 1.0f);
    QCOMPARE(next, controls.size());

    cs::SongPerformance perf;
    perf.intensity = 0.3;
    for (const Control &c : std::as_const(controls)) perf.cues.append(c.cue);
    const auto offline = cs::renderSong(parsed(adaptiveWith("snes")), perf, 8.0, 1.0f, false, rate, true);
    QCOMPARE(offline.size(), live.size());
    for (size_t i = 0; i < live.size(); ++i)
        if (live[i] != offline[i])
            QFAIL(qPrintable(QStringLiteral("sample %1: live %2, offline %3").arg(i).arg(live[i]).arg(offline[i])));
}

void SnesOutputTest::playerTurnsItsBusesOnAndOff()
{
    auto &eng = cs::AudioOutput::instance().engine();
    QTemporaryDir dir;
    auto write = [&](const QString &name, const QByteArray &json) {
        QFile f(dir.filePath(name));
        if (f.open(QIODevice::WriteOnly)) f.write(json);
        return QUrl::fromLocalFile(dir.filePath(name));
    };
    const QUrl snes = write("snes.song.json", adaptiveWith("snes"));
    const QUrl clean = write("clean.song.json", adaptiveWith(nullptr));
    auto &music = eng.snesOutput(cs::Bus::Music);

    {
        SongPlayer a;
        a.setSource(snes);
        QVERIFY(!music.enabled());              // loading turns nothing on
        a.play();
        QVERIFY(music.enabled());
        QVERIFY(!eng.snesOutput(cs::Bus::Sfx).enabled());
        a.stop();
        QVERIFY(music.enabled());               // what rings, rings out through it

        SongPlayer b;
        b.setSource(clean);
        b.play();
        QVERIFY(!music.enabled());              // a song without it plays clean
        b.stop();
        a.play();
        QVERIFY(music.enabled());
    }
    QVERIFY(!music.enabled());                  // gone with the player that turned it on
}

void SnesOutputTest::playerGoneLeavesTheStageToTheOneStillPlaying()
{
    auto &eng = cs::AudioOutput::instance().engine();
    auto &music = eng.snesOutput(cs::Bus::Music);
    QTemporaryDir dir;
    const QString path = dir.filePath("snes.song.json");
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(adaptiveWith("snes"));
    }

    // B plays after A, so B keeps the stage when A goes.
    auto b = std::make_unique<SongPlayer>();
    {
        SongPlayer a;
        a.setSource(QUrl::fromLocalFile(path));
        a.play();
        QVERIFY(music.enabled());
        b->setSource(QUrl::fromLocalFile(path));
        b->play();
        QVERIFY(music.enabled());
    }
    QVERIFY2(music.enabled(), "b still plays a snes song, its Music output is off");
    b.reset();
    QVERIFY(!music.enabled());                  // the last one to play turns it off
}

void SnesOutputTest::playerSwitchedToAV1SongGivesTheStageUp()
{
    auto &eng = cs::AudioOutput::instance().engine();
    auto &music = eng.snesOutput(cs::Bus::Music);
    QTemporaryDir dir;
    auto write = [&](const QString &name, const QByteArray &json) {
        QFile f(dir.filePath(name));
        if (f.open(QIODevice::WriteOnly)) f.write(json);
        return QUrl::fromLocalFile(dir.filePath(name));
    };
    const QUrl snes = write("snes.song.json", adaptiveWith("snes"));
    const QUrl v1 = write("v1.song.json", R"({"tempo": 120, "tracks": {"a": {"instrument": "x"}},
        "patterns": {"P": {"a": [{"t": 0, "note": "C4"}]}}})");

    {
        SongPlayer p;
        p.setSource(snes);
        p.play();
        QVERIFY(music.enabled());
        p.stop();
        p.setSource(v1);
        QVERIFY2(p.loaded(), qPrintable(p.error()));
        QCOMPARE(p.version(), 1);
        p.play();
        QVERIFY2(!music.enabled(), "a v1 song plays through the SNES output the previous song turned on");
        p.stop();

        // The player holds nothing now: a stage someone else starts
        // outlives it.
        music.start(eng.currentFrame());
    }
    QVERIFY(music.enabled());
}

QTEST_MAIN(SnesOutputTest)
#include "tst_snes_output.moc"
