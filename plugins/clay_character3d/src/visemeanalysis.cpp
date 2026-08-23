// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "visemeanalysis.h"

#include <QtGlobal>
#include <QtMath>

#include <algorithm>

namespace ClayViseme {
namespace {

// --- the spectrum ---------------------------------------------------------

// Iterative radix-2 Cooley-Tukey, in place. Sixty lines beats a dependency:
// a 512-point transform every 16 ms of audio is a few hundred thousand flops
// for a whole line of dialogue, which is below the noise floor of the decode
// that produced the samples.
void fftRadix2(QVector<float> &re, QVector<float> &im)
{
    const int n = re.size();
    if (n < 2 || (n & (n - 1)) != 0)
        return;

    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j) {
            std::swap(re[i], re[j]);
            std::swap(im[i], im[j]);
        }
    }

    for (int len = 2; len <= n; len <<= 1) {
        const double ang = -2.0 * M_PI / len;
        const float wr = float(qCos(ang));
        const float wi = float(qSin(ang));
        for (int i = 0; i < n; i += len) {
            float cr = 1.f, ci = 0.f;
            for (int k = 0; k < len / 2; ++k) {
                const int a = i + k;
                const int b = i + k + len / 2;
                const float xr = re[b] * cr - im[b] * ci;
                const float xi = re[b] * ci + im[b] * cr;
                re[b] = re[a] - xr;
                im[b] = im[a] - xi;
                re[a] += xr;
                im[a] += xi;
                const float nr = cr * wr - ci * wi;
                ci = cr * wi + ci * wr;
                cr = nr;
            }
        }
    }
}

// --- helpers --------------------------------------------------------------

// Works with e0 > e1, which is how the round axis is written: one ramp up
// and one ramp down over the same measurement, meeting at neither end so a
// mid frontness is neutral rather than half of both.
float smoothstepf(float e0, float e1, float x)
{
    if (qFuzzyCompare(e0, e1))
        return x < e0 ? 0.f : 1.f;
    float t = (x - e0) / (e1 - e0);
    t = qBound(0.f, t, 1.f);
    return t * t * (3.f - 2.f * t);
}

// Energy in [lo, hi) Hz of a magnitude-squared spectrum.
float bandEnergy(const QVector<float> &mag2, float binHz, float lo, float hi)
{
    const int n = mag2.size();
    int a = int(lo / binHz + 0.5f);
    int b = int(hi / binHz + 0.5f);
    a = qBound(0, a, n);
    b = qBound(a, b, n);
    float sum = 0.f;
    for (int i = a; i < b; ++i)
        sum += mag2.at(i);
    return sum;
}

float medianOf(QVector<float> v)
{
    if (v.isEmpty())
        return 0.f;
    std::sort(v.begin(), v.end());
    return v.at(v.size() / 2);
}

// Median over +-radius frames. A per-frame classification is jittery in a way
// a mouth shows and a spectrogram does not, and this is the cheapest thing
// that removes it without smearing a real transition across four frames the
// way a mean would. Affordable only because the whole file is in hand before
// a single frame is drawn - which is the payoff for lip-sync not being live.
void medianSmooth(QVector<Frame> &frames, int radius)
{
    if (frames.size() < 3 || radius < 1)
        return;
    const QVector<Frame> src = frames;
    for (int i = 0; i < frames.size(); ++i) {
        QVector<float> o, f, s;
        const int lo = qMax(0, i - radius);
        const int hi = qMin(src.size() - 1, i + radius);
        for (int j = lo; j <= hi; ++j) {
            o.append(src.at(j).openness);
            f.append(src.at(j).frontness);
            s.append(src.at(j).fricness);
        }
        frames[i].openness = medianOf(o);
        frames[i].frontness = medianOf(f);
        frames[i].fricness = medianOf(s);
    }
}

} // namespace

// --- analysis -------------------------------------------------------------

QVector<Frame> analyse(const QVector<float> &mono, int sampleRate,
                       const Config &cfg)
{
    QVector<Frame> frames;
    if (mono.isEmpty() || sampleRate <= 0 || cfg.fftSize < 64)
        return frames;

    // Decimate to the analysis rate with a box pre-filter. Crude as an
    // anti-alias, but the bands that matter all sit below 8 kHz and what
    // folds down from above is broadband hiss, not a formant.
    const int step = qMax(1, int(qRound(double(sampleRate) / cfg.analysisRate)));
    const int rate = sampleRate / step;
    QVector<float> x;
    x.reserve(mono.size() / step + 1);
    for (int i = 0; i + step <= mono.size(); i += step) {
        float acc = 0.f;
        for (int k = 0; k < step; ++k)
            acc += mono.at(i + k);
        x.append(acc / step);
    }
    if (x.size() < cfg.fftSize)
        return frames;

    // Pre-emphasis, and it is not optional.
    //
    // A voiced source rolls off about 6 dB per octave, so without this the
    // low band wins every ratio it is in and every frame of real speech
    // reads as rounded. Synthesised vowels hide it - their harmonics are
    // weighted by the formants alone - so the unit tests passed happily
    // while the professor pouted his way through an entire line.
    //
    // The usual first-order differencer, which flattens that tilt and leaves
    // the formant structure where it was. Applied after decimation so the
    // coefficient means the same thing whatever the file's rate was.
    {
        float prev = x.at(0);
        for (int i = 1; i < x.size(); ++i) {
            const float cur = x.at(i);
            x[i] = cur - 0.97f * prev;
            prev = cur;
        }
    }

    const int n = cfg.fftSize;
    const int hop = qMax(1, rate * cfg.hopMs / 1000);
    // Band edges in Hz, never in bins: the bin width follows the file's own
    // sample rate, and a 48 kHz take analysed against 22 kHz bin indices has
    // its formant bands shifted by more than an octave - which fails quietly
    // and reads as "the detection is just bad".
    const float binHz = float(rate) / n;

    QVector<float> win(n);
    for (int i = 0; i < n; ++i)
        win[i] = 0.5f * (1.f - float(qCos(2.0 * M_PI * i / (n - 1))));

    QVector<float> re(n), im(n), mag2(n / 2);
    float peak = 0.f;

    for (int start = 0; start + n <= x.size(); start += hop) {
        double ss = 0.0;
        for (int i = 0; i < n; ++i) {
            const float s = x.at(start + i);
            ss += double(s) * s;
            re[i] = s * win.at(i);
            im[i] = 0.f;
        }
        fftRadix2(re, im);
        for (int i = 0; i < n / 2; ++i)
            mag2[i] = re.at(i) * re.at(i) + im.at(i) * im.at(i);

        Frame f;
        f.ms = qint64(start) * 1000 / rate;
        f.level = float(qSqrt(ss / n));
        peak = qMax(peak, f.level);

        const float total = bandEnergy(mag2, binHz, 80.f, 7800.f) + 1e-12f;
        // F1 sits low for a closed vowel and high for an open one, so its
        // POSITION is what a jaw drop is. Read as the balance between two
        // bands rather than by finding the peak: with a high voice there are
        // only two or three harmonics in the whole F1 range and peak-picking
        // returns a harmonic, which tracks the pitch of the sentence instead
        // of the shape of the mouth.
        const float f1lo = bandEnergy(mag2, binHz, 200.f, 450.f);
        const float f1hi = bandEnergy(mag2, binHz, 550.f, 1100.f);
        // F2 the same way: back and rounded, or front and spread.
        const float f2bk = bandEnergy(mag2, binHz, 700.f, 1400.f);
        const float f2fr = bandEnergy(mag2, binHz, 1700.f, 3000.f);
        const float fric = bandEnergy(mag2, binHz, 3800.f, 7800.f);

        f.openness = f1hi / (f1lo + f1hi + 1e-12f);
        f.frontness = f2fr / (f2bk + f2fr + 1e-12f);
        f.fricness = fric / total;
        frames.append(f);
    }

    if (frames.isEmpty() || peak <= 0.f)
        return QVector<Frame>();

    for (Frame &f : frames) {
        f.level /= peak;
        // Confidence is the whole reason a hostile file degrades to today's
        // behaviour instead of to nonsense: below the floor the ratios above
        // were computed from noise, and the mapping is told to ignore them.
        f.confidence = f.level <= cfg.silenceGate
                     ? 0.f
                     : smoothstepf(cfg.confidenceFloor,
                                   cfg.confidenceFloor * 2.f, f.level);
    }

    medianSmooth(frames, 2);
    return frames;
}

VisemeTimeline timelineFromFrames(const QVector<Frame> &frames)
{
    VisemeTimeline tl;
    if (frames.isEmpty())
        return tl;

    tl.keys.reserve(frames.size() + 1);
    for (const Frame &f : frames) {
        VisemeKey k;
        k.ms = f.ms;

        if (f.level <= 0.f) {
            tl.keys.append(k);
            continue;
        }

        // Loudness still sets how far the mouth moves - it is the one thing
        // the envelope analyser got right, and the shape only says WHICH way.
        const float lvl = qPow(f.level, 0.6f);
        const float c = f.confidence;

        // An open vowel drops the jaw further than a closed one at the same
        // loudness. With no confidence this collapses to the envelope's own
        // answer, which is what "fall back" has to mean to be worth having.
        //
        // The range straddles 1 rather than sitting under it. A factor that
        // can only scale down makes the accurate tier the LESS lively one -
        // measured at 0.61 peak opening against the envelope's 0.86 on the
        // same line - which reads as a worse mouth however much better it is
        // informed. Open vowels have to gain what closed ones give up.
        const float shaped = 0.45f + 0.8f * smoothstepf(0.25f, 0.65f, f.openness);
        k.open = lvl * (1.f - c + c * shaped);

        // wide and round are the two ends of one axis with a neutral middle,
        // so a frontness in between asks for neither rather than half of both.
        k.wide = c * lvl * smoothstepf(0.55f, 0.85f, f.frontness);
        k.round = c * lvl * smoothstepf(0.45f, 0.15f, f.frontness);

        // A fricative is loud and shapeless: narrow the mouth instead of
        // opening it, the way the zero-crossing hint always did, but from a
        // measurement that cannot be fooled by a bright vowel.
        const float s = smoothstepf(0.35f, 0.60f, f.fricness) * c;
        if (s > 0.f) {
            k.wide = qMax(k.wide, 0.55f * lvl * s);
            k.open *= (1.f - 0.55f * s);
            k.round *= (1.f - s);
        }

        k.open = qBound(0.f, k.open, 1.f);
        k.wide = qBound(0.f, k.wide, 1.f);
        k.round = qBound(0.f, k.round, 1.f);
        tl.keys.append(k);
    }

    const qint64 last = tl.keys.last().ms;
    tl.keys.append({last + 16, 0.f, 0.f, 0.f});
    tl.durationMs = last + 16;
    return tl;
}

VisemeTimeline timelineForSamples(const QVector<float> &mono,
                                  int sampleRate, const Config &cfg)
{
    return timelineFromFrames(analyse(mono, sampleRate, cfg));
}

} // namespace ClayViseme
