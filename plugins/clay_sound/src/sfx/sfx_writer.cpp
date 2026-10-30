// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sfx_writer.h"

#include "sfx_recipe.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QLocale>
#include <QStringList>

#include <cmath>

namespace clay::sound {

namespace {

// The order the README documents each object's keys in.
const QStringList &topKeys()
{
    static const QStringList k = {"version", "name", "variation", "maxVoices", "layers"};
    return k;
}

const QStringList &layerKeys()
{
    static const QStringList k = {"name", "role", "source", "sample", "interpolation",
                                  "freq", "detune", "gain", "pan", "offset", "length",
                                  "envelope", "pitch", "filter", "pulseWidth", "lfo", "noise", "burst", "vary"};
    return k;
}

const QStringList &varyKeys()
{
    static const QStringList k = [] {
        QStringList l;
        for (const auto &info : kSfxParams) l << QLatin1String(info.path);
        return l;
    }();
    return k;
}

const QStringList &groupKeys(const QString &group)
{
    static const QStringList variation = {"seed", "pool"};
    static const QStringList envelope = {"attack", "decay", "sustain", "release", "attackCurve",
                                         "decayCurve", "releaseCurve"};
    static const QStringList pitch = {"start", "end", "time", "curve"};
    static const QStringList filter = {"type", "cutoff", "resonance", "attack", "decay",
                                       "sustain", "release", "amount", "attackCurve",
                                       "decayCurve", "releaseCurve"};
    static const QStringList lfo = {"target", "rate", "depth"};
    static const QStringList noise = {"color", "rate"};
    static const QStringList burst = {"count", "duration", "density", "jitter"};
    static const QStringList jitter = {"time", "gain", "cutoff", "freq", "length"};
    static const QStringList none;
    if (group == QLatin1String("variation")) return variation;
    if (group == QLatin1String("envelope")) return envelope;
    if (group == QLatin1String("pitch")) return pitch;
    if (group == QLatin1String("filter")) return filter;
    if (group == QLatin1String("lfo")) return lfo;
    if (group == QLatin1String("noise")) return noise;
    if (group == QLatin1String("burst")) return burst;
    if (group == QLatin1String("jitter")) return jitter;
    if (group == QLatin1String("vary")) return varyKeys();
    return none;
}

// The keys of `obj`: the known ones in their order, then the rest sorted
// (QJsonObject keeps its keys sorted already).
QStringList orderedKeys(const QJsonObject &obj, const QStringList &known)
{
    QStringList keys;
    for (const QString &k : known)
        if (obj.contains(k)) keys << k;
    for (auto it = obj.begin(); it != obj.end(); ++it)
        if (!known.contains(it.key())) keys << it.key();
    return keys;
}

QByteArray number(double d)
{
    // 2^53: every integer below it is exact as a double.
    if (std::isfinite(d) && d == std::floor(d) && std::fabs(d) < 9007199254740992.0)
        return QByteArray::number(static_cast<qint64>(d));
    return QByteArray::number(d, 'g', QLocale::FloatingPointShortest);
}

QByteArray string(const QString &s)
{
    // QJsonDocument escapes; strip the array around the one string.
    const QByteArray a = QJsonDocument(QJsonArray{s}).toJson(QJsonDocument::Compact);
    return a.mid(1, a.size() - 2);
}

// `v` on one line; objects in the order of `group`'s keys.
QByteArray inlineValue(const QJsonValue &v, const QString &group = {})
{
    switch (v.type()) {
    case QJsonValue::Double: return number(v.toDouble());
    case QJsonValue::String: return string(v.toString());
    case QJsonValue::Bool:   return v.toBool() ? "true" : "false";
    case QJsonValue::Array: {
        QByteArrayList items;
        for (const QJsonValue &e : v.toArray()) items << inlineValue(e);
        return "[" + items.join(", ") + "]";
    }
    case QJsonValue::Object: {
        const QJsonObject o = v.toObject();
        if (o.isEmpty()) return "{}";
        QByteArrayList items;
        for (const QString &k : orderedKeys(o, groupKeys(group)))
            items << string(k) + ": " + inlineValue(o.value(k), k);
        return "{ " + items.join(", ") + " }";
    }
    default: return "null";
    }
}

QByteArray layer(const QJsonObject &o)
{
    QByteArrayList lines;
    for (const QString &k : orderedKeys(o, layerKeys()))
        lines << "      " + string(k) + ": " + inlineValue(o.value(k), k);
    return "    {\n" + lines.join(",\n") + "\n    }";
}

} // namespace

QByteArray writeSfxRecipe(const QJsonObject &recipe)
{
    QByteArrayList lines;
    for (const QString &k : orderedKeys(recipe, topKeys())) {
        const QJsonValue v = recipe.value(k);
        if (k == QLatin1String("layers") && v.isArray() && !v.toArray().isEmpty()) {
            QByteArrayList layers;
            for (const QJsonValue &l : v.toArray())
                layers << (l.isObject() ? layer(l.toObject()) : "    " + inlineValue(l));
            lines << "  " + string(k) + ": [\n" + layers.join(",\n") + "\n  ]";
        } else {
            lines << "  " + string(k) + ": " + inlineValue(v, k);
        }
    }
    return "{\n" + lines.join(",\n") + "\n}\n";
}

} // namespace clay::sound
