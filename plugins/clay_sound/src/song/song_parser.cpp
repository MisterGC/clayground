// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "song_parser.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QRegularExpression>
#include <QSet>

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

    static const QSet<QString> allowedTop = { "tempo", "tracks", "patterns", "sections" };
    QString why;
    if (!requireKeysOnly(root, allowedTop, &why)) {
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
        if (!root.value("sections").isArray()) {
            r.error = QStringLiteral("'sections' must be an array");
            return r;
        }
        const QJsonArray secs = root.value("sections").toArray();
        for (int i = 0; i < secs.size(); ++i) {
            if (!secs.at(i).isObject()) {
                r.error = QStringLiteral("section #%1 must be an object").arg(i);
                return r;
            }
            const QJsonObject so = secs.at(i).toObject();
            static const QSet<QString> allowedSec = { "pattern", "repeat" };
            if (!requireKeysOnly(so, allowedSec, &why)) {
                r.error = QStringLiteral("section #%1: %2").arg(i).arg(why);
                return r;
            }
            if (!so.contains("pattern") || !so.value("pattern").isString()) {
                r.error = QStringLiteral("section #%1 requires string 'pattern'").arg(i);
                return r;
            }
            SectionRef sr;
            sr.patternName = so.value("pattern").toString();
            sr.repeat = so.contains("repeat") ? so.value("repeat").toInt(1) : 1;
            if (sr.repeat < 1) sr.repeat = 1;
            if (!r.model.patterns.contains(sr.patternName)) {
                r.error = QStringLiteral("section #%1 references unknown pattern '%2'")
                              .arg(i).arg(sr.patternName);
                return r;
            }
            r.model.sections.append(sr);
        }
    } else {
        // Default order: one pass per declared pattern in insertion order.
        for (auto it = r.model.patterns.begin(); it != r.model.patterns.end(); ++it)
            r.model.sections.append(SectionRef{ it.key(), 1 });
    }

    r.ok = true;
    return r;
}

} // namespace clay::sound
