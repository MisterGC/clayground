// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song_parser.h"

#include "sfx/sfx_recipe.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>

#include <cmath>

namespace clay::sound {

namespace {

static QString makeError(const QString &msg, int line = -1)
{
    return line >= 0
        ? QStringLiteral("line %1: %2").arg(line).arg(msg)
        : msg;
}

// Best-effort reject of unknown keys in a JSON object.
static bool requireKeysOnly(const QJsonObject &obj,
                            const QSet<QString> &allowed,
                            QString *errorOut)
{
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        if (!allowed.contains(it.key())) {
            if (errorOut)
                *errorOut = QStringLiteral("unknown key '%1'").arg(it.key());
            return false;
        }
    }
    return true;
}

static bool parseMidiFromValue(const QJsonValue &v,
                               int *out,
                               QString *errorOut)
{
    if (v.isDouble()) {
        const double d = v.toDouble();
        const int    i = static_cast<int>(d);
        if (d != i) {
            if (errorOut) *errorOut = QStringLiteral("note must be an integer");
            return false;
        }
        if (i < 0 || i > 127) {
            if (errorOut) *errorOut = QStringLiteral("note %1 out of MIDI range 0..127").arg(i);
            return false;
        }
        *out = i;
        return true;
    }
    if (v.isString())
        return SongParser::parseNote(v.toString(), out, errorOut);

    if (errorOut) *errorOut = QStringLiteral("note must be a number or a string");
    return false;
}

static bool parsePattern(const QJsonObject &obj,
                         Pattern *out,
                         QString *errorOut)
{
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        const QString &track = it.key();
        if (!it.value().isArray()) {
            *errorOut = QStringLiteral("pattern track '%1' must be an array").arg(track);
            return false;
        }
        QVector<NoteCell> events;
        const QJsonArray arr = it.value().toArray();
        for (int i = 0; i < arr.size(); ++i) {
            const QJsonValue ev = arr.at(i);
            if (!ev.isObject()) {
                *errorOut = QStringLiteral("pattern track '%1' event #%2 is not an object")
                                .arg(track).arg(i);
                return false;
            }
            const QJsonObject eo = ev.toObject();
            static const QSet<QString> allowed = { "t", "note", "dur", "vel" };
            QString why;
            if (!requireKeysOnly(eo, allowed, &why)) {
                *errorOut = QStringLiteral("pattern '%1' event #%2: %3").arg(track).arg(i).arg(why);
                return false;
            }
            if (!eo.contains("t") || !eo.contains("note")) {
                *errorOut = QStringLiteral("pattern '%1' event #%2 requires 't' and 'note'")
                                .arg(track).arg(i);
                return false;
            }
            NoteCell c;
            c.t   = eo.value("t").toDouble();
            c.dur = eo.contains("dur") ? eo.value("dur").toDouble() : 0.5;
            c.vel = eo.contains("vel") ? eo.value("vel").toDouble() : 0.8;
            if (c.t < 0.0) {
                *errorOut = QStringLiteral("pattern '%1' event #%2: t must be >= 0").arg(track).arg(i);
                return false;
            }
            if (c.dur <= 0.0) {
                *errorOut = QStringLiteral("pattern '%1' event #%2: dur must be > 0").arg(track).arg(i);
                return false;
            }
            if (c.vel < 0.0 || c.vel > 1.0) {
                *errorOut = QStringLiteral("pattern '%1' event #%2: vel must be in 0..1").arg(track).arg(i);
                return false;
            }
            if (!parseMidiFromValue(eo.value("note"), &c.midi, &why)) {
                *errorOut = QStringLiteral("pattern '%1' event #%2: %3").arg(track).arg(i).arg(why);
                return false;
            }
            events.push_back(c);
        }
        out->trackEvents.insert(track, std::move(events));
    }
    return true;
}

// A sections array, each entry checked against the patterns; `what`
// names an entry in the error ("section", "segments.calm.sections").
static bool parseSections(const QJsonArray &secs, const SongModel &model, const QString &what,
                          QVector<SectionRef> *out, QString *errorOut)
{
    for (int i = 0; i < secs.size(); ++i) {
        if (!secs.at(i).isObject()) {
            *errorOut = QStringLiteral("%1 #%2 must be an object").arg(what).arg(i);
            return false;
        }
        const QJsonObject so = secs.at(i).toObject();
        static const QSet<QString> allowedSec = { "pattern", "repeat" };
        QString why;
        if (!requireKeysOnly(so, allowedSec, &why)) {
            *errorOut = QStringLiteral("%1 #%2: %3").arg(what).arg(i).arg(why);
            return false;
        }
        if (!so.contains("pattern") || !so.value("pattern").isString()) {
            *errorOut = QStringLiteral("%1 #%2 requires string 'pattern'").arg(what).arg(i);
            return false;
        }
        SectionRef sr;
        sr.patternName = so.value("pattern").toString();
        sr.repeat = so.contains("repeat") ? so.value("repeat").toInt(1) : 1;
        if (sr.repeat < 1) sr.repeat = 1;
        if (!model.patterns.contains(sr.patternName)) {
            *errorOut = QStringLiteral("%1 #%2 references unknown pattern '%3'")
                            .arg(what).arg(i).arg(sr.patternName);
            return false;
        }
        out->append(sr);
    }
    return true;
}

// --- version 2 -----------------------------------------------------------
//
// Errors start with the path of the failing field, as in an effect
// recipe ("instruments.lead.envelope.attack: ..."), and instrument
// numbers share the recipe's ranges and units (ms, dB, Hz, semitones).

static bool fail(QString *errorOut, const QString &path, const QString &msg)
{
    *errorOut = path + QStringLiteral(": ") + msg;
    return false;
}

static QString num(double d) { return QString::number(d, 'g', 6); }

static QString join(const QString &path, const QString &key)
{
    return path.isEmpty() ? key : path + QLatin1Char('.') + key;
}

static bool keysOnly(const QJsonObject &obj, const QStringList &allowed, const QString &path,
                     QString *errorOut)
{
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        if (!allowed.contains(it.key()))
            return fail(errorOut, path, QStringLiteral("unknown field '%1' (known: %2)")
                                            .arg(it.key(), allowed.join(QStringLiteral(", "))));
    }
    return true;
}

static bool objectOf(const QJsonObject &parent, const QString &key, const QString &path,
                     QJsonObject *out, QString *errorOut)
{
    const QJsonValue v = parent.value(key);
    if (!v.isObject()) return fail(errorOut, join(path, key), QStringLiteral("must be an object"));
    *out = v.toObject();
    return true;
}

static bool stringOf(const QJsonObject &parent, const QString &key, const QString &path,
                     QString *out, QString *errorOut)
{
    const QJsonValue v = parent.value(key);
    if (!v.isString()) return fail(errorOut, join(path, key), QStringLiteral("must be a string"));
    *out = v.toString();
    return true;
}

// parent[key] if present, checked against lo..hi, into *out.
static bool numberOf(const QJsonObject &parent, const QString &key, const QString &path,
                     double lo, double hi, double *out, QString *errorOut)
{
    if (!parent.contains(key)) return true;
    const QJsonValue v = parent.value(key);
    const QString at = join(path, key);
    if (!v.isDouble()) return fail(errorOut, at, QStringLiteral("must be a number"));
    const double d = v.toDouble();
    if (d < lo || d > hi)
        return fail(errorOut, at, QStringLiteral("%1 is outside %2..%3").arg(num(d), num(lo), num(hi)));
    *out = d;
    return true;
}

// The same, in the range an effect recipe gives the parameter.
static bool paramOf(const QJsonObject &parent, const QString &key, const QString &path,
                    SfxParam p, double *out, QString *errorOut)
{
    const auto &info = sfxParamInfo(p);
    return numberOf(parent, key, path, info.min, info.max, out, errorOut);
}

// Milliseconds in the file, seconds in the patch.
static bool msOf(const QJsonObject &parent, const QString &key, const QString &path,
                 SfxParam p, double *seconds, QString *errorOut)
{
    double ms = *seconds * 1000.0;
    if (!paramOf(parent, key, path, p, &ms, errorOut)) return false;
    *seconds = ms / 1000.0;
    return true;
}

static bool syncOf(const QJsonObject &parent, const QString &path, SongSync *out, QString *errorOut)
{
    if (!parent.contains("sync")) return true;
    QString s;
    if (!stringOf(parent, "sync", path, &s, errorOut)) return false;
    if (s == QLatin1String("beat"))      *out = SongSync::Beat;
    else if (s == QLatin1String("bar"))  *out = SongSync::Bar;
    else if (s == QLatin1String("exit")) *out = SongSync::Exit;
    else if (s == QLatin1String("end"))  *out = SongSync::End;
    else return fail(errorOut, path + QStringLiteral(".sync"),
                     QStringLiteral("unknown sync '%1' (beat, bar, exit, end)").arg(s));
    return true;
}

static bool parseInstrument(const QJsonObject &o, const QString &path, SongInstrument *out,
                            QString *errorOut)
{
    using P = SfxParam;
    using W = OscillatorVoice::Waveform;
    if (!keysOnly(o, {"source", "sample", "root", "interpolation", "loop", "envelope", "pitch",
                      "filter", "pulseWidth", "lfo", "gain", "pan", "bus", "maxVoices"},
                  path, errorOut))
        return false;

    InstrumentSpec &spec = out->spec;
    spec.gain = 1.0f;
    spec.bus = Bus::Music;

    QString source;
    if (!o.contains("source")) return fail(errorOut, path, QStringLiteral("needs a 'source'"));
    if (!stringOf(o, "source", path, &source, errorOut)) return false;
    const bool sampler = source == QLatin1String("sample");
    if (sampler) {
        spec.kind = InstrumentSpec::Kind::Sampler;
    } else {
        static const QList<QPair<QString, W>> waves = {
            {"sine", W::Sine}, {"square", W::Square}, {"triangle", W::Triangle},
            {"sawtooth", W::Sawtooth}, {"noise", W::Noise}};
        bool known = false;
        for (const auto &w : waves)
            if (w.first == source) { spec.synth.waveform = w.second; known = true; }
        if (!known)
            return fail(errorOut, path + QStringLiteral(".source"),
                        QStringLiteral("unknown source '%1' (sine, square, triangle, sawtooth, noise, sample)")
                            .arg(source));
    }

    // The fields of the other kind are named, not dropped.
    const QStringList synthOnly = {"pitch", "filter", "pulseWidth", "lfo"};
    const QStringList samplerOnly = {"sample", "root", "interpolation", "loop"};
    for (const QString &key : sampler ? synthOnly : samplerOnly)
        if (o.contains(key))
            return fail(errorOut, join(path, key),
                        sampler ? QStringLiteral("does not apply to a sample instrument")
                                : QStringLiteral("belongs to a sample instrument"));

    if (sampler) {
        if (!o.contains("sample")) return fail(errorOut, path, QStringLiteral("a sample instrument needs a 'sample' file"));
        if (!stringOf(o, "sample", path, &out->sample, errorOut)) return false;
        if (out->sample.isEmpty()) return fail(errorOut, path + QStringLiteral(".sample"), QStringLiteral("must not be empty"));
        if (o.contains("root")) {
            QString why;
            if (!parseMidiFromValue(o.value("root"), &spec.rootMidiNote, &why))
                return fail(errorOut, path + QStringLiteral(".root"), why);
        }
        if (o.contains("interpolation")) {
            QString text;
            if (!stringOf(o, "interpolation", path, &text, errorOut)) return false;
            using I = SampleVoice::Interpolation;
            if (text == QLatin1String("nearest"))       spec.sampler.interpolation = I::Nearest;
            else if (text == QLatin1String("linear"))   spec.sampler.interpolation = I::Linear;
            else if (text == QLatin1String("gaussian")) spec.sampler.interpolation = I::Gaussian;
            else return fail(errorOut, path + QStringLiteral(".interpolation"),
                             QStringLiteral("unknown interpolation '%1' (nearest, linear, gaussian)").arg(text));
        }
        if (o.contains("loop")) {
            const QString lp = path + QStringLiteral(".loop");
            const QJsonValue v = o.value("loop");
            if (v.isBool()) {
                spec.sampler.looping = v.toBool();
            } else if (v.isObject()) {
                const QJsonObject loop = v.toObject();
                spec.sampler.looping = true;
                if (!keysOnly(loop, {"start", "end"}, lp, errorOut)
                    || !numberOf(loop, "start", lp, 0.0, 1.0, &spec.sampler.loopStartFrac, errorOut)
                    || !numberOf(loop, "end", lp, 0.0, 1.0, &spec.sampler.loopEndFrac, errorOut))
                    return false;
                if (spec.sampler.loopStartFrac >= spec.sampler.loopEndFrac)
                    return fail(errorOut, lp, QStringLiteral("start must be before end"));
            } else {
                return fail(errorOut, lp, QStringLiteral("must be true, false or { \"start\", \"end\" }"));
            }
        }
    }

    if (o.contains("envelope")) {
        const QString ep = path + QStringLiteral(".envelope");
        QJsonObject env;
        double *attack  = sampler ? &spec.sampler.attack  : &spec.synth.attack;
        double *decay   = sampler ? &spec.sampler.decay   : &spec.synth.decay;
        double *sustain = sampler ? &spec.sampler.sustain : &spec.synth.sustain;
        double *release = sampler ? &spec.sampler.release : &spec.synth.release;
        if (!objectOf(o, "envelope", path, &env, errorOut)
            || !keysOnly(env, {"attack", "decay", "sustain", "release"}, ep, errorOut)
            || !msOf(env, "attack", ep, P::Attack, attack, errorOut)
            || !msOf(env, "decay", ep, P::Decay, decay, errorOut)
            || !paramOf(env, "sustain", ep, P::Sustain, sustain, errorOut)
            || !msOf(env, "release", ep, P::Release, release, errorOut))
            return false;
    }

    if (!sampler) {
        OscillatorVoice::Patch &patch = spec.synth;
        if (o.contains("pulseWidth") && patch.waveform != W::Square)
            return fail(errorOut, path + QStringLiteral(".pulseWidth"), QStringLiteral("applies to a square instrument only"));
        if (!paramOf(o, "pulseWidth", path, P::PulseWidth, &patch.pulseWidth, errorOut)) return false;

        if (o.contains("pitch")) {
            const QString pp = path + QStringLiteral(".pitch");
            QJsonObject pitch;
            if (!objectOf(o, "pitch", path, &pitch, errorOut)
                || !keysOnly(pitch, {"start", "end", "time"}, pp, errorOut)
                || !paramOf(pitch, "start", pp, P::PitchStart, &patch.pitchStart, errorOut)
                || !paramOf(pitch, "end", pp, P::PitchEnd, &patch.pitchEnd, errorOut)
                || !msOf(pitch, "time", pp, P::PitchTime, &patch.pitchTime, errorOut))
                return false;
        }
        if (o.contains("filter")) {
            const QString fp = path + QStringLiteral(".filter");
            QJsonObject filter;
            QString type;
            if (!objectOf(o, "filter", path, &filter, errorOut)
                || !keysOnly(filter, {"type", "cutoff", "resonance", "attack", "decay", "sustain",
                                      "release", "amount"}, fp, errorOut))
                return false;
            if (!filter.contains("type")) return fail(errorOut, fp, QStringLiteral("needs a 'type'"));
            if (!stringOf(filter, "type", fp, &type, errorOut)) return false;
            using F = OscillatorVoice::FilterType;
            if (type == QLatin1String("lowpass"))       patch.filterType = F::LowPass;
            else if (type == QLatin1String("highpass")) patch.filterType = F::HighPass;
            else if (type == QLatin1String("bandpass")) patch.filterType = F::BandPass;
            else return fail(errorOut, fp + QStringLiteral(".type"),
                             QStringLiteral("unknown type '%1' (lowpass, highpass, bandpass)").arg(type));
            if (!paramOf(filter, "cutoff", fp, P::Cutoff, &patch.cutoff, errorOut)
                || !paramOf(filter, "resonance", fp, P::Resonance, &patch.resonance, errorOut)
                || !msOf(filter, "attack", fp, P::FilterAttack, &patch.filterAttack, errorOut)
                || !msOf(filter, "decay", fp, P::FilterDecay, &patch.filterDecay, errorOut)
                || !paramOf(filter, "sustain", fp, P::FilterSustain, &patch.filterSustain, errorOut)
                || !msOf(filter, "release", fp, P::FilterRelease, &patch.filterRelease, errorOut)
                || !paramOf(filter, "amount", fp, P::FilterAmount, &patch.filterEnvAmount, errorOut))
                return false;
        }
        if (o.contains("lfo")) {
            const QString lp = path + QStringLiteral(".lfo");
            QJsonObject lfo;
            QString target;
            if (!objectOf(o, "lfo", path, &lfo, errorOut)
                || !keysOnly(lfo, {"target", "rate", "depth"}, lp, errorOut))
                return false;
            if (!lfo.contains("target")) return fail(errorOut, lp, QStringLiteral("needs a 'target'"));
            if (!stringOf(lfo, "target", lp, &target, errorOut)) return false;
            if (target == QLatin1String("pitch"))       patch.lfoTarget = 1;
            else if (target == QLatin1String("volume")) patch.lfoTarget = 2;
            else return fail(errorOut, lp + QStringLiteral(".target"),
                             QStringLiteral("unknown target '%1' (pitch, volume)").arg(target));
            if (!paramOf(lfo, "rate", lp, P::LfoRate, &patch.lfoRate, errorOut)
                || !paramOf(lfo, "depth", lp, P::LfoDepth, &patch.lfoDepth, errorOut))
                return false;
            if (patch.lfoTarget == 2 && patch.lfoDepth > 1.0)
                return fail(errorOut, lp + QStringLiteral(".depth"), QStringLiteral("a volume lfo reaches at most 1"));
        }
    }

    // An instrument is at most as loud as its notes: 0 dB is unity.
    double gainDb = 0.0, pan = 0.0, voices = 0.0;
    if (!numberOf(o, "gain", path, -96.0, 0.0, &gainDb, errorOut)
        || !paramOf(o, "pan", path, P::Pan, &pan, errorOut)
        || !numberOf(o, "maxVoices", path, 0.0, 64.0, &voices, errorOut))
        return false;
    if (voices != std::floor(voices))
        return fail(errorOut, path + QStringLiteral(".maxVoices"), QStringLiteral("must be an integer"));
    spec.gain = static_cast<float>(std::pow(10.0, gainDb / 20.0));
    spec.pan = static_cast<float>(pan);
    spec.maxVoices = static_cast<int>(voices);
    if (o.contains("bus")) {
        QString bus;
        if (!stringOf(o, "bus", path, &bus, errorOut)) return false;
        if (bus == QLatin1String("sfx"))        spec.bus = Bus::Sfx;
        else if (bus == QLatin1String("music")) spec.bus = Bus::Music;
        else if (bus == QLatin1String("voice")) spec.bus = Bus::Voice;
        else return fail(errorOut, path + QStringLiteral(".bus"),
                         QStringLiteral("unknown bus '%1' (sfx, music, voice)").arg(bus));
    }
    return true;
}

static bool parseInstruments(const QJsonObject &root, SongModel &model, QString *errorOut)
{
    if (!root.contains("instruments") || !root.value("instruments").isObject())
        return fail(errorOut, QStringLiteral("instruments"),
                    QStringLiteral("a version 2 song defines its instruments in an object"));
    const QJsonObject all = root.value("instruments").toObject();
    for (auto it = all.begin(); it != all.end(); ++it) {
        const QString path = QStringLiteral("instruments.") + it.key();
        if (!it.value().isObject()) return fail(errorOut, path, QStringLiteral("must be an object"));
        SongInstrument inst;
        if (!parseInstrument(it.value().toObject(), path, &inst, errorOut)) return false;
        model.instruments.insert(it.key(), inst);
    }
    return true;
}

// Segments, start, layers, transitions and stingers: everything that
// needs the patterns parsed first.
static bool parseStructure(const QJsonObject &root, SongModel &model, QString *errorOut)
{
    double bpb = model.beatsPerBar;
    if (!numberOf(root, "beatsPerBar", QString(), 1.0, 32.0, &bpb, errorOut)) return false;
    if (bpb != std::floor(bpb)) return fail(errorOut, QStringLiteral("beatsPerBar"), QStringLiteral("must be an integer"));
    model.beatsPerBar = static_cast<int>(bpb);

    if (root.contains("segments")) {
        if (!root.value("segments").isObject() || root.value("segments").toObject().isEmpty())
            return fail(errorOut, QStringLiteral("segments"), QStringLiteral("must be a non-empty object"));
        const QJsonObject all = root.value("segments").toObject();
        for (auto it = all.begin(); it != all.end(); ++it) {
            const QString path = QStringLiteral("segments.") + it.key();
            if (!it.value().isObject()) return fail(errorOut, path, QStringLiteral("must be an object"));
            const QJsonObject so = it.value().toObject();
            if (!keysOnly(so, {"sections", "exits", "next"}, path, errorOut)) return false;
            Segment seg;
            const QJsonValue secs = so.value("sections");
            if (!secs.isArray() || secs.toArray().isEmpty())
                return fail(errorOut, path + QStringLiteral(".sections"), QStringLiteral("must be a non-empty array"));
            if (!parseSections(secs.toArray(), model, path + QStringLiteral(".sections"), &seg.sections, errorOut))
                return false;
            seg.next = it.key();
            if (so.contains("next") && !stringOf(so, "next", path, &seg.next, errorOut)) return false;
            model.segments.insert(it.key(), seg);
            if (so.contains("exits")) {
                const QString ep = path + QStringLiteral(".exits");
                if (!so.value("exits").isArray()) return fail(errorOut, ep, QStringLiteral("must be an array of beats"));
                const double length = segmentBeats(model, it.key());
                for (const QJsonValue &v : so.value("exits").toArray()) {
                    const double b = v.toDouble(-1.0);
                    if (!v.isDouble() || b < 0.0 || b >= length)
                        return fail(errorOut, ep, QStringLiteral("every exit is a beat in 0..%1 (the segment's length)")
                                                      .arg(num(length)));
                    if (!model.segments[it.key()].exits.isEmpty() && b <= model.segments[it.key()].exits.last())
                        return fail(errorOut, ep, QStringLiteral("exits must ascend"));
                    model.segments[it.key()].exits.append(b);
                }
            }
        }
        for (auto it = model.segments.begin(); it != model.segments.end(); ++it)
            if (!model.segments.contains(it->next))
                return fail(errorOut, QStringLiteral("segments.%1.next").arg(it.key()),
                            QStringLiteral("unknown segment '%1'").arg(it->next));
        if (root.contains("start")) {
            if (!stringOf(root, "start", QString(), &model.start, errorOut)) return false;
            if (!model.segments.contains(model.start))
                return fail(errorOut, QStringLiteral("start"), QStringLiteral("unknown segment '%1'").arg(model.start));
        } else if (model.segments.size() == 1) {
            model.start = model.segments.firstKey();
        } else {
            return fail(errorOut, QStringLiteral("start"), QStringLiteral("a song of several segments names the one it starts in"));
        }
    } else {
        if (root.contains("start"))
            return fail(errorOut, QStringLiteral("start"), QStringLiteral("names a segment, and the song has no 'segments'"));
        // The sections are the one segment, and the song ends after it.
        Segment main;
        main.sections = model.sections;
        model.segments.insert(QStringLiteral("main"), main);
        model.start = QStringLiteral("main");
    }

    if (root.contains("layers")) {
        if (!root.value("layers").isObject()) return fail(errorOut, QStringLiteral("layers"), QStringLiteral("must be an object"));
        const QJsonObject all = root.value("layers").toObject();
        QMap<QString, QString> layerOfTrack;
        for (auto it = all.begin(); it != all.end(); ++it) {
            const QString path = QStringLiteral("layers.") + it.key();
            if (!it.value().isObject()) return fail(errorOut, path, QStringLiteral("must be an object"));
            const QJsonObject lo = it.value().toObject();
            if (!keysOnly(lo, {"tracks", "intensity", "fade"}, path, errorOut)) return false;
            Layer layer;
            const QJsonArray tracks = lo.value("tracks").toArray();
            if (!lo.value("tracks").isArray() || tracks.isEmpty())
                return fail(errorOut, path + QStringLiteral(".tracks"), QStringLiteral("must be a non-empty array of track names"));
            for (const QJsonValue &t : tracks) {
                const QString name = t.toString();
                if (!model.tracks.contains(name))
                    return fail(errorOut, path + QStringLiteral(".tracks"), QStringLiteral("unknown track '%1'").arg(name));
                if (layerOfTrack.contains(name))
                    return fail(errorOut, path + QStringLiteral(".tracks"),
                                QStringLiteral("track '%1' is already in layer '%2'").arg(name, layerOfTrack.value(name)));
                layerOfTrack.insert(name, it.key());
                layer.tracks << name;
            }
            const QString ip = path + QStringLiteral(".intensity");
            const QJsonValue iv = lo.value("intensity");
            const QJsonArray range = iv.toArray();
            if (iv.isDouble()) {
                layer.low = layer.high = iv.toDouble();
            } else if (iv.isArray() && range.size() == 2 && range.at(0).isDouble() && range.at(1).isDouble()) {
                layer.low = range.at(0).toDouble();
                layer.high = range.at(1).toDouble();
            } else {
                return fail(errorOut, ip, QStringLiteral("must be a number or [low, high]: silent at low, full at high"));
            }
            if (layer.low < 0.0 || layer.high > 1.0 || layer.low > layer.high)
                return fail(errorOut, ip, QStringLiteral("must lie in 0..1, low not above high"));
            if (!numberOf(lo, "fade", path, 0.0, 1024.0, &layer.fade, errorOut)) return false;
            model.layers.insert(it.key(), layer);
        }
    }

    if (root.contains("stingers")) {
        if (!root.value("stingers").isObject()) return fail(errorOut, QStringLiteral("stingers"), QStringLiteral("must be an object"));
        const QJsonObject all = root.value("stingers").toObject();
        for (auto it = all.begin(); it != all.end(); ++it) {
            const QString path = QStringLiteral("stingers.") + it.key();
            if (!it.value().isObject()) return fail(errorOut, path, QStringLiteral("must be an object"));
            const QJsonObject so = it.value().toObject();
            Stinger st;
            if (!keysOnly(so, {"pattern", "sync"}, path, errorOut)
                || !stringOf(so, "pattern", path, &st.pattern, errorOut)
                || !syncOf(so, path, &st.sync, errorOut))
                return false;
            if (!model.patterns.contains(st.pattern))
                return fail(errorOut, path + QStringLiteral(".pattern"), QStringLiteral("unknown pattern '%1'").arg(st.pattern));
            model.stingers.insert(it.key(), st);
        }
    }

    if (root.contains("transitions")) {
        if (!root.value("transitions").isArray()) return fail(errorOut, QStringLiteral("transitions"), QStringLiteral("must be an array"));
        const QJsonArray all = root.value("transitions").toArray();
        for (int i = 0; i < all.size(); ++i) {
            const QString path = QStringLiteral("transitions[%1]").arg(i);
            if (!all.at(i).isObject()) return fail(errorOut, path, QStringLiteral("must be an object"));
            const QJsonObject to = all.at(i).toObject();
            Transition tr;
            if (!keysOnly(to, {"from", "to", "sync", "stinger"}, path, errorOut)
                || (to.contains("from") && !stringOf(to, "from", path, &tr.from, errorOut))
                || (to.contains("to") && !stringOf(to, "to", path, &tr.to, errorOut))
                || (to.contains("stinger") && !stringOf(to, "stinger", path, &tr.stinger, errorOut))
                || !syncOf(to, path, &tr.sync, errorOut))
                return false;
            for (const auto &[key, name] : {std::pair{"from", tr.from}, std::pair{"to", tr.to}})
                if (!name.isEmpty() && !model.segments.contains(name))
                    return fail(errorOut, join(path, key), QStringLiteral("unknown segment '%1'").arg(name));
            if (!tr.stinger.isEmpty() && !model.stingers.contains(tr.stinger))
                return fail(errorOut, path + QStringLiteral(".stinger"), QStringLiteral("unknown stinger '%1'").arg(tr.stinger));
            model.transitions.append(tr);
        }
    }
    return true;
}

} // namespace

bool SongParser::parseNote(const QString &raw, int *midiOut, QString *errorOut)
{
    const QString s = raw.trimmed();
    static const QRegularExpression re(
        QStringLiteral("^([A-Ga-g])([#b]?)(-?\\d+)$"));
    const auto m = re.match(s);
    if (!m.hasMatch()) {
        if (errorOut) *errorOut = QStringLiteral("invalid note '%1'").arg(raw);
        return false;
    }
    const QChar letter = m.captured(1).toUpper().at(0);
    const QString acc  = m.captured(2);
    const int octave   = m.captured(3).toInt();

    int base = 0;
    switch (letter.toLatin1()) {
        case 'C': base = 0; break;
        case 'D': base = 2; break;
        case 'E': base = 4; break;
        case 'F': base = 5; break;
        case 'G': base = 7; break;
        case 'A': base = 9; break;
        case 'B': base = 11; break;
    }
    if (acc == "#") base += 1;
    else if (acc == "b") base -= 1;

    const int midi = (octave + 1) * 12 + base;
    if (midi < 0 || midi > 127) {
        if (errorOut) *errorOut = QStringLiteral("note '%1' out of MIDI range").arg(raw);
        return false;
    }
    *midiOut = midi;
    return true;
}

SongParseResult SongParser::parse(const QByteArray &json)
{
    SongParseResult r;
    QJsonParseError pe;
    const auto doc = QJsonDocument::fromJson(json, &pe);
    if (doc.isNull()) {
        r.error = QStringLiteral("JSON parse error: %1").arg(pe.errorString());
        return r;
    }
    if (!doc.isObject()) {
        r.error = QStringLiteral("top-level JSON must be an object");
        return r;
    }
    const QJsonObject root = doc.object();

    if (root.contains("version")) {
        const double v = root.value("version").toDouble(0.0);
        if (v != 1.0 && v != 2.0) {
            r.error = QStringLiteral("'version' must be 1 or 2");
            return r;
        }
        r.model.version = static_cast<int>(v);
    }

    static const QSet<QString> allowedTop = { "version", "tempo", "tracks", "patterns", "sections" };
    static const QSet<QString> allowedTopV2 = allowedTop + QSet<QString>{
        "beatsPerBar", "instruments", "segments", "start", "layers", "transitions", "stingers" };
    QString why;
    if (!requireKeysOnly(root, r.model.version >= 2 ? allowedTopV2 : allowedTop, &why)) {
        r.error = why;
        return r;
    }

    if (!root.contains("tempo") || !root.value("tempo").isDouble()) {
        r.error = QStringLiteral("'tempo' is required and must be a number");
        return r;
    }
    r.model.tempo = root.value("tempo").toDouble();
    if (r.model.tempo <= 0.0) {
        r.error = QStringLiteral("'tempo' must be > 0");
        return r;
    }

    // v2: the instruments, before the tracks that play them.
    if (r.model.version >= 2 && !parseInstruments(root, r.model, &r.error))
        return r;

    // tracks
    if (!root.contains("tracks") || !root.value("tracks").isObject()) {
        r.error = QStringLiteral("'tracks' is required and must be an object");
        return r;
    }
    const QJsonObject tracksObj = root.value("tracks").toObject();
    for (auto it = tracksObj.begin(); it != tracksObj.end(); ++it) {
        if (!it.value().isObject()) {
            r.error = QStringLiteral("track '%1' must be an object").arg(it.key());
            return r;
        }
        const QJsonObject tObj = it.value().toObject();
        static const QSet<QString> allowedTrack = { "instrument" };
        if (!requireKeysOnly(tObj, allowedTrack, &why)) {
            r.error = QStringLiteral("track '%1': %2").arg(it.key(), why);
            return r;
        }
        if (!tObj.contains("instrument") || !tObj.value("instrument").isString()) {
            r.error = QStringLiteral("track '%1' requires string 'instrument'").arg(it.key());
            return r;
        }
        if (r.model.version >= 2 && !r.model.instruments.contains(tObj.value("instrument").toString())) {
            r.error = QStringLiteral("track '%1' plays '%2', which 'instruments' does not define")
                          .arg(it.key(), tObj.value("instrument").toString());
            return r;
        }
        r.model.tracks.insert(it.key(),
                              TrackRef{ tObj.value("instrument").toString() });
    }
    if (r.model.tracks.isEmpty()) {
        r.error = QStringLiteral("'tracks' must declare at least one track");
        return r;
    }

    // patterns
    if (root.contains("patterns")) {
        if (!root.value("patterns").isObject()) {
            r.error = QStringLiteral("'patterns' must be an object");
            return r;
        }
        const QJsonObject patternsObj = root.value("patterns").toObject();
        for (auto it = patternsObj.begin(); it != patternsObj.end(); ++it) {
            if (!it.value().isObject()) {
                r.error = QStringLiteral("pattern '%1' must be an object").arg(it.key());
                return r;
            }
            Pattern p;
            if (!parsePattern(it.value().toObject(), &p, &why)) {
                r.error = why;
                return r;
            }
            // Ensure every track referenced in the pattern is declared.
            for (auto pit = p.trackEvents.begin(); pit != p.trackEvents.end(); ++pit) {
                if (!r.model.tracks.contains(pit.key())) {
                    r.error = QStringLiteral("pattern '%1' references unknown track '%2'")
                                  .arg(it.key(), pit.key());
                    return r;
                }
            }
            r.model.patterns.insert(it.key(), std::move(p));
        }
    }

    // sections
    if (root.contains("sections")) {
        if (r.model.version >= 2 && root.contains("segments")) {
            r.error = QStringLiteral("'sections' and 'segments' exclude each other: give each segment its sections");
            return r;
        }
        if (!root.value("sections").isArray()) {
            r.error = QStringLiteral("'sections' must be an array");
            return r;
        }
        if (!parseSections(root.value("sections").toArray(), r.model, QStringLiteral("section"),
                           &r.model.sections, &r.error))
            return r;
    } else if (!root.contains("segments")) {
        // Default order: one pass per declared pattern in insertion order.
        for (auto it = r.model.patterns.begin(); it != r.model.patterns.end(); ++it)
            r.model.sections.append(SectionRef{ it.key(), 1 });
    }

    if (r.model.version >= 2 && !parseStructure(root, r.model, &r.error))
        return r;

    r.ok = true;
    return r;
}

} // namespace clay::sound
