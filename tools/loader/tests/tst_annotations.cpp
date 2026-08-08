// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The annotation surface (issue #182): the store on its own, and the whole
// thing driven through real mouse and key events on a real MainWindow.

#include "clayanchorresolver.h"
#include "clayannotations.h"
#include "clayannotationstore.h"
#include "clayliveloader.h"
#include "mainwindow.h"

#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQuickItem>
#include <QQuickWidget>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>

#include <functional>

class TestAnnotations : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();

    // --- store ---
    void addsSceneAndRegion();
    void mergeKeepsAgentFields();
    void clearAddressedKeepsOpen();
    void wipeAllEmptiesTheFile();
    void detachesOnGenerationBump();
    void detachesOnViewportChange();
    void idsAreMonotonicAcrossRestart();
    void anchoredRegionSurvivesReloadAndResize();
    void dropsNotesNobodyWrote();

    // --- surface ---
    void surfaceTogglesAndFramesRegions();
    void surfaceKeepsRegionsAcrossToggle();
    void surfaceReattachesAnchoredRegionAfterReload();
    void framesRegionInTheRightThird();
    void tabFoldsThePanelAndItStaysFolded();
    void commitsFocusedNoteWhenTheSurfaceCloses();

    // --- selection pairing (replaces the leader lines) ---
    void pairsFrameAndCardBothWays();
    void scrollsOnlyWhenTheCardIsOutOfView();
    void bringsACardCreatedOffTheBottomIntoView();
    void followsTheCardThatGrowsWhileItIsWrittenIn();
    void keepsTheCaretEndOfAnOversizedCardVisible();
    void noLeaderLinesAreDrawn();
    void detachedAnnotationHighlightsNoFrame();
    void badgeStaysLegibleAtTheEdge();

    // Off unless asked for - see the comments on the slots.
    void capturesPairingShots();
    void capturesDetachedShot();

private:
    QString readIndex() const;
    QJsonArray annotationsOnDisk() const;

    QTemporaryDir m_dir;
    QString m_sandboxDir;
};

QString TestAnnotations::readIndex() const
{
    QFile f(m_sandboxDir + "/.clay/crew/annotations/index.json");
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(f.readAll());
}

QJsonArray TestAnnotations::annotationsOnDisk() const
{
    return QJsonDocument::fromJson(readIndex().toUtf8())
        .object().value("annotations").toArray();
}

void TestAnnotations::initTestCase()
{
    QVERIFY(m_dir.isValid());
    m_sandboxDir = m_dir.path();
    // The folded/unfolded state is remembered in QSettings, which is shared
    // with whatever this machine did last. Start from a known one.
    QSettings("Clayground", "LiveLoader")
        .setValue("annotations/panelCollapsed", false);
}

void TestAnnotations::addsSceneAndRegion()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(1200, 800));

    const QString scene = store.addAnnotation("scene", QRectF(), "too dark", true);
    const QString region = store.addAnnotation("region", QRectF(10, 20, 30, 40),
                                               "squashed", true);
    QCOMPARE(scene, QStringLiteral("a1"));
    QCOMPARE(region, QStringLiteral("a2"));
    QCOMPARE(store.openCount(), 2);
    QCOMPARE(store.sceneNoteId(), scene);

    const QJsonArray disk = annotationsOnDisk();
    QCOMPARE(disk.size(), 2);

    const QJsonObject s = disk.at(0).toObject();
    QCOMPARE(s.value("scope").toString(), QStringLiteral("scene"));
    QVERIFY(s.value("rect").isNull());
    QCOMPARE(s.value("note").toString(), QStringLiteral("too dark"));
    QCOMPARE(s.value("status").toString(), QStringLiteral("open"));
    QVERIFY(s.value("anchor").isNull());
    QVERIFY(s.value("crop").isNull());

    const QJsonObject r = disk.at(1).toObject();
    QCOMPARE(r.value("rect").toArray().at(2).toInt(), 30);
    const QJsonObject view = r.value("view").toObject();
    QCOMPARE(view.value("size").toArray().at(0).toInt(), 1200);
    QCOMPARE(view.value("paused").toBool(), true);
    QVERIFY(view.value("camera").isNull());

    // The store must live entirely under .clay/ - anything outside it is
    // watched, and a write there means a hot reload per keystroke.
    QVERIFY(QFile::exists(m_sandboxDir + "/.clay/crew/annotations/index.json"));
    QCOMPARE(QDir(m_sandboxDir).entryList(QDir::Files | QDir::NoDotAndDotDot).size(), 0);
}

void TestAnnotations::mergeKeepsAgentFields()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));
    const QString id = store.addAnnotation("region", QRectF(1, 2, 3, 4),
                                           "before", false);

    // An agent marks it addressed while the surface is still open.
    QJsonArray arr = annotationsOnDisk();
    QJsonObject a = arr.at(0).toObject();
    a["status"] = "addressed";
    a["addressedNote"] = "fixed the padding";
    a["addressedAt"] = "2026-08-02T10:00:00";
    a["anchor"] = QJsonObject{{"objectName", "playButton"}};
    a["crop"] = "annotations/a1.png";
    arr.replace(0, a);
    QJsonObject root;
    root["version"] = 1;
    root["annotations"] = arr;
    QFile f(m_sandboxDir + "/.clay/crew/annotations/index.json");
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(QJsonDocument(root).toJson());
    f.close();

    // The author keeps typing. The mark must survive.
    store.setNote(id, "after");

    const QJsonObject merged = annotationsOnDisk().at(0).toObject();
    QCOMPARE(merged.value("note").toString(), QStringLiteral("after"));
    QCOMPARE(merged.value("status").toString(), QStringLiteral("addressed"));
    QCOMPARE(merged.value("addressedNote").toString(),
             QStringLiteral("fixed the padding"));
    QCOMPARE(merged.value("crop").toString(),
             QStringLiteral("annotations/a1.png"));
    QCOMPARE(merged.value("anchor").toObject().value("objectName").toString(),
             QStringLiteral("playButton"));
    QCOMPARE(store.openCount(), 0);
}

void TestAnnotations::clearAddressedKeepsOpen()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));
    store.addAnnotation("region", QRectF(0, 0, 10, 10), "one", false);
    const QString two = store.addAnnotation("region", QRectF(0, 0, 10, 10),
                                            "two", false);

    QJsonArray arr = annotationsOnDisk();
    QJsonObject a = arr.at(1).toObject();
    a["status"] = "addressed";
    arr.replace(1, a);
    QJsonObject root;
    root["version"] = 1;
    root["annotations"] = arr;
    QFile f(m_sandboxDir + "/.clay/crew/annotations/index.json");
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(QJsonDocument(root).toJson());
    f.close();

    store.reload();
    store.clearAddressed();

    const QJsonArray left = annotationsOnDisk();
    QCOMPARE(left.size(), 1);
    QCOMPARE(left.at(0).toObject().value("note").toString(), QStringLiteral("one"));
    QVERIFY(two != left.at(0).toObject().value("id").toString());
}

void TestAnnotations::wipeAllEmptiesTheFile()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));
    store.addAnnotation("scene", QRectF(), "one", false);
    store.addAnnotation("region", QRectF(0, 0, 10, 10), "two", false);
    store.wipeAll();

    QCOMPARE(annotationsOnDisk().size(), 0);
    QCOMPARE(store.openCount(), 0);
}

void TestAnnotations::detachesOnGenerationBump()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));
    store.bumpGeneration();
    store.addAnnotation("region", QRectF(0, 0, 10, 10), "here", false);

    QVERIFY(store.annotations().at(0).toMap().value("attached").toBool());
    store.bumpGeneration();
    QVERIFY(!store.annotations().at(0).toMap().value("attached").toBool());
}

void TestAnnotations::detachesOnViewportChange()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));
    store.addAnnotation("region", QRectF(0, 0, 10, 10), "here", false);
    QVERIFY(store.annotations().at(0).toMap().value("attached").toBool());

    store.setViewSize(QSize(900, 600));
    QVERIFY(!store.annotations().at(0).toMap().value("attached").toBool());
}

void TestAnnotations::idsAreMonotonicAcrossRestart()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    {
        ClayAnnotationStore store;
        store.setSandboxDir(m_sandboxDir);
        store.setViewSize(QSize(800, 600));
        store.addAnnotation("region", QRectF(0, 0, 10, 10), "one", false);
        store.addAnnotation("region", QRectF(0, 0, 10, 10), "two", false);
    }

    ClayAnnotationStore restarted;
    restarted.setSandboxDir(m_sandboxDir);
    restarted.setViewSize(QSize(800, 600));
    QCOMPARE(restarted.annotations().size(), 2);
    // Nothing from an earlier run is ever drawn on the scene: the run that
    // framed it is gone, so the fingerprint cannot mean anything.
    QVERIFY(!restarted.annotations().at(0).toMap().value("attached").toBool());
    QCOMPARE(restarted.addAnnotation("region", QRectF(0, 0, 10, 10), "three",
                                     false),
             QStringLiteral("a3"));
}

// A scene that can be asked where things are, without needing one to exist.
// It answers for exactly one object and moves it on command, which is all the
// re-projection rule needs to be pinned down.
class FakeScene : public ClayAnchorResolver
{
public:
    explicit FakeScene(const QString& crewDir) : m_crewDir(crewDir) {}

    // Where the anchored object is right now.
    QPointF where{100, 100};
    bool findable = true;
    bool onScreen = true;

    // Writes the anchor into the file, exactly where ClayInspector writes it.
    QVariantMap attachAnnotation(const QString& id, const QRectF&) override
    {
        QJsonObject patch;
        patch["anchor"] = QJsonObject{{"resolved", true},
                                      {"kind", "2d"},
                                      {"objectName", "player"},
                                      {"space", "scene"}};
        patch["crop"] = QJsonValue::Null;
        QString error;
        ClayScene::Annotations::patchEntry(m_crewDir, id, patch, &error);
        return {{"stored", error.isEmpty()}};
    }

    QVariantMap reprojectAnchor(const QVariantMap& anchor) const override
    {
        Q_UNUSED(anchor)
        if (!findable)
            return {{"resolved", false}, {"reason", "the object is gone"}};
        return {{"resolved", true},
                {"x", where.x()},
                {"y", where.y()},
                {"via", "objectName"},
                {"insideViewport", onScreen}};
    }

private:
    QString m_crewDir;
};

void TestAnnotations::anchoredRegionSurvivesReloadAndResize()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    FakeScene scene(m_sandboxDir + "/.clay/crew");
    ClayAnnotationStore store;
    store.setAnchorResolver(&scene);
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));

    const QString id = store.addAnnotation("region", QRectF(90, 90, 20, 20),
                                           "this bit", false);
    QVERIFY(!id.isEmpty());
    // Nothing has moved, so re-projection must be a no-op: a frame that jumps
    // the moment it is drawn is worse than one that never follows.
    QVariantMap fresh = store.annotations().at(0).toMap();
    QVERIFY(fresh.value("attached").toBool());
    QCOMPARE(fresh.value("rectX").toDouble(), 90.0);
    QCOMPARE(fresh.value("rectY").toDouble(), 90.0);

    // Everything the fingerprint cares about changes at once: a reload, and a
    // viewport it has never seen. The anchor is what carries it through.
    store.bumpGeneration();
    store.setViewSize(QSize(900, 640));
    scene.where = QPointF(300, 250);

    QVariantMap m = store.annotations().at(0).toMap();
    QVERIFY2(m.value("attached").toBool(),
             "an anchored annotation did not re-attach after a reload");
    QVERIFY(m.value("reprojected").toBool());
    // The frame keeps its size and follows the object: it was drawn 10px up
    // and left of the anchor point, and stays that way.
    QCOMPARE(m.value("rectW").toDouble(), 20.0);
    QCOMPARE(m.value("rectX").toDouble(), 290.0);
    QCOMPARE(m.value("rectY").toDouble(), 240.0);

    // Off screen is not a place to draw a frame.
    scene.onScreen = false;
    QVERIFY(!store.annotations().at(0).toMap().value("attached").toBool());

    // Neither is "the object this was about no longer exists" - and with the
    // view changed underneath, the fingerprint cannot rescue it either.
    scene.onScreen = true;
    scene.findable = false;
    QVERIFY(!store.annotations().at(0).toMap().value("attached").toBool());
    QCOMPARE(store.annotations().at(0).toMap().value("note").toString(),
             QStringLiteral("this bit"));
}

void TestAnnotations::dropsNotesNobodyWrote()
{
    QDir(m_sandboxDir).removeRecursively();
    QDir().mkpath(m_sandboxDir);

    ClayAnnotationStore store;
    store.setSandboxDir(m_sandboxDir);
    store.setViewSize(QSize(800, 600));
    store.addAnnotation("region", QRectF(0, 0, 10, 10), "", false);
    store.addAnnotation("region", QRectF(0, 0, 10, 10), "   ", false);
    const QString written = store.addAnnotation("region", QRectF(0, 0, 10, 10),
                                                "this one means something",
                                                false);
    QCOMPARE(annotationsOnDisk().size(), 3);

    store.dropEmptyNotes();

    const QJsonArray left = annotationsOnDisk();
    QCOMPARE(left.size(), 1);
    QCOMPARE(left.at(0).toObject().value("id").toString(), written);

    // An addressed annotation is a record of a conversation, not a stray
    // click: it stays even with nothing in its note field.
    QJsonArray arr = left;
    QJsonObject a = arr.at(0).toObject();
    a["note"] = "";
    a["status"] = "addressed";
    arr.replace(0, a);
    QJsonObject root;
    root["version"] = 1;
    root["annotations"] = arr;
    QFile f(m_sandboxDir + "/.clay/crew/annotations/index.json");
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write(QJsonDocument(root).toJson());
    f.close();
    store.reload();
    store.dropEmptyNotes();
    QCOMPARE(annotationsOnDisk().size(), 1);
}

void TestAnnotations::surfaceTogglesAndFramesRegions()
{
    QTemporaryDir sbxDir;
    QVERIFY(sbxDir.isValid());
    QString sbxPath = sbxDir.path() + "/Sandbox.qml";
    // CLAY_ANN_SBX points the run at a real sandbox instead - that is how the
    // surface gets looked at over something other than a grey rectangle.
    const QString override = qEnvironmentVariable("CLAY_ANN_SBX");
    if (!override.isEmpty())
        sbxPath = override;
    else
        QVERIFY(QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath));

    // CLAY_ANN_SHOT names a directory to drop window grabs into.
    const QString shotDir = qEnvironmentVariable("CLAY_ANN_SHOT");
    int shotNr = 0;

    ClayLiveLoader loader;
    loader.addSandboxes({sbxPath});
    loader.setSbxIndex(0);

    MainWindow window(&loader);
    window.resize(1000, 700);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    // Overlays are built 200-500ms after the engine comes up.
    QTest::qWait(1500);

    auto shot = [&](const QString& tag) {
        if (shotDir.isEmpty())
            return;
        window.grab().save(QStringLiteral("%1/%2_%3.png")
                               .arg(shotDir)
                               .arg(++shotNr, 2, 10, QLatin1Char('0'))
                               .arg(tag));
    };

    auto* overlay = window.findChild<QQuickWidget*>();
    QVERIFY(overlay);
    shot("scene");

    // Ctrl+F opens the surface. On macOS the platform swaps Ctrl/Meta at
    // event-translation time, so ControlModifier is what QShortcut sees.
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);

    QQuickWidget* surface = nullptr;
    for (auto* w : window.findChildren<QQuickWidget*>()) {
        if (w->isVisible() && w->source().toString().contains("Annotation"))
            surface = w;
    }
    QVERIFY2(surface, "Ctrl+F did not bring up the annotation surface");
    auto* root = surface->rootObject();
    QVERIFY(root);

    // The scene-note field has the focus, so "type, Enter" is as fast as the
    // flag it replaces.
    shot("surface-open");
    QTest::keyClicks(surface, "the lighting is too dark");
    QTest::qWait(200);
    shot("scene-note");
    QTest::keyClick(surface, Qt::Key_Return);
    QTest::qWait(400);

    const QString sandboxDir = QFileInfo(sbxPath).absolutePath();
    const QString indexPath = sandboxDir + "/.clay/crew/annotations/index.json";
    QVERIFY2(QFile::exists(indexPath), qPrintable(indexPath));

    auto readAll = [&]() {
        QFile f(indexPath);
        f.open(QIODevice::ReadOnly);
        return QJsonDocument::fromJson(f.readAll())
            .object().value("annotations").toArray();
    };

    QJsonArray disk = readAll();
    QCOMPARE(disk.size(), 1);
    QCOMPARE(disk.at(0).toObject().value("scope").toString(),
             QStringLiteral("scene"));
    QCOMPARE(disk.at(0).toObject().value("note").toString(),
             QStringLiteral("the lighting is too dark"));
    // Enter on the scene note closes the surface, exactly as the flag did.
    QVERIFY(!surface->isVisible());

    // Back in, and this time frame a region by dragging.
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QVERIFY(surface->isVisible());

    QTest::mousePress(surface, Qt::LeftButton, {}, QPoint(120, 150));
    for (int i = 1; i <= 8; ++i)
        QTest::mouseMove(surface, QPoint(120 + i * 25, 150 + i * 15));
    QTest::mouseRelease(surface, Qt::LeftButton, {}, QPoint(320, 270));
    QTest::qWait(300);

    shot("region-framed");
    QTest::keyClicks(surface, "this platform is too high");
    QTest::qWait(900);   // the idle commit
    shot("region-note");

    disk = readAll();
    QCOMPARE(disk.size(), 2);
    QJsonObject region;
    for (const auto& v : disk)
        if (v.toObject().value("scope").toString() == "region")
            region = v.toObject();
    QVERIFY(!region.isEmpty());
    QCOMPARE(region.value("note").toString(),
             QStringLiteral("this platform is too high"));
    const QJsonArray rect = region.value("rect").toArray();
    QCOMPARE(rect.size(), 4);
    QCOMPARE(rect.at(0).toInt(), 120);
    QCOMPARE(rect.at(1).toInt(), 150);
    QCOMPARE(rect.at(2).toInt(), 200);
    QCOMPARE(rect.at(3).toInt(), 120);

    // Move it: grab the middle of the frame and drag.
    QTest::mousePress(surface, Qt::LeftButton, {}, QPoint(220, 210));
    for (int i = 1; i <= 6; ++i)
        QTest::mouseMove(surface, QPoint(220 + i * 10, 210 + i * 5));
    QTest::mouseRelease(surface, Qt::LeftButton, {}, QPoint(280, 240));
    QTest::qWait(300);

    disk = readAll();
    for (const auto& v : disk)
        if (v.toObject().value("scope").toString() == "region")
            region = v.toObject();
    const QJsonArray moved = region.value("rect").toArray();
    QVERIFY2(moved.at(0).toInt() > 120, "the frame did not move");
    QCOMPARE(moved.at(2).toInt(), 200);   // size unchanged by a move

    // Resize it: grab the bottom-right corner and pull.
    const QPoint corner(moved.at(0).toInt() + moved.at(2).toInt(),
                        moved.at(1).toInt() + moved.at(3).toInt());
    QTest::mousePress(surface, Qt::LeftButton, {}, corner);
    for (int i = 1; i <= 5; ++i)
        QTest::mouseMove(surface, corner + QPoint(i * 10, i * 8));
    QTest::mouseRelease(surface, Qt::LeftButton, {}, corner + QPoint(50, 40));
    QTest::qWait(300);

    disk = readAll();
    for (const auto& v : disk)
        if (v.toObject().value("scope").toString() == "region")
            region = v.toObject();
    const QJsonArray resized = region.value("rect").toArray();
    QVERIFY2(resized.at(2).toInt() > moved.at(2).toInt(), "the frame did not grow");
    QVERIFY2(resized.at(3).toInt() > moved.at(3).toInt(), "the frame did not grow");
    QCOMPARE(resized.at(0).toInt(), moved.at(0).toInt());   // top-left stays put

    // Esc leaves the surface, and what was written stays written.
    QTest::keyClick(surface, Qt::Key_Escape);
    QTest::qWait(400);
    QVERIFY(!surface->isVisible());
    QCOMPARE(readAll().size(), 2);

    // ... and comes back on the next Ctrl+F.
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QVERIFY(surface->isVisible());
    shot("reopened");
    QCOMPARE(root->property("regionItems").toList().size(), 1);
    QVERIFY(root->property("regionItems").toList().at(0).toMap()
                .value("attached").toBool());

    // A hot reload rebuilds the scene, so the fingerprint no longer describes
    // what is on screen: with no anchor to re-project from, the note detaches
    // into the margin instead of being drawn over pixels that may have moved.
    if (override.isEmpty()) {
        QFile sbx(sbxPath);
        QVERIFY(sbx.open(QIODevice::Append));
        sbx.write("\n// touched\n");
        sbx.close();
        QTest::qWait(4000);

        // The surface (and the widget behind it) is rebuilt with the engine.
        QQuickWidget* reborn = nullptr;
        for (auto* w : window.findChildren<QQuickWidget*>())
            if (w->source().toString().contains("Annotation"))
                reborn = w;
        QVERIFY(reborn);
        QVERIFY2(reborn->isVisible(), "the surface did not come back up");
        auto* rebornRoot = reborn->rootObject();
        QVERIFY(rebornRoot);
        shot("after-reload");

        const auto regions = rebornRoot->property("regionItems").toList();
        QCOMPARE(regions.size(), 1);
        QVERIFY2(!regions.at(0).toMap().value("attached").toBool(),
                 "the annotation stayed attached across a reload");
        QCOMPARE(regions.at(0).toMap().value("note").toString(),
                 QStringLiteral("this platform is too high"));
        QCOMPARE(readAll().size(), 2);

        // Quick clear (Ctrl+Shift+F) drops what an agent marked addressed and
        // leaves everything still open alone.
        QJsonArray arr = readAll();
        QJsonObject marked = arr.at(1).toObject();
        marked["status"] = "addressed";
        arr.replace(1, marked);
        QJsonObject rootObj;
        rootObj["version"] = 1;
        rootObj["annotations"] = arr;
        QFile idx(indexPath);
        QVERIFY(idx.open(QIODevice::WriteOnly));
        idx.write(QJsonDocument(rootObj).toJson());
        idx.close();

        QTest::keyClick(reborn, Qt::Key_F,
                        Qt::ControlModifier | Qt::ShiftModifier);
        QTest::qWait(500);
        arr = readAll();
        QCOMPARE(arr.size(), 1);
        QCOMPARE(arr.at(0).toObject().value("scope").toString(),
                 QStringLiteral("scene"));

        QTest::keyClick(reborn, Qt::Key_Escape);
        QTest::qWait(300);
    } else {
        QTest::keyClick(surface, Qt::Key_Escape);
        QTest::qWait(300);
    }
}

namespace {

QQuickWidget* annotationSurface(QWidget& window)
{
    for (auto* w : window.findChildren<QQuickWidget*>())
        if (w->source().toString().contains("Annotation"))
            return w;
    return nullptr;
}

QVariantList regionsOf(QQuickWidget* surface)
{
    auto* root = surface ? surface->rootObject() : nullptr;
    return root ? root->property("regionItems").toList() : QVariantList();
}

// Repeater delegates hang off the scene graph, not off the QObject tree, so
// findChildren() never sees them. Walk childItems() instead.
void collectItems(QQuickItem* item, const QString& name, QList<QQuickItem*>& out)
{
    if (!item)
        return;
    if (item->objectName() == name)
        out.append(item);
    const auto kids = item->childItems();
    for (auto* k : kids)
        collectItems(k, name, out);
}

QList<QQuickItem*> itemsNamed(QQuickItem* root, const QString& name)
{
    QList<QQuickItem*> out;
    collectItems(root, name, out);
    return out;
}

QQuickItem* itemNamed(QQuickItem* root, const QString& name)
{
    const auto all = itemsNamed(root, name);
    return all.isEmpty() ? nullptr : all.first();
}

} // namespace

// The report that started this round: frame a few things, Ctrl+F out, Ctrl+F
// back in - and everything is marked DETACHED with no frame on the scene. The
// margin panel is only up in one of the two states, so this is where a
// fingerprint taken against the surface's own layout would go wrong.
void TestAnnotations::surfaceKeepsRegionsAcrossToggle()
{
    QTemporaryDir sbxDir;
    QVERIFY(sbxDir.isValid());
    const QString sbxPath = sbxDir.path() + "/Sandbox.qml";
    QVERIFY(QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath));

    ClayLiveLoader loader;
    loader.addSandboxes({sbxPath});
    loader.setSbxIndex(0);

    MainWindow window(&loader);
    window.resize(1000, 700);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    QTest::qWait(1500);

    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QQuickWidget* surface = annotationSurface(window);
    QVERIFY(surface);
    QVERIFY(surface->isVisible());

    // Three plain clicks - a click makes a rect on purpose - but only the last
    // one gets written on. Enter after each: it saves the note and lets go of
    // the pair, which is what leaves the next click free to frame rather than
    // to drop the selection.
    const QList<QPoint> spots{{120, 120}, {420, 120}, {120, 420}};
    for (int i = 0; i < spots.size(); ++i) {
        QTest::mouseClick(surface, Qt::LeftButton, {}, spots.at(i));
        QTest::qWait(300);
        if (i == spots.size() - 1)
            QTest::keyClicks(surface, "the third one matters");
        QTest::keyClick(surface, Qt::Key_Return);
        QTest::qWait(250);
    }
    QCOMPARE(regionsOf(surface).size(), 3);
    for (const auto& r : regionsOf(surface))
        QVERIFY2(r.toMap().value("attached").toBool(),
                 "a region was detached the moment it was framed");

    // Out and back in on the same key the user uses.
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(500);
    QVERIFY(!surface->isVisible());
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(700);
    QVERIFY(surface->isVisible());

    // The two nobody wrote on are gone; the one that carries a remark is
    // still there AND still drawn on the scene.
    const QVariantList after = regionsOf(surface);
    QCOMPARE(after.size(), 1);
    QCOMPARE(after.at(0).toMap().value("note").toString(),
             QStringLiteral("the third one matters"));
    QVERIFY2(after.at(0).toMap().value("attached").toBool(),
             "toggling the surface off and on detached the annotation");

    QFile idx(sbxDir.path() + "/.clay/crew/annotations/index.json");
    QVERIFY(idx.open(QIODevice::ReadOnly));
    QCOMPARE(QJsonDocument::fromJson(idx.readAll())
                 .object().value("annotations").toArray().size(), 1);

    QTest::keyClick(surface, Qt::Key_Escape);
    QTest::qWait(300);
}

// The other half of attachment: a note framed on a NAMED thing comes back
// after a hot reload, re-projected onto wherever that thing is now.
void TestAnnotations::surfaceReattachesAnchoredRegionAfterReload()
{
    QTemporaryDir sbxDir;
    QVERIFY(sbxDir.isValid());
    const QString sbxPath = sbxDir.path() + "/Sandbox.qml";
    QVERIFY(QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath));

    ClayLiveLoader loader;
    loader.addSandboxes({sbxPath});
    loader.setSbxIndex(0);

    MainWindow window(&loader);
    window.resize(1000, 700);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    QTest::qWait(1500);

    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QQuickWidget* surface = annotationSurface(window);
    QVERIFY(surface);

    // TestSandbox.qml's "player" sits at 50,100 and is 16x16 - frame it.
    QTest::mousePress(surface, Qt::LeftButton, {}, QPoint(40, 90));
    for (int i = 1; i <= 4; ++i)
        QTest::mouseMove(surface, QPoint(40 + i * 10, 90 + i * 10));
    QTest::mouseRelease(surface, Qt::LeftButton, {}, QPoint(80, 130));
    QTest::qWait(400);
    QTest::keyClicks(surface, "the player is too small");
    QTest::qWait(900);

    QVariantList regions = regionsOf(surface);
    QCOMPARE(regions.size(), 1);
    QVERIFY2(regions.at(0).toMap().value("hasAnchor").toBool(),
             "framing a named item did not produce an anchor");

    // Touch the sandbox: a new engine, a new scene, a new generation - the
    // fingerprint cannot possibly still apply.
    QFile sbx(sbxPath);
    QVERIFY(sbx.open(QIODevice::Append));
    sbx.write("\n// touched\n");
    sbx.close();
    QTest::qWait(4000);

    QQuickWidget* reborn = annotationSurface(window);
    QVERIFY(reborn);
    QVERIFY2(reborn->isVisible(), "the surface did not come back up");

    regions = regionsOf(reborn);
    QCOMPARE(regions.size(), 1);
    const QVariantMap m = regions.at(0).toMap();
    QVERIFY2(m.value("attached").toBool(),
             "the anchored annotation did not re-attach after the reload");
    QVERIFY2(m.value("reprojected").toBool(),
             "it re-attached on the fingerprint instead of on its anchor");
    // The player did not move, so the frame is where it was drawn.
    QCOMPARE(qRound(m.value("rectW").toDouble()), 40);
    QCOMPARE(qRound(m.value("rectX").toDouble()), 40);
    QCOMPARE(qRound(m.value("rectY").toDouble()), 90);

    QTest::keyClick(reborn, Qt::Key_Escape);
    QTest::qWait(300);
}

namespace {

QJsonArray diskOf(const QString& sandboxDir)
{
    QFile f(sandboxDir + "/.clay/crew/annotations/index.json");
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(f.readAll())
        .object().value("annotations").toArray();
}

QJsonObject regionOnDisk(const QString& sandboxDir)
{
    for (const auto& v : diskOf(sandboxDir))
        if (v.toObject().value("scope").toString() == QLatin1String("region"))
            return v.toObject();
    return {};
}

} // namespace

// The report that started THIS round: the panel took the right third of the
// window and the scene was clipped to what was left, so the right third could
// not be framed at all - and a note re-projected into it claimed to be
// attached while its frame had been clipped away. The panel floats now, and
// the scene is the whole viewport.
void TestAnnotations::framesRegionInTheRightThird()
{
    QTemporaryDir sbxDir;
    QVERIFY(sbxDir.isValid());
    const QString sbxPath = sbxDir.path() + "/Sandbox.qml";
    QVERIFY(QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath));

    ClayLiveLoader loader;
    loader.addSandboxes({sbxPath});
    loader.setSbxIndex(0);

    MainWindow window(&loader);
    window.resize(1000, 700);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    QTest::qWait(1500);

    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QQuickWidget* surface = annotationSurface(window);
    QVERIFY(surface);
    QVERIFY(surface->isVisible());
    auto* root = surface->rootObject();
    QVERIFY(root);

    const qreal W = root->width();
    const qreal H = root->height();
    QVERIFY(W > 600 && H > 400);

    // The scene area is the whole surface: the panel takes no layout space
    // from it, so nothing in the sandbox is out of reach or reflowed.
    auto* scene = itemNamed(root, "annotationSceneArea");
    QVERIFY2(scene, "no scene area on the surface");
    QCOMPARE(scene->width(), W);
    QCOMPARE(scene->height(), H);

    // The panel floats over the bottom-right and is half the height, so the
    // top-left - where most of a scene lives - is never covered.
    auto* dock = itemNamed(root, "annotationDock");
    QVERIFY(dock);
    QVERIFY2(dock->height() < H * 0.75, "the panel still owns the full height");
    QVERIFY2(dock->y() > H * 0.25, "the panel is not parked at the bottom");

    // Frame something in the right third, above the panel.
    const QPoint from(qRound(W * 0.70), qRound(H * 0.10));
    const QPoint to(qRound(W * 0.95), qRound(H * 0.30));
    QTest::mousePress(surface, Qt::LeftButton, {}, from);
    for (int i = 1; i <= 8; ++i)
        QTest::mouseMove(surface, from + (to - from) * i / 8);
    QTest::mouseRelease(surface, Qt::LeftButton, {}, to);
    QTest::qWait(400);
    QTest::keyClicks(surface, "the right third is reachable");
    QTest::qWait(900);

    const QJsonObject region = regionOnDisk(sbxDir.path());
    QVERIFY2(!region.isEmpty(), "no region was created in the right third");
    const QJsonArray rect = region.value("rect").toArray();
    QCOMPARE(rect.size(), 4);
    QVERIFY2(rect.at(0).toInt() > W * 2.0 / 3.0,
             "the frame was clamped out of the right third");
    QCOMPARE(rect.at(0).toInt(), from.x());
    QCOMPARE(rect.at(1).toInt(), from.y());
    QCOMPARE(region.value("note").toString(),
             QStringLiteral("the right third is reachable"));

    // Kept, and actually drawn: the marker exists on the scene, is visible,
    // and sits where it was framed rather than somewhere it was clipped to.
    const QVariantList regions = regionsOf(surface);
    QCOMPARE(regions.size(), 1);
    QVERIFY2(regions.at(0).toMap().value("attached").toBool(),
             "a region framed in the right third was not attached");

    const auto markers = itemsNamed(root, "annotationRegion");
    QCOMPARE(markers.size(), 1);
    QVERIFY2(markers.at(0)->isVisible(), "the frame was not drawn");
    QCOMPARE(qRound(markers.at(0)->x()), from.x());
    QVERIFY2(markers.at(0)->x() + markers.at(0)->width() <= W + 1,
             "the frame ran off the viewport");

    QTest::keyClick(surface, Qt::Key_Escape);
    QTest::qWait(300);
}

// Tab folds the panel out of the way and brings it back, and the choice is
// remembered - a panel that unfolds itself every time the surface reopens is a
// panel you fight.
void TestAnnotations::tabFoldsThePanelAndItStaysFolded()
{
    QSettings("Clayground", "LiveLoader")
        .setValue("annotations/panelCollapsed", false);

    QTemporaryDir sbxDir;
    QVERIFY(sbxDir.isValid());
    const QString sbxPath = sbxDir.path() + "/Sandbox.qml";
    QVERIFY(QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath));

    ClayLiveLoader loader;
    loader.addSandboxes({sbxPath});
    loader.setSbxIndex(0);

    MainWindow window(&loader);
    window.resize(1000, 700);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    QTest::qWait(1500);

    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QQuickWidget* surface = annotationSurface(window);
    QVERIFY(surface);
    auto* root = surface->rootObject();
    QVERIFY(root);
    QVERIFY(!root->property("collapsed").toBool());

    auto* dock = itemNamed(root, "annotationDock");
    auto* handle = itemNamed(root, "annotationHandle");
    QVERIFY(dock && handle);
    const qreal openX = dock->x();
    const qreal W = root->width();

    QTest::keyClick(&window, Qt::Key_Tab);
    QTest::qWait(500);
    QVERIFY2(root->property("collapsed").toBool(), "Tab did not fold the panel");
    QVERIFY2(dock->x() > openX, "the panel did not move out of the way");
    // Only the handle is left on screen, and it is still there to grab.
    QVERIFY2(handle->isVisible(), "the handle went away with the panel");
    QVERIFY2(qAbs(dock->x() + handle->x() + handle->width() - W) < 2.0,
             "the handle is not the only thing left showing");

    // Out of the surface and back in: still folded.
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(500);
    QVERIFY(!surface->isVisible());
    QTest::keyClick(&window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(700);
    QVERIFY(surface->isVisible());
    QVERIFY2(annotationSurface(window)->rootObject()
                 ->property("collapsed").toBool(),
             "the folded panel unfolded itself across a surface toggle");

    // Tab brings it back, exactly where it was.
    QTest::keyClick(&window, Qt::Key_Tab);
    QTest::qWait(500);
    QVERIFY2(!root->property("collapsed").toBool(), "Tab did not unfold the panel");
    QVERIFY(qAbs(dock->x() - openX) < 2.0);

    QTest::keyClick(surface, Qt::Key_Escape);
    QTest::qWait(300);
    QSettings("Clayground", "LiveLoader")
        .setValue("annotations/panelCollapsed", false);
}

// The store commits on Enter, on focus loss and after an idle beat. None of
// the three is "the surface just went away with the cursor still in the
// field", and a note nobody can see again is worse than no note at all.
void TestAnnotations::commitsFocusedNoteWhenTheSurfaceCloses()
{
    QTemporaryDir sbxDir;
    QVERIFY(sbxDir.isValid());
    const QString sbxPath = sbxDir.path() + "/Sandbox.qml";
    QVERIFY(QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath));

    ClayLiveLoader loader;
    loader.addSandboxes({sbxPath});
    loader.setSbxIndex(0);

    auto* window = new MainWindow(&loader);
    window->resize(1000, 700);
    window->show();
    QVERIFY(QTest::qWaitForWindowExposed(window));
    QTest::qWait(1500);

    QTest::keyClick(window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    QQuickWidget* surface = annotationSurface(*window);
    QVERIFY(surface);

    // Frame something, type into it, and close the surface INSIDE the idle
    // window without ever pressing Enter or clicking away.
    QTest::mouseClick(surface, Qt::LeftButton, {}, QPoint(200, 200));
    QTest::qWait(300);
    QTest::keyClicks(surface, "still typing when it closed");
    QTest::qWait(120);   // well under the 700ms idle commit
    QTest::keyClick(window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(500);
    QVERIFY(!surface->isVisible());

    QJsonObject region = regionOnDisk(sbxDir.path());
    QVERIFY2(!region.isEmpty(),
             "the note was dropped as empty - nothing was committed on close");
    QCOMPARE(region.value("note").toString(),
             QStringLiteral("still typing when it closed"));

    // Same again, but this time the WINDOW goes away with the cursor in the
    // field. The surface never deactivates on this path.
    QTest::keyClick(window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(600);
    surface = annotationSurface(*window);
    QVERIFY(surface && surface->isVisible());
    QTest::mouseClick(surface, Qt::LeftButton, {}, QPoint(200, 450));
    QTest::qWait(300);
    QTest::keyClicks(surface, "typed as the window closed");
    QTest::qWait(120);

    window->close();
    QTest::qWait(300);
    delete window;
    QTest::qWait(200);

    const QJsonArray left = diskOf(sbxDir.path());
    bool found = false;
    for (const auto& v : left) {
        if (v.toObject().value("note").toString()
            == QLatin1String("typed as the window closed"))
            found = true;
    }
    QVERIFY2(found, "a note still being typed was lost when the window closed");
}

// ------------------------------------------------------- selection pairing
// The leader lines are gone (they crossed the floating panel, pointed at cards
// that had scrolled away, and drew nothing at all once Tab folded the panel).
// What ties a frame to its card now is the matching number plus a selection
// that lights up both ends at once.

namespace {

// Bring the surface up over a throwaway sandbox. Everything below needs the
// same six lines, and the sandbox has to outlive the window.
struct Surface
{
    QTemporaryDir dir;
    QString sbxPath;
    ClayLiveLoader loader;
    MainWindow* window = nullptr;
    QQuickWidget* widget = nullptr;
    QQuickItem* root = nullptr;

    // `over` names a real sandbox to open instead of the throwaway one - that
    // is how the surface gets looked at over something other than a grey
    // rectangle.
    bool open(const QString& over = QString())
    {
        if (!over.isEmpty()) {
            sbxPath = over;
        } else {
            if (!dir.isValid())
                return false;
            sbxPath = dir.path() + "/Sandbox.qml";
            if (!QFile::copy(QStringLiteral(SRCDIR "/TestSandbox.qml"), sbxPath))
                return false;
        }
        loader.addSandboxes({sbxPath});
        loader.setSbxIndex(0);
        window = new MainWindow(&loader);
        window->resize(1000, 700);
        window->show();
        // Raised and active on purpose: a screen capture photographs whatever
        // is in front, so a window sitting behind the terminal would produce a
        // picture of the terminal.
        window->raise();
        window->activateWindow();
        if (!QTest::qWaitForWindowExposed(window))
            return false;
        QTest::qWait(1500);
        QTest::keyClick(window, Qt::Key_F, Qt::ControlModifier);
        QTest::qWait(600);
        return refresh();
    }

    // The surface is rebuilt with the engine, so a hot reload invalidates
    // every pointer held here.
    bool refresh()
    {
        widget = annotationSurface(*window);
        root = widget ? widget->rootObject() : nullptr;
        return widget && widget->isVisible() && root;
    }

    ~Surface()
    {
        if (window) {
            window->close();
            delete window;
        }
    }
};

// Frame a region by clicking, write its note, and press Enter - which saves
// and lets go of the pair, leaving the next click free to frame.
void frameAndWrite(QQuickWidget* surface, const QPoint& at, const QString& note)
{
    QTest::mouseClick(surface, Qt::LeftButton, {}, at);
    QTest::qWait(300);
    QTest::keyClicks(surface, note);
    QTest::qWait(150);
    QTest::keyClick(surface, Qt::Key_Return);
    QTest::qWait(250);
}

// A point on a margin card, in the surface widget's coordinates. The surface
// covers the whole window at 0,0, so scene coordinates are widget ones.
QPoint pointOn(QQuickItem* card, qreal dx, qreal dy)
{
    return card->mapToScene(QPointF(dx, dy)).toPoint();
}

QPoint centreOfRegion(const QVariantMap& m)
{
    return QPoint(qRound(m.value("rectX").toDouble() + m.value("rectW").toDouble() / 2),
                  qRound(m.value("rectY").toDouble() + m.value("rectH").toDouble() / 2));
}

QQuickItem* visibleMarkerAt(QQuickItem* root, int idx)
{
    const auto markers = itemsNamed(root, "annotationRegion");
    return idx < markers.size() ? markers.at(idx) : nullptr;
}

} // namespace

// Both directions of the pairing, plus the two things that keep a selection
// meaningful: hover only previews it, and clicking empty scene drops it.
void TestAnnotations::pairsFrameAndCardBothWays()
{
    Surface s;
    QVERIFY(s.open());

    frameAndWrite(s.widget, QPoint(120, 120), "the first one");
    frameAndWrite(s.widget, QPoint(350, 120), "the second one");

    const QVariantList regions = regionsOf(s.widget);
    QCOMPARE(regions.size(), 2);
    const QString id1 = regions.at(0).toMap().value("id").toString();
    const QString id2 = regions.at(1).toMap().value("id").toString();
    // Enter let go of the pair, so nothing is carried into the test.
    QCOMPARE(s.root->property("selectedId").toString(), QString());

    auto cards = itemsNamed(s.root, "annotationCard");
    QCOMPARE(cards.size(), 2);

    // --- scene -> panel: click the frame, the card lights up ---------------
    QTest::mouseClick(s.widget, Qt::LeftButton, {},
                      centreOfRegion(regions.at(0).toMap()));
    QTest::qWait(300);
    QCOMPARE(s.root->property("selectedId").toString(), id1);
    QVERIFY2(cards.at(0)->property("selected").toBool(),
             "selecting a frame did not mark its card");
    QVERIFY(!cards.at(1)->property("selected").toBool());
    QVERIFY2(visibleMarkerAt(s.root, 0)->property("selected").toBool(),
             "the frame did not mark itself");
    QVERIFY(!visibleMarkerAt(s.root, 1)->property("selected").toBool());

    // --- panel -> scene: click the card, the frame lights up ---------------
    QTest::mouseClick(s.widget, Qt::LeftButton, {}, pointOn(cards.at(1), 5, 20));
    QTest::qWait(300);
    QCOMPARE(s.root->property("selectedId").toString(), id2);
    QVERIFY2(visibleMarkerAt(s.root, 1)->property("selected").toBool(),
             "selecting a card did not mark its frame");
    QVERIFY(!visibleMarkerAt(s.root, 0)->property("selected").toBool());

    // --- hover previews, it does not choose --------------------------------
    QTest::mouseMove(s.widget, centreOfRegion(regions.at(0).toMap()));
    QTest::qWait(300);
    QCOMPARE(s.root->property("hoveredId").toString(), id1);
    QVERIFY2(cards.at(0)->property("hovered").toBool(),
             "hovering a frame did not preview its card");
    QVERIFY2(s.root->property("selectedId").toString() == id2,
             "a hover moved the selection - hover must never choose");
    // A previewed card is never also a selected one, or the two would be
    // indistinguishable exactly where it matters.
    QVERIFY(!cards.at(0)->property("selected").toBool());
    QVERIFY(!cards.at(1)->property("hovered").toBool());

    // Off the frame again and the preview goes with it.
    QTest::mouseMove(s.widget, QPoint(560, 300));
    QTest::qWait(300);
    QCOMPARE(s.root->property("hoveredId").toString(), QString());

    // --- empty scene drops the pick, and Esc is left alone -----------------
    QTest::mouseClick(s.widget, Qt::LeftButton, {}, QPoint(560, 300));
    QTest::qWait(300);
    QCOMPARE(s.root->property("selectedId").toString(), QString());
    QVERIFY2(regionsOf(s.widget).size() == 2,
             "the deselecting click framed a region as well");
    QVERIFY2(s.widget->isVisible(), "deselecting closed the surface");

    // With nothing held, the very same click frames again.
    QTest::mouseClick(s.widget, Qt::LeftButton, {}, QPoint(560, 300));
    QTest::qWait(300);
    QCOMPARE(regionsOf(s.widget).size(), 3);
}

// The rule: bring a card into view when it cannot be seen, and do not move the
// list by so much as a pixel when it can. A list that jumps for no reason
// costs you your place.
void TestAnnotations::scrollsOnlyWhenTheCardIsOutOfView()
{
    Surface s;
    QVERIFY(s.open());

    const QList<QPoint> spots{{90, 70}, {260, 70}, {430, 70}, {90, 200}, {260, 200}};
    for (int i = 0; i < spots.size(); ++i)
        frameAndWrite(s.widget, spots.at(i), QStringLiteral("note %1").arg(i + 1));
    QCOMPARE(regionsOf(s.widget).size(), 5);

    auto* flick = itemNamed(s.root, "annotationNotes");
    QVERIFY(flick);
    // Without an overflowing list there is nothing to prove either way.
    QVERIFY2(flick->property("contentHeight").toReal() > flick->height() + 20,
             "the list fits - this test cannot say anything about scrolling");

    // The last card was brought into view as it was created, so the top of the
    // list is off screen right now.
    const qreal parked = flick->property("contentY").toReal();
    QVERIFY2(parked > 1.0, "the list never scrolled to the card being written");

    // --- out of view: the list moves --------------------------------------
    const int before = s.root->property("scrollCount").toInt();
    QTest::mouseClick(s.widget, Qt::LeftButton, {},
                      centreOfRegion(regionsOf(s.widget).at(0).toMap()));
    QTest::qWait(500);   // the scroll is animated, ~170ms
    QCOMPARE(s.root->property("scrollCount").toInt(), before + 1);
    QVERIFY2(flick->property("contentY").toReal() < parked - 1.0,
             "the first card was out of view and the list did not scroll to it");

    auto cards = itemsNamed(s.root, "annotationCard");
    QCOMPARE(cards.size(), 5);
    const qreal settled = flick->property("contentY").toReal();
    QVERIFY2(cards.at(0)->y() >= settled - 1.0
                 && cards.at(0)->y() + cards.at(0)->height()
                        <= settled + flick->height() + 1.0,
             "the card was scrolled to but still is not fully visible");

    // --- already visible: the list holds still ----------------------------
    QTest::mouseClick(s.widget, Qt::LeftButton, {},
                      centreOfRegion(regionsOf(s.widget).at(0).toMap()));
    QTest::qWait(500);
    QCOMPARE(s.root->property("scrollCount").toInt(), before + 1);
    QCOMPARE(flick->property("contentY").toReal(), settled);

    // A card picked IN the list never scrolls either - you were looking at it.
    QTest::mouseClick(s.widget, Qt::LeftButton, {}, pointOn(cards.at(1), 5, 20));
    QTest::qWait(400);
    QCOMPARE(s.root->property("scrollCount").toInt(), before + 1);
    QCOMPARE(flick->property("contentY").toReal(), settled);
}

namespace {

// Frame regions until the list of cards is longer than the panel can show.
// Everything about the scroll rule is vacuous while the list still fits, so
// the caller checks that it does not.
bool fillPastTheBottom(Surface& s, QQuickItem* flick)
{
    const QList<QPoint> spots{{90, 70}, {260, 70}, {430, 70}, {90, 200}};
    for (int i = 0; i < spots.size(); ++i)
        frameAndWrite(s.widget, spots.at(i), QStringLiteral("note %1").arg(i + 1));
    return flick->property("contentHeight").toReal() > flick->height() + 20;
}

// Is every pixel of the card inside the part of the list that is on screen?
bool fullyVisible(QQuickItem* card, QQuickItem* flick)
{
    const qreal top = flick->property("contentY").toReal();
    return card->y() >= top - 1.0
           && card->y() + card->height() <= top + flick->height() + 1.0;
}

QString placement(QQuickItem* card, QQuickItem* flick)
{
    const qreal top = flick->property("contentY").toReal();
    return QStringLiteral("card %1..%2, list shows %3..%4")
        .arg(card->y()).arg(card->y() + card->height())
        .arg(top).arg(top + flick->height());
}

} // namespace

// Case one of the report: a new card is appended to the END of the list, so
// when the list already overflows it is created out of sight - and the cursor
// goes into it anyway. Writing into something you cannot see is the complaint.
void TestAnnotations::bringsACardCreatedOffTheBottomIntoView()
{
    Surface s;
    QVERIFY(s.open());

    auto* flick = itemNamed(s.root, "annotationNotes");
    QVERIFY(flick);
    QVERIFY2(fillPastTheBottom(s, flick),
             "the list still fits - this test cannot say anything");

    // One more, and this time no Enter: this is the moment the cursor lands in
    // a card that was appended below the visible area.
    QTest::mouseClick(s.widget, Qt::LeftButton, {}, QPoint(260, 200));
    QTest::qWait(600);

    const auto cards = itemsNamed(s.root, "annotationCard");
    QCOMPARE(cards.size(), 5);
    auto* fresh = cards.last();
    QVERIFY2(fresh->property("editing").toBool(),
             "the card was created without the cursor landing in it");
    QVERIFY2(fullyVisible(fresh, flick),
             qPrintable("the new card was created out of sight: "
                        + placement(fresh, flick)));
    // And not jammed flat against the bottom edge either. A Flickable cannot
    // scroll past its own content, so the last card used to land with its
    // underside exactly on the edge - visible, but one wrapped word away from
    // not being, which from the outside looks like it never scrolled at all.
    QVERIFY2(fresh->y() + fresh->height() + 5.0
                 <= flick->property("contentY").toReal() + flick->height(),
             qPrintable("the new card landed flush against the bottom edge: "
                        + placement(fresh, flick)));
}

// Case two, and the one nothing was watching for: the card being written in
// grows as the note wraps onto another line, and the line being typed slides
// under the bottom edge. The list has to follow the card, not just the cursor.
void TestAnnotations::followsTheCardThatGrowsWhileItIsWrittenIn()
{
    Surface s;
    QVERIFY(s.open());

    auto* flick = itemNamed(s.root, "annotationNotes");
    QVERIFY(flick);
    QVERIFY2(fillPastTheBottom(s, flick),
             "the list still fits - this test cannot say anything");

    QTest::mouseClick(s.widget, Qt::LeftButton, {}, QPoint(260, 200));
    QTest::qWait(600);
    auto* card = itemsNamed(s.root, "annotationCard").last();
    QVERIFY(card && card->property("editing").toBool());

    const qreal oneLine = card->height();
    const int scrollsBefore = s.root->property("scrollCount").toInt();

    QTest::keyClicks(s.widget, "the platform hit box is wider than it looks and ");
    QTest::qWait(300);
    QTest::keyClicks(s.widget, "the player snags on the corner every single time");
    QTest::qWait(700);

    QVERIFY2(card->height() > oneLine + 10,
             "the note did not wrap - there is no growth to follow");
    QVERIFY2(s.root->property("scrollCount").toInt() > scrollsBefore,
             "the card grew past the bottom edge and the list never moved");
    QVERIFY2(fullyVisible(card, flick),
             qPrintable("the card being written in grew out of sight: "
                        + placement(card, flick)));
}

// The third case is the one where "fully visible" cannot be granted: a note
// long enough to be taller than the whole list. One end has to go over an edge,
// and it must be the top - the caret is at the bottom, and the bottom is the
// only end that being able to see is worth anything while typing.
void TestAnnotations::keepsTheCaretEndOfAnOversizedCardVisible()
{
    Surface s;
    QVERIFY(s.open());

    auto* flick = itemNamed(s.root, "annotationNotes");
    QVERIFY(flick);

    QTest::mouseClick(s.widget, Qt::LeftButton, {}, QPoint(200, 200));
    QTest::qWait(400);
    for (int i = 0; i < 8; ++i) {
        QTest::keyClicks(s.widget, "wrapping words wrapping words ");
        QTest::qWait(150);
    }
    QTest::qWait(700);

    auto* card = itemsNamed(s.root, "annotationCard").last();
    QVERIFY(card);
    QVERIFY2(card->height() > flick->height(),
             "the card never outgrew the list - nothing to choose between here");

    const qreal top = flick->property("contentY").toReal();
    const qreal bottom = card->y() + card->height();
    QVERIFY2(bottom >= top && bottom <= top + flick->height() + 1.0,
             qPrintable("the caret end of an oversized card is off screen: "
                        + placement(card, flick)));
    QVERIFY2(card->y() < top - 1.0,
             qPrintable("an oversized card was lined up by its top, which puts "
                        "the line being typed below the edge: "
                        + placement(card, flick)));
}

// Nothing is drawn between a frame and its card any more. The leader layer was
// a Canvas over the scene area and the cards grew a tail to meet it; both are
// deleted, not merely hidden.
void TestAnnotations::noLeaderLinesAreDrawn()
{
    Surface s;
    QVERIFY(s.open());

    frameAndWrite(s.widget, QPoint(120, 120), "one");
    frameAndWrite(s.widget, QPoint(350, 260), "two");
    QCOMPARE(regionsOf(s.widget).size(), 2);

    auto* scene = itemNamed(s.root, "annotationSceneArea");
    QVERIFY(scene);

    // Walk everything the scene area draws - Repeater delegates included,
    // which findChildren() would miss.
    QList<QQuickItem*> all;
    std::function<void(QQuickItem*)> walk = [&](QQuickItem* it) {
        if (!it)
            return;
        all.append(it);
        for (auto* k : it->childItems())
            walk(k);
    };
    walk(scene);
    QVERIFY(all.size() > 2);

    for (auto* it : all) {
        const QString cls = QString::fromLatin1(it->metaObject()->className());
        QVERIFY2(!cls.contains("Canvas"),
                 qPrintable("a canvas is still being drawn over the scene: "
                            + cls + " " + it->objectName()));
    }

    // The card no longer carries the leader's attachment point either.
    auto cards = itemsNamed(s.root, "annotationCard");
    QCOMPARE(cards.size(), 2);
    QVERIFY2(!cards.at(0)->property("tailPoint").isValid(),
             "the card still exposes a leader-line anchor");
    QVERIFY2(!cards.at(0)->property("tailW").isValid(),
             "the card still reserves room for a leader tail");
}

// A detached note has no place on the scene at all. Picking it must highlight
// the card and mark nothing - and say so, because silence would read as a
// broken highlight rather than as an absent frame.
void TestAnnotations::detachedAnnotationHighlightsNoFrame()
{
    Surface s;
    QVERIFY(s.open());

    // Empty space, so there is no anchor to re-project from after the reload.
    frameAndWrite(s.widget, QPoint(600, 200), "nothing in particular");
    QCOMPARE(regionsOf(s.widget).size(), 1);
    QVERIFY(regionsOf(s.widget).at(0).toMap().value("attached").toBool());

    // A new engine, a new scene: the fingerprint cannot apply any more.
    QFile sbx(s.sbxPath);
    QVERIFY(sbx.open(QIODevice::Append));
    sbx.write("\n// touched\n");
    sbx.close();
    QTest::qWait(4000);
    QVERIFY(s.refresh());

    const QVariantList regions = regionsOf(s.widget);
    QCOMPARE(regions.size(), 1);
    QVERIFY2(!regions.at(0).toMap().value("attached").toBool(),
             "the annotation did not detach across the reload");
    const QString id = regions.at(0).toMap().value("id").toString();

    // No frame is drawn for it, so there is nothing on the scene to click.
    for (auto* marker : itemsNamed(s.root, "annotationRegion"))
        QVERIFY2(!marker->isVisible(),
                 "a detached annotation is still drawn on the scene");

    auto cards = itemsNamed(s.root, "annotationCard");
    QCOMPARE(cards.size(), 1);
    QTest::mouseClick(s.widget, Qt::LeftButton, {}, pointOn(cards.at(0), 5, 20));
    QTest::qWait(300);

    QCOMPARE(s.root->property("selectedId").toString(), id);
    QVERIFY2(cards.at(0)->property("selected").toBool(),
             "picking a detached card did not mark it");
    // The card knows it has no counterpart, which is what lets it say so
    // instead of leaving you hunting the scene for a highlight.
    QVERIFY2(cards.at(0)->property("frameless").toBool(),
             "a detached card does not know that no frame corresponds to it");

    // And nothing on the scene claims to be the other end.
    for (auto* marker : itemsNamed(s.root, "annotationRegion")) {
        QVERIFY2(!(marker->isVisible() && marker->property("selected").toBool()),
                 "selecting a detached annotation marked a frame anyway");
    }
}

// The number is the only static thing that says a frame and a card belong
// together, so it may never be clipped away. It sits above the frame when
// there is room, drops inside when the frame hugs the top edge, and slides
// along to stay inside sideways - and it keeps its size when the frame is
// tiny, sticking out of a 24px frame rather than shrinking to match it.
void TestAnnotations::badgeStaysLegibleAtTheEdge()
{
    Surface s;
    QVERIFY(s.open());

    auto* scene = itemNamed(s.root, "annotationSceneArea");
    QVERIFY(scene);
    const qreal W = scene->width();
    const qreal H = scene->height();

    // Jammed into the top-left corner, and small.
    QTest::mousePress(s.widget, Qt::LeftButton, {}, QPoint(2, 2));
    for (int i = 1; i <= 4; ++i)
        QTest::mouseMove(s.widget, QPoint(2 + i * 8, 2 + i * 8));
    QTest::mouseRelease(s.widget, Qt::LeftButton, {}, QPoint(34, 34));
    QTest::qWait(300);
    QTest::keyClicks(s.widget, "in the corner");
    QTest::qWait(250);
    QTest::keyClick(s.widget, Qt::Key_Return);
    QTest::qWait(250);

    // ... and one shoved against the right edge.
    QTest::mousePress(s.widget, Qt::LeftButton, {}, QPoint(qRound(W) - 60, 300));
    for (int i = 1; i <= 4; ++i)
        QTest::mouseMove(s.widget, QPoint(qRound(W) - 60 + i * 14, 300 + i * 12));
    QTest::mouseRelease(s.widget, Qt::LeftButton, {}, QPoint(qRound(W) + 40, 350));
    QTest::qWait(300);
    QTest::keyClicks(s.widget, "against the edge");
    QTest::qWait(250);
    QTest::keyClick(s.widget, Qt::Key_Return);
    QTest::qWait(250);

    const auto badges = itemsNamed(s.root, "annotationRegionBadge");
    QCOMPARE(badges.size(), 2);
    for (auto* b : badges) {
        QVERIFY2(b->isVisible(), "a frame carries no number");
        QVERIFY2(b->width() >= 18.0 && b->height() >= 14.0,
                 "the number shrank with its frame");
        const QRectF r = b->mapRectToItem(scene,
                                          QRectF(0, 0, b->width(), b->height()));
        QVERIFY2(r.left() >= -0.5 && r.top() >= -0.5,
                 qPrintable(QStringLiteral("the number is clipped off the top "
                                           "or left: %1,%2")
                                .arg(r.left()).arg(r.top())));
        QVERIFY2(r.right() <= W + 0.5 && r.bottom() <= H + 0.5,
                 qPrintable(QStringLiteral("the number runs off the viewport: "
                                           "%1,%2").arg(r.right()).arg(r.bottom())));
    }
}

// Not a check - a camera. window.grab() re-renders each QQuickWidget on its
// own and so lies about how the surface composites over the sandbox; the only
// honest picture is one taken off the screen. Runs only when asked:
//
//   CLAY_ANN_SBX=<abs path to a Sandbox.qml> CLAY_ANN_SHOT=<dir> \
//     ./bin/tst_annotations capturesPairingShots
//
// and needs a real window server, so no offscreen platform.
void TestAnnotations::capturesPairingShots()
{
    const QString shotDir = qEnvironmentVariable("CLAY_ANN_SHOT");
    const QString sbx = qEnvironmentVariable("CLAY_ANN_SBX");
    if (shotDir.isEmpty() || sbx.isEmpty())
        QSKIP("set CLAY_ANN_SBX and CLAY_ANN_SHOT to capture the surface");
    QVERIFY2(QFile::exists(sbx), qPrintable(sbx));
    QDir().mkpath(shotDir);

    Surface s;
    QVERIFY(s.open(sbx));
    // Real sandboxes take longer than a grey rectangle to settle.
    QTest::qWait(2500);
    QVERIFY(s.refresh());

    const QString tag = QFileInfo(QFileInfo(sbx).absolutePath()).fileName();
    int nr = 0;
    auto shot = [&](const QString& what) {
        QTest::qWait(700);
        const QRect g = s.window->frameGeometry();
        QProcess::execute(
            "screencapture",
            {"-x", "-o",
             QStringLiteral("-R%1,%2,%3,%4").arg(g.x()).arg(g.y())
                 .arg(g.width()).arg(g.height()),
             QStringLiteral("%1/%2-%3-%4.png").arg(shotDir).arg(tag)
                 .arg(++nr, 2, 10, QLatin1Char('0')).arg(what)});
    };

    // What the sandbox looks like with the surface down, so the surface's own
    // effect on it can be judged rather than guessed at.
    QTest::keyClick(s.widget, Qt::Key_Escape);
    QTest::qWait(500);
    shot("scene-only");
    QTest::keyClick(s.window, Qt::Key_F, Qt::ControlModifier);
    QTest::qWait(800);
    QVERIFY(s.refresh());

    frameAndWrite(s.widget, QPoint(180, 150), "this one is too big");
    frameAndWrite(s.widget, QPoint(430, 320), "and this one is off-colour");
    frameAndWrite(s.widget, QPoint(720, 160), "third, so the list overflows");
    shot("nothing-picked");

    const QVariantList regions = regionsOf(s.widget);
    QCOMPARE(regions.size(), 3);

    // A selected pair: frame 1 gold and haloed, card 1 spined and gold-badged.
    QTest::mouseClick(s.widget, Qt::LeftButton, {},
                      centreOfRegion(regions.at(0).toMap()));
    shot("selected-pair");

    // A hovered pair beside it: gold, but no halo and no gold badge.
    //
    // Hover and the Tab shortcut both need the window to be ACTIVE in the eyes
    // of the window server, and a test process rarely gets to keep the focus
    // it asks for - synthetic moves and shortcuts silently do nothing here.
    // So the states are set through the same entry points the input paths call
    // into; that the input paths reach them is what the headless cases above
    // check. These pictures are about appearance, and appearance is the one
    // thing a headless run cannot show.
    QMetaObject::invokeMethod(s.root, "setHovered",
                              Q_ARG(QVariant, regions.at(1).toMap().value("id")),
                              Q_ARG(QVariant, true));
    shot("hovered-pair-plus-selection");
    QMetaObject::invokeMethod(s.root, "setHovered",
                              Q_ARG(QVariant, regions.at(1).toMap().value("id")),
                              Q_ARG(QVariant, false));

    // Folded away with the pick still held - the frame keeps its halo and the
    // count on the handle keeps the panel from being forgotten.
    QMetaObject::invokeMethod(s.root, "toggleCollapsed");
    shot("folded-with-selection");
    QMetaObject::invokeMethod(s.root, "toggleCollapsed");
    QTest::qWait(400);

    // A viewport change: anchored notes follow their object and keep the pair,
    // unanchored ones detach into the list. Which of the two happens is the
    // sandbox's business, not the surface's - this is here to show that the
    // pairing survives the frames moving underneath it.
    s.window->resize(1040, 700);
    QTest::qWait(1200);
    shot("after-viewport-change");

    // Leave the sandbox as it was found - these are somebody's real files.
    QTest::keyClick(s.widget, Qt::Key_Escape);
    QTest::qWait(400);
    QDir(QFileInfo(sbx).absolutePath() + "/.clay/crew/annotations")
        .removeRecursively();
}

// The detached case, photographed. It needs a hot reload to produce, so it
// runs against the THROWAWAY sandbox only - forcing a reload of somebody's
// real sandbox by writing into it is not something a capture gets to do.
// Needs CLAY_ANN_SHOT and a real window server.
void TestAnnotations::capturesDetachedShot()
{
    const QString shotDir = qEnvironmentVariable("CLAY_ANN_SHOT");
    if (shotDir.isEmpty())
        QSKIP("set CLAY_ANN_SHOT to capture the detached card");
    QDir().mkpath(shotDir);

    Surface s;
    QVERIFY(s.open());

    // One on the named "player", one over nothing: after the reload the first
    // re-projects and keeps its frame, the second has nothing to follow.
    frameAndWrite(s.widget, QPoint(58, 108), "this one is anchored");
    frameAndWrite(s.widget, QPoint(600, 300), "this one is about empty space");

    QFile sbx(s.sbxPath);
    QVERIFY(sbx.open(QIODevice::Append));
    sbx.write("\n// touched\n");
    sbx.close();
    QTest::qWait(4500);
    QVERIFY(s.refresh());

    bool picked = false;
    for (const auto& r : regionsOf(s.widget)) {
        const QVariantMap m = r.toMap();
        if (!m.value("attached").toBool()) {
            QMetaObject::invokeMethod(s.root, "selectAnnotation",
                                      Q_ARG(QVariant, m.value("id")),
                                      Q_ARG(QVariant, true));
            picked = true;
            break;
        }
    }
    QVERIFY2(picked, "nothing detached across the reload - nothing to show");

    QTest::qWait(700);
    const QRect g = s.window->frameGeometry();
    QProcess::execute("screencapture",
                      {"-x", "-o",
                       QStringLiteral("-R%1,%2,%3,%4").arg(g.x()).arg(g.y())
                           .arg(g.width()).arg(g.height()),
                       shotDir + "/detached-selected.png"});
}

QTEST_MAIN(TestAnnotations)
#include "tst_annotations.moc"
