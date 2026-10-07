// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QQuickItem>
#include <QTemporaryDir>
#include <memory>

#include "clayscenequery.h"

// A C++ object as a game would expose one: plain value properties.
class Stats : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int hp READ hp CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QPointF spawn READ spawn CONSTANT)
    Q_PROPERTY(QVariantList tiers READ tiers CONSTANT)
public:
    int hp() const { return 120; }
    QString name() const { return QStringLiteral("knight"); }
    QPointF spawn() const { return {3, 4}; }
    QVariantList tiers() const { return {18, 30, 42}; }
};

// `eval` on any object result used to answer null, because the result went
// through QJsonValue::fromVariant (#336).
class TestSceneEval : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void scalarsAndArraysComeBackAsBefore_data();
    void scalarsAndArraysComeBackAsBefore();
    void jsObjectReturnsItsMembers();
    void qmlSingletonReturnsItsProperties();
    void cppObjectReturnsItsProperties();
    void nestedQtObjectIsWalked();
    void itemReturnsValuePropertiesNotTheScene();
    void valueTypesReadAsTheirMembers();
    void jsCycleIsCutWithAMarker();
    void objectCycleIsCutWithAMarker();
    void deepNestingIsCutWithAMarker();
    void largeArrayIsCutWithAMarkerQuickly();
    void largeObjectIsCutWithAMarker();
    void functionsReadAsAMarker();
    void errorsStayPerExpression();

private:
    QJsonValue eval(const QString& expression);
    QVariant evaluate(const QString& expression);

    QTemporaryDir m_dir;
    std::unique_ptr<QQmlEngine> m_engine;
    std::unique_ptr<QQuickItem> m_root;
    Stats m_stats;
};

void TestSceneEval::initTestCase()
{
    QVERIFY(m_dir.isValid());
    QFile table(m_dir.filePath("Table.qml"));
    QVERIFY(table.open(QIODevice::WriteOnly));
    table.write(R"(pragma Singleton
import QtQuick
QtObject {
    readonly property int minDamage: 1
    readonly property var knight: ({ hp: 120, atk: 15, arcs: [60, 90] })
    function scaled(f) { return knight.atk * f }
}
)");
    table.close();
    QVERIFY(qmlRegisterSingletonType(QUrl::fromLocalFile(table.fileName()),
                                     "EvalTest", 1, 0, "Table") >= 0);
    qmlRegisterSingletonInstance("EvalTest", 1, 0, "Stats", &m_stats);

    m_engine = std::make_unique<QQmlEngine>();
    QQmlComponent component(m_engine.get());
    component.setData(R"(import QtQuick
import EvalTest
Item {
    width: 200; height: 100
    property int score: 7
    property QtObject inner: QtObject { property int n: 3; property string tag: "in" }
    property QtObject ping: QtObject { property QtObject other }
    property QtObject pong: QtObject { property QtObject other }
    Component.onCompleted: { ping.other = pong; pong.other = ping }
    Item { objectName: "child" }
}
)", QUrl());
    std::unique_ptr<QObject> created(component.create());
    QVERIFY2(created, qPrintable(component.errorString()));
    m_root.reset(qobject_cast<QQuickItem*>(created.release()));
    QVERIFY(m_root);
}

QVariant TestSceneEval::evaluate(const QString& expression)
{
    QQmlExpression expr(QQmlEngine::contextForObject(m_root.get()), m_root.get(),
                        expression);
    return expr.evaluate();
}

QJsonValue TestSceneEval::eval(const QString& expression)
{
    const QJsonObject results =
        ClayScene::evalExpressions(m_root.get(), QJsonArray{expression});
    return results.value(expression);
}

void TestSceneEval::scalarsAndArraysComeBackAsBefore_data()
{
    QTest::addColumn<QString>("expression");
    QTest::addColumn<QJsonValue>("expected");
    // Whether fromVariant already answered this, so the old answer must stand.
    QTest::addColumn<bool>("answeredBefore");
    QTest::newRow("int") << "1 + 1" << QJsonValue(2) << true;
    QTest::newRow("double") << "Math.PI" << QJsonValue(M_PI) << true;
    QTest::newRow("string") << "'stone'" << QJsonValue("stone") << true;
    QTest::newRow("bool") << "score > 3" << QJsonValue(true) << true;
    QTest::newRow("null") << "null" << QJsonValue(QJsonValue::Null) << true;
    QTest::newRow("undefined") << "undefined" << QJsonValue(QJsonValue::Null) << true;
    QTest::newRow("property") << "score" << QJsonValue(7) << true;
    QTest::newRow("C++ list") << "Stats.tiers" << QJsonValue(QJsonArray{18, 30, 42})
                              << true;
    // A JS array reaches eval as a QJSValue, which fromVariant made null too.
    QTest::newRow("JS array") << "[1, 'b', true, [2.5]]"
                              << QJsonValue(QJsonArray{1, "b", true, QJsonArray{2.5}})
                              << false;
    QTest::newRow("empty JS array") << "[]" << QJsonValue(QJsonArray{}) << false;
}

void TestSceneEval::scalarsAndArraysComeBackAsBefore()
{
    QFETCH(QString, expression);
    QFETCH(QJsonValue, expected);
    QFETCH(bool, answeredBefore);
    QCOMPARE(eval(expression), expected);
    if (answeredBefore) {
        QCOMPARE(ClayScene::toJson(evaluate(expression)),
                 QJsonValue::fromVariant(evaluate(expression)));
    } else {
        QCOMPARE(QJsonValue::fromVariant(evaluate(expression)),
                 QJsonValue(QJsonValue::Null));
    }
}

void TestSceneEval::jsObjectReturnsItsMembers()
{
    const QJsonValue v = eval("({ a: 1, b: { c: [1, 2], d: 'x' }, u: undefined })");
    const QJsonObject expected{{"a", 1},
                               {"b", QJsonObject{{"c", QJsonArray{1, 2}}, {"d", "x"}}}};
    QCOMPARE(v, QJsonValue(expected));
}

void TestSceneEval::qmlSingletonReturnsItsProperties()
{
    const QJsonObject table = eval("Table").toObject();
    QCOMPARE(table.value("minDamage"), QJsonValue(1));
    QCOMPARE(table.value("knight"),
             QJsonValue(QJsonObject{{"hp", 120}, {"atk", 15},
                                    {"arcs", QJsonArray{60, 90}}}));
    // Functions are methods, not properties: a QObject does not list them.
    QVERIFY(!table.contains("scaled"));
}

void TestSceneEval::cppObjectReturnsItsProperties()
{
    const QJsonObject stats = eval("Stats").toObject();
    QCOMPARE(stats.value("hp"), QJsonValue(120));
    QCOMPARE(stats.value("name"), QJsonValue("knight"));
    QCOMPARE(stats.value("spawn"), QJsonValue(QJsonObject{{"x", 3}, {"y", 4}}));
    QVERIFY(!stats.contains("objectName"));
}

void TestSceneEval::nestedQtObjectIsWalked()
{
    QCOMPARE(eval("inner"), QJsonValue(QJsonObject{{"n", 3}, {"tag", "in"}}));
    // An array of objects, as `enemies()` hands back.
    QCOMPARE(eval("[inner, inner]").toArray().size(), 2);
    QCOMPARE(eval("[inner, inner]").toArray().at(1).toObject().value("n"),
             QJsonValue(3));
}

void TestSceneEval::itemReturnsValuePropertiesNotTheScene()
{
    const QJsonObject root = eval("this").toObject();
    QCOMPARE(root.value("width"), QJsonValue(200));
    QCOMPARE(root.value("score"), QJsonValue(7));
    QCOMPARE(root.value("inner").toObject().value("n"), QJsonValue(3));
    // Children are `tree`'s business, the parent leads out of the result,
    // and Qt's lazy object getters (anchors, layer) are left unread.
    for (const char* skipped : {"parent", "children", "data", "anchors", "layer"})
        QVERIFY2(!root.contains(skipped), skipped);
}

void TestSceneEval::valueTypesReadAsTheirMembers()
{
    QCOMPARE(eval("Qt.vector3d(1, 2, 3)"),
             QJsonValue(QJsonObject{{"x", 1}, {"y", 2}, {"z", 3}}));
    QCOMPARE(eval("({ at: Qt.point(1, 2) })"),
             QJsonValue(QJsonObject{{"at", QJsonObject{{"x", 1}, {"y", 2}}}}));
    QCOMPARE(eval("Qt.rect(1, 2, 3, 4)"),
             QJsonValue(QJsonObject{{"x", 1}, {"y", 2}, {"width", 3}, {"height", 4}}));
    // A color was a string before and stays one.
    QCOMPARE(eval("Qt.color('#ff0000')"), QJsonValue("#ff0000"));
}

void TestSceneEval::jsCycleIsCutWithAMarker()
{
    const QJsonObject v = eval("(function() { var o = { k: 1 }; o.self = o; return o })()")
                              .toObject();
    QCOMPARE(v.value("k"), QJsonValue(1));
    QCOMPARE(v.value("self"), QJsonValue("<cut: cycle>"));
}

void TestSceneEval::objectCycleIsCutWithAMarker()
{
    const QJsonObject left = eval("ping").toObject();
    const QJsonObject right = left.value("other").toObject();
    QCOMPARE(right.value("other"), QJsonValue("<cut: cycle>"));
}

void TestSceneEval::deepNestingIsCutWithAMarker()
{
    QJsonValue v = eval("(function() { var o = {}; for (var i = 0; i < 20; ++i)"
                        " o = { next: o }; return o })()");
    int depth = 0;
    while (v.isObject()) {
        v = v.toObject().value("next");
        ++depth;
    }
    QCOMPARE(v, QJsonValue("<cut: depth>"));
    QCOMPARE(depth, 8);
}

void TestSceneEval::largeArrayIsCutWithAMarkerQuickly()
{
    QElapsedTimer timer;
    timer.start();
    const QJsonArray v = eval("Array.from({ length: 100000 }, (_, i) => i)").toArray();
    QVERIFY2(timer.elapsed() < 2000, qPrintable(QString::number(timer.elapsed())));
    QVERIFY(v.size() < 100000);
    QCOMPARE(v.first(), QJsonValue(0));
    QCOMPARE(v.last(), QJsonValue("<cut: size>"));
}

void TestSceneEval::largeObjectIsCutWithAMarker()
{
    const QJsonObject v = eval("(function() { var o = {}; for (var i = 0; i < 20000; ++i)"
                               " o['k' + i] = i; return o })()").toObject();
    QVERIFY(v.size() < 20000);
    QCOMPARE(v.value("<cut>"), QJsonValue("<cut: size>"));
}

void TestSceneEval::functionsReadAsAMarker()
{
    QCOMPARE(eval("({ f: function() {}, n: 1 })"),
             QJsonValue(QJsonObject{{"f", "<function>"}, {"n", 1}}));
}

void TestSceneEval::errorsStayPerExpression()
{
    const QJsonObject results = ClayScene::evalExpressions(
        m_root.get(), QJsonArray{"noSuchThing.x", "inner.n"});
    QVERIFY(results.value("noSuchThing.x").toObject().contains("error"));
    QCOMPARE(results.value("inner.n"), QJsonValue(3));
}

QTEST_MAIN(TestSceneEval)
#include "tst_scene_eval.moc"
