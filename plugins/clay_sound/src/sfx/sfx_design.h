// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Effect templates and design files, and the one compiler that turns a
// design file into the flat recipe (*.sfx.json) a game plays.
//
// A template is a recipe (version, name, variation, layers) plus its
// identity and its macros:
//
//   {
//     "version": 1,
//     "template": { "id": "wheel-detent", "version": 1 },
//     "name": "wheel-detent",
//     "layers": [ ... as in a recipe ... ],
//     "macros": [
//       { "id": "weight", "label": "Weight", "range": [0, 1], "default": 0.5,
//         "drives": [ { "path": "layers[body].freq", "from": 1108.73, "to": 554.37,
//                       "curve": "exp" } ] }
//     ]
//   }
//
// A design file names its template and that template's version, the
// macro values it sets, the overrides it writes on top and the paths
// the tools must leave alone:
//
//   {
//     "version": 1,
//     "name": "wheel-detent-heavy",
//     "template": { "id": "wheel-detent", "version": 1 },
//     "macros": { "weight": 0.9 },
//     "overrides": { "layers[glint].gain": -26 },
//     "locks": ["weight"]
//   }
//
// A path is `name`, `variation.seed`, `variation.pool`, or a layer field
// in the "vary" syntax behind a layer selector: `layers[1].gain`,
// `layers[body].envelope.decay` (an index, or the name of exactly one
// layer). Overrides take any layer field or group (`layers[0].filter`)
// and null removes one; two overrides may not write into each other. A
// macro drives numbers only, and a path is driven by one macro.
//
// Compiling: the template's recipe, the design's name, then its
// overrides, then every driven path the overrides leave alone - a macro
// at its default writes nothing, so it leaves the template's value as
// it is; any other value goes through the drive's curve, is rounded to
// six significant digits and clamped to what the recipe parser accepts
// there. Each drive is reported, clamped or not. The result is written
// by writeSfxRecipe() and checked by SfxParser: the same template and
// design give the same bytes.
//
// Unknown fields are rejected by name, as in a recipe; `meta` (any
// object, in a template and in a design) is the place for what tools
// keep beside the format: provenance, a licence, lineage.

#ifndef CLAY_SOUND_SFX_DESIGN_H
#define CLAY_SOUND_SFX_DESIGN_H

#include "sfx_recipe.h"

#include <QByteArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QMap>
#include <QString>
#include <QStringList>
#include <QVector>

namespace clay::sound {

enum class SfxCurve {
    Lin,    // from + (to - from) * t
    Exp,    // from * (to / from)^t; from and to non-zero, of one sign
    Db      // 10^(dB / 20), dB = from + (to - from) * t: a level in 0..1 moved in decibels
};

struct SfxDrive
{
    QString  path;              // as written
    int      layer = -1;        // the template layer it resolves to
    SfxParam param = SfxParam::Freq;
    double   from = 0.0;        // at the macro's range min
    double   to = 0.0;          // at its range max
    SfxCurve curve = SfxCurve::Lin;
};

struct SfxMacro
{
    QString id;
    QString label;              // the id when the template gives none
    double  min = 0.0;
    double  max = 1.0;
    double  def = 0.0;
    QVector<SfxDrive> drives;
};

struct SfxTemplate
{
    QString     id;
    int         version = 0;
    QJsonObject recipe;         // version, name, variation, layers as written
    SfxRecipe   parsed;         // the recipe at the default macro values
    QVector<SfxMacro> macros;

    int macroIndex(const QString &id) const;
};

struct SfxDesign
{
    QString name;               // empty: the template's
    QString templateId;
    int     templateVersion = 0;
    QMap<QString, double>      macros;      // id -> value; an absent one is at its default
    QMap<QString, QJsonValue>  overrides;   // path -> value; null removes the field
    QStringList locks;          // macro ids and paths
};

// What one drive did to the compiled recipe.
struct SfxDriveReport
{
    QString macro;
    QString path;               // as written in the template
    double  macroValue = 0.0;
    double  value = 0.0;        // the curve's value, rounded; the template's at the default
    double  written = 0.0;      // what the recipe holds: value clamped, or the override
    double  min = 0.0;          // the range it was clamped to
    double  max = 0.0;
    bool    clamped = false;    // value left [min, max] and was moved to its edge
    bool    overridden = false; // an override wrote the path instead
};

struct SfxTemplateParseResult
{
    SfxTemplate tpl;
    bool    ok = false;
    QString error;              // empty when ok; starts with the field's path
};

struct SfxDesignParseResult
{
    SfxDesign design;
    bool    ok = false;
    QString error;
};

struct SfxCompileResult
{
    bool       ok = false;
    QString    error;
    QByteArray json;            // the recipe as writeSfxRecipe() writes it
    SfxRecipe  recipe;          // json as SfxParser reads it
    QVector<SfxDriveReport> drives;     // every drive of every macro, in template order

    // "<path>: macro '<id>' drives <value>, clamped to <written> (<min>..<max>)"
    // for each clamped drive.
    QStringList clampMessages() const;
};

class SfxDesignCompiler
{
public:
    static SfxTemplateParseResult parseTemplate(const QByteArray &json);
    // The design alone: its fields and its paths' syntax. What it names
    // is checked against the template by compile().
    static SfxDesignParseResult parseDesign(const QByteArray &json);

    static SfxCompileResult compile(const SfxDesign &design, const SfxTemplate &tpl);
    static SfxCompileResult compile(const QByteArray &design, const QByteArray &tpl);
};

} // namespace clay::sound

#endif // CLAY_SOUND_SFX_DESIGN_H
