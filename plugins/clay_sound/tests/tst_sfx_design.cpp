// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Effect design files (#446): a template and a design file compile to a
// recipe through the engine library alone. The parsers reject an unknown
// field by name; the demo design compiles to the committed recipe byte
// for byte, every time; macros at their defaults give the template's
// layers exactly, the same samples included; an override wins over the
// macro that drives its path; a driven value outside what the recipe
// accepts is clamped and reported; and the three curves give their
// values.

#include "offline/sound_files.h"
#include "sfx/sfx_design.h"
#include "sfx/sfx_parser.h"
#include "sfx/sfx_render.h"
#include "sfx/sfx_writer.h"

#include <QtTest/QtTest>
#include <QFile>
#include <QJsonDocument>
#include <QTemporaryDir>

namespace cs = clay::sound;
using P = cs::SfxParam;

static const QString kDir = QStringLiteral(CLAY_SOUND_DEMO_SFX_DIR);

static QByteArray readFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.readAll();
}

static QByteArray demoTemplate() { return readFile(kDir + "/wheel-detent.sfx.template.json"); }

// A one-layer template, its macro "m" (0..1, default 0.5) driving the
// given drives; `layer` and `extra` go into the layer object.
static QByteArray tinyTemplate(const QByteArray &drives, const QByteArray &layer = "\"gain\": -6",
                               const QByteArray &extraMacroFields = {})
{
    return "{ \"template\": { \"id\": \"tiny\", \"version\": 1 },"
           "  \"layers\": [ { \"name\": \"tone\", \"source\": \"sine\", \"length\": 50, " + layer + " } ],"
           "  \"macros\": [ { \"id\": \"m\", \"range\": [0, 1], \"default\": 0.5, " + extraMacroFields +
           "                  \"drives\": [" + drives + "] } ] }";
}

static QByteArray tinyDesign(const QByteArray &fields)
{
    return "{ \"template\": { \"id\": \"tiny\", \"version\": 1 }" + (fields.isEmpty() ? "" : ", " + fields) + " }";
}

static void compareLayers(const cs::SfxRecipe &a, const cs::SfxRecipe &b)
{
    QCOMPARE(a.layers.size(), b.layers.size());
    QCOMPARE(a.seed, b.seed);
    QCOMPARE(a.pool, b.pool);
    for (int i = 0; i < a.layers.size(); ++i) {
        const auto &x = a.layers[i];
        const auto &y = b.layers[i];
        QCOMPARE(x.name, y.name);
        QCOMPARE(int(x.source), int(y.source));
        QCOMPARE(int(x.filterType), int(y.filterType));
        QCOMPARE(x.lfoTarget, y.lfoTarget);
        for (int k = 0; k < cs::kSfxParamCount; ++k) {
            QCOMPARE(x.value[k], y.value[k]);   // exactly: no tolerance
            QCOMPARE(x.vary[k].on, y.vary[k].on);
            QCOMPARE(x.vary[k].lo, y.vary[k].lo);
            QCOMPARE(x.vary[k].hi, y.vary[k].hi);
        }
    }
}

static const cs::SfxDriveReport *report(const cs::SfxCompileResult &r, const QString &path)
{
    for (const auto &d : r.drives)
        if (d.path == path) return &d;
    return nullptr;
}

class TestSfxDesign : public QObject
{
    Q_OBJECT

private slots:
    void writerKeepsTheRecipe();
    void templateRejectsAnUnknownFieldByName_data();
    void templateRejectsAnUnknownFieldByName();
    void designRejectsAnUnknownFieldByName_data();
    void designRejectsAnUnknownFieldByName();
    void demoDesignCompilesToTheCommittedRecipe();
    void macrosAtTheirDefaultsGiveTheTemplatesLayers();
    void anOverrideWinsOverTheMacro();
    void aDrivenValueOutsideItsRangeIsClampedAndReported();
    void curves();
    void templateRejects_data();
    void templateRejects();
    void designRejects_data();
    void designRejects();
    void aNullOverrideRemovesTheField();
};

// The writer changes the bytes, not the recipe: the demo recipe reads
// back as it was, keys in the README's order, and a second write is
// the first.
void TestSfxDesign::writerKeepsTheRecipe()
{
    const QByteArray original = readFile(kDir + "/wheel-detent.sfx.json");
    const auto before = cs::SfxParser::parse(original);
    QVERIFY2(before.ok, qPrintable(before.error));

    const QByteArray written = cs::writeSfxRecipe(QJsonDocument::fromJson(original).object());
    const auto after = cs::SfxParser::parse(written);
    QVERIFY2(after.ok, qPrintable(after.error));
    compareLayers(before.recipe, after.recipe);
    QVERIFY(written.startsWith("{\n  \"version\": 1,\n  \"name\": \"wheel-detent\",\n  \"variation\": "));
    QVERIFY(written.contains("\"freq\": 783.99,"));
    QVERIFY(written.contains("\"envelope\": { \"attack\": 0.5, \"decay\": 55, \"sustain\": 0, \"release\": 20 }"));
    QCOMPARE(cs::writeSfxRecipe(QJsonDocument::fromJson(written).object()), written);
}

void TestSfxDesign::templateRejectsAnUnknownFieldByName_data()
{
    QTest::addColumn<QByteArray>("from");
    QTest::addColumn<QByteArray>("to");
    QTest::addColumn<QString>("error");
    QTest::newRow("top") << QByteArray("\"macros\": [") << QByteArray("\"makros\": [")
                         << "unknown field 'makros'";
    QTest::newRow("template ref") << QByteArray("\"id\": \"wheel-detent\"") << QByteArray("\"name\": \"wheel-detent\"")
                                  << "template: unknown field 'name'";
    QTest::newRow("macro") << QByteArray("\"label\": \"Weight\"") << QByteArray("\"lable\": \"Weight\"")
                           << "macros[0]: unknown field 'lable'";
    QTest::newRow("drive") << QByteArray("\"to\": 554.37") << QByteArray("\"too\": 554.37")
                           << "macros[0].drives[0]: unknown field 'too'";
    QTest::newRow("drive path") << QByteArray("layers[glint].envelope.decay") << QByteArray("layers[glint].envelope.decya")
                                << "macros[2].drives[1].path: 'layers[glint].envelope.decya' is not a layer number";
    QTest::newRow("layer") << QByteArray("\"name\": \"tick\", ") << QByteArray("\"nmae\": \"tick\", ")
                           << "layers[0]: unknown field 'nmae'";
}

void TestSfxDesign::templateRejectsAnUnknownFieldByName()
{
    QFETCH(QByteArray, from);
    QFETCH(QByteArray, to);
    QFETCH(QString, error);
    QByteArray json = demoTemplate();
    QVERIFY(json.contains(from));
    json.replace(json.indexOf(from), from.size(), to);
    const auto res = cs::SfxDesignCompiler::parseTemplate(json);
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
}

void TestSfxDesign::designRejectsAnUnknownFieldByName_data()
{
    QTest::addColumn<QByteArray>("design");
    QTest::addColumn<QString>("error");
    QTest::newRow("top") << tinyDesign("\"overides\": {}") << "unknown field 'overides'";
    QTest::newRow("template ref") << QByteArray("{ \"template\": { \"id\": \"tiny\", \"version\": 1, \"rev\": 2 } }")
                                  << "template: unknown field 'rev'";
    QTest::newRow("override path") << tinyDesign("\"overrides\": { \"layers[0].gian\": -3 }")
                                   << "overrides: unknown path 'layers[0].gian'";
    QTest::newRow("override group field") << tinyDesign("\"overrides\": { \"layers[0].envelope.decya\": 3 }")
                                          << "overrides: unknown path 'layers[0].envelope.decya'";
    QTest::newRow("override vary field") << tinyDesign("\"overrides\": { \"layers[0].vary.gian\": [0, 1] }")
                                         << "overrides: unknown path 'layers[0].vary.gian'";
}

void TestSfxDesign::designRejectsAnUnknownFieldByName()
{
    QFETCH(QByteArray, design);
    QFETCH(QString, error);
    const auto res = cs::SfxDesignCompiler::parseDesign(design);
    QVERIFY(!res.ok);
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
}

// The demo design against the demo template is the committed recipe,
// byte for byte, through the file helper and through compile() alike,
// and a second compile is the first.
void TestSfxDesign::demoDesignCompilesToTheCommittedRecipe()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    const QString out = tmp.filePath("wheel-detent-heavy.sfx.json");
    cs::SfxCompileResult res;
    std::string why;
    QVERIFY2(cs::compileDesignFile((kDir + "/wheel-detent-heavy.sfx.design.json").toStdString(),
                                   (kDir + "/wheel-detent.sfx.template.json").toStdString(),
                                   out.toStdString(), &res, &why),
             why.c_str());

    const QByteArray committed = readFile(kDir + "/wheel-detent-heavy.sfx.json");
    if (readFile(out) != committed)
        qWarning().noquote() << "compiled (left in" << tmp.path() << "):\n" << readFile(out);
    if (readFile(out) != committed) tmp.setAutoRemove(false);
    QCOMPARE(readFile(out), committed);
    QCOMPARE(res.json, committed);

    const QByteArray design = readFile(kDir + "/wheel-detent-heavy.sfx.design.json");
    for (int i = 0; i < 3; ++i) {
        const auto again = cs::SfxDesignCompiler::compile(design, demoTemplate());
        QVERIFY2(again.ok, qPrintable(again.error));
        QCOMPARE(again.json, committed);
    }
    QVERIFY(res.clampMessages().isEmpty());
    QCOMPARE(res.drives.size(), 7);
}

// No macro set, or every macro set to its default, compiles to the
// template's layers exactly - the demo recipe the template was made of,
// the same values, the same bytes as its recipe written alone, and the
// same samples on a render.
void TestSfxDesign::macrosAtTheirDefaultsGiveTheTemplatesLayers()
{
    const QByteArray ref = "\"template\": { \"id\": \"wheel-detent\", \"version\": 1 }";
    const auto none = cs::SfxDesignCompiler::compile("{ " + ref + " }", demoTemplate());
    QVERIFY2(none.ok, qPrintable(none.error));
    const auto defaults = cs::SfxDesignCompiler::compile(
        "{ " + ref + ", \"macros\": { \"weight\": 0.5, \"click\": 0.5, \"ring\": 0.5 } }", demoTemplate());
    QVERIFY2(defaults.ok, qPrintable(defaults.error));
    QCOMPARE(defaults.json, none.json);

    const auto tpl = cs::SfxDesignCompiler::parseTemplate(demoTemplate());
    QVERIFY2(tpl.ok, qPrintable(tpl.error));
    QCOMPARE(none.json, cs::writeSfxRecipe(tpl.tpl.recipe));
    compareLayers(none.recipe, tpl.tpl.parsed);

    const auto demo = cs::SfxParser::parse(readFile(kDir + "/wheel-detent.sfx.json"));
    QVERIFY2(demo.ok, qPrintable(demo.error));
    compareLayers(none.recipe, demo.recipe);

    for (const auto &d : none.drives) {
        QVERIFY(!d.clamped);
        QVERIFY(!d.overridden);
        QCOMPARE(d.written, d.value);
    }
    QCOMPARE(report(none, "layers[body].freq")->written, 783.99);

    for (uint32_t seed : {1u, 2u, 77u}) {
        const auto a = cs::renderRecipe(none.recipe, {}, seed, 1.0f, 1.0f, 0.0f, cs::kSampleRate, false);
        const auto b = cs::renderRecipe(demo.recipe, {}, seed, 1.0f, 1.0f, 0.0f, cs::kSampleRate, false);
        QVERIFY(!a.empty());
        QVERIFY(a == b);
    }
}

// The demo design sets click to 0.8, which drives the glint's gain, and
// overrides that gain to -26: the override is what the recipe holds. A
// group override (the whole envelope) wins over a macro driving a field
// inside it the same way.
void TestSfxDesign::anOverrideWinsOverTheMacro()
{
    const auto res = cs::SfxDesignCompiler::compile(readFile(kDir + "/wheel-detent-heavy.sfx.design.json"),
                                                    demoTemplate());
    QVERIFY2(res.ok, qPrintable(res.error));
    QCOMPARE(res.recipe.layers[2].get(P::Gain), -26.0);
    const auto *glint = report(res, "layers[glint].gain");
    QVERIFY(glint);
    QVERIFY(glint->overridden);
    QCOMPARE(glint->written, -26.0);
    QCOMPARE(glint->value, -18.34);            // what click 0.8 would have written
    const auto *tick = report(res, "layers[tick].gain");
    QVERIFY(!tick->overridden);
    QCOMPARE(res.recipe.layers[0].get(P::Gain), -6.86);

    const QByteArray envelope =
        "{ \"template\": { \"id\": \"wheel-detent\", \"version\": 1 }, \"macros\": { \"ring\": 1 },"
        "  \"overrides\": { \"layers[1].envelope\": { \"attack\": 2, \"decay\": 300, \"sustain\": 0, \"release\": 20 } } }";
    const auto group = cs::SfxDesignCompiler::compile(envelope, demoTemplate());
    QVERIFY2(group.ok, qPrintable(group.error));
    QCOMPARE(group.recipe.layers[1].get(P::Decay), 300.0);
    QCOMPARE(group.recipe.layers[1].get(P::Attack), 2.0);
    QVERIFY(report(group, "layers[body].envelope.decay")->overridden);
    QCOMPARE(group.recipe.layers[2].get(P::Decay), 140.0);    // ring 1 still drives the glint
}

// gain is -96..12 dB: a drive to +30 is clamped to 12, and with a vary
// range reaching 3 dB above the value, to 9. A volume lfo's depth stops
// at 1. Each clamp is reported with what the curve gave.
void TestSfxDesign::aDrivenValueOutsideItsRangeIsClampedAndReported()
{
    const auto gain = cs::SfxDesignCompiler::compile(
        tinyDesign("\"macros\": { \"m\": 1 }"),
        tinyTemplate("{ \"path\": \"layers[tone].gain\", \"from\": -42, \"to\": 30 }"));
    QVERIFY2(gain.ok, qPrintable(gain.error));
    QCOMPARE(gain.recipe.layers[0].get(P::Gain), 12.0);
    const auto *r = report(gain, "layers[tone].gain");
    QVERIFY(r->clamped);
    QCOMPARE(r->value, 30.0);
    QCOMPARE(r->written, 12.0);
    QCOMPARE(r->min, -96.0);
    QCOMPARE(r->max, 12.0);
    QCOMPARE(gain.clampMessages(), QStringList{"layers[tone].gain: macro 'm' drives 30, clamped to 12 (-96..12)"});

    const auto varied = cs::SfxDesignCompiler::compile(
        tinyDesign("\"macros\": { \"m\": 1 }"),
        tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -42, \"to\": 30 }",
                     "\"gain\": -6, \"vary\": { \"gain\": [-2, 3] }"));
    QVERIFY2(varied.ok, qPrintable(varied.error));
    QCOMPARE(varied.recipe.layers[0].get(P::Gain), 9.0);
    QCOMPARE(varied.drives[0].max, 9.0);

    const auto low = cs::SfxDesignCompiler::compile(
        tinyDesign("\"macros\": { \"m\": 0 }"),
        tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -150, \"to\": 138 }"));
    QVERIFY2(low.ok, qPrintable(low.error));
    QCOMPARE(low.recipe.layers[0].get(P::Gain), -96.0);
    QVERIFY(low.drives[0].clamped);

    const auto lfo = cs::SfxDesignCompiler::compile(
        tinyDesign("\"macros\": { \"m\": 1 }"),
        tinyTemplate("{ \"path\": \"layers[0].lfo.depth\", \"from\": 0, \"to\": 1.6 }",
                     "\"lfo\": { \"target\": \"volume\", \"rate\": 6, \"depth\": 0.8 }"));
    QVERIFY2(lfo.ok, qPrintable(lfo.error));
    QCOMPARE(lfo.recipe.layers[0].get(P::LfoDepth), 1.0);
    QVERIFY(lfo.drives[0].clamped);

    // Inside the range nothing is clamped and nothing is reported.
    const auto inside = cs::SfxDesignCompiler::compile(
        tinyDesign("\"macros\": { \"m\": 0.75 }"),
        tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -42, \"to\": 30 }"));
    QVERIFY(inside.ok);
    QCOMPARE(inside.recipe.layers[0].get(P::Gain), 12.0);
    QVERIFY(!inside.drives[0].clamped);
    QVERIFY(inside.clampMessages().isEmpty());
}

// lin, exp and db at a quarter of the range, rounded to six digits.
void TestSfxDesign::curves()
{
    struct Case { QByteArray drive, layer; P param; double expected; };
    const Case cases[] = {
        {"{ \"path\": \"layers[0].gain\", \"from\": -10, \"to\": -2, \"curve\": \"lin\" }",
         "\"gain\": -6", P::Gain, -8.0},
        {"{ \"path\": \"layers[0].freq\", \"from\": 100, \"to\": 10000, \"curve\": \"exp\" }",
         "\"freq\": 1000", P::Freq, 316.228},
        {"{ \"path\": \"layers[0].envelope.sustain\", \"from\": -40, \"to\": 0, \"curve\": \"db\" }",
         "\"envelope\": { \"sustain\": 0.1 }", P::Sustain, 0.0316228},
    };
    for (const auto &c : cases) {
        // A range of 0..1 with the default in the middle: a quarter is 0.25.
        const auto res = cs::SfxDesignCompiler::compile(
            tinyDesign("\"macros\": { \"m\": 0.25 }"),
            tinyTemplate(c.drive, c.layer));
        QVERIFY2(res.ok, qPrintable(res.error + " in " + c.drive));
        QCOMPARE(res.recipe.layers[0].get(c.param), c.expected);
    }
}

void TestSfxDesign::templateRejects_data()
{
    QTest::addColumn<QByteArray>("tpl");
    QTest::addColumn<QString>("error");
    QTest::newRow("default off the curve")
        << tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -12, \"to\": 6 }")
        << "macros[0].drives[0]: at the macro's default 0.5 it gives -3, but layers[0].gain is -6";
    QTest::newRow("a path driven twice")
        << tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -12, \"to\": 0 },"
                        "{ \"path\": \"layers[tone].gain\", \"from\": -9, \"to\": -3 }")
        << "macros[0].drives[1].path: layers[0].gain is driven by macro 'm' already";
    QTest::newRow("a field the layer has no use for")
        << tinyTemplate("{ \"path\": \"layers[0].filter.cutoff\", \"from\": 500, \"to\": 2000, \"curve\": \"exp\" }")
        << "macros[0].drives[0].path: layers[0].filter: needs a 'type'";
    QTest::newRow("exp through zero")
        << tinyTemplate("{ \"path\": \"layers[0].pan\", \"from\": -1, \"to\": 1, \"curve\": \"exp\" }")
        << "macros[0].drives[0]: an exp curve needs 'from' and 'to' non-zero and of one sign";
    QTest::newRow("db on a value in dB")
        << tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -12, \"to\": 0, \"curve\": \"db\" }")
        << "macros[0].drives[0].curve: db moves a level in 0..1; gain is -96..12";
    QTest::newRow("unknown curve")
        << tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -12, \"to\": 0, \"curve\": \"log\" }")
        << "macros[0].drives[0].curve: unknown curve 'log' (lin, exp, db)";
    QTest::newRow("no such layer")
        << tinyTemplate("{ \"path\": \"layers[body].gain\", \"from\": -12, \"to\": 0 }")
        << "macros[0].drives[0].path: no layer is named 'body'";
    QTest::newRow("no such layer index")
        << tinyTemplate("{ \"path\": \"layers[3].gain\", \"from\": -12, \"to\": 0 }")
        << "macros[0].drives[0].path: there is no layer 3 (the template has 1)";
    QTest::newRow("default outside the range")
        << tinyTemplate("", "\"gain\": -6", "\"range\": [0, 0.4], ").replace("\"range\": [0, 1], ", "")
        << "macros[0].default: 0.5 is outside 0..0.4";
    QTest::newRow("the recipe itself")
        << tinyTemplate("", "\"gain\": 40")
        << "layers[0].gain: 40 is outside -96..12";
    QTest::newRow("no identity")
        << QByteArray("{ \"layers\": [ { \"source\": \"sine\", \"length\": 5 } ] }")
        << "needs a 'template' with an 'id' and a 'version'";
}

void TestSfxDesign::templateRejects()
{
    QFETCH(QByteArray, tpl);
    QFETCH(QString, error);
    const auto res = cs::SfxDesignCompiler::parseTemplate(tpl);
    QVERIFY2(!res.ok, tpl.constData());
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
}

void TestSfxDesign::designRejects_data()
{
    QTest::addColumn<QByteArray>("design");
    QTest::addColumn<QString>("error");
    QTest::newRow("another template version")
        << QByteArray("{ \"template\": { \"id\": \"tiny\", \"version\": 2 } }")
        << "template: the design is for tiny@2, the template is tiny@1";
    QTest::newRow("unknown macro")
        << tinyDesign("\"macros\": { \"wieght\": 0.3 }")
        << "macros: unknown macro 'wieght' (known: m)";
    QTest::newRow("macro outside its range")
        << tinyDesign("\"macros\": { \"m\": 1.5 }")
        << "macros.m: 1.5 is outside 0..1";
    QTest::newRow("overlapping overrides")
        << tinyDesign("\"overrides\": { \"layers[0].envelope.decay\": 9, \"layers[tone].envelope\": { \"decay\": 3 } }")
        << "overrides.layers[tone].envelope: writes where 'layers[0].envelope.decay' writes already";
    QTest::newRow("override names no layer")
        << tinyDesign("\"overrides\": { \"layers[ring].gain\": -3 }")
        << "overrides.layers[ring].gain: no layer is named 'ring'";
    QTest::newRow("override out of range")
        << tinyDesign("\"overrides\": { \"layers[0].gain\": 50 }")
        << "the compiled recipe: layers[0].gain: 50 is outside -96..12";
    QTest::newRow("unknown lock")
        << tinyDesign("\"locks\": [\"brightness\"]")
        << "locks[0]: 'brightness' is neither a macro nor a path of the template";
}

void TestSfxDesign::designRejects()
{
    QFETCH(QByteArray, design);
    QFETCH(QString, error);
    const auto res = cs::SfxDesignCompiler::compile(
        design, tinyTemplate("{ \"path\": \"layers[0].gain\", \"from\": -12, \"to\": 0 }"));
    QVERIFY(!res.ok);
    QVERIFY(res.json.isEmpty());
    QVERIFY2(res.error.startsWith(error), qPrintable(res.error));
}

void TestSfxDesign::aNullOverrideRemovesTheField()
{
    const auto res = cs::SfxDesignCompiler::compile(
        "{ \"template\": { \"id\": \"wheel-detent\", \"version\": 1 },"
        "  \"overrides\": { \"layers[body].pitch\": null, \"layers[body].vary.detune\": null } }",
        demoTemplate());
    QVERIFY2(res.ok, qPrintable(res.error));
    QCOMPARE(res.recipe.layers[1].get(P::PitchStart), 0.0);
    QVERIFY(!res.recipe.layers[1].vary[int(P::Detune)].on);
    const QJsonObject body = QJsonDocument::fromJson(res.json).object().value("layers").toArray().at(1).toObject();
    QVERIFY(!body.contains("pitch"));
    QVERIFY(!body.contains("vary"));    // the group went with its last field
}

QTEST_GUILESS_MAIN(TestSfxDesign)
#include "tst_sfx_design.moc"
