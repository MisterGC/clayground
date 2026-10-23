// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sfx_design.h"

#include "sfx_parser.h"
#include "sfx_writer.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QRegularExpression>

#include <algorithm>
#include <cmath>

namespace clay::sound {

namespace {

using P = SfxParam;

// As in sfx_parser.cpp: every check returns false on the first failure,
// after setting `err` to the failing field's path and the reason.
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

QString num(double d) { return QString::number(d, 'g', 6); }

bool requireKeysOnly(const QJsonObject &obj, const QStringList &allowed, const QString &path)
{
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        if (!allowed.contains(it.key()))
            return fail(path, QStringLiteral("unknown field '%1' (known: %2)")
                                  .arg(it.key(), allowed.join(QStringLiteral(", "))));
    }
    return true;
}

bool parseObject(const QByteArray &json, QJsonObject &out, const QString &what)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &perr);
    if (perr.error != QJsonParseError::NoError)
        return fail({}, QStringLiteral("JSON error at offset %1: %2").arg(perr.offset).arg(perr.errorString()));
    if (!doc.isObject()) return fail({}, QStringLiteral("a %1 must be a JSON object").arg(what));
    out = doc.object();
    return true;
}

bool isInteger(const QJsonValue &v, double lo, double hi)
{
    const double d = v.toDouble(lo - 1.0);
    return v.isDouble() && d >= lo && d <= hi && d == std::floor(d);
}

bool formatVersion(const QJsonObject &root)
{
    if (root.contains("version") && root.value("version").toDouble(0.0) != 1.0)
        return fail(QStringLiteral("version"), QStringLiteral("only version 1 is known"));
    return true;
}

// {"id": "...", "version": n}, the same in a template and a design.
bool templateRef(const QJsonObject &root, QString &id, int &version)
{
    const QString tp = QStringLiteral("template");
    if (!root.contains(tp)) return fail({}, QStringLiteral("needs a 'template' with an 'id' and a 'version'"));
    const QJsonValue v = root.value(tp);
    if (!v.isObject()) return fail(tp, QStringLiteral("must be an object"));
    const QJsonObject ref = v.toObject();
    if (!requireKeysOnly(ref, {"id", "version"}, tp)) return false;
    if (!ref.value("id").isString() || ref.value("id").toString().isEmpty())
        return fail(join(tp, "id"), QStringLiteral("must be a non-empty string"));
    if (!isInteger(ref.value("version"), 1.0, 1e9))
        return fail(join(tp, "version"), QStringLiteral("must be an integer from 1"));
    id = ref.value("id").toString();
    version = static_cast<int>(ref.value("version").toDouble());
    return true;
}

bool metaField(const QJsonObject &root)
{
    if (root.contains("meta") && !root.value("meta").isObject())
        return fail(QStringLiteral("meta"), QStringLiteral("must be an object"));
    return true;
}

// ---------------------------------------------------------------- paths

int paramFromPath(const QString &path)
{
    for (int i = 0; i < kSfxParamCount; ++i)
        if (path == QLatin1String(kSfxParams[i].path)) return i;
    return -1;
}

// Layer fields an override may write: every leaf a recipe layer has, and
// the groups as a whole.
bool isLayerField(const QString &field)
{
    static const QStringList named = {"name", "role", "source", "sample", "interpolation",
                                      "filter.type", "lfo.target", "noise.color", "noise.rate",
                                      "envelope", "pitch", "filter", "lfo", "noise", "burst",
                                      "burst.jitter", "vary"};
    if (named.contains(field) || paramFromPath(field) >= 0) return true;
    return field.startsWith(QLatin1String("vary.")) && paramFromPath(field.mid(5)) >= 0;
}

bool isTopField(const QString &path)
{
    return path == QLatin1String("name") || path == QLatin1String("variation")
        || path == QLatin1String("variation.seed") || path == QLatin1String("variation.pool")
        || path == QLatin1String("maxVoices");
}

struct LayerPath
{
    QString selector;   // an index or a layer name
    QString field;      // "gain", "envelope.decay", "vary.detune", "filter", ...
};

bool splitLayerPath(const QString &path, LayerPath &out)
{
    static const QRegularExpression re(QStringLiteral("^layers\\[([^\\[\\]]+)\\]\\.(.+)$"));
    const auto m = re.match(path);
    if (!m.hasMatch()) return false;
    out = {m.captured(1), m.captured(2)};
    return true;
}

QString knownPathHint()
{
    return QStringLiteral("name, variation.seed, variation.pool, maxVoices, or layers[<index or name>].<field> "
                          "with a recipe layer field such as gain, envelope.decay or vary.detune");
}

// The template layer `selector` names: an index, or the one layer of
// that name.
bool resolveLayer(const QJsonArray &layers, const QString &selector, const QString &at, int &index)
{
    bool isIndex = false;
    const int i = selector.toInt(&isIndex);
    if (isIndex) {
        if (i < 0 || i >= layers.size())
            return fail(at, QStringLiteral("there is no layer %1 (the template has %2)").arg(i).arg(layers.size()));
        index = i;
        return true;
    }
    index = -1;
    for (int k = 0; k < layers.size(); ++k) {
        if (layers.at(k).toObject().value("name").toString() != selector) continue;
        if (index >= 0) return fail(at, QStringLiteral("more than one layer is named '%1'; use its index").arg(selector));
        index = k;
    }
    if (index < 0) return fail(at, QStringLiteral("no layer is named '%1'").arg(selector));
    return true;
}

// One place in a recipe object: a top-level field (layer -1) or a field
// of one layer. Two paths that resolve to the same target write the same
// field.
struct Target
{
    int     layer = -1;
    QString field;

    bool operator==(const Target &o) const { return layer == o.layer && field == o.field; }
    // `this` replaces `o` along with everything inside it.
    bool covers(const Target &o) const
    {
        return layer == o.layer && (field == o.field || o.field.startsWith(field + QLatin1Char('.')));
    }
};

bool resolve(const QJsonObject &recipe, const QString &path, const QString &at, Target &t)
{
    if (isTopField(path)) { t = {-1, path}; return true; }
    LayerPath lp;
    if (!splitLayerPath(path, lp) || !isLayerField(lp.field))
        return fail(at, QStringLiteral("unknown path '%1' (%2)").arg(path, knownPathHint()));
    t.field = lp.field;
    return resolveLayer(recipe.value("layers").toArray(), lp.selector, at, t.layer);
}

// "envelope.decay" -> ("envelope", "decay"); "vary.envelope.decay" ->
// ("vary", "envelope.decay"); "burst.jitter.time" -> ("burst",
// "jitter.time"); "gain" -> ("", "gain").
QPair<QString, QString> splitField(const QString &field)
{
    const int dot = field.indexOf(QLatin1Char('.'));
    if (dot < 0) return {QString(), field};
    return {field.left(dot), field.mid(dot + 1)};
}

// A key of "vary" is a whole field path; any other group may hold a
// group of its own.
bool nested(const QString &group, const QString &key)
{
    return group != QLatin1String("vary") && key.contains(QLatin1Char('.'));
}

QJsonValue valueIn(const QJsonObject &obj, const QString &field)
{
    const auto [group, key] = splitField(field);
    if (group.isEmpty()) return obj.value(key);
    if (nested(group, key)) return valueIn(obj.value(group).toObject(), key);
    return obj.value(group).toObject().value(key);
}

// Write `v` at `field` of `obj`; null removes it, and a group left empty
// goes with it.
void writeIn(QJsonObject &obj, const QString &field, const QJsonValue &v)
{
    const auto [group, key] = splitField(field);
    if (group.isEmpty()) {
        if (v.isNull()) obj.remove(key); else obj.insert(key, v);
        return;
    }
    QJsonObject g = obj.value(group).toObject();
    if (nested(group, key)) writeIn(g, key, v);
    else if (v.isNull()) g.remove(key);
    else g.insert(key, v);
    if (g.isEmpty()) obj.remove(group); else obj.insert(group, g);
}

QJsonValue read(const QJsonObject &recipe, const Target &t)
{
    if (t.layer < 0) return valueIn(recipe, t.field);
    return valueIn(recipe.value("layers").toArray().at(t.layer).toObject(), t.field);
}

void write(QJsonObject &recipe, const Target &t, const QJsonValue &v)
{
    if (t.layer < 0) { writeIn(recipe, t.field, v); return; }
    QJsonArray layers = recipe.value("layers").toArray();
    QJsonObject layer = layers.at(t.layer).toObject();
    writeIn(layer, t.field, v);
    layers.replace(t.layer, layer);
    recipe.insert("layers", layers);
}

// The value a driven parameter has in `recipe`: as written, or the
// recipe's default for it.
double baseValue(const QJsonObject &recipe, int layer, SfxParam p)
{
    const QJsonValue v = read(recipe, {layer, QLatin1String(sfxParamInfo(p).path)});
    return v.isDouble() ? v.toDouble() : sfxParamInfo(p).def;
}

// ---------------------------------------------------------------- curves

double curveAt(const SfxDrive &d, double t)
{
    switch (d.curve) {
    case SfxCurve::Exp: return d.from * std::pow(d.to / d.from, t);
    case SfxCurve::Db:  return std::pow(10.0, (d.from + (d.to - d.from) * t) / 20.0);
    case SfxCurve::Lin: break;
    }
    return d.from + (d.to - d.from) * t;
}

double driveAt(const SfxMacro &m, const SfxDrive &d, double x)
{
    return curveAt(d, (x - m.min) / (m.max - m.min));
}

// Six significant digits: a last-bit difference between two platforms'
// pow() never reaches the written bytes.
double rounded(double d) { return QString::number(d, 'g', 6).toDouble(); }

// What the recipe parser accepts for `p` on layer `layer` of `recipe`:
// its range, less the layer's "vary" range for it, and at most 1 for a
// volume lfo's depth.
QPair<double, double> legalRange(const QJsonObject &recipe, int layer, SfxParam p)
{
    const auto &info = sfxParamInfo(p);
    double lo = info.min, hi = info.max;
    const QJsonObject l = recipe.value("layers").toArray().at(layer).toObject();
    if (p == P::LfoDepth && l.value("lfo").toObject().value("target").toString() == QLatin1String("volume"))
        hi = std::min(hi, 1.0);
    const QJsonArray r = l.value("vary").toObject().value(QLatin1String(info.path)).toArray();
    if (r.size() == 2 && r.at(0).isDouble() && r.at(1).isDouble()) {
        lo -= r.at(0).toDouble();
        hi -= r.at(1).toDouble();
    }
    return {lo, hi};
}

// ---------------------------------------------------------------- template

bool parseRange(const QJsonValue &v, const QString &at, double &lo, double &hi)
{
    const QJsonArray a = v.toArray();
    if (!v.isArray() || a.size() != 2 || !a.at(0).isDouble() || !a.at(1).isDouble())
        return fail(at, QStringLiteral("must be [min, max], two numbers"));
    lo = a.at(0).toDouble();
    hi = a.at(1).toDouble();
    if (!(lo < hi)) return fail(at, QStringLiteral("min %1 must be below max %2").arg(num(lo), num(hi)));
    return true;
}

bool numberField(const QJsonObject &o, const QString &key, const QString &path, double &out)
{
    if (!o.contains(key)) return fail(path, QStringLiteral("needs a '%1'").arg(key));
    if (!o.value(key).isDouble()) return fail(join(path, key), QStringLiteral("must be a number"));
    out = o.value(key).toDouble();
    return true;
}

bool parseDrive(const QJsonObject &o, const QString &path, const QJsonObject &recipe, SfxDrive &d)
{
    if (!requireKeysOnly(o, {"path", "from", "to", "curve"}, path)) return false;
    const QString pp = join(path, "path");
    if (!o.value("path").isString()) return fail(path, QStringLiteral("needs a 'path' (a string)"));
    d.path = o.value("path").toString();
    LayerPath lp;
    if (!splitLayerPath(d.path, lp) || paramFromPath(lp.field) < 0) {
        QStringList known;
        for (const auto &info : kSfxParams) known << QLatin1String(info.path);
        return fail(pp, QStringLiteral("'%1' is not a layer number: a macro drives layers[<index or name>].<field>, "
                                       "the field one of %2").arg(d.path, known.join(QStringLiteral(", "))));
    }
    d.param = static_cast<SfxParam>(paramFromPath(lp.field));
    if (!resolveLayer(recipe.value("layers").toArray(), lp.selector, pp, d.layer)) return false;
    if (!numberField(o, "from", path, d.from) || !numberField(o, "to", path, d.to)) return false;

    if (o.contains("curve")) {
        const QString c = o.value("curve").toString();
        if (c == QLatin1String("lin"))      d.curve = SfxCurve::Lin;
        else if (c == QLatin1String("exp")) d.curve = SfxCurve::Exp;
        else if (c == QLatin1String("db"))  d.curve = SfxCurve::Db;
        else return fail(join(path, "curve"), QStringLiteral("unknown curve '%1' (lin, exp, db)")
                                                  .arg(o.value("curve").toVariant().toString()));
    }
    if (d.curve == SfxCurve::Exp && !(d.from * d.to > 0.0))
        return fail(path, QStringLiteral("an exp curve needs 'from' and 'to' non-zero and of one sign"));
    const auto &info = sfxParamInfo(d.param);
    if (d.curve == SfxCurve::Db && (info.min < 0.0 || info.max > 1.0))
        return fail(join(path, "curve"), QStringLiteral("db moves a level in 0..1; %1 is %2..%3")
                                             .arg(QLatin1String(info.path), num(info.min), num(info.max)));
    return true;
}

bool parseMacro(const QJsonObject &o, const QString &path, const QJsonObject &recipe, SfxMacro &m)
{
    if (!requireKeysOnly(o, {"id", "label", "range", "default", "drives"}, path)) return false;
    static const QRegularExpression idRe(QStringLiteral("^[A-Za-z_][A-Za-z0-9_-]*$"));
    if (!o.value("id").isString()) return fail(path, QStringLiteral("needs an 'id' (a string)"));
    m.id = o.value("id").toString();
    if (!idRe.match(m.id).hasMatch())
        return fail(join(path, "id"), QStringLiteral("'%1' is not a name: letters, digits, '_' and '-', "
                                                     "not starting with a digit").arg(m.id));
    m.label = m.id;
    if (o.contains("label")) {
        if (!o.value("label").isString()) return fail(join(path, "label"), QStringLiteral("must be a string"));
        m.label = o.value("label").toString();
    }
    if (!o.contains("range")) return fail(path, QStringLiteral("needs a 'range'"));
    if (!parseRange(o.value("range"), join(path, "range"), m.min, m.max)) return false;
    if (!numberField(o, "default", path, m.def)) return false;
    if (m.def < m.min || m.def > m.max)
        return fail(join(path, "default"), QStringLiteral("%1 is outside %2..%3")
                                               .arg(num(m.def), num(m.min), num(m.max)));
    if (!o.value("drives").isArray()) return fail(path, QStringLiteral("needs 'drives' (an array)"));
    const QJsonArray drives = o.value("drives").toArray();
    for (int i = 0; i < drives.size(); ++i) {
        const QString dp = join(path, QStringLiteral("drives[%1]").arg(i));
        if (!drives.at(i).isObject()) return fail(dp, QStringLiteral("must be an object"));
        SfxDrive d;
        if (!parseDrive(drives.at(i).toObject(), dp, recipe, d)) return false;
        m.drives.append(d);
    }
    return true;
}

bool parseTemplateInto(const QByteArray &json, SfxTemplate &tpl)
{
    QJsonObject root;
    if (!parseObject(json, root, QStringLiteral("template"))) return false;
    if (!requireKeysOnly(root, {"version", "template", "name", "variation", "maxVoices", "layers",
                                "macros", "meta"}, {})
        || !formatVersion(root) || !templateRef(root, tpl.id, tpl.version) || !metaField(root))
        return false;

    // The template's recipe must be one by itself: it is what a design at
    // the default macro values compiles to.
    for (const char *key : {"version", "name", "variation", "maxVoices", "layers"})
        if (root.contains(key)) tpl.recipe.insert(key, root.value(key));
    const auto parsed = SfxParser::parse(QJsonDocument(tpl.recipe).toJson(QJsonDocument::Compact));
    if (!parsed.ok) { err = parsed.error; return false; }
    tpl.parsed = parsed.recipe;

    if (root.contains("macros") && !root.value("macros").isArray())
        return fail(QStringLiteral("macros"), QStringLiteral("must be an array"));
    const QJsonArray macros = root.value("macros").toArray();
    QVector<QPair<Target, QString>> driven;     // each driven field and the macro driving it
    for (int i = 0; i < macros.size(); ++i) {
        const QString mp = QStringLiteral("macros[%1]").arg(i);
        if (!macros.at(i).isObject()) return fail(mp, QStringLiteral("must be an object"));
        SfxMacro m;
        if (!parseMacro(macros.at(i).toObject(), mp, tpl.recipe, m)) return false;
        if (tpl.macroIndex(m.id) >= 0)
            return fail(join(mp, "id"), QStringLiteral("another macro is '%1' already").arg(m.id));

        for (int k = 0; k < m.drives.size(); ++k) {
            const SfxDrive &d = m.drives[k];
            const QString dp = QStringLiteral("%1.drives[%2]").arg(mp).arg(k);
            const Target t{d.layer, QLatin1String(sfxParamInfo(d.param).path)};
            for (const auto &other : driven)
                if (other.first == t)
                    return fail(join(dp, "path"), QStringLiteral("layers[%1].%2 is driven by macro '%3' already")
                                                      .arg(t.layer).arg(t.field, other.second));
            driven.append({t, m.id});

            // The field must have a meaning on its layer: written there
            // explicitly, the recipe still parses.
            QJsonObject probe = tpl.recipe;
            const double base = baseValue(tpl.recipe, d.layer, d.param);
            write(probe, t, base);
            const auto check = SfxParser::parse(QJsonDocument(probe).toJson(QJsonDocument::Compact));
            if (!check.ok) return fail(join(dp, "path"), check.error);

            // At the macro's default the template is its own recipe, so
            // the drive must pass through the value the layer has.
            const double atDefault = driveAt(m, d, m.def);
            if (std::fabs(atDefault - base) > 1e-4 * std::max(1.0, std::fabs(base)))
                return fail(dp, QStringLiteral("at the macro's default %1 it gives %2, but %3 is %4 in the "
                                               "template's layers (a template is its recipe at the default "
                                               "macro values)")
                                    .arg(num(m.def), num(atDefault), d.path, num(base)));
        }
        tpl.macros.append(m);
    }
    return true;
}

// ---------------------------------------------------------------- design

bool isPath(const QString &path)
{
    if (isTopField(path)) return true;
    LayerPath lp;
    return splitLayerPath(path, lp) && isLayerField(lp.field);
}

bool parseDesignInto(const QByteArray &json, SfxDesign &d)
{
    QJsonObject root;
    if (!parseObject(json, root, QStringLiteral("design file"))) return false;
    if (!requireKeysOnly(root, {"version", "name", "template", "macros", "overrides", "locks", "meta"}, {})
        || !formatVersion(root) || !templateRef(root, d.templateId, d.templateVersion) || !metaField(root))
        return false;
    if (root.contains("name")) {
        if (!root.value("name").isString()) return fail(QStringLiteral("name"), QStringLiteral("must be a string"));
        d.name = root.value("name").toString();
    }
    if (root.contains("macros")) {
        if (!root.value("macros").isObject())
            return fail(QStringLiteral("macros"), QStringLiteral("must be an object of macro id -> value"));
        const QJsonObject m = root.value("macros").toObject();
        for (auto it = m.begin(); it != m.end(); ++it) {
            if (!it.value().isDouble())
                return fail(join(QStringLiteral("macros"), it.key()), QStringLiteral("must be a number"));
            d.macros.insert(it.key(), it.value().toDouble());
        }
    }
    if (root.contains("overrides")) {
        if (!root.value("overrides").isObject())
            return fail(QStringLiteral("overrides"), QStringLiteral("must be an object of path -> value"));
        const QJsonObject o = root.value("overrides").toObject();
        for (auto it = o.begin(); it != o.end(); ++it) {
            if (!isPath(it.key()))
                return fail(QStringLiteral("overrides"), QStringLiteral("unknown path '%1' (%2)")
                                                             .arg(it.key(), knownPathHint()));
            d.overrides.insert(it.key(), it.value());
        }
    }
    if (root.contains("locks")) {
        const QJsonValue v = root.value("locks");
        if (!v.isArray()) return fail(QStringLiteral("locks"), QStringLiteral("must be an array of macro ids and paths"));
        const QJsonArray a = v.toArray();
        for (int i = 0; i < a.size(); ++i) {
            if (!a.at(i).isString())
                return fail(QStringLiteral("locks[%1]").arg(i), QStringLiteral("must be a string"));
            d.locks << a.at(i).toString();
        }
    }
    return true;
}

bool compileInto(const SfxDesign &design, const SfxTemplate &tpl, SfxCompileResult &res)
{
    if (design.templateId != tpl.id || design.templateVersion != tpl.version)
        return fail(QStringLiteral("template"), QStringLiteral("the design is for %1@%2, the template is %3@%4")
                                                    .arg(design.templateId).arg(design.templateVersion)
                                                    .arg(tpl.id).arg(tpl.version));
    QStringList ids;
    for (const auto &m : tpl.macros) ids << m.id;
    for (auto it = design.macros.begin(); it != design.macros.end(); ++it) {
        const int i = tpl.macroIndex(it.key());
        if (i < 0)
            return fail(QStringLiteral("macros"), QStringLiteral("unknown macro '%1' (known: %2)")
                                                      .arg(it.key(), ids.join(QStringLiteral(", "))));
        const SfxMacro &m = tpl.macros[i];
        if (it.value() < m.min || it.value() > m.max)
            return fail(join(QStringLiteral("macros"), it.key()), QStringLiteral("%1 is outside %2..%3")
                                                                     .arg(num(it.value()), num(m.min), num(m.max)));
    }
    for (int i = 0; i < design.locks.size(); ++i) {
        const QString &lock = design.locks[i];
        Target t;
        if (tpl.macroIndex(lock) >= 0) continue;
        if (!isPath(lock) || !resolve(tpl.recipe, lock, {}, t))
            return fail(QStringLiteral("locks[%1]").arg(i),
                        QStringLiteral("'%1' is neither a macro nor a path of the template").arg(lock));
    }

    QJsonObject doc = tpl.recipe;
    if (!design.name.isEmpty()) doc.insert("name", design.name);

    QVector<QPair<Target, QString>> overridden;
    for (auto it = design.overrides.begin(); it != design.overrides.end(); ++it) {
        const QString at = join(QStringLiteral("overrides"), it.key());
        Target t;
        if (!resolve(tpl.recipe, it.key(), at, t)) return false;
        // A group and a field inside it would apply in key order, which
        // depends on how the selector is spelled: one of them must go.
        for (const auto &other : overridden)
            if (other.first.covers(t) || t.covers(other.first))
                return fail(at, QStringLiteral("writes where '%1' writes already").arg(other.second));
        overridden.append({t, it.key()});
        write(doc, t, it.value());
    }

    for (const SfxMacro &m : tpl.macros) {
        const double x = design.macros.value(m.id, m.def);
        for (const SfxDrive &d : m.drives) {
            const Target t{d.layer, QLatin1String(sfxParamInfo(d.param).path)};
            SfxDriveReport r;
            r.macro = m.id;
            r.path = d.path;
            r.macroValue = x;
            const auto [lo, hi] = legalRange(doc, d.layer, d.param);
            r.min = lo;
            r.max = hi;
            r.value = x == m.def ? baseValue(tpl.recipe, d.layer, d.param) : rounded(driveAt(m, d, x));
            r.overridden = std::any_of(overridden.begin(), overridden.end(),
                                       [&](const auto &o) { return o.first.covers(t); });
            if (r.overridden) {
                r.written = baseValue(doc, d.layer, d.param);
            } else if (x == m.def && (lo > hi || (r.value >= lo && r.value <= hi))) {
                r.written = r.value;    // the template's own value, left as written
            } else {
                // Off the default, or at it when an override (a wider vary
                // range) narrowed what the field may hold: clamped like any
                // other driven value.
                r.written = lo <= hi ? std::clamp(r.value, lo, hi) : r.value;
                r.clamped = r.written != r.value;
                write(doc, t, r.written);
            }
            res.drives.append(r);
        }
    }

    res.json = writeSfxRecipe(doc);
    const auto parsed = SfxParser::parse(res.json);
    if (!parsed.ok) return fail(QStringLiteral("the compiled recipe"), parsed.error);
    res.recipe = parsed.recipe;
    return true;
}

} // namespace

int SfxTemplate::macroIndex(const QString &macroId) const
{
    for (int i = 0; i < macros.size(); ++i)
        if (macros[i].id == macroId) return i;
    return -1;
}

QStringList SfxCompileResult::clampMessages() const
{
    QStringList out;
    for (const auto &r : drives)
        if (r.clamped)
            out << QStringLiteral("%1: macro '%2' drives %3, clamped to %4 (%5..%6)")
                       .arg(r.path, r.macro, num(r.value), num(r.written), num(r.min), num(r.max));
    return out;
}

SfxTemplateParseResult SfxDesignCompiler::parseTemplate(const QByteArray &json)
{
    SfxTemplateParseResult res;
    err.clear();
    res.ok = parseTemplateInto(json, res.tpl);
    if (!res.ok) res.error = err;
    return res;
}

SfxDesignParseResult SfxDesignCompiler::parseDesign(const QByteArray &json)
{
    SfxDesignParseResult res;
    err.clear();
    res.ok = parseDesignInto(json, res.design);
    if (!res.ok) res.error = err;
    return res;
}

SfxCompileResult SfxDesignCompiler::compile(const SfxDesign &design, const SfxTemplate &tpl)
{
    SfxCompileResult res;
    err.clear();
    res.ok = compileInto(design, tpl, res);
    if (!res.ok) {
        res.error = err;
        res.json.clear();
        res.drives.clear();
    }
    return res;
}

SfxCompileResult SfxDesignCompiler::compile(const QByteArray &design, const QByteArray &tpl)
{
    const auto t = parseTemplate(tpl);
    if (!t.ok) { SfxCompileResult r; r.error = QStringLiteral("in the template: ") + t.error; return r; }
    const auto d = parseDesign(design);
    if (!d.ok) { SfxCompileResult r; r.error = QStringLiteral("in the design: ") + d.error; return r; }
    return compile(d.design, t.tpl);
}

} // namespace clay::sound
