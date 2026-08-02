// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The annotation surface (issue #182): the store on its own, and the whole
// thing driven through real mouse and key events on a real MainWindow.

#include "clayannotations.h"
#include "clayliveloader.h"
#include "mainwindow.h"

#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <QQuickWidget>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>

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

    // --- surface ---
    void surfaceTogglesAndFramesRegions();

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

QTEST_MAIN(TestAnnotations)
#include "tst_annotations.moc"
