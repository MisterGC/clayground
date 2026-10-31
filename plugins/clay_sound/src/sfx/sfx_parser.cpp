// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sfx_parser.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QStringList>

#include <algorithm>
#include <cmath>

namespace clay::sound {

namespace {

using P = SfxParam;

// Every check returns false on the first failure, after setting `err`
// to the failing field's path and the reason.
thread_local QString err;

bool fail(const QString &path, const QString &msg)
{
    err = path.isEmpty() ? msg : path + QStringLiteral(": ") + msg;
    return false;
}

QString join(const QString &path, const QString &key)
{
    return path.isEmpty() ? key : path + QLatin1Char('.') + key;
}

bool requireKeysOnly(const QJsonObject &obj, const QStringList &allowed, const QString &path)
{
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        if (!allowed.contains(it.key()))
            return fail(path, QStringLiteral("unknown field '%1' (known: %2)")
                                  .arg(it.key(), allowed.join(QStringLiteral(", "))));
    }
    return true;
}

bool objectAt(const QJsonObject &parent, const QString &key, const QString &path, QJsonObject &out)
{
    const QJsonValue v = parent.value(key);
    if (!v.isObject()) return fail(join(path, key), QStringLiteral("must be an object"));
    out = v.toObject();
    return true;
}

bool stringAt(const QJsonObject &parent, const QString &key, const QString &path, QString &out)
{
    const QJsonValue v = parent.value(key);
    if (!v.isString()) return fail(join(path, key), QStringLiteral("must be a string"));
    out = v.toString();
    return true;
}

QString formatNumber(double d) { return QString::number(d, 'g', 6); }

// The number at parent[key], if present, into the layer's parameter.
bool numberAt(const QJsonObject &parent, const QString &key, SfxParam p,
              SfxLayer &layer, const QString &path)
{
    if (!parent.contains(key)) return true;
    const QJsonValue v = parent.value(key);
    const QString at = join(path, key);
    if (!v.isDouble()) return fail(at, QStringLiteral("must be a number"));
    const double d = v.toDouble();
    const auto &info = sfxParamInfo(p);
    if (d < info.min || d > info.max)
        return fail(at, QStringLiteral("%1 is outside %2..%3")
                            .arg(formatNumber(d), formatNumber(info.min), formatNumber(info.max)));
    layer.at(p) = d;
    return true;
}

bool isSample(const SfxLayer &l) { return l.source == SfxSource::Sample; }

// Why `p` has no meaning on this layer; empty when it has one.
QString notApplicable(SfxParam p, const SfxLayer &l)
{
    switch (p) {
    case P::Freq: case P::PitchStart: case P::PitchEnd: case P::PitchTime: case P::PitchCurve:
        if (isSample(l)) return QStringLiteral("does not apply to a sample layer (use 'detune')");
        return {};
    case P::Decay: case P::Sustain: case P::DecayCurve:
        if (isSample(l)) return QStringLiteral("does not apply to a sample layer (only attack and release do)");
        return {};
    case P::Cutoff: case P::Resonance: case P::FilterAttack: case P::FilterDecay:
    case P::FilterSustain: case P::FilterRelease: case P::FilterAmount:
    case P::FilterAttackCurve: case P::FilterDecayCurve: case P::FilterReleaseCurve:
        if (isSample(l)) return QStringLiteral("does not apply to a sample layer");
        if (l.filterType == OscillatorVoice::FilterType::Off)
            return QStringLiteral("needs a 'filter' with a 'type'");
        return {};
    case P::PulseWidth:
        if (l.source != SfxSource::Square) return QStringLiteral("applies to a square layer only");
        return {};
    case P::LfoRate: case P::LfoDepth:
        if (isSample(l)) return QStringLiteral("does not apply to a sample layer");
        if (l.lfoTarget == 0) return QStringLiteral("needs an 'lfo' with a 'target'");
        return {};
    case P::BurstCount: case P::BurstDuration: case P::BurstDensity: case P::JitterTime:
    case P::JitterGain: case P::JitterFreq: case P::JitterLength:
        if (!l.burst) return QStringLiteral("needs a 'burst'");
        return {};
    case P::FmRatio: case P::FmIndex: case P::FmAttack: case P::FmDecay: case P::FmSustain:
    case P::FmRelease: case P::FmAttackCurve: case P::FmDecayCurve: case P::FmReleaseCurve:
        if (!l.fm) return QStringLiteral("needs an 'fm'");
        return {};
    case P::RingRatio:
        if (!l.ring) return QStringLiteral("needs a 'ring'");
        return {};
    case P::Drive:
        if (!l.drive) return QStringLiteral("needs a 'drive'");
        return {};
    case P::CrushBits: case P::CrushRate:
        if (!l.crush) return QStringLiteral("needs a 'crush'");
        return {};
    case P::JitterCutoff:
        if (!l.burst) return QStringLiteral("needs a 'burst'");
        if (l.filterType == OscillatorVoice::FilterType::Off)
            return QStringLiteral("needs a 'filter' with a 'type'");
        return {};
    default:
        return {};
    }
}

int paramFromPath(const QString &path)
{
    for (int i = 0; i < kSfxParamCount; ++i)
        if (path == QLatin1String(kSfxParams[i].path)) return i;
    return -1;
}

bool parseVary(const QJsonObject &vary, SfxLayer &layer, const QString &path)
{
    for (auto it = vary.begin(); it != vary.end(); ++it) {
        const QString at = join(path, it.key());
        const int idx = paramFromPath(it.key());
        if (idx < 0) {
            QStringList known;
            for (const auto &info : kSfxParams) known << QLatin1String(info.path);
            return fail(path, QStringLiteral("unknown field '%1' (known: %2)")
                                  .arg(it.key(), known.join(QStringLiteral(", "))));
        }
        const auto p = static_cast<SfxParam>(idx);
        if (const QString why = notApplicable(p, layer); !why.isEmpty()) return fail(at, why);

        const QJsonArray arr = it.value().toArray();
        if (!it.value().isArray() || arr.size() != 2 || !arr.at(0).isDouble() || !arr.at(1).isDouble())
            return fail(at, QStringLiteral("must be [min, max], two numbers added to the value"));
        const SfxRange r{true, arr.at(0).toDouble(), arr.at(1).toDouble()};
        if (r.lo > r.hi)
            return fail(at, QStringLiteral("min %1 is above max %2")
                                .arg(formatNumber(r.lo), formatNumber(r.hi)));
        // Every value the variation can reach must be valid by itself.
        const double base = layer.get(p);
        const auto &info = sfxParamInfo(p);
        if (base + r.lo < info.min || base + r.hi > info.max)
            return fail(at, QStringLiteral("reaches %1..%2, outside %3..%4")
                                .arg(formatNumber(base + r.lo), formatNumber(base + r.hi),
                                     formatNumber(info.min), formatNumber(info.max)));
        layer.vary[idx] = r;
    }
    return true;
}

bool sourceFromName(const QString &name, const QString &path, SfxSource &out)
{
    static const QList<QPair<QString, SfxSource>> names = {
        {"sine", SfxSource::Sine}, {"square", SfxSource::Square},
        {"triangle", SfxSource::Triangle}, {"sawtooth", SfxSource::Sawtooth},
        {"noise", SfxSource::Noise}, {"sample", SfxSource::Sample}};
    for (const auto &n : names)
        if (n.first == name) { out = n.second; return true; }
    return fail(path, QStringLiteral("unknown source '%1' (sine, square, triangle, sawtooth, noise, sample)").arg(name));
}

struct Field { const char *key; SfxParam param; };

// The listed numbers of `obj`, each checked to have a meaning here.
bool numbers(const QJsonObject &obj, const QString &objPath, SfxLayer &l,
             std::initializer_list<Field> fields)
{
    for (const auto &f : fields) {
        if (!obj.contains(f.key)) continue;
        if (const QString why = notApplicable(f.param, l); !why.isEmpty())
            return fail(join(objPath, f.key), why);
        if (!numberAt(obj, f.key, f.param, l, objPath)) return false;
    }
    return true;
}

bool parseLayer(const QJsonObject &o, const QString &path, SfxLayer &l)
{
    if (!requireKeysOnly(o, {"name", "role", "source", "sample", "interpolation",
                             "freq", "detune", "gain", "pan", "offset", "length",
                             "envelope", "pitch", "filter", "pulseWidth", "lfo", "noise", "fm", "ring",
                             "drive", "crush", "burst", "vary"}, path))
        return false;

    for (int i = 0; i < kSfxParamCount; ++i) l.value[i] = kSfxParams[i].def;

    if (!o.contains("source")) return fail(path, QStringLiteral("needs a 'source'"));
    QString text;
    if (!stringAt(o, "source", path, text)
        || !sourceFromName(text, join(path, "source"), l.source))
        return false;

    if (o.contains("name") && !stringAt(o, "name", path, l.name)) return false;
    if (o.contains("role")) {
        if (!stringAt(o, "role", path, l.role)) return false;
        if (l.role != QLatin1String("transient") && l.role != QLatin1String("body")
            && l.role != QLatin1String("tail"))
            return fail(join(path, "role"), QStringLiteral("unknown role '%1' (transient, body, tail)").arg(l.role));
    }

    if (isSample(l)) {
        if (!o.contains("sample")) return fail(path, QStringLiteral("a sample layer needs a 'sample' file"));
        if (!stringAt(o, "sample", path, l.sample)) return false;
        if (l.sample.isEmpty()) return fail(join(path, "sample"), QStringLiteral("must not be empty"));
        if (o.contains("interpolation")) {
            if (!stringAt(o, "interpolation", path, text)) return false;
            using I = SampleVoice::Interpolation;
            if (text == QLatin1String("nearest"))       l.interpolation = I::Nearest;
            else if (text == QLatin1String("linear"))   l.interpolation = I::Linear;
            else if (text == QLatin1String("gaussian")) l.interpolation = I::Gaussian;
            else return fail(join(path, "interpolation"),
                             QStringLiteral("unknown interpolation '%1' (nearest, linear, gaussian)").arg(text));
        }
    } else {
        for (const char *key : {"sample", "interpolation"})
            if (o.contains(key)) return fail(join(path, key), QStringLiteral("belongs to a sample layer"));
        if (!o.contains("length")) return fail(path, QStringLiteral("needs a 'length' in ms"));
    }

    // The filter type, the lfo target and whether there is a burst first:
    // they decide which of the numbers below have a meaning.
    QJsonObject filter, lfo, fm, ring, crush, burst, jitter;
    const QString fp = join(path, "filter");
    const QString lp = join(path, "lfo");
    const QString mp = join(path, "fm");
    const QString rp = join(path, "ring");
    const QString cp = join(path, "crush");
    const QString bp = join(path, "burst");
    const QString jp = join(bp, "jitter");
    if (o.contains("filter")) {
        if (isSample(l)) return fail(fp, QStringLiteral("does not apply to a sample layer"));
        if (!objectAt(o, "filter", path, filter)
            || !requireKeysOnly(filter, {"type", "cutoff", "resonance", "attack", "decay",
                                         "sustain", "release", "amount", "attackCurve",
                                         "decayCurve", "releaseCurve"}, fp))
            return false;
        if (!filter.contains("type")) return fail(fp, QStringLiteral("needs a 'type'"));
        if (!stringAt(filter, "type", fp, text)) return false;
        using F = OscillatorVoice::FilterType;
        if (text == QLatin1String("lowpass"))       l.filterType = F::LowPass;
        else if (text == QLatin1String("highpass")) l.filterType = F::HighPass;
        else if (text == QLatin1String("bandpass")) l.filterType = F::BandPass;
        else return fail(join(fp, "type"), QStringLiteral("unknown type '%1' (lowpass, highpass, bandpass)").arg(text));
    }
    if (o.contains("lfo")) {
        if (isSample(l)) return fail(lp, QStringLiteral("does not apply to a sample layer"));
        if (!objectAt(o, "lfo", path, lfo) || !requireKeysOnly(lfo, {"target", "shape", "rate", "depth"}, lp))
            return false;
        if (!lfo.contains("target")) return fail(lp, QStringLiteral("needs a 'target'"));
        if (!stringAt(lfo, "target", lp, text)) return false;
        if (text == QLatin1String("pitch"))       l.lfoTarget = 1;
        else if (text == QLatin1String("volume")) l.lfoTarget = 2;
        else if (text == QLatin1String("cutoff")) l.lfoTarget = 3;
        else return fail(join(lp, "target"), QStringLiteral("unknown target '%1' (pitch, volume, cutoff)").arg(text));
        if (l.lfoTarget == 3 && l.filterType == OscillatorVoice::FilterType::Off)
            return fail(join(lp, "target"), QStringLiteral("a cutoff lfo needs a 'filter' with a 'type'"));
        if (lfo.contains("shape")) {
            if (!stringAt(lfo, "shape", lp, text)) return false;
            using S = OscillatorVoice::LfoShape;
            if (text == QLatin1String("sine"))               l.lfoShape = S::Sine;
            else if (text == QLatin1String("square"))        l.lfoShape = S::Square;
            else if (text == QLatin1String("sample_hold"))   l.lfoShape = S::SampleHold;
            else if (text == QLatin1String("smooth_random")) l.lfoShape = S::SmoothRandom;
            else return fail(join(lp, "shape"),
                             QStringLiteral("unknown shape '%1' (sine, square, sample_hold, smooth_random)").arg(text));
        }
    }
    if (o.contains("noise")) {
        const QString np = join(path, "noise");
        if (l.source != SfxSource::Noise) return fail(np, QStringLiteral("applies to a noise layer only"));
        QJsonObject noise;
        if (!objectAt(o, "noise", path, noise) || !requireKeysOnly(noise, {"color", "rate"}, np))
            return false;
        using C = OscillatorVoice::NoiseColor;
        using R = OscillatorVoice::NoiseRate;
        if (noise.contains("color")) {
            if (!stringAt(noise, "color", np, text)) return false;
            if (text == QLatin1String("white"))      l.noiseColor = C::White;
            else if (text == QLatin1String("pink"))  l.noiseColor = C::Pink;
            else if (text == QLatin1String("brown")) l.noiseColor = C::Brown;
            else return fail(join(np, "color"), QStringLiteral("unknown color '%1' (white, pink, brown)").arg(text));
        }
        if (noise.contains("rate")) {
            if (!stringAt(noise, "rate", np, text)) return false;
            if (text == QLatin1String("sample"))    l.noiseRate = R::Sample;
            else if (text == QLatin1String("freq")) l.noiseRate = R::Freq;
            else return fail(join(np, "rate"), QStringLiteral("unknown rate '%1' (sample, freq)").arg(text));
        }
    }
    // Either one modulates an oscillator's phase or its wave: a noise or a
    // sample layer has neither.
    const bool oscillator = !isSample(l) && l.source != SfxSource::Noise;
    if (o.contains("fm")) {
        if (!oscillator) return fail(mp, QStringLiteral("applies to a sine, square, triangle or sawtooth layer only"));
        if (!objectAt(o, "fm", path, fm)
            || !requireKeysOnly(fm, {"ratio", "index", "attack", "decay", "sustain", "release",
                                     "attackCurve", "decayCurve", "releaseCurve"}, mp))
            return false;
        if (!fm.contains("ratio")) return fail(mp, QStringLiteral("needs a 'ratio'"));
        if (!fm.contains("index")) return fail(mp, QStringLiteral("needs an 'index'"));
        l.fm = true;
    }
    if (o.contains("ring")) {
        if (!oscillator) return fail(rp, QStringLiteral("applies to a sine, square, triangle or sawtooth layer only"));
        if (l.fm) return fail(rp, QStringLiteral("a layer has an 'fm' or a 'ring', not both"));
        if (!objectAt(o, "ring", path, ring) || !requireKeysOnly(ring, {"ratio"}, rp)) return false;
        if (!ring.contains("ratio")) return fail(rp, QStringLiteral("needs a 'ratio'"));
        l.ring = true;
    }
    // Both act on whatever the layer sounds, a sample too.
    l.drive = o.contains("drive");
    if (o.contains("crush")) {
        if (!objectAt(o, "crush", path, crush) || !requireKeysOnly(crush, {"bits", "rate"}, cp)) return false;
        if (crush.isEmpty()) return fail(cp, QStringLiteral("needs a 'bits' or a 'rate'"));
        l.crush = true;
    }
    if (o.contains("burst")) {
        if (isSample(l)) return fail(bp, QStringLiteral("does not apply to a sample layer"));
        if (!objectAt(o, "burst", path, burst)
            || !requireKeysOnly(burst, {"count", "duration", "density", "jitter"}, bp))
            return false;
        for (const char *key : {"count", "duration"})
            if (!burst.contains(key)) return fail(bp, QStringLiteral("needs a '%1'").arg(key));
        if (burst.contains("jitter")
            && (!objectAt(burst, "jitter", bp, jitter)
                || !requireKeysOnly(jitter, {"time", "gain", "cutoff", "freq", "length"}, jp)))
            return false;
        l.burst = true;
    }

    if (!numbers(o, path, l, {{"freq", P::Freq}, {"detune", P::Detune}, {"gain", P::Gain},
                              {"pan", P::Pan}, {"offset", P::Offset}, {"length", P::Length},
                              {"pulseWidth", P::PulseWidth}, {"drive", P::Drive}}))
        return false;
    if (!isSample(l) && l.get(P::Length) <= 0.0)
        return fail(join(path, "length"), QStringLiteral("must be above 0"));

    if (o.contains("envelope")) {
        const QString ep = join(path, "envelope");
        QJsonObject env;
        if (!objectAt(o, "envelope", path, env)
            || !requireKeysOnly(env, {"attack", "decay", "sustain", "release", "attackCurve",
                                      "decayCurve", "releaseCurve"}, ep)
            || !numbers(env, ep, l, {{"attack", P::Attack}, {"decay", P::Decay},
                                     {"sustain", P::Sustain}, {"release", P::Release},
                                     {"attackCurve", P::AttackCurve}, {"decayCurve", P::DecayCurve},
                                     {"releaseCurve", P::ReleaseCurve}}))
            return false;
    }
    if (o.contains("pitch")) {
        const QString pp = join(path, "pitch");
        if (isSample(l)) return fail(pp, notApplicable(P::PitchStart, l));
        QJsonObject pitch;
        if (!objectAt(o, "pitch", path, pitch)
            || !requireKeysOnly(pitch, {"start", "end", "time", "curve"}, pp)
            || !numbers(pitch, pp, l, {{"start", P::PitchStart}, {"end", P::PitchEnd},
                                       {"time", P::PitchTime}, {"curve", P::PitchCurve}}))
            return false;
    }
    if (!filter.isEmpty()
        && !numbers(filter, fp, l, {{"cutoff", P::Cutoff}, {"resonance", P::Resonance},
                                    {"attack", P::FilterAttack}, {"decay", P::FilterDecay},
                                    {"sustain", P::FilterSustain}, {"release", P::FilterRelease},
                                    {"amount", P::FilterAmount}, {"attackCurve", P::FilterAttackCurve},
                                    {"decayCurve", P::FilterDecayCurve},
                                    {"releaseCurve", P::FilterReleaseCurve}}))
        return false;
    if (!lfo.isEmpty()
        && !numbers(lfo, lp, l, {{"rate", P::LfoRate}, {"depth", P::LfoDepth}}))
        return false;
    if (l.fm
        && !numbers(fm, mp, l, {{"ratio", P::FmRatio}, {"index", P::FmIndex},
                                {"attack", P::FmAttack}, {"decay", P::FmDecay},
                                {"sustain", P::FmSustain}, {"release", P::FmRelease},
                                {"attackCurve", P::FmAttackCurve}, {"decayCurve", P::FmDecayCurve},
                                {"releaseCurve", P::FmReleaseCurve}}))
        return false;
    if (l.ring && !numbers(ring, rp, l, {{"ratio", P::RingRatio}}))
        return false;
    if (l.crush && !numbers(crush, cp, l, {{"bits", P::CrushBits}, {"rate", P::CrushRate}}))
        return false;
    if (l.burst
        && (!numbers(burst, bp, l, {{"count", P::BurstCount}, {"duration", P::BurstDuration},
                                    {"density", P::BurstDensity}})
            || !numbers(jitter, jp, l, {{"time", P::JitterTime}, {"gain", P::JitterGain},
                                        {"cutoff", P::JitterCutoff}, {"freq", P::JitterFreq},
                                        {"length", P::JitterLength}})))
        return false;

    if (o.contains("vary")) {
        QJsonObject vary;
        if (!objectAt(o, "vary", path, vary) || !parseVary(vary, l, join(path, "vary")))
            return false;
    }

    // A volume LFO deeper than 1 would turn the envelope negative.
    const auto &depthRange = l.vary[static_cast<int>(P::LfoDepth)];
    if (l.lfoTarget == 2 && l.get(P::LfoDepth) + (depthRange.on ? depthRange.hi : 0.0) > 1.0)
        return fail(join(lp, "depth"), QStringLiteral("a volume lfo reaches at most 1"));
    return true;
}

bool parseRecipe(const QByteArray &json, SfxRecipe &r)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &perr);
    if (perr.error != QJsonParseError::NoError)
        return fail({}, QStringLiteral("JSON error at offset %1: %2").arg(perr.offset).arg(perr.errorString()));
    if (!doc.isObject()) return fail({}, QStringLiteral("a recipe must be a JSON object"));
    const QJsonObject root = doc.object();
    if (!requireKeysOnly(root, {"version", "name", "variation", "maxVoices", "layers"}, {})) return false;

    if (root.contains("version")) {
        const QJsonValue v = root.value("version");
        if (!v.isDouble() || v.toDouble() != 1.0)
            return fail(QStringLiteral("version"), QStringLiteral("only version 1 is known"));
    }
    if (root.contains("name") && !stringAt(root, "name", {}, r.name)) return false;

    if (root.contains("variation")) {
        const QString vp = QStringLiteral("variation");
        QJsonObject var;
        if (!objectAt(root, "variation", {}, var) || !requireKeysOnly(var, {"seed", "pool"}, vp))
            return false;
        if (var.contains("seed")) {
            const QJsonValue v = var.value("seed");
            const double s = v.toDouble(-1.0);
            if (!v.isDouble() || s < 0.0 || s > 4294967295.0 || s != std::floor(s))
                return fail(join(vp, "seed"), QStringLiteral("must be an integer in 0..4294967295"));
            r.seed = static_cast<uint32_t>(s);
        }
        if (var.contains("pool")) {
            const QJsonValue v = var.value("pool");
            const double n = v.toDouble(-1.0);
            if (!v.isDouble() || n < 0.0 || n > 1024.0 || n != std::floor(n))
                return fail(join(vp, "pool"), QStringLiteral("must be an integer in 0..1024"));
            r.pool = static_cast<int>(n);
        }
    }

    if (root.contains("maxVoices")) {
        const QJsonValue v = root.value("maxVoices");
        const double n = v.toDouble(-1.0);
        if (!v.isDouble() || n < 0.0 || n > 256.0 || n != std::floor(n))
            return fail(QStringLiteral("maxVoices"), QStringLiteral("must be an integer in 0..256"));
        r.maxVoices = static_cast<int>(n);
    }

    if (!root.contains("layers")) return fail({}, QStringLiteral("a recipe needs 'layers'"));
    const QJsonValue lv = root.value("layers");
    if (!lv.isArray() || lv.toArray().isEmpty())
        return fail(QStringLiteral("layers"), QStringLiteral("must be a non-empty array"));
    const QJsonArray layers = lv.toArray();
    for (int i = 0; i < layers.size(); ++i) {
        const QString lp = QStringLiteral("layers[%1]").arg(i);
        if (!layers.at(i).isObject()) return fail(lp, QStringLiteral("must be an object"));
        SfxLayer layer;
        if (!parseLayer(layers.at(i).toObject(), lp, layer)) return false;
        r.layers.append(layer);
    }
    // The cap is on grains alone, so without a burst it would cap nothing.
    if (r.maxVoices > 0
        && std::none_of(r.layers.cbegin(), r.layers.cend(), [](const SfxLayer &l) { return l.burst; }))
        return fail(QStringLiteral("maxVoices"), QStringLiteral("caps the grains of a 'burst', and no layer has one"));
    return true;
}

} // namespace

SfxParseResult SfxParser::parse(const QByteArray &json)
{
    SfxParseResult res;
    err.clear();
    res.ok = parseRecipe(json, res.recipe);
    if (!res.ok) res.error = err;
    return res;
}

} // namespace clay::sound
