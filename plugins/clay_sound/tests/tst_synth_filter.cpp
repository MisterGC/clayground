// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SynthInstrument's filter and pulse width, checked by measurement on
// offline renders (#424): the amplitude of each harmonic of a 100 Hz
// tone, filtered against unfiltered, compared with the two-pole
// response the filter is meant to have. 100 Hz divides 44.1 kHz, so a
// window of whole periods puts every harmonic on a DFT bin of its own.
// No test compares bytes; sample equality is only asserted between two
// renders on the same machine.

#include "synth_instrument.h"

#include <QtTest/QtTest>
#include <cmath>
#include <complex>

static constexpr double kRate = 44100.0;
static constexpr double kF0   = 100.0;
static constexpr double kPi   = 3.14159265358979323846;

// Amplitude of `freq` in buf[from, from + n).
static double amplitudeAt(const QVector<float> &buf, int from, int n, double freq)
{
    std::complex<double> acc = 0.0;
    for (int i = 0; i < n; ++i) {
        const double w = 2.0 * kPi * freq * i / kRate;
        acc += static_cast<double>(buf[from + i]) * std::complex<double>(std::cos(w), -std::sin(w));
    }
    return 2.0 * std::abs(acc) / n;
}

static double dB(double ratio) { return 20.0 * std::log10(ratio); }

// A flat amplitude envelope, so only the filter shapes the spectrum.
static void flatPatch(SynthInstrument &s, const QString &waveform)
{
    s.setWaveform(waveform);
    s.setAttack(0.0);
    s.setDecay(0.0);
    s.setSustain(1.0);
    s.setRelease(0.0);
    s.setVolume(1.0);
}

static QVector<float> renderNote(SynthInstrument &s, double seconds, double velocity = 0.5)
{
    s.trigger(kF0, velocity, seconds);
    return s.renderOffline(seconds);
}

// Steady-state window: skip the filter's settling, keep whole periods.
static constexpr int kFrom = 4410;      // 0.1 s
static constexpr int kLen  = 22050;     // 0.5 s = 50 periods

// Filtered-to-raw gain in dB at harmonic `h` of kF0.
static double gainAt(const QVector<float> &raw, const QVector<float> &filtered, int h)
{
    return dB(amplitudeAt(filtered, kFrom, kLen, h * kF0) /
              amplitudeAt(raw, kFrom, kLen, h * kF0));
}

// Raw-to-filtered energy ratio in dB over harmonics (lo, hi].
static double bandGain(const QVector<float> &raw, const QVector<float> &filtered,
                       int from, int len, double lo, double hi)
{
    double eRaw = 0.0, eFilt = 0.0;
    for (int h = 1; h * kF0 <= hi; ++h) {
        if (h * kF0 <= lo) continue;
        eRaw  += std::pow(amplitudeAt(raw,      from, len, h * kF0), 2.0);
        eFilt += std::pow(amplitudeAt(filtered, from, len, h * kF0), 2.0);
    }
    return 10.0 * std::log10(eFilt / eRaw);
}

class SynthFilterTest : public QObject
{
    Q_OBJECT
private slots:
    void defaultsAreOff();
    void offFilterIgnoresItsParameters();
    void lowPassFallsTwelveDbPerOctave();
    void highPassFallsBelowCutoff();
    void bandPassPeaksAtCutoff();
    void resonanceRaisesTheCutoff();
    void cutoffEnvelopeOpensAndCloses();
    void pulseWidthShapesHarmonics();
    void sameNoteRendersSameSamples();
};

void SynthFilterTest::defaultsAreOff()
{
    SynthInstrument s;
    QCOMPARE(s.filterType(), QString("none"));
    QCOMPARE(s.pulseWidth(), 0.5);
    QCOMPARE(s.resonance(), 0.0);
    QCOMPARE(s.filterEnvAmount(), 0.0);
}

void SynthFilterTest::offFilterIgnoresItsParameters()
{
    // Filter parameters set while the type is "none" must not reach the
    // sound: the bypass is a bypass, not a wide-open filter.
    SynthInstrument plain;
    flatPatch(plain, "sawtooth");
    const auto a = plain.renderPatchPreview(45, 0.3, 0.5);

    SynthInstrument tweaked;
    flatPatch(tweaked, "sawtooth");
    tweaked.setCutoff(300.0);
    tweaked.setResonance(0.9);
    tweaked.setFilterDecay(0.1);
    tweaked.setFilterSustain(0.0);
    tweaked.setFilterEnvAmount(4.0);
    const auto b = tweaked.renderPatchPreview(45, 0.3, 0.5);
    QCOMPARE(a, b);
}

void SynthFilterTest::lowPassFallsTwelveDbPerOctave()
{
    SynthInstrument s;
    flatPatch(s, "sawtooth");
    const auto raw = renderNote(s, 0.7);

    s.setFilterType("lowpass");
    s.setCutoff(1000.0);
    const auto lp = renderNote(s, 0.7);

    // Two-pole Butterworth: |H| = 1 / sqrt(1 + (f/fc)^4).
    auto expected = [](double f) { return dB(1.0 / std::sqrt(1.0 + std::pow(f / 1000.0, 4.0))); };
    for (int h : {2, 5, 10, 20, 40}) {
        const double got = gainAt(raw, lp, h);
        QVERIFY2(std::abs(got - expected(h * kF0)) < 1.5,
                 qPrintable(QString("%1 Hz: %2 dB, expected %3 dB")
                                .arg(h * kF0).arg(got).arg(expected(h * kF0))));
    }

    // The issue's criterion: energy above the cutoff falls as expected.
    const double passband = bandGain(raw, lp, kFrom, kLen, 0.0, 500.0);
    const double octave2  = bandGain(raw, lp, kFrom, kLen, 2000.0, 4000.0);
    const double octave3  = bandGain(raw, lp, kFrom, kLen, 4000.0, 8000.0);
    QVERIFY2(passband > -1.0, qPrintable(QString("below fc/2: %1 dB").arg(passband)));
    QVERIFY2(octave2 < -12.0, qPrintable(QString("2..4 fc: %1 dB").arg(octave2)));
    QVERIFY2(octave3 < -24.0, qPrintable(QString("4..8 fc: %1 dB").arg(octave3)));
    QVERIFY2(octave3 < octave2 - 10.0,
             qPrintable(QString("an octave further up falls only %1 dB more").arg(octave2 - octave3)));
}

void SynthFilterTest::highPassFallsBelowCutoff()
{
    SynthInstrument s;
    flatPatch(s, "sawtooth");
    const auto raw = renderNote(s, 0.7);

    s.setFilterType("highpass");
    s.setCutoff(1000.0);
    const auto hp = renderNote(s, 0.7);

    const double at200 = gainAt(raw, hp, 2);    // fc / 5
    const double at4k  = gainAt(raw, hp, 40);
    QVERIFY2(at200 < -24.0, qPrintable(QString("200 Hz: %1 dB").arg(at200)));
    QVERIFY2(std::abs(at4k) < 1.0, qPrintable(QString("4 kHz: %1 dB").arg(at4k)));
}

void SynthFilterTest::bandPassPeaksAtCutoff()
{
    SynthInstrument s;
    flatPatch(s, "sawtooth");
    const auto raw = renderNote(s, 0.7);

    s.setFilterType("bandpass");
    s.setCutoff(1000.0);
    const auto bp = renderNote(s, 0.7);

    double best = -1e9; int bestH = 0;
    for (int h = 1; h <= 80; ++h) {
        const double g = gainAt(raw, bp, h);
        if (g > best) { best = g; bestH = h; }
    }
    QCOMPARE(bestH, 10);
    QVERIFY2(std::abs(best) < 0.5, qPrintable(QString("peak gain %1 dB").arg(best)));
    const double below = gainAt(raw, bp, 1);    // fc / 10
    const double above = gainAt(raw, bp, 80);   // fc * 8
    QVERIFY2(below < -12.0, qPrintable(QString("100 Hz: %1 dB").arg(below)));
    QVERIFY2(above < -12.0, qPrintable(QString("8 kHz: %1 dB").arg(above)));
}

void SynthFilterTest::resonanceRaisesTheCutoff()
{
    SynthInstrument s;
    flatPatch(s, "sawtooth");
    const auto raw = renderNote(s, 0.7, 0.1);

    s.setFilterType("lowpass");
    s.setCutoff(1000.0);
    const auto flat = renderNote(s, 0.7, 0.1);
    s.setResonance(0.8);
    const auto peaked = renderNote(s, 0.7, 0.1);

    const double flatAtFc   = gainAt(raw, flat, 10);
    const double peakedAtFc = gainAt(raw, peaked, 10);
    QVERIFY2(flatAtFc < -2.0 && flatAtFc > -4.0,
             qPrintable(QString("no resonance at fc: %1 dB").arg(flatAtFc)));
    QVERIFY2(peakedAtFc > 10.0,
             qPrintable(QString("resonance 0.8 at fc: %1 dB").arg(peakedAtFc)));
    // Still a low-pass: far above the peak it falls as before.
    QVERIFY2(gainAt(raw, peaked, 40) < -20.0,
             qPrintable(QString("4 kHz: %1 dB").arg(gainAt(raw, peaked, 40))));
}

void SynthFilterTest::cutoffEnvelopeOpensAndCloses()
{
    // Cutoff 500 Hz, pushed three octaves up (4 kHz) at the envelope's
    // peak and decaying back to 500 Hz over 0.2 s: a bright onset that
    // darkens - the filtered pluck.
    SynthInstrument s;
    flatPatch(s, "sawtooth");
    const auto raw = renderNote(s, 0.7);

    s.setFilterType("lowpass");
    s.setCutoff(500.0);
    const auto fixed = renderNote(s, 0.7);

    s.setFilterDecay(0.2);
    s.setFilterSustain(0.0);
    s.setFilterEnvAmount(3.0);
    const auto swept = renderNote(s, 0.7);

    constexpr int win = 2205;                    // 50 ms, 5 periods
    const double early = bandGain(raw, swept, 0, win, 1000.0, 8000.0);
    const double late  = bandGain(raw, swept, 17640, win, 1000.0, 8000.0);   // 0.4 s
    const double held  = bandGain(raw, fixed, 17640, win, 1000.0, 8000.0);
    QVERIFY2(early > late + 15.0,
             qPrintable(QString("above 1 kHz: onset %1 dB, after decay %2 dB").arg(early).arg(late)));
    QVERIFY2(std::abs(late - held) < 1.0,
             qPrintable(QString("after decay %1 dB, fixed cutoff %2 dB").arg(late).arg(held)));
}

void SynthFilterTest::pulseWidthShapesHarmonics()
{
    // A pulse of duty d has harmonics |sin(pi n d)| / n: a square (0.5)
    // has no even ones, a quarter pulse none at multiples of 4.
    SynthInstrument s;
    flatPatch(s, "square");
    const auto square = renderNote(s, 0.7);
    s.setPulseWidth(0.25);
    const auto quarter = renderNote(s, 0.7);

    auto a = [](const QVector<float> &b, int h) { return amplitudeAt(b, kFrom, kLen, h * kF0); };
    QVERIFY2(a(square, 2) / a(square, 1) < 0.01,
             qPrintable(QString("square h2/h1 = %1").arg(a(square, 2) / a(square, 1))));
    QVERIFY2(a(quarter, 2) / a(quarter, 1) > 0.6,
             qPrintable(QString("quarter h2/h1 = %1").arg(a(quarter, 2) / a(quarter, 1))));
    QVERIFY2(a(quarter, 4) / a(quarter, 1) < 0.02,
             qPrintable(QString("quarter h4/h1 = %1").arg(a(quarter, 4) / a(quarter, 1))));

    int high = 0;
    for (int i = kFrom; i < kFrom + kLen; ++i) high += quarter[i] > 0.0f;
    const double duty = static_cast<double>(high) / kLen;
    QVERIFY2(std::abs(duty - 0.25) < 0.03, qPrintable(QString("duty %1").arg(duty)));
}

void SynthFilterTest::sameNoteRendersSameSamples()
{
    // Noise through a swept, resonant band-pass: the voice's whole
    // filter path. Same patch and note, same machine -> same samples.
    SynthInstrument s;
    flatPatch(s, "noise");
    s.setFilterType("bandpass");
    s.setCutoff(800.0);
    s.setResonance(0.6);
    s.setFilterDecay(0.15);
    s.setFilterSustain(0.2);
    s.setFilterEnvAmount(2.0);
    const auto a = s.renderPatchPreview(60, 0.3, 0.8);
    const auto b = s.renderPatchPreview(60, 0.3, 0.8);
    QCOMPARE(a, b);
    double e = 0.0;
    for (float v : a) e += std::abs(v);
    QVERIFY2(e > 100.0, qPrintable(QString("expected audible noise, energy=%1").arg(e)));
}

QTEST_MAIN(SynthFilterTest)
#include "tst_synth_filter.moc"
